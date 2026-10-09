extends RefCounted
# Explicit bounded vascular allocation approximation; no change to tissue transport.
const CAP={"c":.051,"n":.002,"w":.04}
static func mobile(p)->float:
 var value=0.0
 for n in p.nodes:
  if n.connected:value+=n.c
 return value
static func floor_c(p,n)->float:
 var demand:float=n.solid_c*p.UPKEEP[n.kind]*(1.0+1.8*(1.0-n.w/(n.w+.002)))
 var repair:float=maxf(0,p.PACK[n.kind]-n.solid_c)/(.8 if n.kind=="leaf" else 1.0)
 return 8.0*(demand*1.105+demand*.35/(.8 if n.kind=="leaf" else 1.0)+.00001)+repair
static func floor_value(p,n,key:String)->float:
 if key=="c":return floor_c(p,n)
 if key=="n":return p.PACK[n.kind]*p.NR[n.kind]*.2
 return .004 if n.kind=="leaf" else .002
static func flow(p,node:int,key:String,amount:float,reason:String):
 var index=str(node)+":"+key
 p.reserve_sources[index]=float(p.reserve_sources.get(index,0.0))+amount
 p.reserve_recent.append({"tick":p.tick,"node":node,"resource":key,"amount":amount,"reason":reason})
 if p.reserve_recent.size()>24:p.reserve_recent.pop_front()
static func protect(p)->float:
 var carbon=0.0
 for i in p.nodes.size():
  var n=p.nodes[i]
  if not n.connected:continue
  for key in CAP:
   var need=maxf(0,floor_value(p,n,key)/8.0-float(n[key]))
   var give=minf(float(p.reserve[key]),need)
   if give<=0:continue
   p.reserve[key]-=give;n[key]+=give;p.reserve_refunded[key]+=give;flow(p,i,key,-give,"maintenance priority")
   if key=="c":carbon+=give
 return carbon
static func collect(p,net:float):
 p.reserve_last_surplus=maxf(0,net);p.reserve_surplus+=maxf(0,net)
 if p.reserve_committed or not p.nodes[0].connected:p.reserve_reason="committed or disconnected";return
 if net<=0:p.reserve_reason="no new surplus after maintenance";return
 var fraction=.5*net/CAP.c
 var available={"c":0.0,"n":0.0,"w":0.0}
 for n in p.nodes:
  if not n.connected:continue
  for key in CAP:available[key]+=maxf(0,float(n[key])-floor_value(p,n,key))
 var collected=false
 for key in CAP:
  var total:float=minf(fraction*CAP[key],minf(available[key],CAP[key]-float(p.reserve[key])));var left=total
  if total<=1e-15:continue
  collected=true
  for i in p.nodes.size():
   var n=p.nodes[i]
   if not n.connected:continue
   var excess=maxf(0,float(n[key])-floor_value(p,n,key))
   var take=minf(left,total*excess/available[key]) if available[key]>0 else 0.0
   if take<=0:continue
   n[key]-=take;p.reserve[key]+=take;p.reserve_deposited[key]+=take;left-=take;flow(p,i,key,take,"new surplus allocation")
 p.reserve_reason="collecting half of new surplus; maintenance protected" if collected else "protected mobile C/N/W or capacity"
static func ready(p)->bool:
 for key in CAP:
  if float(p.reserve[key])<CAP[key]-1e-10:return false
 return true
