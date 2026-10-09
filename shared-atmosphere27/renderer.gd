extends Node3D
const UNIT=.16
var seeds:MultiMeshInstance3D
var tissue:MultiMeshInstance3D
var soil:MultiMeshInstance3D
var lines:MeshInstance3D
var selected:MeshInstance3D
var solar_light:DirectionalLight3D
var camera:Camera3D
var node_count:int=0
var proposal_segments:int=0
var yaw:float=.38
var pitch:float=.32
var zoom:float=4.7
var target_y:float=.5
var fit_size:float=5.2
func _ready():
 var environment=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("172b31");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("cce6de");e.ambient_light_energy=.4;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=e;add_child(environment)
 var light=DirectionalLight3D.new();solar_light=light;light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=.85;add_child(light)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;add_child(camera);frame()
 seeds=_multi(Vector3.ONE*UNIT*.7);var sphere=SphereMesh.new();sphere.radius=UNIT*.5;sphere.height=UNIT;sphere.radial_segments=8;sphere.rings=4;seeds.multimesh.mesh=sphere
 tissue=_multi(Vector3.ONE*UNIT);soil=_multi(Vector3(UNIT*.96,.018,UNIT*.96))
 lines=MeshInstance3D.new();add_child(lines)
 selected=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3.ONE*UNIT*1.12;selected.mesh=box
 var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(1,.83,.3,.35);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;selected.material_override=mat;add_child(selected)
func _multi(size:Vector3)->MultiMeshInstance3D:
 var mi=MultiMeshInstance3D.new();var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true
 var box=BoxMesh.new();box.size=size;multi.mesh=box;mi.multimesh=multi
 var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.86;mi.material_override=mat;add_child(mi);return mi
func frame()->void:
 camera.size=fit_size*zoom/4.7;var target=Vector3(0,target_y,0)
 camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*10
 camera.look_at(target)
