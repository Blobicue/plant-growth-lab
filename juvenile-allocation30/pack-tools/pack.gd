extends SceneTree
func _initialize():
 var args=OS.get_cmdline_user_args();var source=args[0];var target=args[1];var pack=PCKPacker.new();assert(pack.pck_start(target)==OK)
 var names=["project.godot","lab.tscn","lab.gd","world.gd","atmosphere.gd","canopy.gd","plant.gd","reserve.gd","hydrology.gd","decomposition.gd","field.gd","field.compute.txt","serial.compute.txt","renderer.gd","bridge.gd","legacy/model.gd","native/resource_field.gdextension","tests.gd"]
 for name in ["world.gd","plant.gd","reserve.gd","canopy.gd","hydrology.gd","decomposition.gd","field.gd","field.compute.txt","serial.compute.txt","legacy/model.gd"]:names.append("control/"+name)
 for name in names:assert(pack.add_file("res://"+name,source+"/"+name)==OK)
 assert(pack.flush()==OK);print("PACKED "+str(names.size())+" resources");quit()
