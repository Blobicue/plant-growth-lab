extends RefCounted
# Shared finite carbon, bounded by measured leaf demand. No new physiological rate.
const SCALE=1000000000.0
static func log_transfer(w,owner:int,amount:float,reason:String):
 w.air_recent.append({"tick":w.tick,"plant":owner,"C":amount,"reason":reason})
 if w.air_recent.size()>48:w.air_recent.pop_front()
static func collect(w,reason:String):
 for p in w.plants:
  var amount:float=p.atmosphere
  if amount<=0:continue
  p.atmosphere=0.0;p.donated.C+=amount;p.air_returned+=amount;w.air+=amount;w.air_returns+=amount
  var key=str(p.plant_id);w.air_sources[key]=float(w.air_sources.get(key,0.0))+amount;log_transfer(w,p.plant_id,amount,reason)
 if w.life_atmos>0:
  var amount:float=w.life_atmos;w.life_atmos=0.0;w.air+=amount;w.air_returns+=amount
  w.air_sources["seed"]=float(w.air_sources.get("seed",0.0))+amount;log_transfer(w,-1,amount,"seed respiration and assembly")
static func allocate(w):
 w.air_hour=[];var claims=[];var total:int=0;var owners=w.plants.duplicate()
 owners.sort_custom(func(a,b):return a.plant_id<b.plant_id)
 for p in owners:
  var want:int=maxi(0,int(floor(p.photo_claim()*SCALE)))
  claims.append({"plant":p.plant_id,"want":[want,0]});total+=want
 var available:int=mini(total,maxi(0,int(floor(w.air*SCALE))))
 var shares=w.allocate(available,claims,0) if total>0 else []
 for i in claims.size():
  var q:int=shares[i] if total>0 else 0;var p=owners[i];var amount:float=q/SCALE
  w.air-=amount;w.air_uptake+=amount;p.atmosphere+=amount;p.air_received+=amount
  w.air_hour.append({"plant":p.plant_id,"requested_q":claims[i].want[0],"received_q":q})
  if q>0:log_transfer(w,p.plant_id,-amount,"finite fair assimilation access")
static func inspect(w):
 if w.air< -1e-12 or absf(w.air_returns-w.air_uptake-w.air)>1e-9:w.error="shared air debit/credit ledger mismatch"
 var receipts=0.0;var returned=0.0
 for p in w.plants:receipts+=p.air_received;returned+=p.air_returned
 if absf(receipts-w.air_uptake)>1e-9 or absf(returned+float(w.air_sources.get("seed",0.0))-w.air_returns)>1e-9:w.error="plant/global air receipts mismatch"
 for h in w.air_hour:
  if h.received_q<0 or h.received_q>h.requested_q:w.error="unbounded atmospheric allocation"
static func report(w)->Dictionary:
 var owners=[]
 for p in w.plants:owners.append({"plant":p.plant_id,"received_C":p.air_received,"returned_C":p.air_returned,"private_buffer_C":p.atmosphere,"account_error":p.max_error()})
 return {"mode":w.config.carbon_access,"shared_C":w.air,"received_by_plants_C":w.air_uptake,"returned_C":w.air_returns,"sources":w.air_sources.duplicate(),"hour":w.air_hour.duplicate(true),"recent":w.air_recent.duplicate(true),"plants":owners,"allocation":"physiological demand bounded, proportional integer shares, rotating residual ties","quantum_C":1.0/SCALE,"external_C_imports":0.0}
