extends RefCounted
## Opt-in same-Windows-user file IPC. No port, credential or persistent service.
var app
var enabled:bool=false
var instance_id:String=""
var folder:String=""
var base:String=""
var next_heartbeat:float=0
var seen:Dictionary={}
var last_blob:String=""
var serial:int=0
var pending_reply:Dictionary={}
var publish_pending:bool=false
func _init(owner):app=owner
func _read(path:String):
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null:return null
 if f.get_length()>32768:f.close();return null
 var value=JSON.parse_string(f.get_as_text());f.close();return value
func _write(path:String,value:Dictionary)->bool:
 var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if f==null:return false
 f.store_string(JSON.stringify(value));f.close()
 return DirAccess.rename_absolute(path+".tmp",path)==OK
func enable()->bool:
 base=ProjectSettings.globalize_path(app.bridge_dir);DirAccess.make_dir_recursive_absolute(base)
 var prior=_read(base+"/active.json")
 if prior is Dictionary and prior.get("enabled",false) and float(prior.get("heartbeat",0))+5>Time.get_unix_time_from_system() and int(prior.get("pid",-1))!=OS.get_process_id():return false
 serial+=1;instance_id="session-%d-%d-%d"%[OS.get_process_id(),Time.get_ticks_msec(),serial];folder=base+"/"+instance_id;DirAccess.make_dir_recursive_absolute(folder);seen={};last_blob="";pending_reply={};enabled=true
 if not _publish():enabled=false;return false
 return true
func _publish()->bool:
 var written:bool=_write(base+"/active.json",{"version":1,"enabled":enabled,"instance_id":instance_id,"pid":OS.get_process_id(),"heartbeat":Time.get_unix_time_from_system(),"folder":folder,"run_id":app.run_id,"tick":app.world.tick,"model":app.Model.FIELD_ID,"connection":"same-user local file adapter; no authenticated remote client"})
 publish_pending=not written;return written
func disable():
 if not enabled:return
 enabled=false
 var current=_read(base+"/active.json")
 if current is Dictionary and current.get("instance_id")==instance_id:_publish()
func _integer(value,lo:int,hi:int)->bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)==int(value) and value>=lo and value<=hi
func _valid_args(command:String,a:Dictionary)->bool:
 match command:
  "status","pause","stop","step","save","replay":return a.is_empty()
  "run":return a.size()==1 and _integer(a.get("target"),1,12288)
  "scenario":return _integer(a.get("carbon_access"),0,1) and a.size()==8 and _integer(a.get("decomposition"),0,1) and _integer(a.get("recycling"),0,1) and _integer(a.get("radiation"),0,2) and _integer(a.get("lifecycle"),0,3) and _integer(a.get("scenario"),0,5) and _integer(a.get("seed"),0,999999) and _integer(a.get("backend"),0,1)
  "inspect":return a.size()==2 and _integer(a.get("world"),0,31) and _integer(a.get("cell"),0,511)
 return false
func handle(request)->Dictionary:
 if not request is Dictionary:return {"ok":false,"error":"invalid request"}
 var id=request.get("request_id");var regex=RegEx.new();regex.compile("^[A-Za-z0-9_-]{1,80}$")
 if not id is String or regex.search(id)==null:return {"ok":false,"error":"invalid request ID"}
 if seen.has(id):return seen[id].duplicate(true)
 var reply:Dictionary={"ok":false,"request_id":id,"instance_id":instance_id}
 if not enabled:reply.error="control disabled"
 elif request.get("instance_id")!=instance_id:reply.error="wrong app instance"
 elif not (request.get("created_at") is int or request.get("created_at") is float) or not is_finite(float(request.created_at)) or absf(Time.get_unix_time_from_system()-float(request.created_at))>5:reply.error="expired request"
 elif not request.get("command") is String or not request.get("args") is Dictionary:reply.error="invalid command schema"
 elif not _valid_args(request.command,request.args):reply.error="unsupported command or invalid arguments"
 elif request.command not in ["status","stop"] and request.get("run_id")!=app.run_id:reply.error="stale run identity"
 elif request.command in ["step","run","scenario","save","replay"] and request.get("expected_tick")!=app.world.tick:reply.error="stale tick; read status and retry with new ID"
 elif not app.first_failure.is_empty() and request.command in ["step","run","replay"]:reply.error="run has failed; reset explicitly"
 else:
  var raw_caller=request.get("caller","local")
  var caller:String=raw_caller if raw_caller is String and raw_caller in ["cli","mcp","qa"] else "local"
  if request.command!="status":app._event("Request "+id.left(12)+" / "+caller+" / "+request.command)
  var outcome:Dictionary=app.command(request.command,request.args,caller)
  reply.merge(outcome,true)
 seen[id]=reply.duplicate(true)
 if seen.size()>128:seen.erase(seen.keys()[0])
 return reply
func poll():
 # Windows readers can briefly prevent atomic replacement. Retry cached output,
 # never the command, including after Stop has disabled new input.
 if not pending_reply.is_empty():
  if _write(folder+"/response.json",pending_reply):pending_reply={}
  else:return
 if publish_pending:
  var current=_read(base+"/active.json")
  if current==null or (current is Dictionary and current.get("instance_id")==instance_id):_publish()
  else:publish_pending=false
 if not enabled:return
 var now:float=Time.get_ticks_msec()/1000.0
 if now>=next_heartbeat:
  var active=_read(base+"/active.json")
  if active is Dictionary and active.get("instance_id")!=instance_id:
   enabled=false;app.agent_box.set_pressed_no_signal(false);app._pause();app._event("Local connection replaced by another instance.");return
  _publish();next_heartbeat=now+.5
 var path:String=folder+"/request.json"
 if not FileAccess.file_exists(path):return
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null:return
 if f.get_length()>32768:f.close();return
 var blob:String=f.get_as_text();f.close()
 if blob==last_blob:return
 last_blob=blob;pending_reply=handle(JSON.parse_string(blob))
 if _write(folder+"/response.json",pending_reply):pending_reply={}
 if enabled:_publish()



