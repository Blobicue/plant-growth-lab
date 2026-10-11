extends Control
const State=preload("res://state.gd")
const View=preload("res://renderer.gd")
var catalog:Dictionary
var selected:int=0
var live
var tabs:TabContainer
var panes:TabContainer
var choose:OptionButton
var heading:Label
var outcome:Label
var summary_table:Tree
var lineage:Tree
var plant_detail:RichTextLabel
var resources:Tree
var day:SpinBox
var provenance:RichTextLabel
var checkpoint:OptionButton
var replay_status:Label
var replay_detail:Label
var archive_world=null
var archive_running=false
var archive_target=0
var archive_start=0
var replay_matches=0
var replay_failed=false
var viewport:SubViewport
var view
var report_choice:OptionButton
var report_text:TextEdit
var replay_button:Button
var load_button:Button
var step_button:Button
var pause_button:Button
var stop_button:Button
var clock=0.0
var changing=false
func label_in(parent,text,size=16)->Label:
 var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.autowrap_mode=TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART;parent.add_child(l);return l
func button_in(parent,text,action)->Button:
 var b=Button.new();b.text=text;b.pressed.connect(action);parent.add_child(b);return b
func rich(parent)->RichTextLabel:
 var r=RichTextLabel.new();r.selection_enabled=true;r.size_flags_vertical=SIZE_EXPAND_FILL;r.size_flags_horizontal=SIZE_EXPAND_FILL;parent.add_child(r);return r
func table(parent,columns:Array)->Tree:
 var t=Tree.new();t.columns=columns.size();t.hide_root=true;t.column_titles_visible=true;t.size_flags_horizontal=SIZE_EXPAND_FILL;t.size_flags_vertical=SIZE_EXPAND_FILL
 for i in columns.size():t.set_column_title(i,columns[i]);t.set_column_custom_minimum_width(i,90)
 parent.add_child(t);return t
func add_row(t,values:Array,metadata=null):
 var item=t.create_item(t.get_root())
 for i in values.size():item.set_text(i,str(values[i]))
 item.set_metadata(0,metadata);return item
func page(parent,name)->VBoxContainer:
 var box=VBoxContainer.new();box.name=name;box.add_theme_constant_override("separation",12);parent.add_child(box);return box
