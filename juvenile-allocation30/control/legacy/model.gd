extends RefCounted
## Bounded vegetative, paid-voxel prototype. Not a backend or calibrated species.
const ID="v8-funded-skeleton-1"
const DEADLINE=14
const MAX_NODES=512
const MAX_TIPS=24
const X=21
const Y=8
const Z=13
const CHEM=20.0
const LATENT=2.0
const PACK={"stem":0.0024,"root":0.0018,"leaf":0.0012}
const NR={"stem":0.024,"root":0.06,"leaf":0.11}
const UPKEEP={"stem":0.0011,"root":0.00375,"leaf":0.0116}
const DIRS=[Vector3i.RIGHT,Vector3i.UP,Vector3i.BACK]
var seed_value:int
var tick:int=0
var initial_responses:bool=true
var side_light:bool=false
var offset_wet:bool=false
var photo_response:bool=true
var hydro_response:bool=true
var transport:bool=true
var diffusion:bool=true
var nodes:Array=[]
var tips:Array=[]
var proposals:Array=[]
var occupancy:Dictionary={}
var water:PackedFloat64Array
var nitrogen:PackedFloat64Array
var soil_edges:Array=[]
var atmosphere:float=5.0
var vapor:float=0.0
var heat:float=0.0
var radiated:float=0.0
var sunlight:float=80.0
var litter:float=0.0
var initial:Dictionary
var totals:Dictionary={"fixed_c":0.0,"uptake_w":0.0,"uptake_n":0.0,"built_c":0.0,"respired_c":0.0,"expired":0,"completed":0,"photons":0.0}
var action_log:Array=[]

func _init(new_seed:int=12011,side:bool=false,offset:bool=false,responses:bool=true,founder:bool=true):
 if not founder:
  seed_value=new_seed;water.resize(X*Y*Z);nitrogen.resize(X*Y*Z);atmosphere=0.0;sunlight=0.0;initial=ledger();return
 seed_value=new_seed;initial_responses=responses;side_light=side;offset_wet=offset;photo_response=responses;hydro_response=responses
 water.resize(X*Y*Z);nitrogen.resize(X*Y*Z)
 var weights:float=0.0
 for i in water.size():
  var p:Vector3=Vector3(soil_pos(i));var target=Vector3(4 if offset else 0,-4,0)
  water[i]=0.02+exp(-p.distance_squared_to(target)/8.0);weights+=water[i]
  nitrogen[i]=0.2/water.size()
  for d in DIRS:
   var j:int=soil_index(soil_pos(i)+d)
   if j>=0:soil_edges.append(Vector2i(i,j))
 for i in water.size():water[i]*=4.0/weights
 _insert(Vector3i.ZERO,-1,"stem")
 _insert(Vector3i(0,1,0),0,"stem")
 _insert(Vector3i(0,-1,0),0,"root")
 for p in [Vector3i(1,1,0),Vector3i(-1,1,0),Vector3i(0,1,1),Vector3i(0,1,-1)]:_insert(p,1,"leaf")
 nodes[0].c=0.30;nodes[0].n=0.018;nodes[0].w=0.08
 _tip(1,"stem",Vector3.UP,0,0);_tip(2,"root",Vector3.DOWN,0,0)
 initial=ledger()

func soil_index(p:Vector3i)->int:
 if p.x< -10 or p.x>10 or p.y> -1 or p.y< -8 or p.z< -6 or p.z>6:return -1
 return ((p.y+8)*Z+p.z+6)*X+p.x+10
func soil_pos(i:int)->Vector3i:
 return Vector3i(i%X-10,int(i/(X*Z))-8,int(i/X)%Z-6)
func _insert(p:Vector3i,parent:int,kind:String)->int:
 var id:int=nodes.size();var mass:float=PACK[kind]
 nodes.append({"pos":p,"parent":parent,"kind":kind,"solid_c":mass,"solid_n":mass*NR[kind],"bound_w":mass*.3,"c":0.0,"n":0.0,"w":0.0,"active":true,"connected":true,"stress":0.0,"birth":tick,"light":0.0})
 occupancy[p]=id;return id
