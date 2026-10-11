extends SceneTree
var checks=[]
var app
func check(ok,name):
 checks.append({"pass":bool(ok),"name":name})
 if not ok:push_error(name)
func _initialize():call_deferred("run")
func click(button):
 await process_frame
 var pos=button.get_global_rect().get_center()
 var e=InputEventMouseButton.new();e.position=pos;e.global_position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e)
 await process_frame
 e=e.duplicate();e.pressed=false;Input.parse_input_event(e)
 await process_frame
func snap(name):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://evidence/"+name+".png")
func run():
 app=load("res://workstation.tscn").instantiate();root.add_child(app);await process_frame
 var reopen="reopen" in OS.get_cmdline_user_args()
 check(app.live.paused and not app.live.bridge.enabled and app.archive_world==null and not app.archive_running,"startup paused, control off, no archive/live hidden resume")
 check(app.catalog.runs.size()==6,"six exact F1 catalog records")
 if reopen:
  check(app.selected==5 and app.panes.current_tab==3,"only archive selection/pane retained across process reopen")
 else:
  app.set_process(false);app.live.set_process(false)
  app.tabs.current_tab=0;app.panes.current_tab=0;app.choose.select(3);app.choose.item_selected.emit(3)
  check(app.current().seed==4242 and app.current().mode==24,"wired catalog selection changes model and seed")
  check(app.summary_table.get_root().get_child_count()==2,"paired whole-world outcomes visible")
  await snap("paired-outcomes")
  app.panes.current_tab=1
  var last=app.lineage.get_root().get_child(app.lineage.get_root().get_child_count()-1);last.select(0);app.lineage.item_selected.emit()
  check(app.plant_detail.text.contains("RIGHT-CENSORED") and app.plant_detail.text.contains("Plant 5"),"living young grandchild labeled censored with actual budget")
  await snap("lineage-budgets")
  app.panes.current_tab=2;app.day.value=768
  check(app.resources.get_root().get_child_count()>20,"paired finite-resource partitions at selected common hour")
  await snap("paired-resources")
  app.panes.current_tab=3
  for i in 6:
   app.choose.select(i);app.choose.item_selected.emit(i);app.checkpoint.select(1);app.checkpoint.item_selected.emit(1)
   await click(app.load_button)
   check(app.archive_world!=null and app.archive_world.tick==6144 and app.archive_world.transport_substeps==app.current().mode,"actual input loads exact model checkpoint "+str(i))
   if app.archive_world==null:continue
   await click(app.replay_button);check(app.archive_running,"wired replay starts "+str(i))
   await click(app.pause_button);check(not app.archive_running,"wired pause halts "+str(i))
   await click(app.step_button);check(app.archive_world.tick==6145,"wired step advances archive copy "+str(i))
   for h in 95:app.advance_archive()
   check(app.replay_matches==96 and not app.replay_failed and app.archive_world.tick==6240,"96 actual saved-state hourly hashes exact "+str(i))
   check(app.live.world.tick==0,"archive replay does not change live world "+str(i))
  app.choose.select(3);app.choose.item_selected.emit(3);app.checkpoint.select(2);app.checkpoint.item_selected.emit(2);await click(app.load_button)
  check(app.archive_world.tick==12288 and app.replay_button.disabled,"fixed endpoint inspect-only; cannot extrapolate")
  await snap("saved-state-geometry")
  app.checkpoint.select(0);app.checkpoint.item_selected.emit(0);await click(app.load_button)
  check(app.archive_world.tick==0,"initial checkpoint restores")
  app.set_process(true);await click(app.replay_button);await create_timer(.25).timeout;await click(app.pause_button)
  var paused_tick=app.archive_world.tick;await create_timer(.15).timeout
  check(paused_tick>0 and app.archive_world.tick==paused_tick,"real frame-driven replay advances then remains paused")
  app.set_process(false)
  var original=app.current().states["0"].sha256;app.current().states["0"].sha256="bad";app.load_archive()
  check(app.archive_world==null and app.replay_status.text.contains("BLOCKED"),"changed checkpoint rejected before deserialize")
  app.current().states["0"].sha256=original;app.load_archive();app.start_archive()
  app.tabs.current_tab=1
  check(not app.archive_running and app.live.paused and not app.live.bridge.enabled,"switching pane pauses archive and revokes live control")
  app.live._step();check(app.live.world.tick==1,"existing live step operates separately")
  app.live._pause();check(app.live.paused,"existing live pause preserved")
  check(app.live.bridge.enable(),"existing explicit local control opt-in still available")
  app.tabs.current_tab=0
  check(not app.live.bridge.enabled and app.live.paused,"leaving live pane revokes local control")
  app.tabs.current_tab=2;await snap("model-status")
  check(app.report_text.text.contains("UNPROMOTED"),"archived report visible with status")
  app.tabs.current_tab=0;app.choose.select(5);app.choose.item_selected.emit(5);app.panes.current_tab=3;app.save_preferences();await click(app.stop_button)
  check(not app.archive_running and not app.live.bridge.enabled,"workstation STOP keeps all control off")
 app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(not app.archive_running and app.live.paused and not app.live.bridge.enabled,"window-close path stops replay and revokes control")
 var output={"checks":checks,"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"catalog_sha256":FileAccess.get_sha256("res://data/catalog.json"),"reopen":reopen}
 var f=FileAccess.open("res://evidence/workstation-"+("reopen" if reopen else "checks")+".json",FileAccess.WRITE);f.store_string(JSON.stringify(output,"  "));f.close()
 print(JSON.stringify(output));quit(0 if checks.all(func(c):return c.pass) else 1)