func arm(r)->String:return "Legacy + R1" if int(r.mode)==0 else "T1/24 + R1"
func current()->Dictionary:return catalog.runs[selected]
func fmt(v)->String:return "—" if v==null else (String.num_scientific(float(v)) if typeof(v) in [TYPE_FLOAT,TYPE_INT] else str(v))
func _ready():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
 var bg=ColorRect.new();bg.color=Color("101f27");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for k in ["margin_left","margin_right","margin_top","margin_bottom"]:margin.add_theme_constant_override(k,18)
 add_child(margin);var body=VBoxContainer.new();body.add_theme_constant_override("separation",12);margin.add_child(body)
 label_in(body,"PLANT LAB   /   RESEARCH WORKSTATION",26)
 label_in(body,"LOCAL CPU CANDIDATE  •  Read-only evidence and isolated live controls  •  No model promoted",15).modulate=Color("9ddbd0")
 tabs=TabContainer.new();tabs.size_flags_vertical=SIZE_EXPAND_FILL;body.add_child(tabs)
 var evidence=page(tabs,"Evidence catalog");var bar=HBoxContainer.new();evidence.add_child(bar)
 label_in(bar,"Archived run",16);choose=OptionButton.new();choose.size_flags_horizontal=SIZE_EXPAND_FILL;bar.add_child(choose)
 for r in catalog.runs:choose.add_item("Seed %d  ·  %s  ·  12,288 h"%[int(r.seed),arm(r)])
 heading=label_in(evidence,"",19);outcome=label_in(evidence,"",16);outcome.modulate=Color("ffdaa0")
 panes=TabContainer.new();panes.size_flags_vertical=SIZE_EXPAND_FILL;evidence.add_child(panes)
 var overview=page(panes,"Paired outcomes")
 label_in(overview,"Same initial resources and founders. Compare whole worlds; descendant IDs are not matched across arms.")
 summary_table=table(overview,["Arm","Births","Alive founders","Alive gen1","Alive gen2","Gen3 births","Living cells","Deaths"])
 label_in(overview,"No generation 3 in any run. More roots or surviving tissue does not establish replacement.\nThe youngest T1 grandchild is right-censored at age 1,018 h with 12 paid nodes and no offspring.")
 var lin=page(panes,"Lineage & budgets")
 label_in(lin,"Select a plant to inspect its budget. Death is an observed event; an alive endpoint is right-censored.")
 lineage=table(lin,["Plant ← parent","Generation","Birth h","Maturity h","Death age h","End − birth h","Living / paid","Offspring"])
 plant_detail=rich(lin);plant_detail.custom_minimum_size.y=200;plant_detail.size_flags_vertical=0
 var res=page(panes,"Paired resources");var row=HBoxContainer.new();res.add_child(row);label_in(row,"Compare at model hour (daily samples)")
 day=SpinBox.new();day.min_value=24;day.max_value=12288;day.step=24;day.value=12288;row.add_child(day)
 resources=table(res,["World quantity · model units","Legacy + R1","T1/24 + R1","T1 minus legacy"]);resources.set_column_custom_minimum_width(0,320)
 label_in(res,"C / N / W are finite inventories; energy is an open boundary. Partition changes are not resource creation.\nDaily matter drift and hourly validation bounds are reported separately in Provenance.",14)
 var replay=page(panes,"Saved-state replay");var controls=HBoxContainer.new();replay.add_child(controls)
 checkpoint=OptionButton.new()
 for tick in [0,6144,12288]:checkpoint.add_item("Saved hour %s"%tick,tick)
 controls.add_child(checkpoint);load_button=button_in(controls,"Load saved state",load_archive);replay_button=button_in(controls,"Replay next 96 h",start_archive);step_button=button_in(controls,"Step",advance_archive);pause_button=button_in(controls,"Pause",pause_archive);stop_button=button_in(controls,"STOP / control off",stop_all)
 replay_status=label_in(replay,"No archive loaded. Loading never starts replay.",17)
 replay_detail=label_in(replay,"Archive replay is an in-memory copy. Each step checks the original hourly physical hash; original files are never written.",14)
 var vc=SubViewportContainer.new();vc.stretch=true;vc.custom_minimum_size.y=340;vc.size_flags_vertical=SIZE_EXPAND_FILL;replay.add_child(vc)
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;vc.add_child(viewport);view=View.new();viewport.add_child(view)
 vc.gui_input.connect(orbit)
 label_in(replay,"Actual saved tissue geometry · brown = inactive tissue · right-drag to orbit, wheel to zoom.\nAt 12,288 h the archived horizon is complete: inspection only, no extrapolated run.",14)
 var prov=page(panes,"Provenance & commands");provenance=rich(prov)
 var livepage=page(tabs,"Live lab · legacy + R1")
 label_in(livepage,"LIVE / UNSAVED · Candidate30 + R1, ordered transport. Separate from selected archive.\nExisting Run / Step / Pause / STOP and exact-save controls remain below. GPU is unavailable here.",15)
 var live_scroll=ScrollContainer.new();live_scroll.size_flags_vertical=SIZE_EXPAND_FILL;livepage.add_child(live_scroll)
 live=load("res://lab.tscn").instantiate();live.custom_minimum_size=Vector2(1350,1080);live_scroll.add_child(live)
 live.backend.set_item_disabled(1,true)
 var guide=page(tabs,"Models & reports")
 label_in(guide,"W27 / reviewed baseline    •    Candidate30 / savings experiment    •    R1 + T1 / experimental contract",18)
 label_in(guide,"The W27 Windows default is unchanged. This catalog replays only F1 binary states through their exact F1 adapter.\nW27 and original candidate30 records remain in their existing workstations; their reports and commands are below.\nHardware GPU / Windows: unavailable, not passed. Root feedback: not implemented or run. Strict JSON metric failures remain recorded.",16)
 report_choice=OptionButton.new();guide.add_child(report_choice)
 for key in catalog.texts:report_choice.add_item(key)
 report_text=TextEdit.new();report_text.editable=false;report_text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;report_text.size_flags_vertical=SIZE_EXPAND_FILL;guide.add_child(report_text)
 report_choice.item_selected.connect(func(i):report_text.text=catalog.texts[report_choice.get_item_text(i)])
 report_choice.select(0);report_text.text=catalog.texts[report_choice.get_item_text(0)]
 choose.item_selected.connect(select_run);lineage.item_selected.connect(show_plant);day.value_changed.connect(func(_v):show_resources())
 tabs.tab_changed.connect(func(_i):stop_all();save_preferences())
 panes.tab_changed.connect(func(_i):stop_all();save_preferences())
 checkpoint.item_selected.connect(func(_i):clear_archive())
 var prefs=ConfigFile.new()
 if prefs.load("user://catalog.cfg")==OK:
  selected=clampi(int(prefs.get_value("view","run",0)),0,catalog.runs.size()-1)
  panes.current_tab=clampi(int(prefs.get_value("view","pane",0)),0,4)
 choose.select(selected);select_run(selected)
 get_tree().auto_accept_quit=false;DisplayServer.window_set_title("Plant Research Workstation · F1 evidence · unpromoted")
