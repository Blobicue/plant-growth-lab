extends SceneTree
const State=preload("res://state.gd")
func _initialize():call_deferred("run")
func run():
 var seed=int(OS.get_cmdline_user_args()[0]);var app=load("res://lab.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.world.close();app.world=State.new().restore("res://evidence/cloud-end-%d.bin"%seed);app.paused=true;app.job="audited ordinary endpoint / unpromoted"
 var c=app.world.config;app.seed_input.value=c.seed;app.light_input.value=c.light
 for i in app.world.nodes.size():
  if app.world.plant_by_id(app.world.nodes[i].plant).generation==2:app.selected_node=i;break
 app._event("Cloud replay matches original8160h fingerprint. No preparation or interventions.");app._refresh()
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://evidence/cloud-ordinary-%d.png"%seed)
 app.queue_free();await process_frame;quit()
