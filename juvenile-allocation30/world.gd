extends RefCounted
const FIELD_ID="juvenile-allocation30-cnw-q1e-9"
const Air=preload("res://atmosphere.gd")
const MAX_RECORDS=32 # computational bound: censor the WHOLE experiment
var air=0.0
var air_uptake=0.0
var air_returns=0.0
var air_sources={}
var air_recent=[]
var air_hour=[]
var censored=""
const Field=preload("res://field.gd")
const Canopy=preload("res://canopy.gd")
const Plant=preload("res://plant.gd")
const Decomp=preload("res://decomposition.gd")
var decomp_total:int=0
var decomp_last:int=0
var decomp_sources:Dictionary={}
const Hydro=preload("res://hydrology.gd")
var hydro_cloud:int=0
var hydro_condensed:int=0
var hydro_rained:int=0
var hydro_last_rain:int=0
var hydro_last_condensed:int=0
var hydro_heat:float=0.0
var hydro_radiated:float=0.0
var hydro_sources:Dictionary={}
var hydro_rain_cells:Dictionary={}
var water_requested:int=0
var water_received:int=0
var water_limited:int=0
const X=21
const Z=13
var field
var plants:Array=[]
var nodes:Array=[]
var proposals:Array=[]
var tick:int=0
var boundary_input:int=0
var boundary_flux:int=0
var wood_heat:float=0.0
var boundary_thermal_out:float=0.0
var sky_remaining:int=0
var sky_emitted:int=0
var sky_escaped:int=0
var sky_wood:int=0
var intercepted:Array=[]
var shadow_loss:Array=[]
var occupied:Dictionary={}
var space_conflicts:int=0
var config:Dictionary
var initial:Dictionary
var error:String=""
var contested:int=0
var limited:int=0
var allocation_residual:int=0
var times={"setup_ms":0.0,"simulation_ms":0.0,"diagnostics_ms":0.0,"audit_ms":0.0,"visual_ms":0.0}
func _init(settings:Dictionary):
 intercepted.resize(MAX_RECORDS);intercepted.fill(0);shadow_loss.resize(MAX_RECORDS);shadow_loss.fill(0)
 var start=Time.get_ticks_usec();config=settings.duplicate(true);config["carbon_access"]=int(config.get("carbon_access",1));config["lifecycle"]=int(config.get("lifecycle",1));config["slant"]=int(config.get("slant",1));config["flux"]=float(config.get("flux",.08));config["radiation"]=int(config.get("radiation",0));config["recycling"]=int(config.get("recycling",0));config["decomposition"]=int(config.get("decomposition",0));sky_remaining=int(round(float(config.light)*1e9)) if config.radiation==0 else 0
 ProjectSettings.set_setting("validation/cpu","native");ProjectSettings.set_setting("validation/scale",1e9);ProjectSettings.set_setting("validation/parallel_reduction",true);ProjectSettings.set_setting("validation/dimensions",Vector3i(21,8,13))
 var template=Plant.new(int(config.seed),0,float(config.light));var w=PackedFloat64Array();var n=PackedFloat64Array();w.resize(2184);n.resize(2184)
 # Localized common nursery patch: identical finite inventory in alone/together controls.
 var abundant:float=8.0 if int(config.scenario) in [3,4,5] else 1.0
 var weights=PackedFloat64Array();weights.resize(2184);var total_weight=0.0
 for i in 2184:weights[i]=exp(-Vector3(template.soil_pos(i)-Vector3i(0,-2,0)).length_squared()/4.0);total_weight+=weights[i]
 for i in 2184:w[i]=float(config.water)*abundant*weights[i]/total_weight;n[i]=float(config.nitrogen)*abundant*weights[i]/total_weight
 field=Field.new(w,n,int(config.backend)==1)
 var ids=[0,1] if int(config.scenario) in [0,3] else [0] if int(config.scenario) in [1,4] else [1]
 for id in ids:
  var plant=Plant.new(int(config.seed)+id*7919,id,float(config.light));plant.shared_field=field;plant.sun_vector=Vector3(1,1,0).normalized() if config.slant==1 else Vector3.UP;plants.append(plant)
 if config.carbon_access==1:Air.collect(self,"initial atmosphere")
 occupied=Canopy.trace(plants,0,config.slant==1).occupied;initial=ledger();
 if config.lifecycle==2:prepare_nursery(plants[0].plant_id);request_propagule(plants[0].plant_id,Vector3i(0,0,3))
 times.setup_ms=(Time.get_ticks_usec()-start)/1000.0;_visual();error=field.error
