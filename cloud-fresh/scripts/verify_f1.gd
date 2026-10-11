extends SceneTree
const State=preload("res://state.gd")
const R=preload("res://relabel.gd")
const ROOT="/workspace/plant-growth-lab/cloud-fresh/work/model/evidence/"
func _initialize():call_deferred("run")
func expected(dir,tick):
 var end=int(ceil(float(tick)/24))*24;var d=JSON.parse_string(FileAccess.get_file_as_string(dir+"day-%05d.json"%end));return d.hashes[(tick-1)%24]
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]);var mode=int(args[1]);var kind=args[2];assert(kind in ["restart","canonical","founder_canonical"])
 var dir=ROOT+"f1-%d-%d/"%[seed,mode];var a;var b=null;var start=6144
 if kind=="restart":a=State.new().restore(dir+"state-06144.bin")
 elif kind=="founder_canonical":
  assert(mode==24);a=State.new().restore(dir+"state-00000.bin");b=State.new().restore(dir+"state-00000.bin");start=0
  for p in b.plants:R.relabel(b,p)
 else:
  assert(mode==24)
  if not FileAccess.file_exists(dir+"birth-2.bin"):
   var f=FileAccess.open(ROOT+"verify-%d-%d-%s.json"%[seed,mode,kind],FileAccess.WRITE);f.store_string(JSON.stringify({"seed":seed,"mode":mode,"kind":kind,"available":false,"reason":"no paid descendant in fixed window"}));f.close();quit();return
  a=State.new().restore(dir+"birth-2.bin");b=State.new().restore(dir+"birth-2.bin");start=a.tick;R.relabel(b,b.plant_by_id(2))
 assert(a.fingerprint()==(JSON.parse_string(FileAccess.get_file_as_string(dir+"initial.json")).fingerprint if a.tick==0 else expected(dir,a.tick)));var count=mini(96,12288-start);var peak=0.0
 for i in count:
  a.step(true)
  for p in a.plants:p.finish_observation()
  assert(a.error.is_empty() and a.censored.is_empty());assert(a.fingerprint()==expected(dir,a.tick),"saved reverse evaluation replay mismatch")
  peak=maxf(peak,a.max_error())
  if b!=null:
   b.step()
   for p in b.plants:p.finish_observation()
   assert(b.error.is_empty() and b.censored.is_empty());assert(a.plants.size()==b.plants.size())
   for p in a.plants:assert(R.canonical(p)==R.canonical(b.plant_by_id(p.plant_id)),"exact canonical nodes differ")
   assert(a.field.full()==b.field.full(),"exact canonical field differs")
   for k in ["C","N","W","E"]:assert(absf(a.ledger()[k]-b.ledger()[k])<=1e-9)
   assert(a.lineage==b.lineage and a.propagules==b.propagules)
 var result={"pass":true,"available":true,"seed":seed,"mode":mode,"kind":kind,"start_tick":start,"hours":count,"reverse_saved_replay_exact":true,"canonical_nodes_and_field_exact":b!=null,"max_world_error":peak}
 var f=FileAccess.open(ROOT+"verify-%d-%d-%s.json"%[seed,mode,kind],FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();a.close()
 if b!=null:b.close()
 print(JSON.stringify(result));quit()