func save_preferences():
 if changing:return
 var prefs=ConfigFile.new();prefs.set_value("view","run",selected);prefs.set_value("view","pane",panes.current_tab);prefs.save("user://catalog.cfg")
func stop_all():
 archive_running=false
 if live!=null:live._stop()
 if archive_world!=null:update_replay("Paused; control off")
func clear_archive():
 stop_all()
 if archive_world!=null:archive_world.close();archive_world=null
 replay_matches=0;replay_failed=false;replay_status.text="No archive loaded. Load the selected checkpoint explicitly."
 if view!=null:
  view.tissue.multimesh.instance_count=0;view.soil.multimesh.instance_count=0;view.seeds.multimesh.instance_count=0;view.lines.mesh=null;view.selected.visible=false
func select_run(i):
 selected=i;clear_archive();var r=current();heading.text="ARCHIVED / COMPLETE   ·   %s   ·   seed %d"%[arm(r),int(r.seed)]
 outcome.text="%d paid births  /  %d deaths  /  no generation 3  —  sustained replacement unestablished"%[int(r.summary.paid_births),int(r.summary.death_count)]
 summary_table.clear();summary_table.create_item()
 for s in catalog.runs:
  if int(s.seed)!=int(r.seed):continue
  var alive=s.summary.living_plants_by_generation
  add_row(summary_table,[arm(s),int(s.summary.paid_births),int(alive.get("0",0)),int(alive.get("1",0)),int(alive.get("2",0)),int(s.summary.generation3_births),int(s.summary.living_tissue),int(s.summary.death_count)])
 lineage.clear();lineage.create_item()
 for p in r.plants:
  add_row(lineage,["%d ← %s"%[int(p.id),"founder" if int(p.parent)<0 else str(int(p.parent))],int(p.generation),int(p.birth_tick),fmt(p.maturity_tick),fmt(p.death_age),int(p.endpoint_age),"%d / %d"%[int(p.living),int(p.paid)],int(p.paid_offspring)],p)
 plant_detail.text="Select a row. No deaths are inferred from missing samples.";show_resources();show_provenance();save_preferences()
func show_plant():
 var item=lineage.get_selected()
 if item==null:return
 var p=item.get_metadata(0)
 if p==null:return
 plant_detail.text="Plant %d / generation %d / %s\nLifetime model C: fixation %.6f | operation %.6f | construction %.6f\nReserve C: deposited %.6f | maintenance refunds %.6f | released %.6f\nFirst 768 h operating C %.6f; final world 192 h %.6f. These are different age windows.\nPaid roots %d / connected roots %d. Mobile carbon budget closure: %s\n%s"%[int(p.id),int(p.generation),"ALIVE — RIGHT-CENSORED" if p.survival_right_censored else "ALL TISSUE DEAD at hour %d"%int(p.death_tick),p.lifetime_fixed_C,p.lifetime_operating_C,p.lifetime_construction_C,p.reserve_deposited_C,p.reserve_refunded_C,p.reserve_released_C,p["0_768_operating_C"],p.final_world192_operating_C,int(p.paid_roots),int(p.connected_roots),fmt(p.mobile_budget_closure),"Alive is not mature or reproducing. Negative lifetime operation may spend initial reserves."]
func show_resources():
 resources.clear();resources.create_item();var pair=[]
 for r in catalog.runs:
  if int(r.seed)==int(current().seed):pair.append(r.daily_environment[int(day.value/24)-1])
 if pair.size()!=2:return
 for key in pair[0]:
  if key in ["seed","mode","tick"]:continue
  var a=float(pair[0][key]);var b=float(pair[1][key]);add_row(resources,[key,fmt(a),fmt(b),("+" if b>=a else "")+fmt(b-a)])
