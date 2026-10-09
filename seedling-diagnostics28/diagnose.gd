extends SceneTree
const W=preload("res://diagnostic_world.gd")
const C=preload("res://checkpoint.gd")
func _initialize():call_deferred("run")
func cfg(seed:int)->Dictionary:return {"seed":seed,"scenario":3,"backend":0,"water":.3,"nitrogen":.01,"light":32768.0,"slant":1,"flux":.08,"lifecycle":3,"radiation":2,"recycling":1,"decomposition":1,"carbon_access":1}
func write_json(path:String,data):
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]) if args.size()>0 else 12011
 var baseline=JSON.parse_string(FileAccess.get_file_as_string("../shared-atmosphere27/evidence/matrix-%s-1.json"%seed))
 var w=W.new(cfg(seed));var checkpoint="res://evidence/birth-%s.bin"%seed;var saved=false;var mismatch=[];var samples=[];var peak=0.0
 var trace=FileAccess.open("res://evidence/baseline-%s.jsonl"%seed,FileAccess.WRITE)
 for t in 8160:
  w.step();peak=maxf(peak,w.max_error())
  if w.tick<=960 and w.fingerprint()!=baseline.hashes[str(w.tick)]:mismatch.append(w.tick)
  if not saved and w.plants.size()>2:C.save_world(w,checkpoint);saved=true
  for p in w.plants:
   if p.generation>0 and (w.tick-p.birth_tick<=768 or w.tick%24==0):trace.store_line(JSON.stringify(p.hour))
  if w.tick in [96,240,480,720,960,2040,4080,8160]:samples.append(w.metrics().duplicate(true))
  if w.tick%480==0:print("baseline ",seed," ",w.tick)
  if not w.error.is_empty() or not w.censored.is_empty():break
 trace.close()
 var events={}
 for p in w.plants:
  if p.generation>0:events[str(p.plant_id)]=p.events
 write_json("res://evidence/baseline-%s.json"%seed,{"samples":samples,"end":w.metrics(),"mismatches":mismatch,"max_error":peak,"events":events,"fingerprint":w.fingerprint(),"reference_fingerprint":baseline.fingerprint})
 w.close()
 if not mismatch.is_empty():quit(2);return
 for mode in 4:
  w=C.restore(checkpoint);w.target_id=w.plants[2].plant_id;w.policy_mode=mode
  var start_hash=w.fingerprint();var rows=[];peak=0.0
  for t in 768:
   w.step();peak=maxf(peak,w.max_error());rows.append(w.plants[2].hour.duplicate(true))
  write_json("res://evidence/matched-%s-%s.json"%[seed,mode],{"seed":seed,"mode":mode,"start_hash":start_hash,"end":w.metrics(),"rows":rows,"events":w.plants[2].events,"max_error":peak,"fingerprint":w.fingerprint()})
  print("matched ",seed," ",mode," nodes=",w.plants[2].nodes.size());w.close()
 quit()
