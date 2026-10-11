extends SceneTree
const State=preload("res://state.gd")
const T=preload("res://transport.gd")
const R=preload("res://relabel.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var plan=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-transport/protocol.json"));var rows=[]
 for c in plan.cohorts:
  var path="/workspace/plant-growth-lab/"+c.file;var a=State.new().restore(path);var b=State.new().restore(path);var fine=State.new().restore(path)
  assert(a.fingerprint()==c.fingerprint and b.fingerprint()==c.fingerprint)
  var pa=a.plant_by_id(int(c.id));var pb=b.plant_by_id(int(c.id));var pf=fine.plant_by_id(int(c.id));var before=pa.ledger();var births=[]
  for n in pa.nodes:births.append(n.birth)
  assert(births.all(func(t):return t==births[0]),"same-age audit")
  R.relabel(b,pb);assert(R.canonical(pa)==R.canonical(pb))
  var report=T.apply(pa,24);T.apply(pb,24);T.apply(pf,48);assert(R.canonical(pa)==R.canonical(pb),"real graph canonical transport exact")
  var residual=0.0;var relative_difference={}
  for k in ["C","N","W","E"]:residual=maxf(residual,absf(pa.ledger()[k]-before[k]))
  for k in ["c","n","w"]:
   var norm=0.0;var delta=0.0
   for i in pa.nodes.size():norm+=pa.nodes[i][k];delta+=absf(pa.nodes[i][k]-pf.nodes[i][k])
   relative_difference[k]=delta/norm if norm>0 else 0.0
  assert(residual<=1e-9);a.close();b.close();fine.close()
  var w=State.new().restore(path);var ref=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-feedback/evidence/relabel-%d-%d.json"%[c.seed,c.id]))
  for age in 96:
   w.step();assert(w.fingerprint()==ref.hourly[age].baseline_physical_hash,"OFF original every-hour physics")
  rows.append({"seed":c.seed,"id":c.id,"all_node_births_equal":true,"canonical_permutation_exact":true,"OFF_hours_exact":96,"transport_ledger_residual":residual,"N24_vs_N48_normalized_l1":relative_difference,"maximum_sender_fraction":report.maximum_sender_fraction});w.close();print("birth preflight %d/%d passed"%[c.seed,c.id])
 var f=FileAccess.open("res://evidence/birth-preflight.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":rows,"pass":true},"  ",true,true));f.close();quit()
