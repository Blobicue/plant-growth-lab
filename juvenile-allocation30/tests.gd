extends SceneTree
const W=preload("res://world.gd")
const Old=preload("res://control/world.gd")
var checks=[]
func check(ok:bool,name:String):
 checks.append({"pass":ok,"name":name})
 if not ok:push_error(name)
func cfg(mode:int=1)->Dictionary:return {"seed":4242,"scenario":3,"backend":0,"water":.3,"nitrogen":.01,"light":32768.0,"slant":1,"flux":.08,"lifecycle":3,"radiation":2,"recycling":1,"decomposition":1,"carbon_access":mode}
func _initialize():call_deferred("run")
func clean_metrics(w)->Dictionary:
 var m=w.metrics();m.erase("air");m.erase("censored");m.intercepted.resize(6);m.shadow_loss.resize(6);return m
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var a=W.new(cfg(0));var b=Old.new(cfg(0));var match_old=true
 for i in 960:
  a.step();b.step();match_old=match_old and a.error.is_empty() and b.error.is_empty() and clean_metrics(a)==b.metrics()
 check(match_old,"private control exactly matches W20 physical metrics every hour960");a.close();b.close()
 a=W.new(cfg());check(absf(a.air-10)<1e-12 and absf(a.initial.C-10.6228)<1e-12,"shared initialization transfers existing founder gas without subsidy")
 var valid=true
 for i in 960:a.step();valid=valid and a.error.is_empty() and a.air>=0
 check(valid,"shared960h positivity and global/plant C N W E ledgers")
 check(a.air_uptake>0 and a.air_returns>10,"actual assimilation access and accounted respiration/litter returns")
 check(a.plants.all(func(p):return p.air_received>0 and p.max_error()<1e-9),"perplant receipts reconcile with global air")
 a.close()
 for kind in ["dark","dry","noN"]:
  var c=cfg();c.flux=0.0 if kind=="dark" else c.flux;c.water=0.0 if kind=="dry" else c.water;c.nitrogen=0.0 if kind=="noN" else c.nitrogen;a=W.new(c)
  for i in 240:a.step()
  check(a.error.is_empty(),kind+" conservative resource boundary")
  if kind=="dark":check(a.air_uptake==0 and a.plants.all(func(p):return p.totals.fixed_c==0),"no fixation or atmospheric withdrawal in darkness")
  a.close()
 # Synthetic allocation claims exercise stock/rounding independently of physiology.
 a=W.new(cfg());var claims=[{"plant":0,"want":[7,0]},{"plant":1,"want":[7,0]}];var sa=0;var sb=0;var bounded=true
 for t in 14:
  a.tick=t;var shares=a.allocate(3,claims,0);sa+=shares[0];sb+=shares[1];bounded=bounded and shares[0]+shares[1]==3 and shares[0]<=7 and shares[1]<=7
 check(bounded and sa==sb,"symmetric competition bounded fair rotating remainder no double spend")
 check(a.allocate(0,claims,0)==[0,0],"empty finite source grants zero")
 # Direct photo fixture: withdraw real finite air then consume actual leaf energy.
 for p in a.plants:
  for n in p.nodes:
   if n.kind=="leaf":n.w=.006;n.light=1.0
  p.leaf_energy={3:10000000,4:10000000,5:10000000,6:10000000};p.sunlight=.04
 a.air=.000000005;var before=a.air_uptake;W.Air.allocate(a)
 check(absf(a.air_uptake-before-.000000005)<1e-12 and a.air>=-1e-12,"five-quanta finite air exhausted without overdraft")
 for p in a.plants:p.photosynthesize()
 check(a.plants.all(func(p):return p.atmosphere<1e-12),"allocated atmospheric C used by actual photon-limited fixation")
 for p in a.plants:p.atmosphere=0.0
 a.air=0.0;before=a.air_uptake;W.Air.allocate(a);var fixed=0.0
 for p in a.plants:fixed+=p.totals.fixed_c;p.photosynthesize()
 var after=0.0
 for p in a.plants:after+=p.totals.fixed_c
 check(a.air_uptake==before and fixed==after,"no available carbon means no fixation despite light and water");a.close()
 a=W.new(cfg());a.censor("fixture computational capacity");var tick=a.tick;var fingerprint=a.fingerprint();a.step();check(a.tick==tick and a.fingerprint()==fingerprint,"safety censor freezes whole experiment rather than selecting a birth");a.close()
 # Repeat-commitment unit fixture: bank funded exclusively from existing stores.
 a=W.new(cfg());var parent=a.plants[0];a.prepare_nursery(0);var funded=fixture_bank(parent)
 var first=a.request_propagule(0,Vector3i(-3,0,3)) if funded else false
 for i in 6:a.step()
 var reset=not parent.reserve_committed
 a.prepare_nursery(0);funded=fixture_bank(parent)
 var second=a.request_propagule(0,a.next_site(0)) if funded else false
 W.Air.collect(a,"fixture assembly return");a.inspect()
 check(first and reset and second and a.error.is_empty(),"second parent commitment is fully paid after prior seed resolves; fixture only")
 check(a.propagules[0].gas==0 and a.propagules[1].gas==0,"shared seeds have no duplicated private gas parcel")
 var blank=W.Plant.new(4242,31,0.0,false)
 check(blank.nodes.is_empty() and blank.ledger().C==0 and blank.ledger().N==0 and blank.ledger().W==0,"offspring constructor contains zero tissue and zero matter subsidy")
 a.close()
 var screen=load("res://lab.gd").new();var record={"version":27,"identity":W.FIELD_ID,"config":cfg(),"tick":960,"fingerprint":"a".repeat(64)}
 check(screen._valid_record(JSON.parse_string(JSON.stringify(record))),"shared/private carbon mode in exact replay schema");record.config.carbon_access=.5;check(not screen._valid_record(record),"fractional carbon mode rejected");screen.free()
 var f=FileAccess.open("res://evidence/model-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"  "));f.close();print(JSON.stringify({"checks":checks}));quit(0 if checks.all(func(x):return x.pass) else 1)

func fixture_bank(p)->bool:
 for key in W.Plant.Reserve.CAP:
  var need=maxf(0,float(W.Plant.Reserve.CAP[key])-float(p.reserve[key]));var total=0.0
  for n in p.nodes:total+=n[key]
  if total<need:return false
 for key in W.Plant.Reserve.CAP:
  var need=maxf(0,float(W.Plant.Reserve.CAP[key])-float(p.reserve[key]))
  for i in p.nodes.size():
   var amount=minf(need,float(p.nodes[i][key]));p.nodes[i][key]-=amount;p.reserve[key]+=amount;p.reserve_deposited[key]+=amount;need-=amount
   if amount>0:W.Plant.Reserve.flow(p,i,key,amount,"explicit paid reserve unit fixture")
 return true
