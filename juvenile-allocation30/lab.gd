extends Control
const Model=preload("res://world.gd")
const Renderer=preload("res://renderer.gd")
const Bridge=preload("res://bridge.gd")
var world
var renderer
var bridge
var bridge_dir="user://juvenile30/control"
var record_dir="user://juvenile30/runs"
var recipe:OptionButton
var backend:OptionButton
var seed_input:SpinBox
var water_input:SpinBox
var nitrogen_input:SpinBox
var light_input:SpinBox
var flux_input:SpinBox
var sky_mode:OptionButton
var decomposition_mode:OptionButton
var carbon_label:Label
var air_mode:OptionButton
var air_label:Label
var recycling_mode:OptionButton
var water_label:Label
var radiation_mode:OptionButton
var radiation_label:Label
var input_bar:ProgressBar
var stored_bar:ProgressBar
var lifecycle_mode:OptionButton
var life_seen=0
var target_input:SpinBox
var rate:SpinBox
var agent_box:CheckBox
var saved_runs:OptionButton
var title:Label
var stats:Label
var timing:Label
var status:Label
var details:Label
var log_view:RichTextLabel
var paused=true
var job="ready"
var goal=192
var run_id=""
var serial=0
var first_failure:Dictionary={}
var loaded_record:Dictionary={}
var replay_target:Dictionary={}
var events:Array=[]
var measurements:Array=[]
var control_owner="You"
var remote_deadline=0.0
var accumulator=0.0
var ui_ms=0.0
var selected_node=0
func label(parent:Node,text:String,size:int=14)->Label:
 var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",Color("193d35"));parent.add_child(l);return l
func button(parent:Node,text:String,callback:Callable):
 var b=Button.new();b.text=text;b.custom_minimum_size.y=34;b.pressed.connect(callback);parent.add_child(b);return b
func number(parent:Node,caption:String,lo:float,hi:float,value:float,step_size:float)->SpinBox:
 var row=HBoxContainer.new();parent.add_child(row);var l=label(row,caption);l.size_flags_horizontal=SIZE_EXPAND_FILL;var s=SpinBox.new();s.min_value=lo;s.max_value=hi;s.step=step_size;s.value=value;s.custom_minimum_size.x=130;row.add_child(s);return s
