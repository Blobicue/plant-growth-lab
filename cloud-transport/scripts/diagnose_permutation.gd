extends SceneTree
const State=preload("res://diagnostic_state.gd")
const R=preload("res://relabel.gd")
func _initialize():call_deferred("run")
func node_differences(a,b):
 var result=[]
 for j in a.plants.size():
  var pa=a.plants[j];var pb=b.plants[j]
  for i in pa.nodes.size():
   for key in pa.nodes[i]:
    var x=pa.nodes[i][key];var y=pb.nodes[i][key]
    if x!=y:result.append({"plant":pa.id,"pos":pa.nodes[i].pos,"key":key,"a":x,"b":y,"delta":float(y)-float(x) if typeof(x) in [TYPE_FLOAT,TYPE_INT] else null})
 return result
func field_differences(a,b):
 var result=[]
 for i in a.size():
  if a[i]!=b[i]:result.append({"index":i/2,"resource":"W" if i%2==0 else "N","a_q":a[i],"b_q":b[i],"delta_q":b[i]-a[i]})
 return result
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var path="/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-12011-3.bin";var a=State.new().restore(path);var b=State.new().restore(path);R.relabel(b,b.plant_by_id(3));a.transport_substeps=24;b.transport_substeps=24
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/trial-12011-3-24.json"));var earliest={};var first_scalar={};var result={};var previous=[]
 for age in 768:
  a.phase_samples=[];b.phase_samples=[];a.audit_sample("before_hour");b.audit_sample("before_hour");a.step(true);b.step();a.audit_sample("after_hour");b.audit_sample("after_hour")
  assert(a.fingerprint()==reference.hashes[age],"passive diagnostic changed original trajectory")
  assert(a.error.is_empty() and b.error.is_empty())
  for phase in a.phase_samples.size():
   var x=a.phase_samples[phase];var y=b.phase_samples[phase];var diffs=node_differences(x,y)
   if not diffs.is_empty() and earliest.is_empty():earliest={"age":age+1,"phase":x.phase,"differences":diffs,"a":x,"b":y}
   if first_scalar.is_empty():
    for i in x.plants.size():
     for key in ["vapor","litter","heat","photo_claim"]:
      if x.plants[i][key]!=y.plants[i][key]:first_scalar={"age":age+1,"phase":x.phase,"plant":x.plants[i].id,"key":key,"a":x.plants[i][key],"b":y.plants[i][key]};break
     if not first_scalar.is_empty():break
  var fd=field_differences(a.field.full(),b.field.full())
  if not fd.is_empty():
   result={"seed":12011,"id":3,"mode":24,"first_field_difference_age":age+1,"first_field_difference_tick":a.tick,"field_differences":fd,"earliest_exact_node_difference":earliest,"earliest_scalar_difference":first_scalar,"previous_hour":previous,"a_phases":a.phase_samples,"b_phases":b.phase_samples,"baseline_fingerprint":a.fingerprint(),"relabelled_fingerprint":b.fingerprint(),"baseline_error":a.error,"relabelled_error":b.error,"purpose":"Bounded localization of failed permutation check, not a new biological arm"}
   State.new().save_world(a,"res://evidence/permutation-failure-original.bin");State.new().save_world(b,"res://evidence/permutation-failure-relabelled.bin");break
  previous=[a.phase_samples.duplicate(true),b.phase_samples.duplicate(true)]
 assert(not result.is_empty(),"expected preserved failure must reproduce")
 var f=FileAccess.open("res://evidence/permutation-failure-diagnosis.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print(JSON.stringify({"age":result.first_field_difference_age,"field_differences":result.field_differences,"first_scalar":first_scalar,"first_node_age":earliest.age,"first_node_phase":earliest.phase}));a.close();b.close();quit()
