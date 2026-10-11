extends SceneTree
func _initialize():
 var outcomes=[]
 for seed in [12011,4242,7301]:
  var ref=JSON.parse_string(FileAccess.get_file_as_string("res://golden/matrix-%d-1.json"%seed));var failed=[]
  for sample in ref.samples:
   if JSON.parse_string(JSON.stringify(sample))!=sample:failed.append(sample.tick)
  outcomes.append({"seed":seed,"non_idempotent_json_sample_ticks":failed})
 var f=FileAccess.open("res://evidence/cloud-json-roundtrip.json",FileAccess.WRITE);f.store_string(JSON.stringify(outcomes,"  "));f.close();print(JSON.stringify(outcomes));quit()