func _ready():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var bg=ColorRect.new();bg.color=Color("edf1e8");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for k in ["margin_left","margin_right","margin_top","margin_bottom"]:margin.add_theme_constant_override(k,18)
 add_child(margin);var layout=HBoxContainer.new();layout.add_theme_constant_override("separation",18);margin.add_child(layout)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size.x=335;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;layout.add_child(scroll);var side=VBoxContainer.new();side.custom_minimum_size.x=320;side.add_theme_constant_override("separation",6);scroll.add_child(side)
 label(side,"BLOBUS / PLANT LAB 27",14);label(side,"Shared finite air.\nEvery generation pays.",27)
 label(side,"SETTINGS / apply with New experiment",12)
 recipe=OptionButton.new();recipe.fit_to_longest_item=false;recipe.custom_minimum_size.x=320
 for name in ["Shared pair / finite patch","Plant A alone / same patch","Plant B alone / same patch","Shared pair / 8x soil resources","Plant A alone / 8x soil","Plant B alone / 8x soil"]:recipe.add_item(name)
 side.add_child(recipe);recipe.select(3);lifecycle_mode=OptionButton.new();lifecycle_mode.fit_to_longest_item=false
 for item in ["Reproduction OFF / competition control","Ordinary reproduction / unprepared","PREPARED parent-funded nursery","Surplus account / ordinary reproduction"]:lifecycle_mode.add_item(item)
 lifecycle_mode.select(3);side.add_child(lifecycle_mode);backend=OptionButton.new();backend.fit_to_longest_item=false;backend.custom_minimum_size.x=320;backend.add_item("Native CPU / compiled field");backend.add_item("GPU / hierarchical reduction");side.add_child(backend)
 seed_input=number(side,"Base seed",0,999999,12011,1);water_input=number(side,"Soil water",0,.4,.3,.01);nitrogen_input=number(side,"Soil nitrogen",0,.08,.01,.001);light_input=number(side,"Legacy light stock (E)",0,32768,16384,128)
 radiation_mode=OptionButton.new();radiation_mode.fit_to_longest_item=false
 for item in ["Legacy / finite light reservoir","Open / continuous input","Open /12h day +12h night"]:radiation_mode.add_item(item)
 radiation_mode.select(2);side.add_child(radiation_mode)
 flux_input=number(side,"Mean E / ray / model hour",0,.12,.08,.01);sky_mode=OptionButton.new();sky_mode.fit_to_longest_item=false;sky_mode.add_item("Shared sky / overhead");sky_mode.add_item("Shared sky / diagonal +X");sky_mode.select(1);side.add_child(sky_mode)
 recycling_mode=OptionButton.new();recycling_mode.fit_to_longest_item=false;recycling_mode.add_item("Water return OFF / vapor retained");recycling_mode.add_item("Water return ON / condense + rain");recycling_mode.select(1);side.add_child(recycling_mode)
 decomposition_mode=OptionButton.new();decomposition_mode.fit_to_longest_item=false;decomposition_mode.add_item("Litter return OFF / carbon retained");decomposition_mode.add_item("Litter return ON / source atmosphere");decomposition_mode.select(1);side.add_child(decomposition_mode)
 air_mode=OptionButton.new();air_mode.fit_to_longest_item=false;air_mode.add_item("Legacy private carbon / control");air_mode.add_item("Shared finite atmosphere / accounted");air_mode.select(1);side.add_child(air_mode)
 button(side,"New experiment / reset",_reset)
 var controls=HBoxContainer.new();side.add_child(controls);button(controls,"Run",func():start_job(int(target_input.value),"You"));button(controls,"Step",_step);button(controls,"Pause",_pause)
 button(side,"STOP / TAKE OVER",_stop);target_input=number(side,"Run to tick",1,12288,256,1);rate=number(side,"Visible ticks / second",1,60,20,1)
 button(side,"Save exact replay",_save);saved_runs=OptionButton.new();saved_runs.fit_to_longest_item=false;saved_runs.custom_minimum_size.x=320;side.add_child(saved_runs);var file_controls=HBoxContainer.new();side.add_child(file_controls);button(file_controls,"Load record",_load);button(file_controls,"Replay",_begin_replay)
 agent_box=CheckBox.new();agent_box.text="Allow local commands this session";agent_box.add_theme_font_size_override("font_size",13);agent_box.add_theme_color_override("font_color",Color("193d35"));agent_box.add_theme_color_override("font_pressed_color",Color("193d35"));agent_box.toggled.connect(_agent_enabled);side.add_child(agent_box)
 status=label(side,"",12);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.x=318
 label(side,"1 tick =1 model hour;24h model day.\nToy mineralization; oxygen not modeled.\nMatter closure covers modeled C/N/W only.",12)
 var main=VBoxContainer.new();main.size_flags_horizontal=SIZE_EXPAND_FILL;main.add_theme_constant_override("separation",9);layout.add_child(main)
 title=label(main,"",24);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label(main,"A / green-teal   B / rose   C / gold   Gold spheres: funded propagules. Red crosses: blocked growth.",14)
 radiation_label=label(main,"",14);radiation_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var bars=HBoxContainer.new();main.add_child(bars);label(bars,"IN / hour",12);input_bar=ProgressBar.new();input_bar.custom_minimum_size=Vector2(220,16);input_bar.show_percentage=false;bars.add_child(input_bar);label(bars,"Stored E",12);stored_bar=ProgressBar.new();stored_bar.custom_minimum_size=Vector2(220,16);stored_bar.show_percentage=false;bars.add_child(stored_bar)
 water_label=label(main,"",14);water_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 carbon_label=label(main,"",14);carbon_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 air_label=label(main,"",13);air_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var panel=PanelContainer.new();panel.size_flags_vertical=SIZE_EXPAND_FILL;main.add_child(panel);var container=SubViewportContainer.new();container.stretch=true;container.custom_minimum_size=Vector2(650,220);panel.add_child(container);var viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport);renderer=Renderer.new();viewport.add_child(renderer);container.gui_input.connect(_input_view)
 stats=label(main,"",16);stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;timing=label(main,"",13);timing.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var bottom=HBoxContainer.new();bottom.custom_minimum_size.y=235;bottom.add_theme_constant_override("separation",12);main.add_child(bottom);var detail_scroll=ScrollContainer.new();detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_scroll.custom_minimum_size.x=440;detail_scroll.size_flags_horizontal=SIZE_EXPAND_FILL;bottom.add_child(detail_scroll);details=label(detail_scroll,"",13);details.custom_minimum_size.x=440;details.size_flags_horizontal=SIZE_EXPAND_FILL;details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;log_view=RichTextLabel.new();log_view.custom_minimum_size.x=300;log_view.size_flags_horizontal=SIZE_EXPAND_FILL;log_view.add_theme_color_override("default_color",Color("193d35"));log_view.scroll_following=true;bottom.add_child(log_view)
 label(main,"Click tissue to inspect. Right-drag to orbit; wheel to zoom. Soil tint shows sampled root water, not a full-field map.",12)
 bridge=Bridge.new(self);_reset();_list_runs();DisplayServer.window_set_title("Plant Growth Lab / Shared Finite Air 27")
