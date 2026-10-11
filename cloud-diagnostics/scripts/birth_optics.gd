extends SceneTree
const State=preload("res://state.gd")
const Canopy=preload("res://canopy.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var rows=[]
 for seed in [12011,4242,7301]:
  var observations=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/observer-%d-12288.json"%seed))
  for b in observations.births:
   var w=State.new().restore("res://evidence/birth-%d-%d.bin"%[seed,b.plant]);var target=w.plant_by_id(int(b.plant));var fingerprint=w.fingerprint()
   var emission=int(round(w.config.flux*1e9))*Canopy.BEAMS*2
   var shared=Canopy.trace(w.plants,emission,true);var alone=Canopy.trace([target],emission,true);var details=[]
   for r in shared.records:
    if r.plant==target.plant_id and target.nodes[r.node].kind=="leaf":details.append(r)
   assert(w.fingerprint()==fingerprint,"pure optics calculation must not mutate state")
   rows.append({"seed":seed,"id":target.plant_id,"generation":target.generation,"birth":w.tick,"position":target.nodes[0].pos,"hypothetical_daytime_emission_q":emission,"shared_received_q":shared.intercepted[target.plant_id],"target_alone_received_q":alone.intercepted[target.plant_id],"leaf_records":details,"unchanged_state":true,"note":"Static daytime ray calculation only. No light or resource is assigned to the simulation; no survival inference from this alone."});w.close()
 var f=FileAccess.open("res://evidence/birth-optics.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  ",true,true));f.close();print("Pure saved-birth optics comparison complete, no steps or assignments.");quit()
