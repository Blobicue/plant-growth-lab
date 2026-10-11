extends RefCounted
# R1 canonical numerical traversal. Reconstruct existing shared-world physical history.
const SEED_OFFSETS=[Vector3i.ZERO,Vector3i.UP,Vector3i.DOWN,Vector3i(1,1,0),Vector3i(-1,1,0),Vector3i(0,1,1),Vector3i(0,1,-1)]
static func unique_positions(nodes:Array)->bool:
 var seen={}
 for n in nodes:
  if seen.has(n.pos):return false
  seen[n.pos]=true
 return true
static func ids(p)->Array:
 if p.nodes.is_empty():return []
 assert(unique_positions(p.nodes),"R1 rejects duplicate physical keys; never tie-break by node ID")
 var collar=null
 for n in p.nodes:
  if n.parent<0:assert(collar==null,"one physical collar required");collar=n
 assert(collar!=null)
 var records=[]
 for i in p.nodes.size():
  var n=p.nodes[i];var seed_rank=SEED_OFFSETS.find(n.pos-collar.pos) if n.birth==collar.birth else -1
  var spatial=(n.pos.y+8)*273+(n.pos.z+6)*21+n.pos.x+10
  records.append({"id":i,"birth":int(n.birth),"group":0 if seed_rank>=0 else 1,"rank":seed_rank if seed_rank>=0 else spatial})
 records.sort_custom(func(a,b):return a.birth<b.birth if a.birth!=b.birth else a.group<b.group if a.group!=b.group else a.rank<b.rank)
 var result=[]
 for r in records:result.append(r.id)
 return result
static func ranks(p)->Array:
 var result=[];result.resize(p.nodes.size());var order=ids(p)
 for rank in order.size():result[order[rank]]=rank
 return result
static func sum_values(p,values:Array)->float:
 assert(values.size()==p.nodes.size());var total=0.0
 for i in ids(p):total+=float(values[i])
 return total
