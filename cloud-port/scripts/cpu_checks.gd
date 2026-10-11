extends SceneTree
const W=preload("res://world.gd")
const F=preload("res://field.gd")
var checks=[]
func check(ok:bool,name:String):
 checks.append({"pass":ok,"name":name})
 if not ok:push_error(name)
func cfg()->Dictionary:return {"seed":4242,"scenario":3,"backend":0,"water":.3,"nitrogen":.01,"light":32768.0,"slant":1,"flux":.08,"lifecycle":3,"radiation":2,"recycling":1,"decomposition":1,"carbon_access":1}
func _initialize():call_deferred("run")
func replace_field(w,kind:String):
 var data=w.field.full();var samples=w.field.samples.duplicate(true);var summary=w.field.summary.duplicate();w.field.close()
 var water=PackedFloat64Array();var nitrogen=PackedFloat64Array();water.resize(2184);nitrogen.resize(2184)
 for i in 2184:water[i]=float(data[2*i])/1e9;nitrogen[i]=float(data[2*i+1])/1e9
 ProjectSettings.set_setting("validation/cpu",kind);w.field=F.new(water,nitrogen,false);w.field.samples=samples;w.field.summary=summary
 for p in w.plants:p.shared_field=w.field
func capture(obj,exclude:Array)->Dictionary:
 var result={}
 for info in obj.get_property_list():
  if not (int(info.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE) or info.name in exclude:continue
  var value=obj.get(info.name)
  if typeof(value) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID]:continue
  result[info.name]=value
 return result.duplicate(true)
func save_world(w,path:String):
 var state={"world":capture(w,["field","plants","nodes","proposals","times"]),"plants":[],"field":w.field.full(),"samples":w.field.samples.duplicate(true),"summary":w.field.summary.duplicate(true),"fingerprint":w.fingerprint()}
 for p in w.plants:state.plants.append(capture(p,["shared_field","hour","previous","events"]))
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(var_to_bytes(state));f.close()
func restore(path:String):
 var f=FileAccess.open(path,FileAccess.READ);var state=bytes_to_var(f.get_buffer(f.get_length()));f.close();var w=W.new(state.world.config)
 w.field.close();var water=PackedFloat64Array();var nitrogen=PackedFloat64Array();water.resize(2184);nitrogen.resize(2184)
 for i in 2184:water[i]=float(state.field[2*i])/1e9;nitrogen[i]=float(state.field[2*i+1])/1e9
 w.field=F.new(water,nitrogen,false);w.field.samples=state.samples;w.field.summary=state.summary
 for key in state.world:w.set(key,state.world[key])
 w.plants=[]
 for ps in state.plants:
  var p=W.Plant.new(ps.seed_value,ps.plant_id,0,false)
  for key in ps:p.set(key,ps[key])
  p.shared_field=w.field;w.plants.append(p)
 w._visual();check(w.fingerprint()==state.fingerprint,"saved binary state restores exact full fingerprint");return w
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 check(ClassDB.class_exists("NativeResourceField"),"native registration")
 var a=W.new(cfg());var b=W.new(cfg());replace_field(b,"gdscript");var same=a.fingerprint()==b.fingerprint()
 for i in 96:
  a.step();b.step();same=same and a.error.is_empty() and b.error.is_empty() and a.fingerprint()==b.fingerprint() and a.field.full()==b.field.full()
 check(same,"native versus interpreted CPU exact full field and biology every hour96");b.close()
 save_world(a,"res://evidence/cloud-state.bin");b=restore("res://evidence/cloud-state.bin");same=true
 for i in 96:a.step();b.step();same=same and a.fingerprint()==b.fingerprint() and a.error.is_empty() and b.error.is_empty()
 check(same,"saved binary continuation matches uninterrupted full state96h");a.close();b.close()
 # Maximum cells and wide integer totals exercise signed diffusion and >2^32 sums.
 for impulse in [false,true]:
  var water=PackedFloat64Array();var nitrogen=PackedFloat64Array();water.resize(2184);nitrogen.resize(2184)
  if impulse:water[0]=.1;nitrogen[2183]=.1
  else:water.fill(.1);nitrogen.fill(.1)
  ProjectSettings.set_setting("validation/cpu","native");var native=F.new(water,nitrogen,false)
  ProjectSettings.set_setting("validation/cpu","gdscript");var reference=F.new(water,nitrogen,false);same=true
  var totals=native.summary.slice(0,2)
  for i in 16:
   native.advance([],[]);reference.advance([],[]);same=same and native.full()==reference.full() and native.summary.slice(0,2)==totals and native.error.is_empty() and reference.error.is_empty()
  check(same,"exact conservative native/reference "+("signed impulse diffusion" if impulse else "wide totals >2^32"));native.close();reference.close()
 var screen=load("res://lab.gd").new();var record={"version":27,"identity":W.FIELD_ID,"config":cfg(),"tick":192,"fingerprint":"a".repeat(64)}
 check(screen._valid_record(JSON.parse_string(JSON.stringify(record))),"existing native replay schema roundtrip")
 record.identity="wrong-policy";check(not screen._valid_record(record),"replay rejects foreign scientific identity");screen.free()
 var f=FileAccess.open("res://evidence/cloud-cpu-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"  "));f.close();print(JSON.stringify(checks));quit(0 if checks.all(func(x):return x.pass) else 1)