func _tip(node:int,kind:String,heading:Vector3,order:int,segments:int)->void:
 if tips.size()>=MAX_TIPS:return
 tips.append({"node":node,"kind":kind,"heading":heading,"order":order,"segments":segments,"ready":tick+3,"proposal":-1,"alive":true})
func sun_direction()->Vector3:
 return Vector3(1,.30,0).normalized() if side_light else Vector3.UP
func _connections()->void:
 for i in nodes.size():
  var n:Dictionary=nodes[i];n.connected=n.active and (n.parent<0 or nodes[n.parent].connected)
func diffuse_soil()->void:
 # Jacobi pair transfers; coefficients below1/degree preserve nonnegativity.
 var dw:PackedFloat64Array;var dn:PackedFloat64Array;dw.resize(water.size());dn.resize(water.size())
 for edge in soil_edges:
  var fw:float=(water[edge.x]-water[edge.y])*.03
  var fn:float=(nitrogen[edge.x]-nitrogen[edge.y])*.02
  dw[edge.x]-=fw;dw[edge.y]+=fw;dn[edge.x]-=fn;dn[edge.y]+=fn
 for i in water.size():water[i]+=dw[i];nitrogen[i]+=dn[i]
func transport_pools()->void:
 _connections()
 # Pairwise finite-volume exchange, equal/opposite, no edge to an unbuilt cell.
 for _pass in 3:
  for child in nodes:
   if child.parent<0 or not child.connected:continue
   var parent:Dictionary=nodes[child.parent]
   var conductivity:float=minf(child.solid_c/PACK[child.kind],parent.solid_c/PACK[parent.kind])*.24
   for key in ["c","n","w"]:
    var flux:float=(parent[key]-child[key])*conductivity
    parent[key]-=flux;child[key]+=flux
func uptake()->void:
 for node in nodes:
  if node.kind!="root" or not node.connected:continue
  var i:int=soil_index(node.pos)
  if i<0:continue
  var w:float=minf(water[i],minf(node.solid_c*.7,maxf(0,.012-node.w)))
  var n:float=minf(nitrogen[i],minf(node.solid_c*.10,maxf(0,.003-node.n)))
  water[i]-=w;node.w+=w;nitrogen[i]-=n;node.n+=n
  totals.uptake_w+=w;totals.uptake_n+=n
func exposure(p:Vector3i)->float:
 var strength:float=1.0;var direction:Vector3=sun_direction();var previous:Vector3i=p
 for s in range(1,65):
  var q:Vector3i=Vector3i((Vector3(p)+direction*s*.65).round())
  if q==previous:continue
  previous=q
  if occupancy.has(q):
   var o:Dictionary=nodes[occupancy[q]]
   strength*=1.0-(.32 if o.kind=="leaf" else .65)*clampf(o.solid_c/PACK[o.kind],0,1)
 return strength
func photosynthesize()->void:
 var photons:float=minf(sunlight,.16);sunlight-=photons;totals.photons+=photons
 var wants:Array=[];var total:float=0.0
 for node in nodes:
  var want:float=0.0
  if node.kind=="leaf" and node.connected:
   node.light=exposure(node.pos)*(.35+.65*absf(sun_direction().y))
   want=minf(node.solid_c*.216*node.light*node.w/(node.w+.002),node.w/.5)
  wants.append(want);total+=want
 var factor:float=minf(1.0,minf(photons*.18/CHEM,atmosphere)/total) if total>0 else 0.0
 var absorbed:float=0.0
 for i in nodes.size():
  var gain:float=wants[i]*factor
  if gain<=0:continue
  var n:Dictionary=nodes[i];var moisture:float=gain*.5;var energy:float=gain*CHEM/.18
  n.c+=gain;atmosphere-=gain;n.w-=moisture;vapor+=moisture
  heat+=energy-gain*CHEM-moisture*LATENT;absorbed+=energy;totals.fixed_c+=gain
 radiated+=photons-absorbed
