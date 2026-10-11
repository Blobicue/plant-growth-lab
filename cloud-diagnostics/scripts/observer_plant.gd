extends "res://base_plant.gd"
var obs_hour={}
var obs_day={}
var obs_events=[]
var obs_seen={}
var obs_last_totals={"uptake_w":0.0,"uptake_n":0.0}
func event_once(key:String,data:Dictionary):
 if obs_seen.has(key):return
 obs_seen[key]=true;obs_events.append({"tick":tick,"age":tick-birth_tick,"event":key,"data":data.duplicate(true)})
func pools()->Dictionary:
 var x={"c":0.0,"n":0.0,"w":0.0,"disconnected_c":0.0,"disconnected_n":0.0,"disconnected_w":0.0}
 for n in nodes:
  for k in ["c","n","w"]:x[k if n.connected else "disconnected_"+k]+=n[k]
 return x
func transport_pools():
 obs_hour={"uptake_W":totals.uptake_w-obs_last_totals.uptake_w,"uptake_N":totals.uptake_n-obs_last_totals.uptake_n,"fixed_C":0.0,"direct_respired_C":0.0,"repair_C":0.0,"turnover_C":0.0,"unpaid_C":0.0,"construction_C":0.0,"construction_N":0.0,"construction_W":0.0,"actual_demand_C":0.0,"hydrated_demand_C":0.0,"unshaded_hydrated_C":0.0,"leaf_water_sum":0.0,"connected_leaves":0.0,"light_receipt_E":0.0,"refused_C":0.0,"refused_N":0.0,"refused_W":0.0}
 super.transport_pools()
func photosynthesize():
 if generation>0:
  var sun=.35+.65*absf(sun_direction().y)
  for i in nodes.size():
   var n=nodes[i]
   if n.kind!="leaf" or not n.connected:continue
   var light_cap=float(leaf_energy.get(i,0))/1e9*.18/CHEM
   obs_hour.hydrated_demand_C+=minf(n.solid_c*.216*n.light*sun,light_cap)
   obs_hour.unshaded_hydrated_C+=n.solid_c*.216*sun if n.light>0 else 0.0
   obs_hour.leaf_water_sum+=n.w;obs_hour.connected_leaves+=1;obs_hour.light_receipt_E+=float(leaf_energy.get(i,0))/1e9
  obs_hour.actual_demand_C=photo_claim()
 var before=totals.fixed_c;super.photosynthesize();obs_hour.fixed_C=totals.fixed_c-before
func respire(n:Dictionary,amount:float)->float:
 var paid=super.respire(n,amount)
 if not obs_hour.is_empty():obs_hour.direct_respired_C+=paid
 return paid
func maintain():
 var before=nodes.duplicate(true) if generation>0 else [];super.maintain()
 for i in before.size():
  var old=before[i];var n=nodes[i]
  if not old.active:continue
  var demand=old.solid_c*UPKEEP[old.kind]*(1+1.8*(1-old.w/(old.w+.002)))
  var turnover=minf(old.solid_c,demand*.35);var repair=maxf(0,n.solid_c-old.solid_c+turnover)/(.8 if old.kind=="leaf" else 1.0)
  var unpaid=maxf(0,demand*.65-old.c)
  obs_hour.repair_C+=repair;obs_hour.turnover_C+=turnover;obs_hour.unpaid_C+=unpaid
  if unpaid>1e-14:event_once("unpaid_node_%d"%i,{"node":i,"kind":old.kind,"required_C":demand*.65,"available_C":old.c,"water":old.w,"stress":old.stress})
  if not n.active:event_once("death_node_%d"%i,{"node":i,"kind":old.kind,"before":old,"after":n,"stress_threshold":n.stress>45,"mass_threshold":n.solid_c<PACK[n.kind]*.2})
func prepare_growth()->Array:
 var before=[]
 if generation>0:
  for i in proposals.size():
   if proposals[i].state=="developing":before.append({"id":i,"data":proposals[i].duplicate(true)})
 var result=super.prepare_growth()
 for entry in before:
  var old=entry.data
  if proposals[entry.id].state=="failed":event_once("cancel_"+old.kind+"_"+old.blocked,{"proposal":entry.id,"before":old,"local":nodes[old.front],"pools":pools()})
 return result
func payable(p:Dictionary)->bool:
 var ok=super.payable(p)
 if generation>0 and not ok:
  var cost={"c":PACK[p.kind]/(.8 if p.kind=="leaf" else 1.0),"n":PACK[p.kind]*NR[p.kind],"w":PACK[p.kind]*.3};var n=nodes[p.front];var short=[]
  for k in cost:
   if n[k]<cost[k]:short.append(k);obs_hour[{"c":"refused_C","n":"refused_N","w":"refused_W"}[k]]+=1
  event_once("refusal_"+p.kind+"_"+str(short),{"kind":p.kind,"proposal":proposals.find(p),"front":p.front,"cost":cost,"local":n,"pools":pools(),"short":short})
 return ok
func commit_growth(p:Dictionary):
 if generation>0:
  obs_hour.construction_C+=PACK[p.kind]/(.8 if p.kind=="leaf" else 1.0);obs_hour.construction_N+=PACK[p.kind]*NR[p.kind];obs_hour.construction_W+=PACK[p.kind]*.3
  event_once("built_node_%d"%nodes.size(),{"kind":p.kind,"proposal":proposals.find(p),"front":p.front,"position":p.path[p.cursor],"cursor":p.cursor,"path_size":p.path.size()})
 super.commit_growth(p)
func finish_observation():
 if obs_hour.is_empty():return
 obs_hour.operating_C=obs_hour.fixed_C-obs_hour.direct_respired_C-obs_hour.repair_C
 for k in obs_hour:obs_day[k]=float(obs_day.get(k,0.0))+obs_hour[k]
 obs_last_totals={"uptake_w":totals.uptake_w,"uptake_n":totals.uptake_n}
 if generation>0 and nodes.size()>=32:event_once("maturity32",{"pools":pools(),"reserve":reserve_state()})
 if generation>0 and metrics().living==0:event_once("all_tissue_dead",{"nodes":nodes.size(),"pools":pools()})