func soil_index(p:Vector3i)->int:return plants[0].soil_index(p)
func sun_direction()->Vector3:return plants[0].sun_direction()
func allocate(amount:int,claims:Array,resource:int)->Array:
 var total:int=0
 for c in claims:total+=int(c.want[resource])
 var shares:Array=[];var used:int=0;var ranking:Array=[]
 for i in claims.size():
  var numerator:int=amount*int(claims[i].want[resource]);var value:int=numerator/total if total>0 else 0
  shares.append(value);used+=value;ranking.append({"index":i,"remainder":numerator%total if total>0 else 0,"tie":(i+tick)%claims.size()})
 ranking.sort_custom(func(a,b):return a.remainder>b.remainder if a.remainder!=b.remainder else a.tie<b.tie)
 for i in amount-used:shares[ranking[i].index]+=1
 return shares
func step(reverse:bool=false):
 if not error.is_empty() or not censored.is_empty() or tick>=12288:return
 if config.carbon_access==1 and (plants.size()>=MAX_RECORDS or nodes.size()>=4096):censor("computational record/tissue capacity");return
 var begin=Time.get_ticks_usec();tick+=1;var demands:Dictionary={};var queries:Dictionary={};var order=plants.duplicate()
 if reverse:order.reverse()
 for p in order:
  p.tick=tick;p._connections()
  for id in p.nodes.size():
   var node:Dictionary=p.nodes[id]
   if node.kind!="root" or not node.connected:continue
   var index:int=p.soil_index(node.pos)
   if index<0:continue
   var want=[int(floor(minf(node.solid_c*.7,maxf(0,.012-node.w))*field.scale)),int(floor(minf(node.solid_c*.1,maxf(0,.003-node.n))*field.scale))]
   if not demands.has(index):demands[index]=[]
   demands[index].append({"plant":p.plant_id,"node":id,"key":p.plant_id*512+id,"want":want})
   queries[index]=true
   for v in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
    var q:int=p.soil_index(node.pos+v)
    if q>=0:queries[q]=true
 var indices=demands.keys();indices.sort();var commands:Array=[]
 for index in indices:
  demands[index].sort_custom(func(a,b):return a.key<b.key)
  var sum=[0,0]
  for c in demands[index]:sum[0]+=c.want[0];sum[1]+=c.want[1]
  if sum[0]>field.CAP or sum[1]>field.CAP:error="bounded aggregate demand exceeded";return
  commands.append([index,sum[0],sum[1],0])
 for pod in propagules:
  if pod.stage in ["escrow","dormant"]:queries[soil_index(pod.pos+Vector3i.DOWN)]=true
 if commands.size()>field.MAX_COMMANDS:censor("soil exchange command capacity");return
 var rain_positions=Hydro.rain_requests(self,commands)
 var qkeys=queries.keys();qkeys.sort();var receipts=field.advance(commands,qkeys)
 if not field.error.is_empty():error=field.error;return
 Hydro.receive_rain(self,receipts,indices.size(),rain_positions)
 for j in indices.size():
  water_requested+=commands[j][1];water_received+=receipts[j][0]
  if receipts[j][0]<commands[j][1]:water_limited+=1
  var claims:Array=demands[indices[j]];var owners:Dictionary={}
  for c in claims:owners[c.plant]=true
  if owners.size()>1:contested+=1
  if receipts[j][0]<commands[j][1] or receipts[j][1]<commands[j][2]:limited+=1
  var sw=allocate(receipts[j][0],claims,0);var sn=allocate(receipts[j][1],claims,1);var sum=[0,0]
  for k in claims.size():
   var c=claims[k];var p
   for candidate in plants:
    if candidate.plant_id==c.plant:p=candidate;break
   var w:float=sw[k]/field.scale;var n:float=sn[k]/field.scale;p.nodes[c.node].w+=w;p.nodes[c.node].n+=n;p.totals.uptake_w+=w;p.totals.uptake_n+=n;sum[0]+=sw[k];sum[1]+=sn[k]
  allocation_residual=maxi(allocation_residual,maxi(absi(sum[0]-receipts[j][0]),absi(sum[1]-receipts[j][1])))
 distribute_light()
 audit_sample("before_transport")
 for p in order:p.transport_pools()
 audit_sample("after_transport")
 if config.carbon_access==1:Air.allocate(self)
 for p in order:
  var before=Plant.Reserve.mobile(p);p.photosynthesize()
  var refunded=Plant.Reserve.protect(p) if config.lifecycle==3 else 0.0
  p.maintain()
  if config.lifecycle==3:
   p._connections() # Exclude tissue disconnected by this maintenance pass.
   if config.carbon_access==1 and p.nodes.size()<32:
    # The existing structural maturity gate also bounds new reproductive saving.
    # No refund, growth allocation, threshold/rate change or ancestry special case.
    p.reserve_last_surplus=0.0;p.reserve_reason="juvenile: reproductive collection deferred until32 paid cells"
   else:Plant.Reserve.collect(p,Plant.Reserve.mobile(p)-before-refunded)
 audit_sample("after_maintenance")
 resolve_growth(order)
 audit_sample("after_construction")
 lifecycle_step()
 Hydro.condense(self)
 Decomp.advance(self)
 if config.carbon_access==1:Air.collect(self,"respiration and mineralization")
 for p in order:
  var cooling:float=p.heat*.02;p.heat-=cooling;p.radiated+=cooling;p.thermal_out+=cooling
 if config.radiation!=0:
  var wood_loss=wood_heat*.02;wood_heat-=wood_loss;boundary_thermal_out+=wood_loss
  var seed_loss=life_heat*.02;life_heat-=seed_loss;boundary_thermal_out+=seed_loss
 times.simulation_ms+=(Time.get_ticks_usec()-begin)/1000.0;begin=Time.get_ticks_usec();inspect();times.diagnostics_ms+=(Time.get_ticks_usec()-begin)/1000.0;_visual()
