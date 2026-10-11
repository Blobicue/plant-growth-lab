extends SceneTree
const W=preload("res://world.gd")
var checks=[]
func check(ok:bool,name:String):
 checks.append({"pass":ok,"name":name})
 if not ok:push_error(name)
func _initialize():call_deferred("run")
func press(app,text:String):
 for button in app.find_children("*","Button",true,false):
  if button.text==text:button.pressed.emit();return true
 return false
func run():
 var app=load("res://lab.tscn").instantiate();root.add_child(app);app.set_process(false)
 check(app.world.error.is_empty() and app.world.tick==0 and not app.bridge.enabled,"native UI loads with local control off")
 check(press(app,"Step") and app.world.tick==1,"wired Step button advances one hour")
 press(app,"Pause");check(app.paused,"wired Pause button pauses")
 for i in 95:app._advance()
 var fingerprint=app.world.fingerprint();check(app._save(),"native UI saves exact replay record")
 var run_id=app.run_id;var saved_path=ProjectSettings.globalize_path(app.record_dir+"/"+run_id+".json")
 app._reset();app._list_runs();app._load();check(app.loaded_record.get("fingerprint")==fingerprint,"saved record reload through native UI")
 app._begin_replay()
 for i in 95:app._advance()
 app._process(1.0/app.rate.value)
 check(app.world.tick==96 and app.world.fingerprint()==fingerprint and app.first_failure.is_empty() and app.job=="complete" and app.replay_target.is_empty(),"native UI exact replay96h")
 var foreign=app.loaded_record.duplicate(true);foreign.identity="foreign-policy";check(not app._valid_record(foreign),"native UI rejects different scientific policy")
 var enabled=app.bridge.enable();check(enabled,"session local control enable")
 press(app,"STOP / TAKE OVER");check(app.paused and not app.bridge.enabled and app.control_owner=="You","wired Stop revokes control")
 app._refresh()
 if DisplayServer.get_name()!="headless":
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://evidence/cloud-ui.png")
 var f=FileAccess.open("res://evidence/cloud-ui-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"saved_path":saved_path,"display":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()},"  "));f.close();print(JSON.stringify(checks));app.queue_free();await process_frame;quit(0 if checks.all(func(x):return x.pass) else 1)