func _settings()->Dictionary:return {"seed":int(seed_input.value),"scenario":recipe.selected,"backend":backend.selected,"water":water_input.value,"nitrogen":nitrogen_input.value,"light":light_input.value,"flux":flux_input.value,"slant":sky_mode.selected,"lifecycle":lifecycle_mode.selected,"radiation":radiation_mode.selected,"recycling":recycling_mode.selected,"decomposition":decomposition_mode.selected,"carbon_access":air_mode.selected}
func _reset():
 if world!=null:world.close()
 world=Model.new(_settings());life_seen=0;serial+=1;run_id="juvenile30-%d-%d-%d"%[int(Time.get_unix_time_from_system()),OS.get_process_id(),serial];paused=true;job="ready";first_failure={};events=[];measurements=[];loaded_record={};replay_target={};control_owner="You";ui_ms=0;selected_node=0
 if not world.censored.is_empty():paused=true;job="CENSORED";_event(world.censored)
 if not world.error.is_empty():first_failure={"issues":[world.error]};job="FAILED"
 _event("New shared-soil experiment. Settings fixed until reset.")
 for entry in world.life_events:_event(entry.message,int(entry.tick))
 life_seen=world.life_events.size();_refresh()
func _event(message:String,at_tick:int=-1):
 events.append({"tick":at_tick if at_tick>=0 else world.tick if world!=null else 0,"message":message.left(300)})
 if events.size()>128:events.pop_front()
 if log_view!=null:
  log_view.clear()
  for e in events:log_view.add_text("[%03d] %s\n"%[e.tick,e.message])
func start_job(target:int,who:String)->bool:
 if target<=world.tick or target>12288 or not first_failure.is_empty() or not world.censored.is_empty():return false
 goal=target;paused=false;job="replaying" if not replay_target.is_empty() else "running";control_owner=who;remote_deadline=Time.get_ticks_msec()/1000.0+15;_event(who+": run to "+str(goal));_refresh();return true
func _pause():paused=true;job="paused";_refresh()
func _stop():
 paused=true;job="stopped";control_owner="You";replay_target={};bridge.disable();agent_box.set_pressed_no_signal(false);_event("Stopped. Session control revoked.");_refresh()
func _step():
 paused=true;job="paused";_advance();_refresh()
func _advance():
 if not first_failure.is_empty() or not world.censored.is_empty() or world.tick>=12288:return
 world.step()
 if world.tick%48==0:
  var sample=world.metrics()
  for p in sample.plants:p.reserve.erase("sources");p.reserve.erase("recent")
  sample.erase("life_events");measurements.append(sample)
 while life_seen<world.life_events.size():_event(world.life_events[life_seen].message,int(world.life_events[life_seen].tick));life_seen+=1
 if not world.censored.is_empty():paused=true;job="CENSORED";_event(world.censored)
 if not world.error.is_empty():first_failure={"issues":[world.error]};job="FAILED";paused=true;bridge.disable();agent_box.set_pressed_no_signal(false);_event("FAILED: "+world.error)