func ledger()->Dictionary:
 var result={"C":0.0,"N":field.summary[1]/field.scale,"W":field.summary[0]/field.scale,"E":(sky_remaining+sky_escaped+sky_wood)/1e9}
 result.W+=hydro_cloud/1e9;result.E+=hydro_heat+hydro_radiated
 result.C+=air+life_atmos+detritus.C;result.N+=detritus.N;result.W+=detritus.W;result.E+=life_heat+detritus.C*20.0
 for pod in propagules:result.C+=pod.c+pod.gas;result.N+=pod.n;result.W+=pod.w;result.E+=pod.c*20.0
 if config.radiation!=0:result.E+=wood_heat+boundary_thermal_out-sky_wood/1e9
 for p in plants:
  var values=p.ledger()
  for key in result:result[key]+=values[key]
 return result
func max_error()->float:
 var result=0.0;var current=ledger()
 for key in initial:result=maxf(result,absf(current[key]-initial[key]-(boundary_input/1e9 if key=="E" else 0.0)))
 return result
func distribute_light():
 var ray=int(round(config.flux*1e9));var emission:int=0
 if config.radiation==0:emission=mini(sky_remaining,ray*Canopy.BEAMS);sky_remaining-=emission
 else:
  var multiplier=1 if config.radiation==1 else 2 if (tick-1)%24<12 else 0
  emission=ray*Canopy.BEAMS*multiplier;boundary_input+=emission
 boundary_flux=emission;sky_emitted+=emission
 var result=Canopy.trace(plants,emission,config.slant==1)
 if result.duplicate:error="shared occupied-space overlap";return
 sky_escaped+=result.escaped;sky_wood+=result.wood
 if config.radiation!=0:wood_heat+=result.wood/1e9
 for p in plants:
  p.leaf_energy={};p.shared_exposure={};var receipt:int=result.intercepted[p.plant_id];p.sunlight+=receipt/1e9;p.received_light+=receipt;intercepted[p.plant_id]+=receipt;shadow_loss[p.plant_id]+=result.shadow[p.plant_id]
  for n in p.nodes:n.light=0.0;n["shadow_owner"]=-1;n["light_receipt"]=0
 for record in result.records:
  var p=plant_by_id(record.plant);var n=p.nodes[record.node];n.light=float(record.incoming)/record.incident if record.incident>0 else 0.0;n.shadow_owner=record.blocker;n.light_receipt=record.receipt;p.shared_exposure[n.pos]=n.light;p.leaf_energy[record.node]=record.receipt
 if emission!=result.escaped+result.wood+int_sum(result.intercepted):error="light partition mismatch"
func plant_by_id(id:int):
 for p in plants:
  if p.plant_id==id:return p
 return null
