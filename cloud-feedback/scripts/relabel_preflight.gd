extends SceneTree
const State=preload("res://state.gd")
func _initialize():call_deferred("run")
func canonical(p):
 var out=[]
 for n in p.nodes:
  var d=n.duplicate(true);d.parent=p.nodes[n.parent].pos if n.parent>=0 else Vector3i(999,999,999);out.append(d)
 out.sort_custom(func(a,b):return str(a.pos)<str(b.pos))
 return out
func relabel(w,p):
 assert(p.nodes.size()==7 and p.proposals.is_empty() and p.reserve_sources.is_empty() and p.reserve_recent.is_empty())
 # Reverse equal-birth siblings; retain parent-before-child topological validity.
 var order=[];var remaining=range(p.nodes.size())
 while not remaining.is_empty():
  var eligible=[]
  for i in remaining:
   if p.nodes[i].parent<0 or p.nodes[i].parent in order:eligible.append(i)
  eligible.sort_custom(func(a,b):return p.nodes[a].birth<p.nodes[b].birth if p.nodes[a].birth!=p.nodes[b].birth else a>b)
  var chosen=eligible[0];order.append(chosen);remaining.erase(chosen)
 var map={}
 for i in order.size():map[order[i]]=i
 var old=p.nodes.duplicate(true);p.nodes=[];p.occupancy={}
 for i in order:
  var n=old[i];n.parent=map[n.parent] if n.parent>=0 else -1;p.nodes.append(n);p.occupancy[n.pos]=map[i]
 for tip in p.tips:tip.node=map[tip.node]
 for key in ["leaf_energy"]:
  var replacement={}
  for i in p.get(key):replacement[map[i]]=p.get(key)[i]
  p.set(key,replacement)
 for pos in w.occupied:
  if w.occupied[pos].plant==p.plant_id:w.occupied[pos].node=map[w.occupied[pos].node]
 p._connections();w._visual()
 return order
func event_summary(p):
 var out=[]
 for e in p.obs_events:
  if e.event.begins_with("built_node_"):out.append({"age":e.age,"kind":e.data.kind,"position":e.data.position,"proposal":e.data.proposal})
 return out
func refusal_summary(p):
 var out=[]
 for e in p.obs_events:
  if e.event.begins_with("refusal_"):out.append({"age":e.age,"kind":e.data.kind,"short":e.data.short,"front_position":e.data.local.pos,"proposal":e.data.proposal,"cost":e.data.cost,"local":e.data.local})
 return out
func ref_predicates(p):
 var out=[]
 for e in refusal_summary(p):out.append([e.age,e.kind,e.short,e.front_position,e.proposal])
 return out
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]);var id=int(args[1]);var path="/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-%d-%d.bin"%[seed,id]
 var a=State.new().restore(path);var b=State.new().restore(path);var pa=a.plant_by_id(id);var pb=b.plant_by_id(id);var start=a.tick
 var origin_hash=a.fingerprint();assert(origin_hash==b.fingerprint())
 var before=canonical(pb);var order=relabel(b,pb);var initial_equivalent=canonical(pb)==before;assert(initial_equivalent)
 for world in [a,b]:
  for p in world.plants:p.obs_last_totals={"uptake_w":p.totals.uptake_w,"uptake_n":p.totals.uptake_n}
 var first_physical={};var first_payment={};var first_constraint={};var rows=[];var peak=0.0;var pp=0.0;var max_delta=0.0
 for age in 96:
  a.step();b.step()
  for w in [a,b]:
   peak=maxf(peak,w.max_error())
   for p in w.plants:p.finish_observation();pp=maxf(pp,p.max_error())
   assert(w.error.is_empty() and w.censored.is_empty(),w.error+" "+w.censored)
   assert(w.allocation_residual==0)
  var ca=canonical(pa);var cb=canonical(pb)
  if ca!=cb and first_physical.is_empty():first_physical={"age":age+1,"baseline":ca,"relabelled":cb}
  if event_summary(pa)!=event_summary(pb) and first_payment.is_empty():first_payment={"age":age+1,"baseline":event_summary(pa),"relabelled":event_summary(pb)}
  if ref_predicates(pa)!=ref_predicates(pb) and first_constraint.is_empty():first_constraint={"age":age+1,"baseline":refusal_summary(pa),"relabelled":refusal_summary(pb)}
  var pools_delta={}
  for k in ["C","N","W","E"]:pools_delta[k]=b.ledger()[k]-a.ledger()[k];max_delta=maxf(max_delta,absf(pools_delta[k]))
  rows.append({"age":age+1,"baseline_physical_hash":a.fingerprint(),"relabelled_physical_hash":b.fingerprint(),"baseline_nodes":pa.nodes.size(),"relabelled_nodes":pb.nodes.size(),"baseline_roots":pa.nodes.filter(func(n):return n.kind=="root").size(),"relabelled_roots":pb.nodes.filter(func(n):return n.kind=="root").size(),"world_ledger_difference":pools_delta})
 var result={"seed":seed,"id":id,"generation":pa.generation,"birth_tick":start,"origin_fingerprint":origin_hash,"permutation_new_to_old":order,"initial_canonical_state_exact":initial_equivalent,"first_physical_difference":first_physical,"first_payment_difference":first_payment,"first_constraint_difference":first_constraint,"baseline_events":event_summary(pa),"relabelled_events":event_summary(pb),"baseline_refusals":refusal_summary(pa),"relabelled_refusals":refusal_summary(pb),"max_world_error":peak,"max_plant_error":pp,"max_between_world_ledger_difference":max_delta,"hourly":rows,"baseline_error":a.error,"relabelled_error":b.error,"gate_pass":first_payment.is_empty() and first_constraint.is_empty()}
 var f=FileAccess.open("res://evidence/relabel-%d-%d.json"%[seed,id],FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close()
 print(JSON.stringify({"seed":seed,"id":id,"gate_pass":result.gate_pass,"first_payment_age":first_payment.get("age",-1),"first_constraint_age":first_constraint.get("age",-1),"max_world_error":peak}));a.close();b.close();quit()