func _process(delta):
 if bridge==null:return
 bridge.poll()
 if paused:return
 if control_owner!="You" and Time.get_ticks_msec()/1000.0>remote_deadline:_stop();return
 accumulator+=delta
 if accumulator<1.0/rate.value:return
 accumulator=0;_advance()
 if world.tick>=goal and first_failure.is_empty() and world.censored.is_empty():
  paused=true;job="complete"
  if not replay_target.is_empty():
   var same=world.fingerprint()==replay_target.fingerprint;_event("Exact full-field replay "+("PASS" if same else "FAIL"));replay_target={}
   if not same:first_failure={"issues":["replay mismatch"]};job="FAILED";bridge.disable();agent_box.set_pressed_no_signal(false)
  _event("Completed with conservative shared resource checks.")
 _refresh()
func _refresh():
 if world==null:return
 var begin=Time.get_ticks_usec();title.text="TICK %03d  /  %s  /  %s"%[world.tick,job.to_upper(),"NATIVE CPU" if world.config.backend==0 else "PARALLEL GPU"]
 var text=""
 for p in world.plants:text+="%s  %d paid / %d living    uptake W %.5f / N %.6f    built C %.4f\n"%[String.chr(65+p.plant_id),p.nodes.size(),p.metrics().living,p.totals.uptake_w,p.totals.uptake_n,p.totals.built_c]
 stats.text=text+"SHARED SOIL   W %.6f / N %.6f     budget error %.2f x10^-12\n%d multi-plant cell-ticks / %d limited cell-ticks / allocation residual %d quanta"%[world.field.summary[0]/world.field.scale,world.field.summary[1]/world.field.scale,world.max_error()*1e12,world.contested,world.limited,world.allocation_residual]
 var ar=world.Air.report(world);air_label.text="AIR %s | available %.6f C / uptake %.6f / returned %.6f C\nLineage births %d / highest generation %d. External carbon imports ZERO."%["SHARED FINITE" if world.config.carbon_access==1 else "PRIVATE CONTROL",ar.shared_C,ar.received_by_plants_C,ar.returned_C,world.lineage.size(),_highest_generation()]
 var dc=world.decomposition_report();carbon_label.text="LITTER RETURN %s | held %.5f / recycled %.5f C | released %.4f E heat"%["ON" if world.config.decomposition==1 else "OFF",dc.litter,dc.returned_C,dc.heat_released]
 var h=world.hydrology_report();var wp=world.matter_report().W
 water_label.text="WATER RETURN %s | soil %.4f / vapor %.4f / cloud %.6f | rain %.6f now / %.4f total W"%["ON" if world.config.recycling==1 else "OFF",wp.soil,h.vapor,h.cloud,h.rain_this_hour,h.rain_total]
 var rad=world.radiation_report();var phase="LEGACY finite source" if world.config.radiation==0 else "CONTINUOUS" if world.config.radiation==1 else "DAY" if rad.hour<12 else "NIGHT"
 radiation_label.text="%s / hour %02d | external IN %.2f E/hour | stored %.2f E (heat %.2f)\nBoundary totals IN %.2f / OUT %.2f E | legacy source remaining %.2f E"%[phase,rad.hour,rad.input_this_tick,rad.stored_inside,rad.heat_inside,rad.input_total,rad.output_total,rad.source_remaining]
 input_bar.max_value=maxf(1,world.config.flux*559*2);input_bar.value=rad.input_this_tick;input_bar.tooltip_text="Current external boundary input; finite legacy source is internal"
 stored_bar.max_value=maxf(100,rad.stored_inside);stored_bar.value=rad.stored_inside;stored_bar.tooltip_text="Internal model energy excluding exported radiation and the legacy source stock; auto scale"
 stats.text+="\nOUT: transmitted %.2f / leaf prompt %.2f / thermal %.2f E | energy residual %.2f x10^-9\nOther-canopy loss A %.2f / B %.2f E | space blocks %d | C/N/W boundary transfers ZERO"%[rad.transmitted_out,rad.leaf_prompt_out,rad.thermal_out,rad.energy_error*1e9,world.shadow_loss[0]/1e9,world.shadow_loss[1]/1e9,world.space_conflicts]
 stats.text+="\nPROPAGULES %d / juveniles %d | detritus C %.5f N %.5f W %.5f | mutation OFF"%[world.propagules.size(),world.lineage.size(),world.detritus.C,world.detritus.N,world.detritus.W]
 for pod in world.propagules:stats.text+=" | #%d %s (%s>%s)"%[pod.id,pod.stage,String.chr(65+pod.parent),"seed" if pod.child<0 else String.chr(65+pod.child)]
 var t=world.field.times;timing.text="Measured cumulative ms: setup %.1f | simulation %.1f | checks %.1f | replay audit %.1f | view data %.1f | UI %.1f\nField dispatch+sync %.1f / readback %.1f / native %.1f | sparse return %d bytes. Rendering/pacing excluded."%[world.times.setup_ms,world.times.simulation_ms,world.times.diagnostics_ms,world.times.audit_ms,world.times.visual_ms,ui_ms,t.dispatch_sync_ms,t.readback_ms,t.cpu_field_ms,t.sparse_bytes]
 status.text="%s\nSeed %d / %s\nW %.3f / N %.3f / sky %.0f%s\nOwner: %s / local %s"%[run_id,world.config.seed,recipe.get_item_text(world.config.scenario),world.config.water,world.config.nitrogen,world.config.light," / soil x8" if int(world.config.scenario) in [3,4,5] else "",control_owner,"ON" if bridge.enabled else "OFF"]
 status.text+="\n"+lifecycle_mode.get_item_text(int(world.config.lifecycle))
 status.text+="\n"+radiation_mode.get_item_text(world.config.radiation)+" / water return "+("ON" if world.config.recycling==1 else "OFF")
 status.text+="\nRay %.2f / %s"%[world.config.flux,"diagonal" if world.config.slant==1 else "overhead"]
 selected_node=clampi(selected_node,0,world.nodes.size()-1);var n=world.nodes[selected_node];var selected_plant=world.plant_by_id(n.plant);details.text="INSPECT / %s / %s #%d / parent %d\nAvailable C %.5f / W %.5f / N %.6f\nAIR received %.6f / returned %.6f C\nPlant ledger residual %.2f x10^-12. Model units."%[String.chr(65+n.plant),n.kind,selected_node,n.parent,n.c,n.w,n.n,selected_plant.air_received,selected_plant.air_returned,selected_plant.max_error()*1e12]
 details.text+="\nLight %.0f%% / receipt %.6f / shadow owner %s"%[n.light*100,float(n.get("light_receipt",0))/1e9,"none" if n.get("shadow_owner",-1)<0 else String.chr(65+n.shadow_owner)]
 for proposal in world.proposals:
  if proposal.front==selected_node and proposal.state=="developing":details.text+="\nNext tissue: "+str(proposal.blocked);break
 if not first_failure.is_empty():details.text="FAILED / "+str(first_failure)
 details.text+="\nID %s / parent %s / birth tick %d\nGenotype v1: branch_seed %d / paid-v8 / copied, mutation OFF"%[String.chr(65+n.plant),"founder" if selected_plant.parent_id<0 else String.chr(65+selected_plant.parent_id),selected_plant.birth_tick,selected_plant.genotype.branch_seed]
 var bank=selected_plant.reserve
 details.text+="\nGeneration %d / reserve C %.5f/.051 N %.5f/.002 W %.5f/.04\n%s"%[selected_plant.generation,bank.c,bank.n,bank.w,selected_plant.reserve_reason]
 details.text+="\nPrivate air buffer %.5f C / vapor %.5f W"%[selected_plant.atmosphere,selected_plant.vapor]
 details.text+="\nLitter %.5f / source-accounted return %.5f C"%[selected_plant.litter,float(world.decomp_sources.get(str(selected_plant.plant_id),0))/1e9]
 details.text+="\nBank transfers C: in %.5f / refund %.5f / released %.5f"%[selected_plant.reserve_deposited.c,selected_plant.reserve_refunded.c,selected_plant.reserve_released.c]
 for pod in world.propagules:
  if pod.stage in ["escrow","dormant","failed"]:details.text+="\nSeed #%d: C %.4f N %.4f W %.4f / CO2 %.3f"%[pod.id,pod.c,pod.n,pod.w,pod.gas];break
 var ymax=2.5
 for node in world.nodes:ymax=maxf(ymax,node.pos.y*.16+.2)
 renderer.target_y=(ymax-1.6)*.5;renderer.fit_size=maxf(4.7,ymax+2.7);renderer.frame();renderer.rebuild(world,true,true,true,selected_node);ui_ms+=(Time.get_ticks_usec()-begin)/1000.0
