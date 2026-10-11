extends SceneTree
const State=preload("res://state.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var all=[]
 for seed in [12011,4242,7301]:
  for endpoint in ["end","final"]:
   var w=State.new().restore("/workspace/plant-growth-lab/cloud-port/evidence/juvenile-allocation30-cloud-%s-%d.bin"%[endpoint,seed]);var plants=[]
   for p in w.plants:
    var cancels={};var first=[]
    for q in p.proposals:
     var key=str(q.state)+":"+str(q.blocked);cancels[key]=cancels.get(key,0)+1
     if first.size()<12:first.append(q)
    plants.append({"id":p.plant_id,"generation":p.generation,"birth":p.birth_tick,"parent":p.parent_id,"genotype":p.genotype,"initial":p.initial,"totals":p.totals,"nodes":p.nodes,"tips":p.tips,"first_proposals":first,"proposal_counts":cancels,"reserve":p.reserve_state(),"litter":p.litter,"vapor":p.vapor,"received_light":p.received_light,"air_received":p.air_received,"air_returned":p.air_returned})
   all.append({"seed":seed,"tick":w.tick,"fingerprint":w.fingerprint(),"plants":plants,"matter":w.matter_report(),"air":w.air,"lineage":w.lineage});w.close()
 var f=FileAccess.open("res://evidence/saved-inventory.json",FileAccess.WRITE);f.store_string(JSON.stringify(all,"  ",true,true));f.close();print("Inspected six existing binary endpoints without advancing simulation.");quit()
