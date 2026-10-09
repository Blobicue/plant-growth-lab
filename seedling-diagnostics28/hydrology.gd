extends RefCounted
const SCALE=1000000000.0
const CONDENSE_RATE=.01
const CONDENSE_CAP=2000000
const RAIN_CAP=1000000
static func rain_requests(w,commands:Array)->Array:
 w.hydro_last_rain=0;w.hydro_last_condensed=0
 if w.config.recycling==0:return []
 var count=mini(273,maxi(0,w.field.MAX_COMMANDS-commands.size()))
 var budget=mini(w.hydro_cloud,mini(RAIN_CAP,w.field.COUNT*w.field.CAP-int(w.field.summary[0])))
 if count<=0 or budget<=0:return []
 var positions=[]
 for j in count:
  var cell=((w.tick-1)+j)%273;var pos=Vector3i(cell%21-10,-1,int(cell/21)-6);var index=w.soil_index(pos);var amount:int=budget/count+(1 if j<budget%count else 0)
  if amount>0:commands.append([index,amount,0,1]);positions.append(index)
 return positions
static func receive_rain(w,receipts:Array,offset:int,positions:Array):
 for j in positions.size():
  var q:int=receipts[offset+j][0];w.hydro_cloud-=q;w.hydro_rained+=q;w.hydro_last_rain+=q
  var key=str(positions[j]);w.hydro_rain_cells[key]=int(w.hydro_rain_cells.get(key,0))+q
static func condense(w):
 if w.config.recycling==0:return
 var claims=[];var total=0
 for p in w.plants:
  var q=maxi(0,int(floor(p.vapor*SCALE*CONDENSE_RATE)));claims.append({"plant":p.plant_id,"want":[q,0]});total+=q
 if total>0:
  var shares=w.allocate(mini(total,CONDENSE_CAP),claims,0)
  for i in claims.size():
   var q:int=shares[i]
   if q<=0:continue
   var p=w.plant_by_id(claims[i].plant);var amount=q/SCALE;p.vapor-=amount;p.donated.W+=amount;p.donated.E+=amount*2.0
   w.hydro_cloud+=q;w.hydro_condensed+=q;w.hydro_last_condensed+=q;w.hydro_heat+=amount*2.0
   var key=str(p.plant_id);w.hydro_sources[key]=int(w.hydro_sources.get(key,0))+q
 var loss=w.hydro_heat*.02;w.hydro_heat-=loss;w.hydro_radiated+=loss
