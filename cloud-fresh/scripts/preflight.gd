extends SceneTree
const W=preload("res://world.gd")
const State=preload("res://state.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 assert(load("res://f1.gd")!=null and load("res://verify_f1.gd")!=null)
 var checks=[]
 for seed in [12011,4242,7301]:
  var ref=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/juvenile-allocation30/evidence/matrix-%d-1.json"%seed));var w=W.new(ref.config)
  for age in 96:
   w.step()
   for p in w.plants:p.finish_observation()
   assert(w.error.is_empty() and w.censored.is_empty());assert(w.fingerprint()==ref.hashes[str(w.tick)],"founder observer changed original hash")
  checks.append({"seed":seed,"legacy_original_hourly_hashes":96});w.close()
 var ref=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-reductions/evidence/trial-12011-3-24.json"));var w=State.new().restore("/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-12011-3.bin");w.transport_substeps=24
 for p in w.plants:p.obs_last_totals={"uptake_w":p.totals.uptake_w,"uptake_n":p.totals.uptake_n};p.obs_day={};p.obs_hour={}
 for age in 768:
  w.step()
  for p in w.plants:p.finish_observation()
  assert(w.error.is_empty() and w.censored.is_empty());assert(w.fingerprint()==ref.hashes[age],"T1 observer changed completed trajectory")
 checks.append({"seed":12011,"plant":3,"T1_completed_hourly_hashes":768});w.close()
 var f=FileAccess.open("res://evidence/preflight.json",FileAccess.WRITE);f.store_string(JSON.stringify({"pass":true,"checks":checks,"new_biology":false},"  ",true,true));f.close();print("F1 observer passes1056 original/reference hourly hashes");quit()
