extends SceneTree
const State=preload("res://state.gd")
func _initialize():call_deferred("run")
func health(w):
 var out=[]
 for p in w.plants:out.append({"id":p.plant_id,"generation":p.generation,"paid":p.nodes.size(),"living":p.metrics().living,"paid_roots":p.nodes.filter(func(n):return n.kind=="root").size(),"connected_roots":p.nodes.filter(func(n):return n.kind=="root" and n.connected).size(),"fixed_C":p.totals.fixed_c,"expired":p.totals.expired,"reserve":p.reserve.duplicate(),"pools":p.pools()})
 return out
func row(p):return {"tick":p.tick,"age":p.tick-p.birth_tick,"nodes":p.nodes.size(),"living":p.metrics().living,"roots":p.nodes.filter(func(n):return n.kind=="root").size(),"connected_roots":p.nodes.filter(func(n):return n.kind=="root" and n.connected).size(),"leaves":p.nodes.filter(func(n):return n.kind=="leaf").size(),"pools":p.pools(),"reserve":p.reserve_state(),"budget":p.obs_day.duplicate(),"totals":p.totals.duplicate()}
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var a=OS.get_cmdline_user_args();var seed=int(a[0]);var id=int(a[1]);var mode=int(a[2]);assert(mode in [0,24,48])
 var w=State.new().restore("/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-%d-%d.bin"%[seed,id]);var target=w.plant_by_id(id);var origin=w.fingerprint();var start=w.tick
 var plan=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-transport/protocol.json"));var cohort=plan.cohorts.filter(func(c):return int(c.seed)==seed and int(c.id)==id)[0];assert(origin==cohort.fingerprint)
 w.transport_substeps=mode
 for p in w.plants:p.obs_last_totals={"uptake_w":p.totals.uptake_w,"uptake_n":p.totals.uptake_n};p.obs_day={};p.obs_events=[];p.obs_seen={}
 var daily=[row(target)];var world_daily=[health(w)];var hourly=[];var hashes=[];var peak=0.0;var pp=0.0;var initial_ledger=w.ledger();var max_sender=0.0
 for age in 768:
  w.step();peak=maxf(peak,w.max_error())
  for p in w.plants:p.finish_observation();pp=maxf(pp,p.max_error());max_sender=maxf(max_sender,float(p.transport_last.get("maximum_sender_fraction",0.0)))
  assert(w.error.is_empty() and w.censored.is_empty(),w.error+" "+w.censored);assert(w.tick==start+age+1 and w.allocation_residual==0)
  hashes.append(w.fingerprint())
  if age<96:
   var fronts=[]
   for q in target.proposals:
    if q.state=="developing":fronts.append({"kind":q.kind,"front":target.nodes[q.front].pos,"C":target.nodes[q.front].c,"N":target.nodes[q.front].n,"W":target.nodes[q.front].w,"deadline":q.deadline,"blocked":q.blocked})
   hourly.append({"age":age+1,"budget":target.obs_hour.duplicate(),"fronts":fronts,"roots":target.nodes.filter(func(n):return n.kind=="root").size(),"pools":target.pools()})
  if (age+1)%24==0:daily.append(row(target));world_daily.append(health(w));target.obs_day={}
  if (age+1)%192==0:print(JSON.stringify({"seed":seed,"id":id,"mode":mode,"age":age+1,"paid":target.nodes.size(),"living":target.metrics().living}))
 var name="trial-%d-%d-%d"%[seed,id,mode];State.new().save_world(w,"res://evidence/"+name+"-768.bin")
 var result={"contract":"legacy sequential" if mode==0 else "T1 simultaneous nominal g=.72/hour","seed":seed,"id":id,"mode":mode,"generation":target.generation,"birth_tick":start,"origin_fingerprint":origin,"origin_exact":true,"duration":768,"daily":daily,"hourly":hourly,"world_daily":world_daily,"hashes":hashes,"events":target.obs_events.duplicate(true),"lineage":w.lineage.duplicate(true),"initial_ledger":initial_ledger,"final_ledger":w.ledger(),"max_world_error":peak,"max_plant_error":pp,"max_sender_fraction":max_sender,"error":w.error,"censored":w.censored,"endpoint_fingerprint":w.fingerprint()}
 var f=FileAccess.open("res://evidence/"+name+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();w.close();quit()
