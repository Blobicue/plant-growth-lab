extends RefCounted
const BEAMS=559 # 43 fixed projected lattice columns x 13 z columns.
const Q=1000000000
static func trace(plants:Array,emission:int,slant:bool)->Dictionary:
 var columns:Dictionary={};var occupied:Dictionary={};var records:Array=[];var duplicate=false
 for p in plants:
  for i in p.nodes.size():
   var n=p.nodes[i];var pos:Vector3i=n.pos
   if occupied.has(pos):duplicate=true
   occupied[pos]={"plant":p.plant_id,"node":i}
   if pos.y<0:continue
   var key=Vector2i(pos.x-pos.y if slant else pos.x,pos.z)
   if not columns.has(key):columns[key]=[]
   columns[key].append({"plant":p.plant_id,"node":i,"pos":pos,"kind":n.kind,"solid":n.solid_c,"connected":n.connected})
 var escaped:int=0;var wood:int=0;var intercepted=[];intercepted.resize(32);intercepted.fill(0);var shadow=intercepted.duplicate()
 for z in range(-6,7):
  for x in range(-32,11):
   var ordinal=(z+6)*43+x+32;var incoming:int=emission/BEAMS+(1 if ordinal<emission%BEAMS else 0);var incident=incoming
   var own=[];own.resize(32);own.fill(incoming);var above=[];above.resize(32);above.fill(false);var members:Array=columns.get(Vector2i(x,z),[])
   members.sort_custom(func(a,b):return a.pos.y>b.pos.y if a.pos.y!=b.pos.y else a.plant<b.plant)
   for n in members:
    var alpha:float=(.32 if n.kind=="leaf" else .65)*clampf(n.solid/(.0012 if n.kind=="leaf" else .0024),0,1)
    var loss:int=mini(incoming,int(floor(incoming*alpha)));var owner:int=n.plant
    var lost_to_other=maxi(0,int(own[owner])-incoming);var blocker=-1
    for other in 32:
     if other!=owner and above[other]:blocker=other;break
    records.append({"plant":owner,"node":n.node,"incoming":incoming,"incident":incident,"receipt":loss if n.kind=="leaf" and n.connected else 0,"shadow_loss":lost_to_other,"blocker":blocker})
    if n.kind=="leaf" and n.connected:intercepted[owner]+=loss;shadow[owner]+=lost_to_other
    else:wood+=loss
    own[owner]-=int(floor(own[owner]*alpha));incoming-=loss
    if loss>0:above[owner]=true
   escaped+=incoming
 records.sort_custom(func(a,b):return a.plant*512+a.node<b.plant*512+b.node)
 return {"records":records,"occupied":occupied,"duplicate":duplicate,"escaped":escaped,"wood":wood,"intercepted":intercepted,"shadow":shadow,"emitted":emission}
