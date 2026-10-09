extends SceneTree
const W=preload("res://world.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var w=W.new({"seed":4242,"scenario":3,"backend":0,"water":.3,"nitrogen":.01,"light":32768.0,"slant":1,"flux":.08,"lifecycle":3,"radiation":2,"recycling":1,"decomposition":1,"carbon_access":1})
 for i in 96:w.step()
 print(JSON.stringify({"tick":w.tick,"error":w.error,"air":w.air,"budget":w.max_error()}));w.close();quit(0 if w.error.is_empty() else 1)
