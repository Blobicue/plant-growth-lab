extends RefCounted
var COUNT:int=2184
var dimensions:Vector3i=Vector3i(21,8,13)
var scale:float=1000000000.0
var CAP:int=100000000
const MAX_COMMANDS=513
const MAX_QUERIES=3584
var gpu:bool=false
var native
var backend:String="gdscript"
var rd:RenderingDevice
var shader:RID
var pipeline:RID
var buffers:Array=[]
var sets:Array=[]
var request_buffer:RID
var result_buffer:RID
var scratch:Array=[]
var reduction_sets:Array=[]
var parallel_reduction:bool=true
var current:int=0
var values:PackedInt32Array
var summary:Array=[]
var samples:Dictionary={}
var error:String=""
var times:Dictionary={"setup_ms":0.0,"upload_ms":0.0,"dispatch_sync_ms":0.0,"readback_ms":0.0,"cpu_field_ms":0.0,"full_readback_ms":0.0,"sparse_bytes":0,"upload_bytes":0,"full_reads":0,"steps":0}
func _init(w:PackedFloat64Array,n:PackedFloat64Array,use_gpu:bool):
 var start=Time.get_ticks_usec();dimensions=ProjectSettings.get_setting("validation/dimensions",Vector3i(21,8,13));COUNT=dimensions.x*dimensions.y*dimensions.z
 if COUNT>500000 or dimensions.x<21 or dimensions.y<8 or dimensions.z<13:error="grid exceeds declared bounds";return
 gpu=use_gpu;backend="gpu" if gpu else str(ProjectSettings.get_setting("validation/cpu","gdscript"));scale=float(ProjectSettings.get_setting("validation/scale",1000000000.0));CAP=int(round(.1*scale))
 if CAP>1000000000 or scale<1:error="precision outside validated integer range";return
 values.resize(COUNT*2)
 for i in w.size():
  if not is_finite(w[i]) or not is_finite(n[i]) or w[i]<0 or n[i]<0 or w[i]*scale>CAP or n[i]*scale>CAP:error="initial cell outside supported capacity";return
  var mapped=map_index(i);values[mapped*2]=int(round(w[i]*scale));values[mapped*2+1]=int(round(n[i]*scale))
 summary=_summary(values)
 if CAP>1000000000:error="per-cell range exceeds validated signed arithmetic";return
 if backend=="native":
  native=ClassDB.instantiate("NativeResourceField");var initial=PackedInt32Array([0,CAP,dimensions.x,dimensions.y,dimensions.z]);initial.append_array(values);native.transact(initial.to_byte_array());values=PackedInt32Array()
 if gpu:
  parallel_reduction=bool(ProjectSettings.get_setting("validation/parallel_reduction",true))
  rd=RenderingServer.create_local_rendering_device()
  if rd==null:error="Vulkan compute unavailable";return
  var source=RDShaderSource.new();source.source_compute=FileAccess.get_file_as_string("res://field.compute.txt" if parallel_reduction else "res://serial.compute.txt").replace("CAP=100000000","CAP="+str(CAP)).replace("X=21,Y=8,Z=13","X=%d,Y=%d,Z=%d"%[dimensions.x,dimensions.y,dimensions.z]);var spirv=rd.shader_compile_spirv_from_source(source)
  if spirv.compile_error_compute!="":error=spirv.compile_error_compute;return
  shader=rd.shader_create_from_spirv(spirv);pipeline=rd.compute_pipeline_create(shader)
  buffers=[rd.storage_buffer_create(COUNT*8,values.to_byte_array()),rd.storage_buffer_create(COUNT*8)]
  request_buffer=rd.storage_buffer_create(16+MAX_COMMANDS*16+MAX_QUERIES*4);result_buffer=rd.storage_buffer_create(32+MAX_COMMANDS*8+MAX_QUERIES*8)
  if parallel_reduction:
   var size=ceili(float(COUNT)/64.0)*32;scratch=[rd.storage_buffer_create(size),rd.storage_buffer_create(size)]
  for index in 2:
   var base=[_uniform(0,buffers[index]),_uniform(1,buffers[1-index]),_uniform(2,request_buffer),_uniform(3,result_buffer)]
   if parallel_reduction:
    var pair:Array=[]
    for side in 2:pair.append(rd.uniform_set_create(base+[_uniform(4,scratch[side]),_uniform(5,scratch[1-side])],shader,0))
    reduction_sets.append(pair);sets.append(pair[0])
   else:sets.append(rd.uniform_set_create(base,shader,0))
  values=PackedInt32Array()
 times.setup_ms=(Time.get_ticks_usec()-start)/1000.0
