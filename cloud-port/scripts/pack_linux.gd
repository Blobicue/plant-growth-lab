extends SceneTree
func _initialize():
 var target=OS.get_cmdline_user_args()[0];var pack=PCKPacker.new();assert(pack.pck_start(target)==OK)
 var names=["project.godot","lab.tscn","lab.gd","world.gd","atmosphere.gd","canopy.gd","plant.gd","reserve.gd","hydrology.gd","decomposition.gd","field.gd","field.compute.txt","serial.compute.txt","renderer.gd","bridge.gd","legacy/model.gd","native/resource_field.gdextension","smoke.gd","ui_checks.gd","restart_checks.gd"]
 for name in names:assert(pack.add_file("res://"+name,ProjectSettings.globalize_path("res://"+name))==OK)
 assert(pack.flush()==OK);print("PACKED "+str(names.size())+" resources");quit()
