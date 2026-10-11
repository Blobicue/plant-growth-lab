extends SceneTree
const W=preload("res://world.gd")
const State=preload("res://state.gd")
func _initialize():call_deferred("run")
func row(p)->Dictionary:
 return {"id":p.plant_id,"generation":p.generation,"parent":p.parent_id,"tick":p.tick,"age":p.tick-p.birth_tick,"nodes":p.nodes.size(),"living":p.metrics().living,"pools":p.pools(),"reserve":p.reserve_state(),"totals":p.totals.duplicate(),"budget":p.obs_day.duplicate(),"tips":p.tips.duplicate(true)}
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]);var horizon=int(args[1]) if args.size()>1 else 12288
 var ref=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/juvenile-allocation30/evidence/matrix-%d-1.json"%seed));var end=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-port/evidence/juvenile-allocation30-cloud-survival-%d.json"%seed))
 var w=W.new(ref.config);var births=[];var fingerprints=[];var peak=0.0;var pp=0.0;var before_count=w.plants.size()
 var stream=FileAccess.open("res://evidence/observations-%d-%d.jsonl"%[seed,horizon],FileAccess.WRITE)
 while w.tick<horizon and w.error.is_empty() and w.censored.is_empty():
  w.step();peak=maxf(peak,w.max_error())
  for p in w.plants:
   pp=maxf(pp,p.max_error());p.finish_observation()
   if p.generation>0 and (w.tick%24==0 or p.birth_tick==w.tick):
    var r=row(p);stream.store_line(JSON.stringify(r,"",true,true));p.obs_day={}
  if w.plants.size()>before_count:
   for i in range(before_count,w.plants.size()):
    var p=w.plants[i];var path="res://evidence/birth-%d-%d.bin"%[seed,p.plant_id];State.new().save_world(w,path);births.append({"plant":p.plant_id,"generation":p.generation,"tick":w.tick,"fingerprint":w.fingerprint(),"path":path,"nodes":p.nodes.duplicate(true),"field":w.field.full(),"matter":w.matter_report(),"air":w.air})
   before_count=w.plants.size()
  if w.tick in [96,240,480,720,960,8160,12288]:
   var expected=ref.hashes[str(w.tick)] if w.tick<=960 else ref.fingerprint if w.tick==8160 else end.fingerprint;var same=w.fingerprint()==expected;fingerprints.append({"tick":w.tick,"exact":same});assert(same,"passive observer changed physical state")
  if w.tick%2040==0:stream.flush();print(JSON.stringify({"seed":seed,"tick":w.tick,"births":births.size(),"error":w.error}))
 stream.close();var plants=[]
 for p in w.plants:
  if p.generation>0:plants.append({"id":p.plant_id,"generation":p.generation,"birth_tick":p.birth_tick,"genotype":p.genotype,"events":p.obs_events,"end":row(p)})
 var result={"seed":seed,"horizon":w.tick,"fingerprints":fingerprints,"births":births,"plants":plants,"max_error":peak,"max_plant_error":pp,"error":w.error,"censored":w.censored}
 var f=FileAccess.open("res://evidence/observer-%d-%d.json"%[seed,horizon],FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();w.close();quit(0 if w.tick==horizon and w.error.is_empty() and w.censored.is_empty() else 1)
