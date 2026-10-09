extends SceneTree
const C=preload("res://checkpoint.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]);var mode=int(args[1])
 var w=C.restore("../seedling-diagnostics28/evidence/birth-%s.bin"%seed);w.target_id=w.plants[2].plant_id;w.policy_mode=mode
 var start_hash=w.fingerprint();var rows=[];var samples=[];var peak=0.0
 for t in 3072:
  w.step();peak=maxf(peak,w.max_error())
  if t<768 or w.tick%24==0:rows.append(w.plants[2].hour.duplicate(true))
  if t+1 in [768,1536,3072]:samples.append(w.metrics().duplicate(true))
  if (t+1)%768==0:print(seed," ",mode," age=",t+1," nodes=",w.plants[2].nodes.size())
  if not w.error.is_empty() or not w.censored.is_empty():break
 var f=FileAccess.open("res://evidence/matched-%s-%s.json"%[seed,mode],FileAccess.WRITE)
 f.store_string(JSON.stringify({"seed":seed,"mode":mode,"start_hash":start_hash,"end":w.metrics(),"samples":samples,"rows":rows,"events":w.plants[2].events,"max_error":peak,"fingerprint":w.fingerprint(),"error":w.error,"censored":w.censored}));f.close();w.close();quit()
