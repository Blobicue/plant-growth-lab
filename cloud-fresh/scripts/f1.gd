extends SceneTree
const W=preload("res://world.gd")
const State=preload("res://state.gd")
const O=preload("res://reduction_order.gd")
const ROOT="/workspace/plant-growth-lab/cloud-fresh/work/model/evidence/"
func _initialize():call_deferred("run")
func write_json(path,data):
 var f=FileAccess.open(path+".tmp",FileAccess.WRITE);assert(f!=null);f.store_string(JSON.stringify(data,"",true,true));f.close();assert(DirAccess.rename_absolute(path+".tmp",path)==OK)
func save(w,path):
 State.new().save_world(w,path+".tmp");assert(DirAccess.rename_absolute(path+".tmp",path)==OK)
func row(p):
 return {"id":p.plant_id,"parent":p.parent_id,"generation":p.generation,"birth_tick":p.birth_tick,"age":p.tick-p.birth_tick,"genotype":p.genotype,"paid":p.nodes.size(),"living":p.metrics().living,"roots":p.nodes.filter(func(n):return n.kind=="root").size(),"connected_roots":p.nodes.filter(func(n):return n.kind=="root" and n.connected).size(),"leaves":p.nodes.filter(func(n):return n.kind=="leaf").size(),"pools":p.pools(),"reserve":p.reserve_state(),"totals":p.totals.duplicate(),"budget":p.obs_day.duplicate(),"cumulative":p.f1_total.duplicate(),"windows":p.f1_windows.duplicate(true),"fronts":p.f1_fronts.duplicate(true),"events":p.obs_events.duplicate(true)}
func environment(w):
 return {"ledger":w.ledger(),"matter":w.matter_report(),"radiation":w.radiation_report(),"hydrology":w.hydrology_report(),"decomposition":w.decomposition_report(),"soil_totals":w.field.summary.duplicate(),"air":w.air,"detritus":w.detritus.duplicate(),"lineage":w.lineage.duplicate(true),"propagules":w.propagules.duplicate(true),"contested":w.contested,"limited":w.limited,"space_conflicts":w.space_conflicts,"allocation_residual":w.allocation_residual}
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]);var mode=int(args[1]);assert(seed in [12011,4242,7301] and mode in [0,24])
 var dir=ROOT+"f1-%d-%d/"%[seed,mode];DirAccess.make_dir_recursive_absolute(dir)
 var ref=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/juvenile-allocation30/evidence/matrix-%d-1.json"%seed));var prior=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-port/evidence/juvenile-allocation30-cloud-survival-%d.json"%seed))
 var w;var peak=0.0;var pp=0.0;var hashes=[];var initial
 if FileAccess.file_exists(dir+"latest.json"):
  var last=JSON.parse_string(FileAccess.get_file_as_string(dir+"latest.json"));w=State.new().restore(dir+last.state);assert(w.tick==int(last.tick));assert(w.transport_substeps==mode);peak=last.max_world_error;pp=last.max_plant_error;initial=JSON.parse_string(FileAccess.get_file_as_string(dir+"initial.json"));print("RESUME %d/%d tick%d"%[seed,mode,w.tick])
 else:
  w=W.new(ref.config);w.transport_substeps=mode;var plants=[]
  for p in w.plants:plants.append({"row":row(p),"nodes":p.nodes.duplicate(true)});p.obs_last_totals={"uptake_w":p.totals.uptake_w,"uptake_n":p.totals.uptake_n}
  initial={"seed":seed,"mode":mode,"config":w.config,"fingerprint":w.fingerprint(),"environment":environment(w),"plants":plants};write_json(dir+"initial.json",initial);save(w,dir+"state-00000.bin")
 var golden=[]
 while w.tick<12288:
  var before=w.plants.size();w.step();peak=maxf(peak,w.max_error())
  assert(w.error.is_empty() and w.censored.is_empty(),w.error+" "+w.censored);assert(w.allocation_residual==0)
  for p in w.plants:
   assert(O.ids(p)==range(p.nodes.size()),"physical chronology changed");p.finish_observation();pp=maxf(pp,p.max_error())
  var fingerprint=w.fingerprint();hashes.append(fingerprint)
  if mode==0 and (w.tick<=960 or w.tick in [8160,12288]):
   var expected=ref.hashes[str(w.tick)] if w.tick<=960 else ref.fingerprint if w.tick==8160 else prior.fingerprint
   assert(fingerprint==expected,"fresh legacy R1 original physical golden mismatch at "+str(w.tick))
   if w.tick in [96,960,8160,12288]:golden.append({"tick":w.tick,"exact":true})
  for i in range(before,w.plants.size()):
   var p=w.plants[i];write_json(dir+"birth-%d.json"%p.plant_id,{"tick":w.tick,"plant":row(p),"nodes":p.nodes.duplicate(true),"fingerprint":fingerprint,"environment":environment(w)});save(w,dir+"birth-%d.bin"%p.plant_id)
  if w.tick%24==0:
   var plants=[]
   for p in w.plants:plants.append(row(p));p.obs_day={}
   var day={"tick":w.tick,"seed":seed,"mode":mode,"hashes":hashes,"plants":plants,"environment":environment(w),"max_world_error":peak,"max_plant_error":pp,"golden":golden};hashes=[];golden=[]
   write_json(dir+"day-%05d.json"%w.tick,day);var filename="state-%05d.bin"%w.tick;save(w,dir+filename)
   write_json(dir+"latest.json",{"tick":w.tick,"state":filename,"fingerprint":fingerprint,"max_world_error":peak,"max_plant_error":pp})
  if w.tick%768==0:print(JSON.stringify({"seed":seed,"mode":mode,"tick":w.tick,"plants":w.plants.size(),"max_world_error":peak,"max_plant_error":pp}))
 var plants=[]
 for p in w.plants:plants.append(row(p))
 write_json(dir+"complete.json",{"complete":true,"seed":seed,"mode":mode,"tick":w.tick,"initial_fingerprint":initial.fingerprint,"fingerprint":w.fingerprint(),"max_world_error":peak,"max_plant_error":pp,"plants":plants,"environment":environment(w),"error":w.error,"censored":w.censored})
 w.close();quit()