func respire(node:Dictionary,amount:float)->float:
 var paid:float=minf(node.c,maxf(0,amount));node.c-=paid;atmosphere+=paid;heat+=paid*CHEM;totals.respired_c+=paid;return paid
func maintain()->void:
 for node in nodes:
  if not node.active:continue
  var demand:float=node.solid_c*UPKEEP[node.kind]*(1.0+1.8*(1.0-node.w/(node.w+.002)))
  var fraction:float=minf(1,demand*.35/node.solid_c)
  var turnover:float=node.solid_c*fraction
  node.solid_c-=turnover;litter+=turnover
  var release_n:float=node.solid_n*fraction;var release_w:float=node.bound_w*fraction
  node.solid_n-=release_n;node.n+=release_n;node.bound_w-=release_w;node.w+=release_w
  var required:float=demand*.65;var paid:float=respire(node,required)
  var damage:float=(required-paid)/required if required>0 else 0.0
  node.stress+=damage
  if damage<1e-10 and node.stress>0 and required>0:
   node.stress-=respire(node,minf(.7,node.stress)*required)/required
  if node.stress>45 or node.solid_c<PACK[node.kind]*.20:node.active=false
  # Local paid tissue renewal to packet capacity; no free growth or revival.
  if node.active and node.connected:
   var missing:float=PACK[node.kind]-node.solid_c
   var yield_c:float=.8 if node.kind=="leaf" else 1.0
   var repair:float=maxf(0,minf(missing,minf(node.c*yield_c,minf(node.n/NR[node.kind],node.w/.3))))
   node.c-=repair/yield_c;node.n-=repair*NR[node.kind];node.w-=repair*.3
   node.solid_c+=repair;node.solid_n+=repair*NR[node.kind];node.bound_w+=repair*.3
   var loss:float=repair/yield_c-repair;atmosphere+=loss;heat+=loss*CHEM;totals.respired_c+=loss
 for tip in tips:
  if tip.alive:respire(nodes[tip.node],.00001)
func moisture_gradient(p:Vector3i)->Vector3:
 var gradient=Vector3.ZERO
 for d in DIRS:
  var lo:int=soil_index(p-d);var hi:int=soil_index(p+d)
  var mid:int=soil_index(p);var fallback:float=water[mid] if mid>=0 else 0.0
  var a:float=water[lo] if lo>=0 else fallback;var b:float=water[hi] if hi>=0 else fallback
  gradient+=Vector3(d)*(b-a)
 return gradient
func path_between(a:Vector3i,b:Vector3i)->Array:
 # Deterministic six-connected DDA, occupied cells are never overwritten.
 var result:Array=[];var p:Vector3i=a;var delta:Vector3i=b-a
 var length:Vector3=Vector3(abs(delta.x),abs(delta.y),abs(delta.z));var done=Vector3.ZERO
 for _i in 32:
  if p==b:break
  var best:int=-1;var score:float=INF
  for axis in 3:
   if p[axis]!=b[axis]:
    var next:float=(done[axis]+.5)/maxf(1,length[axis])
    if next<score:score=next;best=axis
  if best<0:break
  p[best]+=signi(delta[best]);done[best]+=1;result.append(p)
 return result
