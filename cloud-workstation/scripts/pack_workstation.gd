extends SceneTree
func _initialize():
 var pack=PCKPacker.new();var args=OS.get_cmdline_user_args();assert(pack.pck_start(args[0])==OK)
 var names=JSON.parse_string(FileAccess.get_file_as_string("res://pack-files.json"))
 for name in names:assert(pack.add_file("res://"+name,ProjectSettings.globalize_path("res://"+name))==OK)
 assert(pack.flush()==OK);print("PACKED "+str(names.size())+" resources");quit()
