extends RefCounted
static func canonical(p):
 var out=[]
 for n in p.nodes:
  var d=n.duplicate(true);d.parent=p.nodes[n.parent].pos if n.parent>=0 else Vector3i(999,999,999);out.append(d)
 out.sort_custom(func(a,b):return str(a.pos)<str(b.pos))
 return out
static func relabel(w,p):
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