func _propose(tip_id:int)->void:
 var tip:Dictionary=tips[tip_id];var parent:Dictionary=nodes[tip.node]
 if not parent.connected:tip.alive=false;return
 var heading:Vector3=tip.heading
 if tip.kind=="stem":
  heading=(heading*.45+Vector3.UP*.55+(sun_direction()*.9*exposure(parent.pos) if photo_response else Vector3.ZERO)).normalized()
 else:
  var gradient:Vector3=moisture_gradient(parent.pos)
  heading=(heading*.40+Vector3.DOWN*.25+(gradient.normalized()*.85 if hydro_response and gradient.length()>1e-8 else Vector3.ZERO)).normalized()
 var goal:Vector3i=parent.pos+Vector3i((heading*2.8).round())
 goal.x=clampi(goal.x,-10,10);goal.z=clampi(goal.z,-6,6);goal.y=clampi(goal.y,-8,-1) if tip.kind=="root" else clampi(goal.y,1,22)
 var path:Array=path_between(parent.pos,goal)
 # A lateral bud leaves the parent axis sideways before elongating. Otherwise
 # lattice rounding can put both apices into the same first cell forever.
 if tip.order>0 and tip.segments==0:
  var lateral:Vector3i=Vector3i.RIGHT if absf(tip.heading.x)>=absf(tip.heading.z) else Vector3i.BACK
  if (tip.heading.x if lateral.x!=0 else tip.heading.z)<0:lateral=-lateral
  var first:Vector3i=parent.pos+lateral
  if soil_index(first)<0 and tip.kind=="root":tip.alive=false;return
  if first.x< -10 or first.x>10 or first.z< -6 or first.z>6:tip.alive=false;return
  path=[first];path.append_array(path_between(first,goal))
 if path.is_empty():tip.alive=false;return
 proposals.append({"tip":tip_id,"parent":tip.node,"front":tip.node,"kind":tip.kind,"path":path,"cursor":0,"birth":tick,"deadline":tick+DEADLINE,"state":"developing","heading":heading,"blocked":""})
 tip.proposal=proposals.size()-1
func _leaf_proposal(parent:int,direction:Vector3i)->void:
 var goal:Vector3i=nodes[parent].pos+direction
 if occupancy.has(goal):return
 proposals.append({"tip":-1,"parent":parent,"front":parent,"kind":"leaf","path":[goal],"cursor":0,"birth":tick,"deadline":tick+DEADLINE,"state":"developing","heading":Vector3(direction),"blocked":""})
func _complete(p:Dictionary)->void:
 p.state="established";totals.completed+=1
 if p.tip<0:return
 var tip:Dictionary=tips[p.tip];tip.node=p.front;tip.heading=p.heading;tip.segments+=1;tip.proposal=-1;tip.ready=tick+4
 if tip.kind=="stem":
  var angle:float=fmod(seed_value*.013+tip.segments*2.399963+tip.order*.9,TAU)
  var d:Vector3i=Vector3i.RIGHT if absf(cos(angle))>absf(sin(angle)) else Vector3i.BACK
  if (cos(angle) if d.x!=0 else sin(angle))<0:d=-d
  # Attach leaves across the axis, not into the apical elongation path.
  if maxf(absf(tip.heading.x),absf(tip.heading.z))>.25:d=Vector3i.BACK if absf(tip.heading.x)>absf(tip.heading.z) else Vector3i.RIGHT
  _leaf_proposal(tip.node,d);_leaf_proposal(tip.node,-d)
 if tip.segments%2==0 and tip.order<2:
  var angle:float=fmod(seed_value*.019+tip.segments*2.399963+tip.order*1.2,TAU)
  var direction:Vector3=Vector3(cos(angle),.6 if tip.kind=="stem" else -.3,sin(angle)).normalized()
  _tip(tip.node,tip.kind,direction,tip.order+1,0)
