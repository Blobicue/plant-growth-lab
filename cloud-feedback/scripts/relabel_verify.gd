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
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]);var id=int(args[1]);var path="/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-%d-%d.bin"%[seed,id]
 var ref=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/relabel-%d-%d.json"%[seed,id]));var checks=[]
 var a=State.new().restore(path);var b=State.new().restore(path);var pa=a.plant_by_id(id);var pb=b.plant_by_id(id)
 var old=pa.snapshot();var before_field=a.field.full();var perm=relabel(b,pb)
 var canonical_same=canonical(pa)==canonical(pb);assert(canonical_same)
 # Undo references in a copied snapshot: all science properties, not just amounts.
 var corrected=pb.snapshot();var sorted=[];sorted.resize(perm.size())
 for i in perm.size():
  var n=corrected.nodes[i];n.parent=perm[n.parent] if n.parent>=0 else -1;sorted[perm[i]]=n
 corrected.nodes=sorted
 for t in corrected.tips:t.node=perm[t.node]
 assert(corrected==old,"full plant snapshot must be equivalent after inverse mapping")
 assert(before_field==b.field.full())
 for p in a.plants:
  if p.plant_id!=id:assert(p.snapshot()==b.plant_by_id(p.plant_id).snapshot())
 checks.append({"name":"inverse-remapped full plant snapshot, other plants and finite field exact","pass":true})
 var la=pa.ledger();var lb=pb.ledger();pa.transport_pools();pb.transport_pools();var residual=0.0
 for k in ["C","N","W","E"]:residual=maxf(residual,absf(pa.ledger()[k]-la[k]));residual=maxf(residual,absf(pb.ledger()[k]-lb[k]))
 assert(residual<1e-9)
 var transport={"canonical_before_exact":canonical_same,"canonical_after_exact":canonical(pa)==canonical(pb),"maximum_ledger_residual":residual,"baseline_after":canonical(pa),"relabelled_after":canonical(pb)}
 a.close();b.close()
 var maximum_error=0.0;var pp=0.0;var replay=[]
 for arm in 2:
  var w=State.new().restore(path)
  if arm==1:relabel(w,w.plant_by_id(id))
  for age in 96:
   w.step(true);maximum_error=maxf(maximum_error,w.max_error())
   for p in w.plants:pp=maxf(pp,p.max_error())
   var expected=ref.hourly[age].baseline_physical_hash if arm==0 else ref.hourly[age].relabelled_physical_hash
   assert(w.fingerprint()==expected,"reverse-order replay disagrees")
   assert(w.error.is_empty() and w.censored.is_empty() and w.allocation_residual==0)
   if age==47:
    var checkpoint="res://evidence/relabel-replay-%d-%d-%d-48.bin"%[seed,id,arm]
    State.new().save_world(w,checkpoint);w.close();w=State.new().restore(checkpoint)
    assert(w.fingerprint()==expected,"restart must match forward reference")
  replay.append({"arm":"original" if arm==0 else "relabelled","hours_exact":96,"reverse_plant_order":true,"saved_restart_at_age":48});w.close()
 var result={"seed":seed,"id":id,"checks":checks,"transport_only":transport,"replay":replay,"max_world_error":maximum_error,"max_plant_error":pp,"error":""}
 var f=FileAccess.open("res://evidence/relabel-verification-%d-%d.json"%[seed,id],FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close()
 print(JSON.stringify({"seed":seed,"id":id,"transport_alone_changes_distribution":not transport.canonical_after_exact,"replay_hours_exact":192,"ledger_residual":residual}));quit()
