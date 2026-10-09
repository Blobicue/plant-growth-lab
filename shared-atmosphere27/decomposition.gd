extends RefCounted
# Carbon-only turnover litter: N and W were already mobilized by maintain().
# Prescribed mineralization, no decomposer population or oxygen chemistry.
const RATE=.002
const CAP=100000
const SCALE=1000000000.0
static func advance(w):
 w.decomp_last=0
 if w.config.decomposition==0:return
 for p in w.plants:
  var q=mini(CAP,maxi(0,int(floor(p.litter*SCALE*RATE))))
  if q<=0:continue
  var amount=q/SCALE
  p.litter-=amount;p.atmosphere+=amount;p.heat+=amount*20.0
  w.decomp_total+=q;w.decomp_last+=q
  var key=str(p.plant_id);w.decomp_sources[key]=int(w.decomp_sources.get(key,0))+q
