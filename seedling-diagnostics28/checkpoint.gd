extends RefCounted
const W=preload("res://diagnostic_world.gd")
const P=preload("res://plant.gd")
const F=preload("res://field.gd")
static func capture(obj,exclude:Array)->Dictionary:
 var result={}
 for info in obj.get_property_list():
  if not (int(info.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE) or info.name in exclude:continue
  var v=obj.get(info.name)
  if typeof(v) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID]:continue
  result[info.name]=v
 return result.duplicate(true)
static func save_world(w,path:String):
 var state={"world":capture(w,["field","plants","nodes","proposals","times"]),"plants":[],"field":w.field.full(),"samples":w.field.samples.duplicate(true),"summary":w.field.summary.duplicate(true),"fingerprint":w.fingerprint()}
 for p in w.plants:state.plants.append(capture(p,["shared_field","hour","previous","events"]))
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(var_to_bytes(state));f.close()
static func restore(path:String):
 var f=FileAccess.open(path,FileAccess.READ);var state=bytes_to_var(f.get_buffer(f.get_length()));f.close()
 var w=W.new(state.world.config);w.field.close()
 var water=PackedFloat64Array();var nitrogen=PackedFloat64Array();water.resize(2184);nitrogen.resize(2184)
 for i in 2184:water[i]=float(state.field[i*2])/1e9;nitrogen[i]=float(state.field[i*2+1])/1e9
 w.field=F.new(water,nitrogen,false);w.field.samples=state.samples;w.field.summary=state.summary
 for key in state.world:w.set(key,state.world[key])
 w.plants=[]
 for ps in state.plants:
  var p=P.new(ps.seed_value,ps.plant_id,0,false)
  for key in ps:p.set(key,ps[key])
  p.shared_field=w.field;p.previous=p.nodes.duplicate(true);w.plants.append(p)
 w._visual()
 assert(w.fingerprint()==state.fingerprint,"checkpoint exact physical hash")
 return w
