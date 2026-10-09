extends SceneTree
const W=preload("res://world.gd")
var checks=[]
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 for seed in [12011,4242,7301]:
  var ref=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/matrix-%s-1.json"%str(seed)))
  for kind in ["gpu","reverse","replay"]:
   var cfg=ref.config.duplicate();cfg.backend=1 if kind=="gpu" else 0;var w=W.new(cfg);var valid=true
   for i in 960:
    w.step(kind=="reverse");valid=valid and w.error.is_empty() and w.fingerprint()==ref.hashes[str(w.tick)]
   checks.append({"pass":valid,"name":"full-state hourly960 "+str(seed)+" "+kind});w.close()
 var f=FileAccess.open("res://evidence/parity-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"  "));f.close();print(JSON.stringify(checks));quit(0 if checks.all(func(x):return x.pass) else 1)