func show_provenance():
 var r=current();var g=catalog.guard_summary
 provenance.text="MODEL CONTRACT\n%s\nSeed %d • fixed horizon 12,288 model hours • native CPU\nF1 evidence commit %s\nR1 scientific basis %s\n\nVALIDATION / measured, not inferred from a green badge\nAll 12 F1 verification jobs passed: 1,152 exact replay hours, including 576 canonical comparison hours.\nSelected windows only; not every possible graph relabeling. All original legacy golden endpoints and 11 birth fingerprints matched.\nThis run maximum world error %s; per-plant %s.\nAcross F1, daily C/N/W drift: %s / %s / %s (matter limit 1e-9).\nOpen-energy maximum %s (separate limit 1e-7); plant limit 1e-9.\nHardware GPU and Windows unavailable, not passed. Historical strict JSON metrics failures are separate from physical hashes.\n\nREAD-ONLY SOURCE\n%s\nBinary checkpoint SHA256 is checked before restore; model/seed/hour and physical fingerprint are checked after restore.\nEvidence browsing never applies archived settings to the live lab. Files/commands below refer to the saved cloud checkout.\n\nREPRODUCTION / repository root\npython3 cloud-fresh/run_matrix.py\npython3 cloud-fresh/run_founder_checks.py\npython3 cloud-fresh/analyze.py\npython3 cloud-fresh/audit.py\nCompleted runs are preserved/skipped. For a fresh environment, see cloud-fresh/README.txt and cloud-port/REPORT.txt.\n\nARTIFACTS\ncloud-fresh/evidence/plants.csv\ncloud-fresh/evidence/paired-founders.csv\ncloud-fresh/evidence/environment-days.csv\ncloud-fresh/evidence/lineage-events.csv\ncloud-fresh/REPORT.txt\ncloud-workstation/evidence/adapter-manifest.json\n\nSCOPE\n%s"%[r.contract,int(r.seed),catalog.evidence_commit,catalog.science_commit,fmt(r.summary.max_world_error),fmt(r.summary.max_plant_error),fmt(g.daily_matter_max_abs_drift.C),fmt(g.daily_matter_max_abs_drift.N),fmt(g.daily_matter_max_abs_drift.W),fmt(g.daily_reported_energy_max_abs_error),r.source,catalog.scope]
func load_archive():
 clear_archive();var r=current();var tick=checkpoint.get_selected_id();var meta=r.states[str(tick)]
 if not FileAccess.file_exists(meta.path) or FileAccess.get_sha256(meta.path)!=meta.sha256:replay_status.text="BLOCKED: missing or changed checkpoint. No state loaded.";return
 var raw=bytes_to_var(FileAccess.get_file_as_bytes(meta.path))
 if not raw is Dictionary or not raw.has("world") or int(raw.world.config.seed)!=int(r.seed) or int(raw.world.transport_substeps)!=int(r.mode) or int(raw.world.tick)!=tick or raw.fingerprint!=r.hashes[str(tick)]:replay_status.text="BLOCKED: checkpoint model, seed, hour or fingerprint mismatch.";return
 archive_world=State.new().restore(meta.path);archive_start=tick;archive_target=mini(tick+96,int(r.horizon));replay_matches=0
 if archive_world.fingerprint()!=r.hashes[str(tick)]:replay_failed=true
 render_archive();update_replay("Exact saved state loaded / paused")
func render_archive():
 var ymax=2.5
 for node in archive_world.nodes:ymax=maxf(ymax,node.pos.y*.16+.2)
 view.target_y=(ymax-1.6)*.5;view.fit_size=maxf(4.7,ymax+2.7);view.frame();view.rebuild(archive_world,true,true,true)
func update_replay(message):
 if archive_world==null:return
 replay_status.text="ARCHIVE COPY / %s / seed %d / hour %d → %d / %d exact steps\n%s"%[arm(current()),int(current().seed),archive_world.tick,archive_target,replay_matches,message]
 replay_detail.text="%s\nSHA256 %s\nThis is replay of an archived run, not the live lab or a new biological result."%[current().states[str(archive_start)].path,current().states[str(archive_start)].sha256]
 replay_button.disabled=replay_failed or archive_world.tick>=archive_target;step_button.disabled=replay_button.disabled
func start_archive():
 if archive_world==null:replay_status.text="Load a saved state first.";return
 if replay_failed or archive_world.tick>=archive_target:return
 archive_running=true;clock=0;update_replay("Replaying; Pause and STOP remain available")
func pause_archive():archive_running=false;update_replay("Paused")
func advance_archive():
 if archive_world==null or replay_failed or archive_world.tick>=archive_target:return
 archive_world.step()
 for p in archive_world.plants:p.finish_observation()
 if not archive_world.error.is_empty() or not archive_world.censored.is_empty() or archive_world.fingerprint()!=current().hashes[str(archive_world.tick)]:
  replay_failed=true;archive_running=false;update_replay("FAILED: physical replay or model guard. Stopped.");return
 replay_matches+=1;render_archive()
 if archive_world.tick>=archive_target:archive_running=false;update_replay("PASS: selected saved-state replay complete")
 else:update_replay("Replaying" if archive_running else "Paused after step")
func _process(delta):
 if archive_running:
  clock+=delta
  if clock>=0.05:clock=0;advance_archive()
func orbit(event):
 if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT:view.yaw-=event.relative.x*.01;view.pitch=clampf(view.pitch+event.relative.y*.01,.08,1.45);view.frame()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:view.zoom=maxf(1.5,view.zoom*.9);view.frame()
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:view.zoom=minf(12,view.zoom*1.1);view.frame()
func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:stop_all();save_preferences();get_tree().quit()
func _exit_tree():
 archive_running=false
 if archive_world!=null:archive_world.close();archive_world=null
 if live!=null and is_instance_valid(live):live.paused=true;live.bridge.disable();live.world.close()