func rebuild(m,show_roots:bool,show_graph:bool,show_proposals:bool,selection:int=-1):
 if m.config.radiation==2:solar_light.light_energy=.85 if m.tick==0 or (m.tick-1)%24<12 else .15
 else:solar_light.light_energy=.85
 var pods=m.propagules.filter(func(p):return p.stage in ["escrow","dormant","failed"])
 seeds.multimesh.instance_count=pods.size()
 for i in pods.size():seeds.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(pods[i].pos)*UNIT+Vector3(0,.1,0)));seeds.multimesh.set_instance_color(i,Color("eac653") if pods[i].stage!="failed" else Color("837e77"))
 var visible_nodes:Array=[]
 for i in m.nodes.size():
  if show_roots or m.nodes[i].kind!="root":visible_nodes.append(i)
 tissue.multimesh.instance_count=visible_nodes.size();node_count=visible_nodes.size()
 for j in visible_nodes.size():
  var n:Dictionary=m.nodes[visible_nodes[j]];var color=Color("98ce61") if n.kind=="leaf" else (Color("60bcb5") if n.kind=="root" else Color("c79968"))
  if n.get("plant",0)==1:color=color.lerp(Color("ec92b5"),.55)
  if n.get("plant",0)==2:color=color.lerp(Color("e2b643"),.7)
  if n.get("plant",0)==3:color=color.lerp(Color("859bec"),.7)
  if n.get("plant",0)==4:color=color.lerp(Color("d78644"),.7)
  if n.get("plant",0)==5:color=color.lerp(Color("be81d8"),.7)
  if n.kind=="leaf":color=color.lerp(Color("27383c"),.8*(1.0-float(n.light)))
  if not n.active:color=Color("746452")
  tissue.multimesh.set_instance_transform(j,Transform3D(Basis.IDENTITY,Vector3(n.pos)*UNIT));tissue.multimesh.set_instance_color(j,color)
 soil.multimesh.instance_count=m.X*m.Z
 var index:int=0
 for z in range(-6,7):
  for x in range(-10,11):
   var w:float=0
   for y in range(-8,0):w+=m.field.samples.get(m.soil_index(Vector3i(x,y,z)),[0,0])[0]/m.field.scale
   # Fixed scale across all panels, never per-panel min/max normalization.
   var color:Color=Color("263f46").lerp(Color("4ec6d3"),clampf(w/.043,0,1))
   soil.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3(x*UNIT,-1.45,z*UNIT)));soil.multimesh.set_instance_color(index,color);index+=1
 var mesh=ImmediateMesh.new();var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true
 mesh.surface_begin(Mesh.PRIMITIVE_LINES,mat);proposal_segments=0
 # Collar plane boundary and +X axis.
 var corners=[Vector3(-1.76,-.09,-1.12),Vector3(1.76,-.09,-1.12),Vector3(1.76,-.09,1.12),Vector3(-1.76,-.09,1.12)]
 for i in 4:_line(mesh,corners[i],corners[(i+1)%4],Color("54717a"))
 _line(mesh,Vector3(-1.65,-.085,1.02),Vector3(-.85,-.085,1.02),Color("e68eb0"));_line(mesh,Vector3(-.85,-.085,1.02),Vector3(-1,-.085,.93),Color("e68eb0"))
 var sun:Vector3=m.sun_direction();var end=Vector3(0,1.8,0);var start:Vector3=end+sun*.65
 _line(mesh,start,end,Color("f7d47a"));_line(mesh,end,end+sun*.17+Vector3(.07,.02,.08),Color("f7d47a"));_line(mesh,end,end+sun*.17-Vector3(.07,.02,.08),Color("f7d47a"))
 if show_graph:
  for n in m.nodes:
   if n.parent>=0 and (show_roots or n.kind!="root"):_line(mesh,Vector3(n.pos)*UNIT+Vector3(0,0,.087),Vector3(m.nodes[n.parent].pos)*UNIT+Vector3(0,0,.087),Color("f8f4df"))
 if show_proposals:
  for p in m.proposals:
   if p.state!="developing" or (not show_roots and p.kind=="root"):continue
   if str(p.blocked).begins_with("occupied") and p.cursor<p.path.size():
    var blocked=Vector3(p.path[p.cursor])*UNIT
    _line(mesh,blocked+Vector3(-.08,-.08,.10),blocked+Vector3(.08,.08,.10),Color("ff6679"));_line(mesh,blocked+Vector3(-.08,.08,.10),blocked+Vector3(.08,-.08,.10),Color("ff6679"))
   var from:Vector3=Vector3(m.nodes[p.front].pos)*UNIT
   for i in range(p.cursor,p.path.size()):
    var to:Vector3=Vector3(p.path[i])*UNIT;_line(mesh,from.lerp(to,.16),from.lerp(to,.82),Color("ffd077"));from=to;proposal_segments+=1
 if selection>=0 and selection<m.nodes.size():
  var n=m.nodes[selection];var at=Vector3(n.pos)*UNIT
  if n.kind!="root":_line(mesh,at,at+m.sun_direction()*.7,Color("ffd46b"))
 mesh.surface_end();lines.mesh=mesh
 selected.visible=selection>=0 and selection<m.nodes.size() and (show_roots or m.nodes[selection].kind!="root")
 if selected.visible:selected.position=Vector3(m.nodes[selection].pos)*UNIT
func _line(mesh:ImmediateMesh,a:Vector3,b:Vector3,c:Color):
 mesh.surface_set_color(c);mesh.surface_add_vertex(a);mesh.surface_set_color(c);mesh.surface_add_vertex(b)
func pick(m,p:Vector2,roots:bool)->int:
 var chosen:int=-1;var best:float=18
 for i in m.nodes.size():
  if not roots and m.nodes[i].kind=="root":continue
  var point:Vector2=camera.unproject_position(Vector3(m.nodes[i].pos)*UNIT);var distance:float=point.distance_to(p)
  if distance<best:best=distance;chosen=i
 return chosen

