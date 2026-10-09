extends SceneTree
const W=preload("res://world.gd")
var moves=[]
func _initialize():call_deferred("run")
func pool(p,key:String,front:int,amount:float)->bool:
 var need=maxf(0,amount-p.nodes[front][key]);var total=0.0
 for i in p.nodes.size():
  if i!=front and p.nodes[i].connected:total+=p.nodes[i][key]
 if total+1e-14<need:return false
 for i in p.nodes.size():
  if i==front or not p.nodes[i].connected:continue
  var take=minf(need,float(p.nodes[i][key]));p.nodes[i][key]-=take;p.nodes[front][key]+=take;need-=take
 return need<1e-12
func prepare(w,p):
 # Deliberate contract fixture: arrested apices, conservative caregiving W/N,
 # within-plant pool mixing, manually selected PAID ground-level support packets.
 # No fixture carbon donation; every new C atom comes via ordinary photosynthesis.
 for t in p.tips:t.alive=false
 p.proposals=[]
 var claims=[]
 for i in 9:claims.append([w.soil_index(Vector3i(i%3-1,-2,int(i/3)-1)),2000000,100000,0])
 var receipts=w.field.advance(claims,[])
 for receipt in receipts:p.nodes[0].w+=receipt[0]/1e9;p.nodes[0].n+=receipt[1]/1e9;p.totals.uptake_w+=receipt[0]/1e9;p.totals.uptake_n+=receipt[1]/1e9
 for key in ["c","n","w"]:
  var total=0.0;var live=[]
  for i in p.nodes.size():
   if p.nodes[i].connected:total+=p.nodes[i][key];live.append(i)
  for i in live:p.nodes[i][key]=total/live.size()
 if p.nodes.size()>=32:return
 var front=-1;var pos=Vector3i.ZERO
 for i in p.nodes.size():
  if p.nodes[i].pos.y!=0:continue
  for d in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD,Vector3i.BACK]:
   var at=p.nodes[i].pos+d
   if at.x< -10 or at.x>10 or at.z< -6 or at.z>6 or w.occupied.has(at):continue
   front=i;pos=at;break
  if front>=0:break
 if front<0:return
 var available=0.0
 for n in p.nodes:available+=n.c
 if available<.0224:return
 if not pool(p,"c",front,.0024) or not pool(p,"n",front,.0000576) or not pool(p,"w",front,.00072):return
 var q={"front":front,"kind":"stem","cursor":0,"path":[pos],"tip":-1,"state":"developing","blocked":""}
 if not p.payable(q):return
 p.commit_growth(q);w.occupied[pos]={"plant":p.plant_id,"node":p.nodes.size()-1};moves.append({"tick":w.tick,"plant":p.plant_id,"paid_C":.0024,"kind":"fixture support"})
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var cfg={"seed":4242,"scenario":4,"backend":0,"water":.3,"nitrogen":.01,"light":32768.0,"slant":1,"flux":.08,"lifecycle":3,"radiation":2,"recycling":1,"decomposition":1,"carbon_access":1};var w=W.new(cfg);var max_error=0.0;var samples=[];var reached=false;var births=[];var known=1
 for i in 4080:
  for p in w.plants:
   prepare(w,p)
   if w.lineage.any(func(x):return x.parent==p.plant_id):p.reserve_committed=true
  w.step();
  if w.plants.size()>known:
   for j in range(known,w.plants.size()):births.append({"id":w.plants[j].plant_id,"initial":w.plants[j].initial.duplicate(),"air_received":w.plants[j].air_received,"genotype":w.plants[j].genotype.duplicate(),"nodes":w.plants[j].nodes.size()})
   known=w.plants.size()
  max_error=maxf(max_error,w.max_error())
  if w.tick%96==0:samples.append(w.metrics().duplicate(true))
  if not w.error.is_empty() or not w.censored.is_empty():break
  if w.lineage.any(func(x):return x.generation>=2):reached=true;break
 var checks=[{"pass":births.all(func(x):return absf(x.initial.C-.0477)<1e-9 and x.air_received==0 and x.nodes==7),"name":"actual paid germination inherits only organic seed remainder; no free private gas"},{"pass":w.lineage.all(func(x):return not x.mutation and x.genotype.branch_seed==4242),"name":"verified genotype inheritance; mutation OFF"},{"pass":w.error.is_empty(),"name":"prepared fixture C N W E positivity/conservation"},{"pass":max_error<1e-9,"name":"fixture paid construction and finite soil transfers preserve global budget"},{"pass":reached,"name":"prepared paid founder child grandchild chain"}]
 var f=FileAccess.open("res://evidence/fixture-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"fixture":true,"normal_growth":false,"config":cfg,"tick":w.tick,"lineage":w.lineage,"moves":moves,"births":births,"samples":samples,"end":w.metrics(),"max_error":max_error},"  "));f.close();print(JSON.stringify({"checks":checks,"tick":w.tick,"lineage":w.lineage,"error":w.error}));w.close();quit(0 if checks.all(func(x):return x.pass) else 1)