func _uniform(binding:int,rid:RID)->RDUniform:
 var u=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;u.binding=binding;u.add_id(rid);return u
func _summary(data:PackedInt32Array)->Array:
 var r=[0,0,CAP,CAP,0,0]
 for i in COUNT:
  for k in 2:r[k]+=data[i*2+k];r[k+2]=mini(r[k+2],data[i*2+k]);r[k+4]=maxi(r[k+4],data[i*2+k])
 return r
func _diffuse():
 var next=PackedInt32Array();next.resize(values.size())
 for i in COUNT:
  var x=i%dimensions.x;var z=(i/dimensions.x)%dimensions.z;var y=i/(dimensions.x*dimensions.z);var plane=dimensions.x*dimensions.z
  var adjacent=[i-1 if x>0 else -1,i+1 if x+1<dimensions.x else -1,i-dimensions.x if z>0 else -1,i+dimensions.x if z+1<dimensions.z else -1,i-plane if y>0 else -1,i+plane if y+1<dimensions.y else -1]
  for k in 2:
   var delta:int=0
   for j in adjacent:
    if j>=0:delta+=(int(values[j*2+k])-int(values[i*2+k]))*(3 if k==0 else 2)/100
   next[i*2+k]=values[i*2+k]+delta
 values=next
func map_index(i:int)->int:
 var x=i%21+(dimensions.x-21)/2;var z=(i/21)%13+(dimensions.z-13)/2;var y=i/273+dimensions.y-8
 return (y*dimensions.z+z)*dimensions.x+x