func resolve_growth(order:Array):
 var groups:Dictionary={}
 for p in order:
  for intent in p.prepare_growth():
   if not groups.has(intent.pos):groups[intent.pos]=[]
   groups[intent.pos].append(intent)
 var positions=groups.keys();positions.sort_custom(func(a,b):return (a.y+8)*273+(a.z+6)*21+a.x+10<(b.y+8)*273+(b.z+6)*21+b.x+10)
 for pos in positions:
  var claims:Array=groups[pos];claims.sort_custom(func(a,b):return ((plant_rank(a.plant)+tick)%plants.size())*1024+a.proposal<((plant_rank(b.plant)+tick)%plants.size())*1024+b.proposal)
  var winner=-1
  for claim in claims:
   var p=plant_by_id(claim.plant);var proposal=p.proposals[claim.proposal]
   if occupied.has(pos):
    var owner:int=occupied[pos].plant;proposal.blocked="occupied by "+String.chr(65+owner);proposal["blocker"]=owner
    if owner!=p.plant_id:p.blocked_count+=1;space_conflicts+=1
    continue
   if not p.payable(proposal):continue
   p.commit_growth(proposal);occupied[pos]={"plant":p.plant_id,"node":proposal.front};winner=p.plant_id
func inspect():
 if config.carbon_access==1:Air.inspect(self)
 var source_total=0
 for q in decomp_sources.values():source_total+=q
 if source_total!=decomp_total or decomp_last<0 or decomp_last>plants.size()*Decomp.CAP:error="litter source/rate mismatch"
 for p in plants:
  if p.litter< -1e-12 or p.atmosphere< -1e-12:error="negative litter or atmosphere"
 if hydro_cloud<0 or hydro_cloud!=hydro_condensed-hydro_rained:error="hydrological water transfer mismatch"
 var sources=0;var returns=0
 for q in hydro_sources.values():sources+=q
 for q in hydro_rain_cells.values():returns+=q
 if sources!=hydro_condensed or returns!=hydro_rained:error="hydrology source/soil receipts mismatch"
 if absf(hydro_heat+hydro_radiated-hydro_condensed/1e9*2.0)>1e-9:error="condensation latent energy mismatch"
 for pod in propagules:
  if pod.c< -1e-12 or pod.n< -1e-12 or pod.w< -1e-12 or pod.gas< -1e-12:error="negative propagule store"
  if pod.child>=0 and plant_by_id(pod.child).genotype!=pod.genotype:error="inheritance mismatch"
 var seen:Dictionary={}
 for p in plants:
  for node in p.nodes:
   if seen.has(node.pos):error="duplicate solid tissue position"
   seen[node.pos]=true
 if sky_remaining<0 or sky_emitted!=sky_escaped+sky_wood+int_sum(intercepted):error="finite sky ledger failed"
 if allocation_residual!=0 or not boundary_balanced():error="shared-world conservation failed"
 for p in plants:
  for key in Plant.Reserve.CAP:
   if absf(p.reserve_deposited[key]-p.reserve_refunded[key]-p.reserve_released[key]-p.reserve_disposed[key]-p.reserve[key])>1e-9:error="reserve transfer ledger failed"
   if p.reserve[key]< -1e-9 or p.reserve[key]>Plant.Reserve.CAP[key]+1e-9:error="reserve capacity/positivity failed"
  if p.max_error()>1e-9:error="plant receipt ledger failed"
  for id in p.nodes.size():
   var node=p.nodes[id]
   if node.parent>=id:error="invalid parent graph"
   for key in ["c","n","w","solid_c","solid_n","bound_w"]:
    if not is_finite(node[key]) or node[key]< -1e-12:error="invalid plant store"
func _visual():
 var start=Time.get_ticks_usec()
 nodes=[];proposals=[]
 for p in plants:
  var offset=nodes.size()
  for n in p.nodes:
   var copy=n.duplicate(true);copy.plant=p.plant_id
   if copy.parent>=0:copy.parent+=offset
   nodes.append(copy)
  for proposal in p.proposals:
   var copy=proposal.duplicate(true);copy.front+=offset;proposals.append(copy)
 times.visual_ms+=(Time.get_ticks_usec()-start)/1000.0
func metrics()->Dictionary:
 var per:Array=[]
 for p in plants:per.append({"id":p.plant_id,"data":p.metrics(),"generation":p.generation,"reserve":p.reserve_state()})
 return {"air":Air.report(self),"censored":censored,"tick":tick,"plants":per,"field":field.summary.duplicate(),"budget_error":max_error(),"radiation":radiation_report(),"hydrology":hydrology_report(),"decomposition":decomposition_report(),"matter":matter_report(),"contested_cell_ticks":contested,"limited_cell_ticks":limited,"allocation_residual":allocation_residual,"error":error,"sky_remaining":sky_remaining,"sky_emitted":sky_emitted,"sky_escaped":sky_escaped,"sky_wood":sky_wood,"intercepted":intercepted.duplicate(),"shadow_loss":shadow_loss.duplicate(),"space_conflicts":space_conflicts,"propagules":propagules.duplicate(true),"lineage":lineage.duplicate(true),"life_events":life_events.duplicate(true),"detritus":detritus.duplicate(),"life_atmos":life_atmos,"life_heat":life_heat}
