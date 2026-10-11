extends SceneTree
const O=preload("res://reduction_order.gd")
const State=preload("res://state.gd")
const R=preload("res://relabel.gd")
var max_node_difference=0.0
var max_state_difference=0.0
func _initialize():call_deferred("run")
func compare(a,b,tolerance:float,path:String=""):
 if typeof(a) in [TYPE_FLOAT,TYPE_INT] and typeof(b) in [TYPE_FLOAT,TYPE_INT]:
  var delta=absf(float(a)-float(b));max_state_difference=maxf(max_state_difference,delta);assert(delta<=tolerance,"canonical numeric difference "+path+" "+str(delta));return
 assert(typeof(a)==typeof(b),"canonical type "+path)
 if a is Dictionary:
  assert(a.size()==b.size(),"canonical keys "+path)
  for k in a:assert(b.has(k),"canonical missing key "+path);compare(a[k],b[k],tolerance,path+"/"+str(k))
 elif a is Array or a is PackedFloat64Array or a is PackedInt64Array or a is PackedInt32Array:
  assert(a.size()==b.size(),"canonical length "+path)
  for i in a.size():compare(a[i],b[i],tolerance,path+"/"+str(i))
 else:assert(a==b,"canonical value "+path+" "+str(a)+" vs "+str(b))
func plant_canonical(p):
 var d=p.snapshot();d.nodes=R.canonical(p)
 for t in d.tips:t.node=p.nodes[t.node].pos
 for q in d.proposals:
  for k in ["parent","front"]:q[k]=p.nodes[q[k]].pos
 if d.has("reserve"):
  var mapped={}
  for k in d.reserve.sources:
   var pieces=k.split(":");mapped[str(p.nodes[int(pieces[0])].pos)+":"+pieces[1]]=d.reserve.sources[k]
  d.reserve.sources=mapped
  for e in d.reserve.recent:e.node=p.nodes[e.node].pos
 return d
func check_nodes(a,b):
 assert(a.plants.size()==b.plants.size(),"plant birth sequence")
 for p in a.plants:
  var ca=R.canonical(p);var cb=R.canonical(b.plant_by_id(p.plant_id))
  assert(ca==cb,"R1 exact canonical physical nodes")
  compare(ca,cb,1e-12,"nodes/"+str(p.plant_id))
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]);var id=int(args[1]);var mode=int(args[2]);assert(mode in [0,24,48])
 var base="/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-%d-%d.bin"%[seed,id];var name="trial-%d-%d-%d"%[seed,id,mode]
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/"+name+".json"));var w=State.new().restore(base);var perm=null;w.transport_substeps=mode
 if mode>0:
  perm=State.new().restore(base);R.relabel(perm,perm.plant_by_id(id));perm.transport_substeps=mode
 var peak=0.0;var pp=0.0
 for age in 768:
  w.step(true)
  for p in w.plants:assert(O.ids(p)==range(p.nodes.size()),"R1 chronology unchanged")
  assert(w.fingerprint()==reference.hashes[age],"reverse/restart every-hour hash")
  assert(w.error.is_empty() and w.censored.is_empty())
  if mode>0:
   perm.step();assert(perm.error.is_empty() and perm.censored.is_empty());check_nodes(w,perm)
   assert(w.field.full()==perm.field.full(),"canonical exact finite field")
   for k in ["C","N","W","E"]:assert(absf(w.ledger()[k]-perm.ledger()[k])<=1e-9,"canonical world ledger")
  for world in [w,perm] if mode>0 else [w]:
   peak=maxf(peak,world.max_error());assert(world.allocation_residual==0)
   for p in world.plants:pp=maxf(pp,p.max_error())
  if age==383:
   var checkpoint="res://evidence/verify-%d-%d-%d-384.bin"%[seed,id,mode];State.new().save_world(w,checkpoint);w.close();w=State.new().restore(checkpoint);assert(w.fingerprint()==reference.hashes[age])
  if (age+1)%192==0:print("verified %d/%d mode%d age%d"%[seed,id,mode,age+1])
 if mode>0:
  for p in w.plants:compare(plant_canonical(p),plant_canonical(perm.plant_by_id(p.plant_id)),1e-9,"plant endpoint")
  for k in ["lineage","propagules","life_events","detritus","initial","hydro_sources","hydro_rain_cells","decomp_sources","intercepted","shadow_loss"]:compare(w.get(k),perm.get(k),1e-9,"world/"+k)
  perm.close()
 var result={"numerical_contract":"R1","original_chronological_order_preserved":true,"exact_canonical_nodes":mode>0,"seed":seed,"id":id,"mode":mode,"reverse_saved_replay_hours_exact":768,"restart_age":384,"canonical_node_and_field_hours_checked":768 if mode>0 else 0,"canonical_endpoint_checked":mode>0,"max_canonical_numeric_difference":max_state_difference,"max_world_error":peak,"max_plant_error":pp,"pass":true}
 var f=FileAccess.open("res://evidence/verify-%d-%d-%d.json"%[seed,id,mode],FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();w.close();quit()