func _input_view(e:InputEvent):
 if e is InputEventMouseButton and e.pressed:
  if e.button_index==MOUSE_BUTTON_LEFT:selected_node=maxi(0,renderer.pick(world,e.position,true));_refresh()
  elif e.button_index==MOUSE_BUTTON_WHEEL_UP:renderer.zoom=maxf(2,renderer.zoom*.9);renderer.frame()
  elif e.button_index==MOUSE_BUTTON_WHEEL_DOWN:renderer.zoom=minf(12,renderer.zoom*1.1);renderer.frame()
 if e is InputEventMouseMotion and e.button_mask&MOUSE_BUTTON_MASK_RIGHT:renderer.yaw-=e.relative.x*.008;renderer.pitch=clampf(renderer.pitch+e.relative.y*.008,.05,1.2);renderer.frame()
func _agent_enabled(value:bool):
 if value:
  if not bridge.enable():agent_box.set_pressed_no_signal(false);_event("Another session owns control.")
  else:_event("Local commands enabled for this session only.")
 else:bridge.disable();_pause()
 _refresh()
func status_record()->Dictionary:return {"identity":Model.FIELD_ID,"run_id":run_id,"tick":world.tick,"canopy_samples":_canopy_samples(),"rain_cell_receipts_q":world.hydro_rain_cells.duplicate(),"blocked_sites":_blocked_sites(),"goal":goal,"paused":paused,"job":job,"config":world.config,"metrics":world.metrics(),"timings":world.times,"field_timings":world.field.times,"ui_ms":ui_ms,"failure":first_failure,"control_owner":control_owner,"local_enabled":bridge.enabled}
func command(cmd:String,args:Dictionary,caller:String)->Dictionary:
 match cmd:
  "status":remote_deadline=Time.get_ticks_msec()/1000.0+15
  "pause":_pause()
  "stop":_stop()
  "step":_step()
  "run":
   if not start_job(int(args.target),"Local adapter"):return {"ok":false,"error":"Healthy run and target ahead <=12288 required"}
  "scenario":air_mode.select(int(args.carbon_access));decomposition_mode.select(int(args.decomposition));recycling_mode.select(int(args.recycling));radiation_mode.select(int(args.radiation));recipe.select(int(args.scenario));lifecycle_mode.select(int(args.lifecycle));seed_input.value=args.seed;backend.select(int(args.backend));_reset()
  "inspect":
   var found=false;var ordinal=0
   for i in world.nodes.size():
    if world.nodes[i].plant!=int(args.world):continue
    if ordinal==int(args.cell):selected_node=i;found=true;break
    ordinal+=1
   if not found:return {"ok":false,"error":"plant or tissue cell absent"}
   _refresh()
  "save":
   if not _save():return {"ok":false,"error":"save failed"}
  "replay":
   if not _valid_record(loaded_record):return {"ok":false,"error":"save or load first"}
   _begin_replay();control_owner="Local adapter";remote_deadline=Time.get_ticks_msec()/1000.0+15
 return {"ok":true,"state":status_record()}
