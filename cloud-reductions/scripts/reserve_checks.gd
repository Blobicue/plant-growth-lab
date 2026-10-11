extends SceneTree
const State=preload("res://state.gd")
const O=preload("res://reduction_order.gd")
const R=preload("res://relabel.gd")
const Reserve=preload("res://reserve.gd")
func _initialize():call_deferred("run")
func stock(p):
 var result=p.reserve.duplicate()
 for i in O.ids(p):
  for k in result:result[k]+=p.nodes[i][k]
 return result
func prepare(p,kind):
 p.reserve={"c":.00009,"n":.000006,"w":.001} if kind=="scarce_upkeep" else {"c":.0509,"n":.0019999,"w":.0399}
 p.reserve_deposited=p.reserve.duplicate();p.reserve_refunded={"c":0.0,"n":0.0,"w":0.0};p.reserve_released={"c":0.0,"n":0.0,"w":0.0};p.reserve_disposed={"c":0.0,"n":0.0,"w":0.0}
 var ids=O.ids(p)
 for rank in ids.size():
  var n=p.nodes[ids[rank]]
  n.c=0.0 if kind=="scarce_upkeep" else .001*(rank+1);n.n=0.0 if kind=="scarce_upkeep" else .00001*(rank+1);n.w=0.0 if kind=="scarce_upkeep" else .003*(rank+1)
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var checks=[]
 for kind in ["scarce_upkeep","near_capacity_collection"]:
  var a=State.new().restore("/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-12011-3.bin");var b=State.new().restore("/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-12011-3.bin");var pa=a.plant_by_id(3);var pb=b.plant_by_id(3);R.relabel(b,pb);prepare(pa,kind);prepare(pb,kind)
  var before=stock(pa);assert(before==stock(pb))
  for p in [pa,pb]:
   if kind=="scarce_upkeep":Reserve.protect(p)
   else:Reserve.collect(p,.002)
  assert(R.canonical(pa)==R.canonical(pb));assert(pa.reserve==pb.reserve);var after=stock(pa);var maximum=0.0
  for k in before:
   maximum=maxf(maximum,absf(after[k]-before[k]));assert(absf(after[k]-before[k])<1e-12)
   assert(pa.reserve[k]>=0.0 and pa.reserve[k]<=Reserve.CAP[k]+1e-12)
   assert(absf(pa.reserve_deposited[k]-pa.reserve_refunded[k]-pa.reserve[k])<1e-12)
  checks.append({"fixture":kind,"canonical_nodes_and_bank_exact":true,"conservation_error":maximum,"before":before,"after":after,"bank":pa.reserve.duplicate()});a.close();b.close()
 var f=FileAccess.open("res://evidence/reserve-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"pass":true,"synthetic_closed_transfer_fixtures":true,"checks":checks},"  ",true,true));f.close();print("Scarce reserve upkeep and near-capacity collection pass exact permutations and budgets");quit()