func fingerprint()->String:
 var begin=Time.get_ticks_usec();var states:Array=[]
 for p in plants:states.append(p.snapshot())
 var hash=var_to_bytes({"air":Air.report(self),"censored":censored,"identity":FIELD_ID,"tick":tick,"boundary":[boundary_input,boundary_flux,wood_heat,boundary_thermal_out],"decomposition":[decomp_total,decomp_last,decomp_sources],"hydrology":[hydro_cloud,hydro_condensed,hydro_rained,hydro_last_rain,hydro_last_condensed,hydro_heat,hydro_radiated,hydro_sources,hydro_rain_cells,water_requested,water_received,water_limited],"plants":states,"field":field.full(),"contested":contested,"limited":limited,"sky":[sky_remaining,sky_emitted,sky_escaped,sky_wood],"intercepted":intercepted,"shadow_loss":shadow_loss,"space_conflicts":space_conflicts,"propagules":propagules,"lineage":lineage,"life_events":life_events,"detritus":detritus,"life_atmos":life_atmos,"life_heat":life_heat,"config":{ "carbon_access":config.carbon_access,"slant":config.slant,"flux":config.flux,"lifecycle":config.lifecycle,"radiation":config.radiation,"recycling":config.recycling,"decomposition":config.decomposition}}).hex_encode().sha256_text();times.audit_ms+=(Time.get_ticks_usec()-begin)/1000.0;return hash
func close():
 if field!=null:field.close()

var propagules:Array=[]
var lineage:Array=[]
var life_events:Array=[]
var detritus={"C":0.0,"N":0.0,"W":0.0}
var life_atmos:float=0.0
var life_heat:float=0.0
func int_sum(values:Array)->int:
 var sum:int=0
 for value in values:sum+=int(value)
 return sum
func plant_rank(id:int)->int:
 for i in plants.size():
  if plants[i].plant_id==id:return i
 return 0
func life_event(text:String):life_events.append({"tick":tick,"message":text})
func seed_shape(pos:Vector3i)->Array:return [pos,pos+Vector3i.UP,pos+Vector3i.DOWN,pos+Vector3i(1,1,0),pos+Vector3i(-1,1,0),pos+Vector3i(0,1,1),pos+Vector3i(0,1,-1)]
func site_free(pos:Vector3i)->bool:
 if pos.y!=0:return false
 for at in seed_shape(pos):
  if occupied.has(at) or at.x< -10 or at.x>10 or at.z< -6 or at.z>6:return false
 for pod in propagules:
  if pod.stage not in ["escrow","dormant"]:continue
  for at in seed_shape(pos):
   if at in seed_shape(pod.pos):return false
 return true
func prepare_nursery(parent:int=0):
 # Explicit finite fixture transfer from soil to A, never extra initial inventory.
 var p=plant_by_id(parent);var commands:Array=[]
 for z in range(-1,2):
  for x in range(-1,2):commands.append([soil_index(Vector3i(x,-2,z)),6000000,350000,0])
 var receipts=field.advance(commands,[])
 for receipt in receipts:p.nodes[0].w+=receipt[0]/1e9;p.nodes[0].n+=receipt[1]/1e9;p.totals.uptake_w+=receipt[0]/1e9;p.totals.uptake_n+=receipt[1]/1e9
 life_event("PREPARED nursery: finite soil W/N transferred to parent "+String.chr(65+parent)+"; founder carbon unchanged")
