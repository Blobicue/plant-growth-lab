extends RefCounted
# T1: simultaneous conservative amount diffusion; all sends use frozen substep stock.
static func advance(values:PackedFloat64Array,edges:Array,rates:PackedFloat64Array,keys:Array,requested:int)->Dictionary:
 assert(requested>0 and values.size()==keys.size()*3 and edges.size()==rates.size())
 var count=keys.size();var sorted=[];var rows=PackedFloat64Array();rows.resize(count)
 for z in edges.size():
  var e=edges[z];assert(e.x!=e.y and rates[z]>=0.0)
  var a=e.x;var b=e.y
  if str(keys[a])>str(keys[b]):var swap=a;a=b;b=swap
  sorted.append({"a":a,"b":b,"g":rates[z],"key":str(keys[a])+"|"+str(keys[b])})
 sorted.sort_custom(func(a,b):return a.key<b.key)
 for e in sorted:rows[e.a]+=e.g;rows[e.b]+=e.g
 var maximum=0.0
 for r in rows:maximum=maxf(maximum,r)
 var steps=maxi(requested,1+int(floor(maximum)));var retain=PackedFloat64Array();retain.resize(count)
 for i in count:retain[i]=1.0-rows[i]/steps;assert(retain[i]>=0.0 and retain[i]<=1.0)
 for e in sorted:e["k"]=e.g/steps
 var old=values.duplicate()
 for _s in steps:
  var next=PackedFloat64Array();next.resize(old.size())
  for i in count:
   for channel in 3:next[3*i+channel]=old[3*i+channel]*retain[i]
  for e in sorted:
   for channel in 3:
    next[3*e.b+channel]+=e.k*old[3*e.a+channel]
    next[3*e.a+channel]+=e.k*old[3*e.b+channel]
  old=next
 return {"values":old,"steps":steps,"maximum_sender_fraction":maximum/steps}
static func apply(p,steps:int):
 p._connections()
 var values=PackedFloat64Array();var keys=[];var edges=[];var rates=PackedFloat64Array()
 for i in p.nodes.size():
  var node=p.nodes[i];keys.append(str(node.pos))
  for resource in ["c","n","w"]:values.append(node[resource])
  if node.parent>=0 and node.connected:
   edges.append(Vector2i(node.parent,i));rates.append(.72*minf(node.solid_c/p.PACK[node.kind],p.nodes[node.parent].solid_c/p.PACK[p.nodes[node.parent].kind]))
 var result=advance(values,edges,rates,keys,steps)
 for i in p.nodes.size():
  for channel in 3:p.nodes[i][["c","n","w"][channel]]=result.values[3*i+channel]
 return {"steps":result.steps,"maximum_sender_fraction":result.maximum_sender_fraction}
