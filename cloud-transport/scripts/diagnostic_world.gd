extends "res://world.gd"
const R=preload("res://relabel.gd")
var phase_samples=[]
func audit_sample(phase:String):
 super.audit_sample(phase)
 var states=[];var requests=[]
 for p in plants:
  states.append({"id":p.plant_id,"nodes":R.canonical(p),"vapor":p.vapor,"litter":p.litter,"heat":p.heat,"totals":p.totals.duplicate(),"photo_claim":p.photo_claim(),"reserve":p.reserve.duplicate()})
  for n in p.nodes:
   if n.kind=="root" and n.connected:requests.append({"plant":p.plant_id,"pos":n.pos,"solid_c":n.solid_c,"water":n.w,"nitrogen":n.n,"want_w_raw":minf(n.solid_c*.7,maxf(0,.012-n.w))*1e9,"want_n_raw":minf(n.solid_c*.1,maxf(0,.003-n.n))*1e9,"want_w":int(floor(minf(n.solid_c*.7,maxf(0,.012-n.w))*1e9)),"want_n":int(floor(minf(n.solid_c*.1,maxf(0,.003-n.n))*1e9))})
 requests.sort_custom(func(a,b):return str(a.plant)+str(a.pos)<str(b.plant)+str(b.pos))
 phase_samples.append({"phase":phase,"tick":tick,"plants":states,"field":field.full(),"air_hour":air_hour.duplicate(true),"hydro_cloud":hydro_cloud,"hydro_condensed":hydro_condensed,"root_requests":requests,"ledger":ledger()})
