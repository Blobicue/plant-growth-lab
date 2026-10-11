extends SceneTree
const State=preload("res://state.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var seed=int(OS.get_cmdline_user_args()[0]);var w=State.new().restore("res://evidence/cloud-end-%d.bin"%seed)
 var reverse=State.new().restore("res://evidence/cloud-end-%d.bin"%seed);var order_equal=true
 var original=JSON.parse_string(FileAccess.get_file_as_string("res://golden/matrix-%d-1.json"%seed));var start=w.fingerprint()==original.fingerprint and w.tick==8160
 if not start:push_error("ordinary continuation origin mismatch");quit(1);return
 var history=[];var peak=0.0;var plant_peak=0.0
 while w.tick<12288 and w.error.is_empty() and w.censored.is_empty():
  w.step();reverse.step(true);order_equal=order_equal and w.fingerprint()==reverse.fingerprint() and reverse.error.is_empty() and reverse.censored.is_empty();peak=maxf(peak,w.max_error())
  for p in w.plants:plant_peak=maxf(plant_peak,p.max_error())
  if w.tick%960==0:print(JSON.stringify({"progress_seed":seed,"tick":w.tick,"births":w.lineage.size(),"order_exact_so_far":order_equal,"error":w.error}))
  if w.tick%24==0:
   var plants=[]
   for p in w.plants:plants.append({"id":p.plant_id,"parent":p.parent_id,"generation":p.generation,"nodes":p.nodes.size(),"living":p.metrics().living,"leaves":p.metrics().leaves,"reserve":p.reserve.duplicate(),"reason":p.reserve_reason})
   history.append({"tick":w.tick,"plants":plants})
 State.new().save_world(w,"res://evidence/cloud-final-%d.bin"%seed)
 var result={"seed":seed,"allocation_order_exact_every_hour":order_equal,"origin_tick":8160,"origin_exact":start,"horizon":w.tick,"lineage":w.lineage,"daily":history,"end":w.metrics(),"fingerprint":w.fingerprint(),"max_error":peak,"max_plant_error":plant_peak,"error":w.error,"censored":w.censored,"protocol":"Unchanged ordinary conditions; continuation to existing12288h bound; no interventions, parameter changes or site clearing."}
 var f=FileAccess.open("res://evidence/cloud-survival-%d.json"%seed,FileAccess.WRITE);f.store_string(JSON.stringify(result));f.close();print(JSON.stringify({"seed":seed,"tick":w.tick,"lineage":w.lineage,"error":w.error,"censored":w.censored}));w.close();reverse.close();quit(0 if order_equal and w.tick==12288 and w.error.is_empty() and w.censored.is_empty() else 1)