func build_proposals()->void:
 _connections()
 var tip_count:int=tips.size()
 for i in tip_count:
  var t:Dictionary=tips[i]
  if t.alive and t.proposal<0 and tick>=t.ready:_propose(i)
 var count:int=proposals.size()
 for i in count:
  var p:Dictionary=proposals[i]
  if p.state!="developing":continue
  var front:Dictionary=nodes[p.front]
  if tick>=p.deadline or not front.connected:
   p.state="failed";totals.expired+=1
   if p.tip>=0:
    var t:Dictionary=tips[p.tip];t.node=p.front;t.proposal=-1;t.ready=tick+4
   continue
  if nodes.size()>=MAX_NODES:p.blocked="cell cap";continue
  var pos:Vector3i=p.path[p.cursor]
  if occupancy.has(pos):p.blocked="occupied";continue
  var mass:float=PACK[p.kind];var cost:float=mass/(.8 if p.kind=="leaf" else 1.0);var n_cost:float=mass*NR[p.kind];var w_cost:float=mass*.3
  p.blocked="C" if front.c<cost else ("N" if front.n<n_cost else ("water" if front.w<w_cost else ""))
  if not p.blocked.is_empty():continue
  front.c-=cost;front.n-=n_cost;front.w-=w_cost
  var loss:float=cost-mass;atmosphere+=loss;heat+=loss*CHEM;totals.respired_c+=loss
  var id:int=_insert(pos,p.front,p.kind);totals.built_c+=mass;p.front=id;p.cursor+=1
  if p.tip>=0:tips[p.tip].node=id
  if p.cursor==p.path.size():_complete(p)
func step()->void:
 tick+=1;_connections()
 if diffusion:diffuse_soil()
 uptake()
 if transport:transport_pools()
 photosynthesize();maintain();build_proposals()
 var cooling:float=heat*.02;heat-=cooling;radiated+=cooling
func set_control(key:String,value:bool)->bool:
 if key not in ["photo_response","hydro_response","transport","diffusion"]:return false
 set(key,value);action_log.append({"tick":tick,"key":key,"value":value});return true
func ledger()->Dictionary:
 var c:float=atmosphere+litter;var n:float=0;var w:float=vapor;var chemical:float=litter*CHEM
 for v in water:w+=v
 for v in nitrogen:n+=v
 for node in nodes:
  c+=node.c+node.solid_c;n+=node.n+node.solid_n;w+=node.w+node.bound_w
  chemical+=(node.c+node.solid_c)*CHEM
 return {"C":c,"N":n,"W":w,"E":chemical+sunlight+heat+radiated+vapor*LATENT}
func max_error()->float:
 var now:Dictionary=ledger();var error:float=0
 for key in initial:error=maxf(error,absf(now[key]-initial[key]))
 return error
func metrics()->Dictionary:
 var shoot=Vector3.ZERO;var root=Vector3.ZERO;var sc:float=0;var rc:float=0;var leaf:int=0;var active:int=0;var pending:int=0
 for n in nodes:
  if n.kind=="root":root+=Vector3(n.pos)*n.solid_c;rc+=n.solid_c
  else:shoot+=Vector3(n.pos)*n.solid_c;sc+=n.solid_c
  if n.kind=="leaf":leaf+=1
  if n.active:active+=1
 for p in proposals:
  if p.state=="developing":pending+=1
 return {"seed":seed_value,"tick":tick,"side":side_light,"offset":offset_wet,"photo":photo_response,"hydro":hydro_response,"nodes":nodes.size(),"living":active,"leaves":leaf,"pending":pending,"shoot_centroid_x":shoot.x/sc if sc>0 else 0.0,"root_centroid_x":root.x/rc if rc>0 else 0.0,"shoot_tip_x":nodes[tips[0].node].pos.x,"root_tip_x":nodes[tips[1].node].pos.x,"shoot_tip_y":nodes[tips[0].node].pos.y,"root_tip_y":nodes[tips[1].node].pos.y,"error":max_error(),"totals":totals.duplicate(true)}
func fingerprint()->String:
 return var_to_bytes(snapshot()).hex_encode().sha256_text()
func snapshot()->Dictionary:
 var s:Dictionary={"identity":ID}
 for key in ["seed_value","initial_responses","tick","side_light","offset_wet","photo_response","hydro_response","transport","diffusion","nodes","tips","proposals","water","nitrogen","atmosphere","vapor","heat","radiated","sunlight","litter","initial","totals","action_log"]:s[key]=get(key)
 return s.duplicate(true)



