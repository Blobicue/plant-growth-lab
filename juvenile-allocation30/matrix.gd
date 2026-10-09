extends SceneTree
const W=preload("res://world.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var seed=int(OS.get_cmdline_user_args()[0]);var cfg={"seed":seed,"scenario":3,"backend":0,"water":.3,"nitrogen":.01,"light":32768.0,"slant":1,"flux":.08,"lifecycle":3,"radiation":2,"recycling":1,"decomposition":1,"carbon_access":1}
 var w=W.new(cfg);var samples=[];var hashes={};var history=[];var peak=0.0;var perplant_peak=0.0
 for t in 8160:
  w.step();peak=maxf(peak,w.max_error())
  for p in w.plants:perplant_peak=maxf(perplant_peak,p.max_error())
  if w.tick<=960:hashes[str(w.tick)]=w.fingerprint()
  if w.tick in [96,240,480,720,960,2040,4080,8160]:samples.append(w.metrics().duplicate(true))
  if w.tick%24==0:
   var records=[]
   for p in w.plants:records.append({"id":p.plant_id,"parent":p.parent_id,"generation":p.generation,"birth":p.birth_tick,"data":p.metrics(),"reserve":p.reserve_state()})
   history.append({"tick":w.tick,"plants":records})
  if w.tick%960==0:print(seed," ",w.tick," births=",w.lineage.size())
  if not w.error.is_empty() or not w.censored.is_empty():break
 var data={"config":w.config,"horizon":w.tick,"samples":samples,"hashes":hashes,"history":history,"lineage":w.lineage,"end":w.metrics(),"max_error":peak,"max_plant_error":perplant_peak,"fingerprint":w.fingerprint()}
 var f=FileAccess.open("res://evidence/matrix-%s-1.json"%seed,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close();var ok=w.error.is_empty() and w.censored.is_empty() and w.tick==8160;w.close();quit(0 if ok else 1)