func _save()->bool:
 if not world.censored.is_empty():_event("Censored experiment: exact-run save unavailable; inspect censor diagnostics.");return false
 if not first_failure.is_empty():return false
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(record_dir));var record={"version":27,"identity":Model.FIELD_ID,"run_id":run_id,"config":world.config.duplicate(true),"tick":world.tick,"fingerprint":world.fingerprint(),"measurements":measurements,"events":events,"timings":status_record()};var f=FileAccess.open(record_dir+"/"+run_id+".json",FileAccess.WRITE)
 if f==null:return false
 f.store_string(JSON.stringify(record,"  "));f.close();loaded_record=record;_event("Saved exact full-field replay.");_list_runs();_refresh();return true
func _list_runs():
 saved_runs.clear()
 if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(record_dir)):return
 for name in DirAccess.get_files_at(record_dir):
  if name.begins_with("juvenile30-") and name.ends_with(".json"):saved_runs.add_item(name)
 if saved_runs.item_count>0:saved_runs.select(saved_runs.item_count-1)
func _valid_record(r)->bool:
 if not r is Dictionary or r.get("version")!=27 or r.get("identity")!=Model.FIELD_ID or not r.get("config") is Dictionary:return false
 var c=r.config
 for key in ["seed","scenario","backend","water","nitrogen","light","flux","slant","lifecycle","radiation","recycling","decomposition","carbon_access"]:
  if not (c.get(key) is int or c.get(key) is float) or not is_finite(float(c[key])):return false
 if int(c.carbon_access)!=c.carbon_access or int(c.carbon_access) not in [0,1]:return false
 if c.seed<0 or c.seed>999999 or int(c.seed)!=c.seed or int(c.scenario)!=c.scenario or int(c.scenario) not in [0,1,2,3,4,5] or int(c.backend)!=c.backend or int(c.backend) not in [0,1] or c.water<0 or c.water>.4 or c.nitrogen<0 or c.nitrogen>.08 or c.light<0 or c.light>32768 or c.flux<0 or c.flux>.12 or int(c.slant)!=c.slant or int(c.slant) not in [0,1] or int(c.lifecycle)!=c.lifecycle or int(c.lifecycle) not in [0,1,2,3] or int(c.radiation)!=c.radiation or int(c.radiation) not in [0,1,2] or int(c.recycling)!=c.recycling or int(c.recycling) not in [0,1] or int(c.decomposition)!=c.decomposition or int(c.decomposition) not in [0,1]:return false
 if not (r.get("tick") is int or r.get("tick") is float) or not is_finite(float(r.tick)) or int(r.tick)!=r.tick or r.tick<0 or r.tick>12288:return false
 if not r.get("fingerprint") is String:return false
 var re=RegEx.new();re.compile("^[0-9a-f]{64}$");return re.search(r.fingerprint)!=null