func request_propagule(parent:int,pos:Vector3i)->bool:
 var p=plant_by_id(parent)
 if p==null:return false
 if config.carbon_access==1 and plants.size()+propagules.filter(func(x):return x.stage in ["escrow","dormant"]).size()>=MAX_RECORDS:censor("computational plant record capacity before seed");return false
 if config.carbon_access==0 and plants.size()+propagules.filter(func(x):return x.stage in ["escrow","dormant"]).size()>=(6 if config.lifecycle==3 else 4):life_event("No propagule: population cap");return false
 for pod in propagules:
  if pod.parent==parent and (config.carbon_access==0 or pod.stage in ["escrow","dormant"]):life_event("No propagule: one commitment per parent" if config.carbon_access==0 else "No propagule: pending seed");return false
 if not site_free(pos):life_event("No propagule: occupied site");return false
 var n=p.nodes[0]
 if config.lifecycle==3:
  if not n.connected or not Plant.Reserve.ready(p) or (config.carbon_access==0 and p.atmosphere<.1):life_event("Parent %s: reserve incomplete (%s)"%[String.chr(65+parent),p.reserve_reason]);return false
 elif not n.connected or n.c<.071 or n.n<.0022 or n.w<.042 or (config.carbon_access==0 and p.atmosphere<.1):life_event("Parent %s: insufficient collar C %.5f/.071 N %.5f/.0022 W %.5f/.042"%[String.chr(65+parent),n.c,n.n,n.w]);return false
 # .02C/.0002N/.002W parental safety floors; .001C assembly respiration.
 if config.lifecycle==3:
  for key in Plant.Reserve.CAP:p.reserve_released[key]+=Plant.Reserve.CAP[key]
  p.reserve.c-=.051;p.reserve.n-=.002;p.reserve.w-=.04;p.reserve_committed=true;p.atmosphere+=.001;p.heat+=.02;p.totals.respired_c+=.001
 else:n.c-=.05;n.n-=.002;n.w-=.04;p.respire(n,.001)
 var gas=.1 if config.carbon_access==0 else 0.0
 p.atmosphere-=gas
 p.donated.C+=.05+gas;p.donated.N+=.002;p.donated.W+=.04;p.donated.E+=1.0
 var pod={"id":propagules.size(),"parent":parent,"child":-1,"genotype":p.genotype.duplicate(true),"pos":pos,"birth":tick,"release":tick+2,"deadline":tick+18,"stage":"escrow","c":.05,"n":.002,"w":.04,"gas":gas,"respired":0.0,"failure":""}
 propagules.append(pod);life_event("Parent "+String.chr(65+parent)+" funded escrow #"+str(pod.id));return true
func seed_respire(pod:Dictionary,amount:float):
 var paid=minf(pod.c,amount);pod.c-=paid;pod.respired+=paid;life_atmos+=paid;life_heat+=paid*20.0
func lifecycle_step():
 if config.lifecycle==0:return
 if config.lifecycle==3:
  for p in plants:
   if not p.nodes[0].connected:
    detritus.C+=p.reserve.c;detritus.N+=p.reserve.n;detritus.W+=p.reserve.w;p.donated.C+=p.reserve.c;p.donated.N+=p.reserve.n;p.donated.W+=p.reserve.w;p.donated.E+=p.reserve.c*20.0
    for key in p.reserve:p.reserve_disposed[key]+=p.reserve[key];p.reserve[key]=0.0
    p.reserve_reason="disconnected account released to detritus"
 if config.lifecycle in [1,3] and tick>=64 and tick%32==0:
  for p in plants:
   if (p.parent_id<0 or config.lifecycle==3) and tick-p.birth_tick>=64 and p.nodes.size()>=32:
    var sites=[Vector3i(-3,0,3),Vector3i(3,0,3),Vector3i(-3,0,-3),Vector3i(3,0,-3),Vector3i(-7,0,3),Vector3i(7,0,3)]
    request_propagule(p.plant_id,sites[p.plant_id] if config.carbon_access==0 else next_site(p.plant_id))
 for pod in propagules:
  if pod.stage=="escrow" and tick>=pod.release:pod.stage="dormant";life_event("Propagule #"+str(pod.id)+" released / dormant")
  if pod.stage=="failed":
   detritus.C+=pod.c;detritus.N+=pod.n;detritus.W+=pod.w;life_atmos+=pod.gas;pod.c=0.0;pod.n=0.0;pod.w=0.0;pod.gas=0.0;pod.stage="decomposed";
   if config.carbon_access==1:plant_by_id(pod.parent).reserve_committed=false
   life_event("Failed propagule transferred to tracked detritus");continue
  if pod.stage!="dormant":continue
  seed_respire(pod,.00002)
  if pod.c<.0136:pod.stage="failed";pod.failure="respiration exhausted construction carbon";life_event(pod.failure);continue
  if tick>=pod.deadline:pod.stage="failed";pod.failure="germination deadline / moisture or occupied space";life_event(pod.failure);continue
  if tick<pod.release+4:continue
  var free=true
  for at in seed_shape(pod.pos):
   if occupied.has(at):free=false
  var moisture:int=field.samples.get(soil_index(pod.pos+Vector3i.DOWN),[0,0])[0]
  if not free or moisture<10000:continue
  germinate(pod)
