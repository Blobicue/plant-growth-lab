extends SceneTree
const Checkpoint=preload("res://checkpoint.gd")
var checks=[]
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 for seed in [12011,4242,7301]:
  var path="res://golden/birth-%d.bin"%seed
  var f=FileAccess.open(path,FileAccess.READ);var state=bytes_to_var(f.get_buffer(f.get_length()));f.close()
  var a=Checkpoint.restore(path);var b=Checkpoint.restore(path)
  checks.append({"pass":a.fingerprint()==state.fingerprint,"name":"original birth checkpoint full hash "+str(seed),"tick":a.tick})
  var same=true
  for i in 96:a.step();b.step();same=same and a.error.is_empty() and b.error.is_empty() and a.fingerprint()==b.fingerprint()
  checks.append({"pass":same,"name":"original birth checkpoint deterministic continuation96h "+str(seed),"fingerprint":a.fingerprint()});a.close();b.close()
 var f=FileAccess.open("res://evidence/cloud-birth-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"  "));f.close();print(JSON.stringify(checks));quit(0 if checks.all(func(x):return x.pass) else 1)