func advance(commands:Array,queries:Array)->Array:
 if not error.is_empty():return []
 for cmd in commands:
  if cmd.size()!=4 or cmd[0]<0 or cmd[0]>=2184:error="invalid logical soil command index";return []
 for q in queries:
  if q<0 or q>=2184:error="invalid logical soil sensor index";return []
 var original_queries=queries.duplicate();commands=commands.duplicate(true);queries=queries.duplicate()
 for cmd in commands:cmd[0]=map_index(cmd[0])
 for i in queries.size():queries[i]=map_index(queries[i])
 if commands.size()>MAX_COMMANDS or queries.size()>MAX_QUERIES:error="request capacity exceeded";return []
 for cmd in commands:
  if cmd.size()!=4 or cmd[0]<0 or cmd[0]>=COUNT or cmd[1]<0 or cmd[2]<0 or cmd[1]>CAP or cmd[2]>CAP or cmd[3] not in [0,1]:error="invalid exchange request";return []
 for q in queries:
  if q<0 or q>=COUNT:error="invalid sensor request";return []
 var ceiling=summary.slice(0,2)
 for cmd in commands:
  if cmd[3]==1:ceiling[0]+=cmd[1];ceiling[1]+=cmd[2]
 if ceiling[0]>COUNT*CAP or ceiling[1]>COUNT*CAP:error="deposit exceeds supported total capacity";return []
 var start=Time.get_ticks_usec();var receipts:Array=[];var old=summary.duplicate();samples={}
 if backend=="gdscript":
  _diffuse()
  for cmd in commands:
   var actual=[0,0]
   for k in 2:
    var at:int=cmd[0]*2+k;actual[k]=mini(cmd[k+1],CAP-values[at] if cmd[3]==1 else values[at]);values[at]+=actual[k] if cmd[3]==1 else -actual[k]
   receipts.append(actual)
  for q in queries:samples[q]=[values[q*2],values[q*2+1]]
  summary=_summary(values);times.cpu_field_ms+=(Time.get_ticks_usec()-start)/1000.0
 else:
  var request=PackedInt32Array([commands.size(),queries.size(),0,0])
  for cmd in commands:request.append_array(PackedInt32Array(cmd))
  request.append_array(PackedInt32Array(queries));var bytes=request.to_byte_array();var output:PackedByteArray
  if backend=="native":
   var packet=PackedInt32Array([1]).to_byte_array();packet.append_array(bytes);output=native.transact(packet);times.cpu_field_ms+=(Time.get_ticks_usec()-start)/1000.0
  else:
   rd.buffer_update(request_buffer,0,bytes.size(),bytes);times.upload_bytes+=bytes.size();times.upload_ms+=(Time.get_ticks_usec()-start)/1000.0
   start=Time.get_ticks_usec();var list=rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(list,pipeline);rd.compute_list_bind_uniform_set(list,sets[current],0)
   rd.compute_list_set_push_constant(list,PackedInt32Array([0,COUNT]).to_byte_array(),8);rd.compute_list_dispatch(list,ceili(float(COUNT)/64.0),1,1);rd.compute_list_add_barrier(list)
   rd.compute_list_set_push_constant(list,PackedInt32Array([1,COUNT]).to_byte_array(),8);rd.compute_list_dispatch(list,1,1,1)
   if parallel_reduction:
    var remaining=COUNT;var mode=2;var side=0
    while true:
     rd.compute_list_add_barrier(list);rd.compute_list_bind_uniform_set(list,reduction_sets[current][side],0);rd.compute_list_set_push_constant(list,PackedInt32Array([mode,remaining]).to_byte_array(),8)
     var groups=ceili(float(remaining)/64.0);rd.compute_list_dispatch(list,groups,1,1)
     if groups==1:break
     remaining=groups;mode=3;side=1-side
   rd.compute_list_end();rd.submit();rd.sync();current=1-current;times.dispatch_sync_ms+=(Time.get_ticks_usec()-start)/1000.0
   start=Time.get_ticks_usec();var length=32+commands.size()*8+queries.size()*8;output=rd.buffer_get_data(result_buffer,0,length);times.sparse_bytes+=length;times.readback_ms+=(Time.get_ticks_usec()-start)/1000.0
  summary=[]
  for j in 6:summary.append(output.decode_u32(j*4))
  summary[0]+=int(output.decode_u32(24))*4294967296;summary[1]+=int(output.decode_u32(28))*4294967296
  for j in commands.size():receipts.append([output.decode_u32(32+j*8),output.decode_u32(36+j*8)])
  for j in queries.size():samples[queries[j]]=[output.decode_u32(32+commands.size()*8+j*8),output.decode_u32(36+commands.size()*8+j*8)]
 var expected=old.slice(0,2)
 for j in commands.size():
  for k in 2:expected[k]+=receipts[j][k]*(1 if commands[j][3]==1 else -1)
 if summary[0]!=expected[0] or summary[1]!=expected[1] or summary[2]<0 or summary[3]<0 or summary[4]>CAP or summary[5]>CAP:error="field conservation / positivity / capacity failure"
 var remapped:Dictionary={}
 for i in queries.size():remapped[original_queries[i]]=samples[queries[i]]
 samples=remapped;times.steps+=1;return receipts
func full()->PackedInt32Array:
 if backend=="native":return native.transact(PackedInt32Array([2]).to_byte_array()).to_int32_array()
 if not gpu:return values.duplicate()
 var start=Time.get_ticks_usec();var result=rd.buffer_get_data(buffers[current]).to_int32_array();times.full_readback_ms+=(Time.get_ticks_usec()-start)/1000.0;times.full_reads+=1;return result
func close():
 native=null
 if rd==null:return
 if parallel_reduction:
  for pair in reduction_sets:
   for rid in pair:rd.free_rid(rid)
 else:
  for rid in sets:rd.free_rid(rid)
 for rid in scratch:rd.free_rid(rid)
 for rid in buffers:rd.free_rid(rid)
 for rid in [request_buffer,result_buffer,pipeline,shader]:
  if rid.is_valid():rd.free_rid(rid)
 rd.free();rd=null
