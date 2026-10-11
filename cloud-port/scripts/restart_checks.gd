extends SceneTree
var checks=[]
func check(ok:bool,name:String):checks.append({"pass":ok,"name":name})
func _initialize():call_deferred("run")
func run():
 var app=load("res://lab.tscn").instantiate();root.add_child(app);app.set_process(false)
 check(app.world.tick==0 and app.paused and app.loaded_record.is_empty() and not app.bridge.enabled,"fresh process starts paused at zero; no restored control or hidden resume")
 app._list_runs();app._load();var valid=app._valid_record(app.loaded_record)
 check(valid,"previous process native saved record validates")
 if valid:
  var fingerprint=app.loaded_record.fingerprint;var tick=int(app.loaded_record.tick);app._begin_replay()
  for i in tick:app._process(1.0/app.rate.value)
  check(app.world.tick==tick and app.world.fingerprint()==fingerprint and app.job=="complete" and app.first_failure.is_empty(),"previous process saved record replays exactly")
 check(app.bridge.enable(),"new session control explicitly enabled")
 var request={"request_id":"valid-status","instance_id":app.bridge.instance_id,"created_at":Time.get_unix_time_from_system(),"command":"status","args":{},"run_id":app.run_id,"expected_tick":app.world.tick,"caller":"qa"}
 check(app.bridge.handle(request).ok,"current session status allowed")
 request=request.duplicate(true);request.request_id="stale-instance";request.instance_id="wrong"
 check(not app.bridge.handle(request).ok,"foreign session rejected")
 request.instance_id=app.bridge.instance_id;request.request_id="stale-tick";request.command="step";request.expected_tick=app.world.tick-1
 var before=app.world.tick;check(not app.bridge.handle(request).ok and app.world.tick==before,"stale mutation rejected without advancing")
 app._stop();request.request_id="disabled-control";request.expected_tick=app.world.tick
 check(not app.bridge.handle(request).ok and app.world.tick==before,"Stop disables further commands")
 var f=FileAccess.open("res://evidence/cloud-restart-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"  "));f.close();print(JSON.stringify(checks));app.queue_free();await process_frame;quit(0 if checks.all(func(x):return x.pass) else 1)
