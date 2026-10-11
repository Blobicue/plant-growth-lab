extends SceneTree
const State=preload("res://state.gd")
const R=preload("res://relabel.gd")
func _initialize():call_deferred("run")
func decisions(w):
 var growth=[];var alive=[];var expiry=[];var reproduction=[]
 for p in w.plants:
  for n in R.canonical(p):
   growth.append({"plant":p.plant_id,"position":n.pos,"kind":n.kind,"birth":n.birth,"parent":n.parent})
   alive.append({"plant":p.plant_id,"position":n.pos,"active":n.active,"connected":n.connected})
  for i in p.proposals.size():
   var q=p.proposals[i]
   if q.state=="failed":expiry.append({"plant":p.plant_id,"proposal":i,"kind":q.kind,"deadline":q.deadline,"front":p.nodes[q.front].pos})
 for pod in w.propagules:reproduction.append({"id":pod.id,"parent":pod.parent,"birth":pod.birth,"child":pod.child,"stage":pod.stage})
 return {"growth":growth,"death_or_connectivity":alive,"expiry":expiry,"reproduction":reproduction,"lineage":w.lineage.duplicate(true)}
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var file="/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-12011-3.bin";var a=State.new().restore(file);var b=State.new().restore(file);R.relabel(b,b.plant_by_id(3));a.transport_substeps=24;b.transport_substeps=24
 var ref=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-transport/evidence/trial-12011-3-24.json"));var first={};var first_field=-1;var first_condensation=-1;var differing_field_hours=0;var maximum_field_q=0;var maximum_nodes=0.0;var hourly=[];var max_error=0.0
 for age in 768:
  a.step();b.step();assert(a.fingerprint()==ref.hashes[age],"original old numeric trajectory must replay exactly")
  assert(a.error.is_empty() and b.error.is_empty() and a.censored.is_empty() and b.censored.is_empty())
  max_error=maxf(max_error,maxf(a.max_error(),b.max_error()))
  if a.hydro_condensed!=b.hydro_condensed and first_condensation<0:first_condensation=age+1
  var fa=a.field.full();var fb=b.field.full();var l1=0;var cells=0
  for i in fa.size():
   var delta=absi(int(fa[i])-int(fb[i]));l1+=delta
   if delta>0:cells+=1
  if l1>0:
   differing_field_hours+=1
   if first_field<0:first_field=age+1
  maximum_field_q=maxi(maximum_field_q,l1)
  var da=decisions(a);var db=decisions(b)
  for key in da:
   if da[key]!=db[key] and not first.has(key):first[key]={"age":age+1,"original":da[key],"permuted":db[key]}
  for p in a.plants:
   var q=b.plant_by_id(p.plant_id);var ca=R.canonical(p);var cb=R.canonical(q)
   if ca.size()==cb.size():
    for j in ca.size():
     if ca[j].pos!=cb[j].pos:continue
     for k in ["c","n","w","solid_c","solid_n","bound_w"]:maximum_nodes=maxf(maximum_nodes,absf(ca[j][k]-cb[j][k]))
  hourly.append({"age":age+1,"field_L1_quanta":l1,"different_field_entries":cells,"condensation_delta_q":b.hydro_condensed-a.hydro_condensed,"biological_decisions_equal":da==db})
  if (age+1)%192==0:print("old quantum diagnostic age%d; biological differences %s"%[age+1,str(first.keys())])
 var result={"diagnostic_only":true,"old_exact_field_gate_still_failed":true,"seed":12011,"id":3,"duration":768,"original_hourly_hashes_exact":768,"first_condensation_difference_age":first_condensation,"first_field_difference_age":first_field,"field_differing_hours":differing_field_hours,"max_field_L1_quanta":maximum_field_q,"max_node_resource_difference":maximum_nodes,"first_biological_differences":first,"biological_decisions_equal_all_hours":first.is_empty(),"hourly":hourly,"max_world_error":max_error,"scope":"Observed old numerical original/permutation pair only; not every possible single-quantum perturbation"}
 var f=FileAccess.open("res://evidence/quantum-outcomes.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print(JSON.stringify({"first_field":first_field,"biological_differences":first.keys(),"max_field_L1_q":maximum_field_q}));a.close();b.close();quit()
