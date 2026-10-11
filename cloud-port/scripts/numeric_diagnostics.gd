extends SceneTree
const W=preload("res://world.gd")
const State=preload("res://state.gd")
var rows=[]
func bits(x):return PackedFloat64Array([float(x)]).to_byte_array().hex_encode()
func walk(raw,actual,expected,path:String,context):
 if actual is Dictionary:
  for k in actual:walk(raw[k],actual[k],expected[k],path+"/"+str(k),context)
 elif actual is Array:
  for i in actual.size():walk(raw[i],actual[i],expected[i],path+"/"+str(i),context)
 elif actual!=expected:
  var row=context.duplicate();row.merge({"path":path,"raw_full":JSON.stringify(raw,"",true,true),"raw_default":JSON.stringify(raw),"actual_full":JSON.stringify(actual,"",true,true),"expected_full":JSON.stringify(expected,"",true,true),"expected_default":JSON.stringify(expected),"expected_roundtrip_full":JSON.stringify(JSON.parse_string(JSON.stringify(expected)),"",true,true),"raw_bits":bits(raw),"actual_bits":bits(actual),"expected_bits":bits(expected)});rows.append(row)
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var candidate=W.FIELD_ID.begins_with("juvenile");var fingerprints=[]
 for seed in [12011,4242,7301]:
  for mode in ([1] if candidate else [0,1]):
   var ref=JSON.parse_string(FileAccess.get_file_as_string("res://golden/matrix-%d-%d.json"%[seed,mode]));var w
   if candidate:w=State.new().restore("res://evidence/cloud-end-%d.bin"%seed)
   else:w=W.new(ref.config)
   var ticks=[8160] if candidate else [96,240,480,720,960];var sample_index=7 if candidate else 0
   for tick in ticks:
    while w.tick<tick:w.step()
    var exact=w.fingerprint()==(ref.fingerprint if candidate else ref.hashes[str(tick)]);assert(exact)
    fingerprints.append({"seed":seed,"mode":mode,"tick":tick,"exact":exact})
    var raw=w.metrics();walk(raw,JSON.parse_string(JSON.stringify(raw)),ref.samples[sample_index],"",{"seed":seed,"mode":mode,"tick":tick});sample_index+=1
   w.close()
 var parser=[]
 for s in ["0.000000000000007105427357601","7.105427357601e-15","0.0000775966051052753","7.75966051052753e-5","0.008928","0.00892799999999999"]:
  var x=JSON.parse_string(s);parser.append({"input":s,"parsed_full":JSON.stringify(x,"",true,true),"parsed_bits":bits(x),"default":JSON.stringify(x),"second_parse_full":JSON.stringify(JSON.parse_string(JSON.stringify(x)),"",true,true)})
 var result={"rows":rows,"fingerprints":fingerprints,"parser_probes":parser,"note":"String fields preserve full_precision output and binary bits; no physics or archive changes."};var f=FileAccess.open("res://evidence/cloud-numeric-diagnostics.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print(JSON.stringify({"mismatched_scalar_rows":rows.size(),"exact_state_checkpoints":fingerprints.size()}));quit()