func germinate(pod:Dictionary):
 if pod.n<.0007512 or pod.w<.00342 or pod.c<.0136:return
 seed_respire(pod,.001)
 var id=2
 while plant_by_id(id)!=null:id+=1
 if id>=MAX_RECORDS:censor("computational record capacity at germination");return
 if config.carbon_access==0 and id>=(6 if config.lifecycle==3 else 4):return
 var child=Plant.new(int(pod.genotype.branch_seed),id,0.0,false);child.genotype=pod.genotype.duplicate(true);child.parent_id=pod.parent;child.generation=plant_by_id(pod.parent).generation+1;child.birth_tick=tick;child.tick=tick;child.shared_field=field;child.sun_vector=sun_direction();var positions=seed_shape(pod.pos)
 for i in positions.size():child._insert(positions[i],-1 if i==0 else 0 if i in [1,2] else 1,"stem" if i<2 else "root" if i==2 else "leaf")
 pod.c-=.0126;pod.n-=.0007512;pod.w-=.00342
 # Leaf construction loss .0012C is respired, never free tissue.
 life_atmos+=.0012;life_heat+=.024
 child.nodes[0].c=pod.c;child.nodes[0].n=pod.n;child.nodes[0].w=pod.w;child.atmosphere=pod.gas;pod.c=0.0;pod.n=0.0;pod.w=0.0;pod.gas=0.0
 child._tip(1,"stem",Vector3.UP,0,0);child._tip(2,"root",Vector3.DOWN,0,0);child.initial=child.ledger();plants.append(child)
 for i in child.nodes.size():occupied[child.nodes[i].pos]={"plant":id,"node":i}
 if config.carbon_access==1:plant_by_id(pod.parent).reserve_committed=false
 pod.child=id;pod.stage="juvenile";lineage.append({"parent":pod.parent,"child":id,"propagule":pod.id,"birth_tick":tick,"genotype":child.genotype.duplicate(true),"mutation":false,"generation":child.generation});life_event("Paid germination: child "+String.chr(65+id)+" / copied genotype / mutation OFF")

var audit_enabled=false
var audit_rows:Array=[]
func audit_sample(phase:String):
 if not audit_enabled or tick not in [64,96,128,192,256,384,512,768,1024]:return
 for p in plants:
  var mobile={"C":0.0,"N":0.0,"W":0.0};var connected={"C":0.0,"N":0.0,"W":0.0};var by_kind:Dictionary={};var required_c=0.0
  for n in p.nodes:
   if not by_kind.has(n.kind):by_kind[n.kind]={"C":0.0,"N":0.0,"W":0.0}
   for pair in [["C","c"],["N","n"],["W","w"]]:
    mobile[pair[0]]+=n[pair[1]];by_kind[n.kind][pair[0]]+=n[pair[1]]
    if n.connected:connected[pair[0]]+=n[pair[1]]
   if n.active:required_c+=n.solid_c*p.UPKEEP[n.kind]*(1.0+1.8*(1.0-n.w/(n.w+.002)))
  audit_rows.append({"tick":tick,"phase":phase,"plant":p.plant_id,"nodes":p.nodes.size(),"living":p.metrics().living,"collar":[p.nodes[0].c,p.nodes[0].n,p.nodes[0].w],"mobile":mobile,"connected":connected,"by_kind":by_kind,"maintenance_c_one_tick_estimate":required_c,"totals":p.totals.duplicate(true),"sky_remaining":sky_remaining})

func radiation_report()->Dictionary:
 var thermal=boundary_thermal_out+hydro_radiated;var prompt=0.0;var heat=wood_heat+life_heat+hydro_heat
 for p in plants:thermal+=p.thermal_out;prompt+=p.radiated-p.thermal_out;heat+=p.heat
 var out=sky_escaped/1e9+thermal+prompt
 var accounted=ledger().E
 return {"mode":config.radiation,"hour":(tick-1)%24 if tick>0 else 0,"input_this_tick":boundary_flux/1e9 if config.radiation!=0 else 0.0,"canopy_flux":boundary_flux/1e9,"input_total":boundary_input/1e9,"transmitted_out":sky_escaped/1e9,"leaf_prompt_out":prompt,"thermal_out":thermal,"output_total":out,"source_remaining":sky_remaining/1e9,"stored_inside":accounted-out-sky_remaining/1e9,"heat_inside":heat,"energy_error":accounted-initial.get("E",accounted)-boundary_input/1e9,"day_energy":int(round(config.flux*1e9))*559*24/1e9,"units":"E model units; one tick = one model hour;24 ticks/day"}
