extends SceneTree
const W=preload("res://world.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var args=OS.get_cmdline_user_args();var seed=int(args[0]);var mode=int(args[1]);var horizon=int(args[2]);var reverse=args.size()>3 and args[3]=="reverse"
 var ref=JSON.parse_string(FileAccess.get_file_as_string("res://golden/matrix-%d-%d.json"%[seed,mode]))
 var w=W.new(ref.config);var hourly_mismatches=0;var metric_differences=[];var mismatch=[];var peak=0.0;var pp=0.0;var checkpoints=[];var n=0;var juvenile_ok=true;var mature_deposits=0;var juvenile_hours={"founder":0,"descendant":0}
 for i in horizon:
  var before=[]
  for plant in w.plants:before.append({"nodes":plant.nodes.size(),"deposit":plant.reserve_deposited.duplicate()})
  w.step(reverse)
  if W.FIELD_ID.begins_with("juvenile") and mode==1:
   for j in before.size():
    if before[j].nodes<32:
     juvenile_ok=juvenile_ok and before[j].deposit==w.plants[j].reserve_deposited
     juvenile_hours["founder" if w.plants[j].generation==0 else "descendant"]+=1
    elif before[j].deposit!=w.plants[j].reserve_deposited:mature_deposits+=1
  peak=maxf(peak,w.max_error())
  for plant in w.plants:pp=maxf(pp,plant.max_error())
  if w.tick<=960:
   var current_hash=w.fingerprint()
   if current_hash!=ref.hashes[str(w.tick)]:hourly_mismatches+=1
   if current_hash!=ref.hashes[str(w.tick)] and mismatch.size()<10:mismatch.append({"tick":w.tick,"kind":"hourly fingerprint","actual":current_hash,"expected":ref.hashes[str(w.tick)]})
  if w.tick in [96,240,480,720,960,2040,4080,8160]:
   # JSON roundtrip normalizes original vector/string and int/float serialization.
   var actual=JSON.parse_string(JSON.stringify(w.metrics()));var expected=ref.samples[n];var same=actual==expected
   checkpoints.append({"tick":w.tick,"match":same});n+=1
   if not same:metric_differences.append({"tick":w.tick,"differences":differences(actual,expected)})
   if not same and mismatch.size()<10:mismatch.append({"tick":w.tick,"kind":"metrics"})
  if not w.error.is_empty() or not w.censored.is_empty():break
 if horizon==8160 and W.FIELD_ID.begins_with("juvenile"):load("res://state.gd").new().save_world(w,"res://evidence/cloud-end-%d.bin"%seed)
 var end_match=w.fingerprint()==ref.fingerprint if horizon==8160 else w.fingerprint()==ref.hashes[str(horizon)]
 var result={"allocation_policy":{"juvenile_no_new_deposits":juvenile_ok,"observed_hours":juvenile_hours,"mature_deposit_hours":mature_deposits},"seed":seed,"mode":mode,"reverse":reverse,"horizon":w.tick,"hourly_hash_mismatches":hourly_mismatches,"metric_differences":metric_differences,"checks":{"hourly_and_metrics":mismatch.is_empty(),"endpoint":end_match,"healthy":w.error.is_empty() and w.censored.is_empty() and w.tick==horizon},"mismatch":mismatch,"checkpoints":checkpoints,"fingerprint":w.fingerprint(),"error":w.error,"censored":w.censored,"max_error":peak,"max_plant_error":pp,"lineage":w.lineage,"end":w.metrics()}
 var path="res://evidence/cloud-golden-%d-%d-%d-%s.json"%[seed,mode,horizon,"reverse" if reverse else "forward"]
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();print(JSON.stringify(result));w.close();quit(0 if result.checks.values().all(func(x):return x) else 1)

func differences(a,b,path:String="")->Array:
 var result=[]
 if a is Dictionary and b is Dictionary:
  for key in a:result.append_array(differences(a[key],b.get(key),path+"/"+str(key)))
 elif a is Array and b is Array:
  if a.size()!=b.size():result.append({"path":path,"kind":"length","actual":a.size(),"expected":b.size()})
  for i in mini(a.size(),b.size()):result.append_array(differences(a[i],b[i],path+"/"+str(i)))
 elif a!=b:result.append({"path":path,"actual":a,"expected":b})
 return result
