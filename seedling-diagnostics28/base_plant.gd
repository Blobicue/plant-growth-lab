extends "res://legacy/model.gd"
const Reserve=preload("res://reserve.gd")
var reserve={"c":0.0,"n":0.0,"w":0.0}
var reserve_deposited={"c":0.0,"n":0.0,"w":0.0}
var reserve_refunded={"c":0.0,"n":0.0,"w":0.0}
var reserve_released={"c":0.0,"n":0.0,"w":0.0}
var reserve_disposed={"c":0.0,"n":0.0,"w":0.0}
var reserve_sources:Dictionary={}
var reserve_recent:Array=[]
var reserve_last_surplus=0.0
var reserve_surplus=0.0
var reserve_committed=false
var reserve_reason="not collecting"
var air_received=0.0
var air_returned=0.0
var generation=0
var thermal_out:float=0.0
var shared_field
var plant_id:int=0
func _init(seed:int,id:int,light:float,founder:bool=true):
 super(seed,false,false,true,founder);plant_id=id;genotype={"version":1,"branch_seed":seed,"physiology":"paid-v8"}
 if not founder:return
 var offset=Vector3i(-2 if id==0 else 2,0,0);occupancy={}
 for i in nodes.size():nodes[i].pos+=offset;occupancy[nodes[i].pos]=i
 nodes[0].w=.001;nodes[0].n=.00001;water.fill(0.0);nitrogen.fill(0.0);sunlight=0.0;initial=ledger()
func moisture_gradient(p:Vector3i)->Vector3:
 var g=Vector3.ZERO;var mid=soil_index(p);var fallback:float=shared_field.samples.get(mid,[0,0])[0]/shared_field.scale
 for d in DIRS:
  var a:float=shared_field.samples.get(soil_index(p-d),[int(fallback*shared_field.scale),0])[0]/shared_field.scale
  var b:float=shared_field.samples.get(soil_index(p+d),[int(fallback*shared_field.scale),0])[0]/shared_field.scale
  g+=Vector3(d)*(b-a)
 return g
func max_error()->float:
 var now=ledger();var error=0.0
 for key in initial:
  var expected:float=initial[key]+(totals.uptake_w if key=="W" else totals.uptake_n if key=="N" else received_light/1e9 if key=="E" else air_received if key=="C" else 0.0)-float(donated.get(key,0.0))
  error=maxf(error,absf(now[key]-expected))
 return error

var parent_id:int=-1
var birth_tick:int=0
var genotype:Dictionary={}
var donated={"C":0.0,"N":0.0,"W":0.0,"E":0.0}
var received_light:int=0
var leaf_energy:Dictionary={}
var shared_exposure:Dictionary={}
var sun_vector=Vector3.UP
var blocked_count:int=0
func exposure(p:Vector3i)->float:return float(shared_exposure.get(p,1.0))
func sun_direction()->Vector3:return sun_vector
func photo_demands()->Array:
 var wants:Array=[]
 for i in nodes.size():
  var node=nodes[i];var want=0.0
  if node.kind=="leaf" and node.connected:
   want=minf(node.solid_c*.216*node.light*(.35+.65*absf(sun_direction().y))*node.w/(node.w+.002),node.w/.5)
   want=minf(want,float(leaf_energy.get(i,0))/1e9*.18/CHEM)
  wants.append(want)
 return wants
func photo_claim()->float:
 var total=0.0
 for want in photo_demands():total+=want
 return total
func photosynthesize()->void:
 var wants=photo_demands();var total=photo_claim();var photons=sunlight;sunlight=0.0;totals.photons+=photons
 var factor=minf(1.0,atmosphere/total) if total>0 else 0.0;var absorbed=0.0
 for i in nodes.size():
  var gain:float=wants[i]*factor
  if gain<=0:continue
  var node=nodes[i];var moisture=gain*.5;var energy=gain*CHEM/.18
  node.c+=gain;atmosphere-=gain;node.w-=moisture;vapor+=moisture;heat+=energy-gain*CHEM-moisture*LATENT;absorbed+=energy;totals.fixed_c+=gain
 radiated+=photons-absorbed
func prepare_growth()->Array:
 _connections()
 var count=tips.size()
 for i in count:
  var tip=tips[i]
  if tip.alive and tip.proposal<0 and tick>=tip.ready:_propose(i)
 var intents:Array=[]
 for i in proposals.size():
  var p=proposals[i]
  if p.state!="developing":continue
  if proposal_expired(p) or not nodes[p.front].connected:
   p.state="failed";totals.expired+=1
   if p.tip>=0:tips[p.tip].node=p.front;tips[p.tip].proposal=-1;tips[p.tip].ready=tick+4
   continue
  intents.append({"plant":plant_id,"proposal":i,"pos":p.path[p.cursor]})
 return intents
func payable(p:Dictionary)->bool:
 if nodes.size()>=MAX_NODES:p.blocked="cell cap";return false
 var front=nodes[p.front];var mass:float=PACK[p.kind];var cost:float=mass/(.8 if p.kind=="leaf" else 1.0)
 p.blocked="C" if front.c<cost else "N" if front.n<mass*NR[p.kind] else "water" if front.w<mass*.3 else ""
 return p.blocked.is_empty()
func commit_growth(p:Dictionary):
 var front=nodes[p.front];var mass:float=PACK[p.kind];var cost:float=mass/(.8 if p.kind=="leaf" else 1.0)
 front.c-=cost;front.n-=mass*NR[p.kind];front.w-=mass*.3
 var loss=cost-mass;atmosphere+=loss;heat+=loss*CHEM;totals.respired_c+=loss
 var id=_insert(p.path[p.cursor],p.front,p.kind);totals.built_c+=mass;p.front=id;p.cursor+=1;p.blocked=""
 if p.tip>=0:tips[p.tip].node=id
 if p.cursor==p.path.size():_complete(p)
func snapshot()->Dictionary:
 var result=super.snapshot();result.air_received=air_received;result.air_returned=air_returned;result.received_light=received_light;result.blocked_count=blocked_count;result.parent_id=parent_id;result.birth_tick=birth_tick;result.genotype=genotype.duplicate(true);result.donated=donated.duplicate();result.reserve=reserve_state();result.generation=generation;result.thermal_out=thermal_out;return result

func ledger()->Dictionary:
 var result=super.ledger()
 if reserve!=null:result.C+=reserve.c;result.N+=reserve.n;result.W+=reserve.w;result.E+=reserve.c*20.0
 return result
func reserve_state()->Dictionary:return {"balance":reserve.duplicate(),"capacity":Reserve.CAP,"deposited":reserve_deposited.duplicate(),"refunded":reserve_refunded.duplicate(),"released":reserve_released.duplicate(),"disposed":reserve_disposed.duplicate(),"sources":reserve_sources.duplicate(),"recent":reserve_recent.duplicate(true),"last_surplus":reserve_last_surplus,"surplus":reserve_surplus,"committed":reserve_committed,"reason":reserve_reason}

func proposal_expired(p:Dictionary)->bool:return tick>=p.deadline
