extends "res://base_plant.gd"
var hold_partial=false
var hold_leaves=false
var hour={}
var previous=[]
var events=[]
func proposal_expired(p:Dictionary)->bool:
 if (hold_partial and p.cursor>0 or hold_leaves and p.kind=="leaf") and not str(p.blocked).begins_with("occupied"):return false
 return super.proposal_expired(p)
func transport_pools():
 hour={"tick":tick,"plant":plant_id,"uptake_W":0.0,"uptake_N":0.0,"leaf_transport_W":0.0,"fixed_C":0.0,"respired_C":0.0,"repair_C":0.0,"unpaid_C":0.0,"leaf_fixed_C":0.0,"leaf_respired_C":0.0,"leaf_repair_C":0.0,"growth":[],"refusals":[],"leaf_samples":[]}
 var before=nodes.duplicate(true)
 for i in nodes.size():
  if i<previous.size() and nodes[i].kind=="root":
   hour.uptake_W+=nodes[i].w-previous[i].w;hour.uptake_N+=nodes[i].n-previous[i].n
 super.transport_pools()
 for i in nodes.size():
  if nodes[i].kind=="leaf":hour.leaf_transport_W+=nodes[i].w-before[i].w
func photosynthesize():
 var before=nodes.duplicate(true);super.photosynthesize()
 for i in nodes.size():
  var n=nodes[i];var fixed=n.c-before[i].c;hour.fixed_C+=fixed
  if n.kind=="leaf":
   hour.leaf_fixed_C+=fixed;hour.leaf_samples.append({"id":i,"connected":n.connected,"water":before[i].w,"mass":n.solid_c,"light":n.light,"receipt":leaf_energy.get(i,0),"fixed_C":fixed})
func respire(n:Dictionary,amount:float)->float:
 var paid=super.respire(n,amount)
 if not hour.is_empty():
  hour.respired_C+=paid
  if n.kind=="leaf":hour.leaf_respired_C+=paid
 return paid
func maintain():
 var before=nodes.duplicate(true);super.maintain()
 for i in before.size():
  var old=before[i];var n=nodes[i]
  if not old.active:continue
  var demand=old.solid_c*UPKEEP[old.kind]*(1+1.8*(1-old.w/(old.w+.002)))
  var repair=maxf(0,n.solid_c-old.solid_c+minf(old.solid_c,demand*.35))/(.8 if old.kind=="leaf" else 1.0)
  hour.repair_C+=repair;hour.unpaid_C+=maxf(0,demand*.65-old.c)
  if old.kind=="leaf":hour.leaf_repair_C+=repair
  if not n.active:events.append({"tick":tick,"event":"death","node":i,"before":old,"after":n.duplicate(true)})
func prepare_growth()->Array:
 var before=proposals.duplicate(true);var result=super.prepare_growth()
 for i in before.size():
  if before[i].state=="developing" and proposals[i].state=="failed":events.append({"tick":tick,"event":"proposal_cancel","proposal":i,"old":before[i],"connected":nodes[before[i].front].connected})
 return result
func payable(p:Dictionary)->bool:
 var ok=super.payable(p)
 if generation>0 and not ok:hour.refusals.append({"proposal":proposals.find(p),"cursor":p.cursor,"goal":p.path[-1],"front":p.front,"kind":p.kind,"blocked":p.blocked,"local":nodes[p.front].duplicate(true),"cost_C":PACK[p.kind]/(.8 if p.kind=="leaf" else 1.0),"cost_N":PACK[p.kind]*NR[p.kind],"cost_W":PACK[p.kind]*.3})
 return ok
func commit_growth(p:Dictionary):
 if generation>0:hour.growth.append({"proposal":proposals.find(p),"kind":p.kind,"cursor_before":p.cursor,"path_size":p.path.size(),"front_before":p.front,"cost_C":PACK[p.kind]/(.8 if p.kind=="leaf" else 1.0)})
 super.commit_growth(p)
func finish_hour():
 if hour.is_empty():previous=nodes.duplicate(true);return
 var mobile={"c":0.0,"n":0.0,"w":0.0};var disconnected=mobile.duplicate();var living=0
 for n in nodes:
  var pool=mobile if n.connected else disconnected
  for key in pool:pool[key]+=n[key]
  if n.active:living+=1
 hour.mobile=mobile;hour.disconnected=disconnected;hour.living=living;hour.nodes=nodes.size();hour.reserve=reserve_state();hour.totals=totals.duplicate(true)
 hour.margin_C=hour.fixed_C-hour.respired_C-hour.repair_C;hour.leaf_margin_C=hour.leaf_fixed_C-hour.leaf_respired_C-hour.leaf_repair_C
 previous=nodes.duplicate(true)