func matter_report()->Dictionary:
 var c={"atmosphere":air+life_atmos,"mobile":0.0,"structure":0.0,"reserves":0.0,"seed_organic":0.0,"seed_gas":0.0,"litter":0.0,"detritus":detritus.C}
 var n={"soil":field.summary[1]/1e9,"mobile":0.0,"structure":0.0,"reserves":0.0,"seeds":0.0,"detritus":detritus.N}
 var w={"cloud":hydro_cloud/1e9,"soil":field.summary[0]/1e9,"mobile":0.0,"bound":0.0,"vapor":0.0,"reserves":0.0,"seeds":0.0,"detritus":detritus.W}
 for p in plants:
  c.atmosphere+=p.atmosphere;c.litter+=p.litter;c.reserves+=p.reserve.c;n.reserves+=p.reserve.n;w.reserves+=p.reserve.w;w.vapor+=p.vapor
  for node in p.nodes:c.mobile+=node.c;c.structure+=node.solid_c;n.mobile+=node.n;n.structure+=node.solid_n;w.mobile+=node.w;w.bound+=node.bound_w
 for pod in propagules:c.seed_organic+=pod.c;c.seed_gas+=pod.gas;n.seeds+=pod.n;w.seeds+=pod.w
 return {"C":c,"N":n,"W":w,"boundary_imports":{"C":0.0,"N":0.0,"W":0.0},"boundary_exports":{"C":0.0,"N":0.0,"W":0.0}}
func boundary_balanced()->bool:
 var totals=ledger();var parts=matter_report()
 for key in ["C","N","W"]:
  var sum=0.0
  for value in parts[key].values():sum+=value
  if absf(sum-totals[key])>1e-9 or absf(totals[key]-initial[key])>1e-9:return false
 var energy_error=absf(totals.E-initial.E-boundary_input/1e9)
 return energy_error<=(1e-9 if config.radiation==0 else 1e-7)

func hydrology_report()->Dictionary:
 var active=0.0;var disconnected=0.0;var vapor=0.0
 for p in plants:
  vapor+=p.vapor
  for n in p.nodes:
   if n.connected:active+=n.w
   else:disconnected+=n.w
 return {"enabled":config.recycling,"cloud":hydro_cloud/1e9,"vapor":vapor,"connected_mobile":active,"disconnected_mobile":disconnected,"condensed_total":hydro_condensed/1e9,"rain_total":hydro_rained/1e9,"condensed_this_hour":hydro_last_condensed/1e9,"rain_this_hour":hydro_last_rain/1e9,"latent_released":hydro_condensed/1e9*2.0,"heat":hydro_heat,"radiated":hydro_radiated,"sources_q":hydro_sources.duplicate(),"rain_cells":hydro_rain_cells.size(),"water_requested":water_requested/1e9,"water_received":water_received/1e9,"water_limited_cell_hours":water_limited}

func decomposition_report()->Dictionary:
 var rows=[];var litter=0.0
 for p in plants:
  litter+=p.litter
  rows.append({"plant":p.plant_id,"litter":p.litter,"atmosphere":p.atmosphere,"returned_C":float(decomp_sources.get(str(p.plant_id),0))/1e9,"heat_released":float(decomp_sources.get(str(p.plant_id),0))/1e9*20.0})
 return {"enabled":config.decomposition,"litter":litter,"returned_C":decomp_total/1e9,"this_hour_C":decomp_last/1e9,"heat_released":decomp_total/1e9*20.0,"sources":rows,"rate":Decomp.RATE,"cap_C_per_plant_hour":Decomp.CAP/1e9,"associated_N_W":"already mobilized by unchanged turnover; zero additional return","excluded_detritus":detritus.duplicate()}

func censor(reason:String):
 if censored.is_empty():censored=reason;life_event("CENSORED whole experiment: "+reason)
func next_site(parent:int)->Vector3i:
 var sites=[Vector3i(-3,0,3),Vector3i(3,0,3),Vector3i(-3,0,-3),Vector3i(3,0,-3),Vector3i(-7,0,3),Vector3i(7,0,3)]
 for z in [-3,3,-5,5,0]:
  for x in [-7,-3,3,7,-9,0,9]:sites.append(Vector3i(x,0,z))
 for k in sites.size():
  var at=sites[(k+parent)%sites.size()]
  if site_free(at):return at
 return Vector3i(0,1,0) # no physical site, not a history/lineage veto
