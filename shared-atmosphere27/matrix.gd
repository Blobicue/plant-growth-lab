extends SceneTree
const W=preload("res://world.gd")
func _initialize():call_deferred("run")
func cfg(seed:int,mode:int)->Dictionary:return {"seed":seed,"scenario":3,"backend":0,"water":.3,"nitrogen":.01,"light":32768.0,"slant":1,"flux":.08,"lifecycle":3,"radiation":2,"recycling":1,"decomposition":1,"carbon_access":mode}
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var outcomes=[]
 for seed in [12011,4242,7301]:
  for mode in [0,1]:
   var w=W.new(cfg(seed,mode));var samples=[];var hashes={};var peak_error=0.0
   for t in 8160:
    w.step();peak_error=maxf(peak_error,w.max_error())
    if w.tick<=960:hashes[str(w.tick)]=w.fingerprint()
    if w.tick in [96,240,480,720,960,2040,4080,8160]:samples.append(w.metrics().duplicate(true))
    if not w.error.is_empty() or not w.censored.is_empty():break
   var row={"config":w.config,"horizon":w.tick,"samples":samples,"hashes":hashes,"lineage":w.lineage,"end":w.metrics(),"max_error":peak_error,"fingerprint":w.fingerprint()}
   var f=FileAccess.open("res://evidence/matrix-%s-%s.json"%[str(seed),str(mode)],FileAccess.WRITE);f.store_string(JSON.stringify(row));f.close();print(JSON.stringify({"seed":seed,"mode":mode,"tick":w.tick,"lineage":w.lineage,"error":w.error,"censored":w.censored}));outcomes.append({"seed":seed,"mode":mode,"tick":w.tick,"lineage":w.lineage.duplicate(true),"error":w.error,"censored":w.censored});w.close()
 var f=FileAccess.open("res://evidence/outcomes.json",FileAccess.WRITE);f.store_string(JSON.stringify(outcomes,"  "));f.close();quit(0 if outcomes.all(func(x):return x.error.is_empty()) else 1)
