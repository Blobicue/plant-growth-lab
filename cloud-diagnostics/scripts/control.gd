extends SceneTree
const State=preload("res://control_state.gd")
func _initialize():call_deferred("run")
func compartments(w):
 var result=[]
 for p in w.plants:
  var pool={"c":0.0,"n":0.0,"w":0.0,"disconnected_n":0.0,"disconnected_w":0.0};var roots=0
  for n in p.nodes:
   for k in ["c","n","w"]:pool[k]+=n[k]
   if not n.connected:pool.disconnected_n+=n.n;pool.disconnected_w+=n.w
   if n.kind=="root" and n.connected:roots+=1
  result.append({"id":p.plant_id,"generation":p.generation,"nodes":p.nodes.size(),"connected_roots":roots,"mobile":pool,"reserve":p.reserve.duplicate()})
 return {"plants":result,"matter":w.matter_report(),"ledger":w.ledger(),"shared_air":w.air}
func row(p):return {"tick":p.tick,"age":p.tick-p.birth_tick,"nodes":p.nodes.size(),"living":p.metrics().living,"roots":p.nodes.filter(func(n):return n.kind=="root").size(),"leaves":p.nodes.filter(func(n):return n.kind=="leaf").size(),"pools":p.pools(),"reserve":p.reserve_state(),"budget":p.obs_day.duplicate(),"totals":p.totals.duplicate()}
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var a=OS.get_cmdline_user_args();var seed=int(a[0]);var id=int(a[1]);var arm=int(a[2]);var duration=int(a[3]);var w=State.new().restore("res://evidence/birth-%d-%d.bin"%[seed,id]);var target=w.plant_by_id(id)
 var birth_hash=w.fingerprint();var origin=compartments(w);var start=w.tick
 var observer=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/observer-%d-12288.json"%seed));var expected_birth=""
 for b in observer.births:
  if b.plant==id:expected_birth=b.fingerprint
 assert(birth_hash==expected_birth,"control origin must equal passive birth fingerprint")
 for p in w.plants:p.obs_last_totals={"uptake_w":p.totals.uptake_w,"uptake_n":p.totals.uptake_n}
 w.diagnostic_arm=arm;w.diagnostic_target=id
 var daily=[row(target)];var peak=0.0;var pp=0.0;var known=[]
 var ref=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/juvenile-allocation30/evidence/matrix-%d-1.json"%seed))
 while w.tick<start+duration and w.error.is_empty() and w.censored.is_empty():
  w.step();peak=maxf(peak,w.max_error())
  for p in w.plants:p.finish_observation();pp=maxf(pp,p.max_error())
  if (w.tick-start)%24==0:daily.append(row(target));target.obs_day={}
  if arm==0 and w.tick in [960,8160]:
   var expected=ref.hashes["960"] if w.tick==960 else ref.fingerprint;known.append({"tick":w.tick,"exact":w.fingerprint()==expected});assert(w.fingerprint()==expected)
 var endpoint={"fingerprint":w.fingerprint(),"tick":w.tick,"target":row(target),"world":compartments(w),"lineage":w.lineage.duplicate(true)}
 # A baseline ending before8160 can cheaply continue to that existing exact hash.
 if arm==0 and start>5000 and w.tick<8160:
  while w.tick<8160 and w.error.is_empty() and w.censored.is_empty():w.step()
  known.append({"tick":w.tick,"exact":w.fingerprint()==ref.fingerprint});assert(w.fingerprint()==ref.fingerprint)
 if arm==0 and start>8160:
  var final_ref=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-port/evidence/juvenile-allocation30-cloud-survival-%d.json"%seed))
  while w.tick<12288 and w.error.is_empty() and w.censored.is_empty():w.step()
  known.append({"tick":w.tick,"exact":w.fingerprint()==final_ref.fingerprint});assert(w.fingerprint()==final_ref.fingerprint)
 var result={"seed":seed,"id":id,"generation":target.generation,"arm":arm,"duration":duration,"origin_fingerprint":birth_hash,"origin_exact":birth_hash==expected_birth,"origin":origin,"baseline_known_hashes":known,"endpoint":endpoint,"daily":daily,"events":target.obs_events.filter(func(e):return e.tick<=endpoint.tick),"max_error":peak,"max_plant_error":pp,"error":w.error,"censored":w.censored}
 var f=FileAccess.open("res://evidence/control-%d-%d-%d-%d.json"%[seed,id,arm,duration],FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print(JSON.stringify({"seed":seed,"id":id,"arm":arm,"end_tick":endpoint.tick,"nodes":endpoint.target.nodes,"living":endpoint.target.living,"error":w.error}));w.close();quit(0 if w.error.is_empty() and w.censored.is_empty() and endpoint.tick==start+duration else 1)