func _load():
 if saved_runs.item_count==0:return
 var f=FileAccess.open(record_dir+"/"+saved_runs.get_item_text(saved_runs.selected),FileAccess.READ)
 if f==null or f.get_length()>5000000:_event("Record unavailable or oversized");return
 var record=JSON.parse_string(f.get_as_text());f.close()
 if not _valid_record(record):_event("Invalid record rejected");return
 loaded_record=record;_event("Loaded record. Replay uses its saved settings.")
func _begin_replay():
 if not _valid_record(loaded_record):_event("Save or load a record first.");return
 var record=loaded_record.duplicate(true);var c=record.config;air_mode.select(int(c.carbon_access));decomposition_mode.select(int(c.decomposition));recycling_mode.select(int(c.recycling));radiation_mode.select(int(c.radiation));recipe.select(int(c.scenario));backend.select(int(c.backend));seed_input.value=c.seed;water_input.value=c.water;nitrogen_input.value=c.nitrogen;light_input.value=c.light;flux_input.value=c.flux;sky_mode.select(int(c.slant));lifecycle_mode.select(int(c.lifecycle));_reset();loaded_record=record;replay_target=record
 if record.tick==0:
  var same=world.fingerprint()==record.fingerprint;_event("Tick-zero exact replay "+("PASS" if same else "FAIL"));replay_target={};_refresh();return
 start_job(int(record.tick),"You")
func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:
  if bridge!=null:bridge.disable()
  if world!=null:world.close()
  get_tree().quit()

func _canopy_samples()->Array:
 var result:Array=[]
 for p in world.plants:
  for i in p.nodes.size():
   var n=p.nodes[i]
   if n.kind=="leaf":result.append({"plant":p.plant_id,"node":i,"incoming":n.light,"receipt":n.get("light_receipt",0),"shadow_owner":n.get("shadow_owner",-1)})
 return result
func _blocked_sites()->Array:
 var result:Array=[]
 for p in world.plants:
  for proposal in p.proposals:
   if proposal.state=="developing" and str(proposal.blocked).begins_with("occupied"):result.append({"plant":p.plant_id,"node":proposal.front,"reason":proposal.blocked})
 return result

func _highest_generation()->int:
 var highest=0
 for p in world.plants:highest=maxi(highest,p.generation)
 return highest
