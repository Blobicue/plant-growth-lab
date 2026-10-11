"""Analyze passive trajectories and independently reconcile mobile/reserve carbon."""
from pathlib import Path
import json,collections,csv
P=Path(__file__).resolve().parent;E=P/'evidence';W=P/'work/candidate30/evidence'
cohorts=[];checks=[]
for seed in [12011,4242,7301]:
 f=W/f'observer-{seed}-12288.json'
 if not f.exists():continue
 d=json.loads(f.read_text());rows=[json.loads(s)for s in (W/f'observations-{seed}-12288.jsonl').read_text().splitlines()]
 checks.append({'seed':seed,'physical_checkpoints_exact':all(x['exact']for x in d['fingerprints']),'horizon':d['horizon'],'error':d['error'],'censored':d['censored'],'max_error':d['max_error']})
 for p in d['plants']:
  rs=[r for r in rows if r['id']==p['id']];birth=next(b for b in d['births'] if b['plant']==p['id']);budgets=collections.Counter();closure=0.;full=[]
  def stock(r):return r['pools']['c']+r['pools']['disconnected_c']+sum(r['reserve'][x]['c']for x in ['balance','released','disposed'])
  for a,b in zip(rs,rs[1:]):
   budget=b['budget'];budgets.update(budget);closure=max(closure,abs(stock(b)-stock(a)+budget['construction_C']-budget['operating_C']))
   if b['tick']-a['tick']==24 and b['age']<=192:full.append(b)
  early={k:sum(r['budget'].get(k,0)for r in full)for k in ['uptake_N','uptake_W','fixed_C','direct_respired_C','repair_C','operating_C','actual_demand_C','hydrated_demand_C','unshaded_hydrated_C','unpaid_C','refused_C','refused_N','refused_W']}
  early['complete_days']=len(full);early['water_after_fixation']=early['uptake_W']-.5*early['fixed_C'];early['hydration_ratio']=early['actual_demand_C']/early['hydrated_demand_C'] if early['hydrated_demand_C']else None;early['air_fulfillment_ratio']=early['fixed_C']/early['actual_demand_C']if early['actual_demand_C']else None
  first=lambda pred:next((x for x in p['events'] if pred(x)),None)
  cohorts.append({'seed':seed,'id':p['id'],'generation':p['generation'],'parent':rs[0]['parent'],'birth_tick':p['birth_tick'],'genotype':p['genotype'],'birth_soil_N':birth['matter']['N']['soil'],'birth_soil_W':birth['matter']['W']['soil'],'birth_plant_mobile_N':birth['matter']['N']['mobile'],'birth_shared_air_C':birth['air'],'initial_mobile':rs[0]['pools'],'end_paid_nodes':rs[-1]['nodes'],'end_living_nodes':rs[-1]['living'],'carbon_stock_closure_max_abs':closure,'first_complete_days':early,'whole_observed_budget':dict(budgets),'first_root_N_only_refusal':first(lambda x:x['event'].startswith('refusal_root')and x['data'].get('short')==['n']),'first_root_N_refusal':first(lambda x:x['event'].startswith('refusal_root')and'n'in x['data'].get('short',[])),'first_unpaid':first(lambda x:x['event'].startswith('unpaid')),'first_death':first(lambda x:x['event'].startswith('death')),'all_dead':first(lambda x:x['event']=='all_tissue_dead'),'maturity':first(lambda x:x['event']=='maturity32'),'first_zero_mobile_C_daily':next(({'tick':r['tick'],'age':r['age']}for r in rs if r['pools']['c']+r['pools']['disconnected_c']<1e-12),None)})
assert all(x['carbon_stock_closure_max_abs']<1e-9 for x in cohorts)
result={'definitions':{'operating_C':'fixed_C minus direct respire() payments minus full repair construction cost; before new growth and reserve transfers','closure':'Delta(all node mobile C + reserve C + cumulative reserve release C + disposal C) + interval construction C = interval operating C','early_window':'complete24h intervals ending by age192h; excludes the partial first interval','hydration_ratio':'actual physiological carbon demand / demand with water saturation, same observed light/energy caps; not a simulation intervention','air_fulfillment_ratio':'actual fixation / physiological demand; integer allocation quantization can make this slightly below1'},'checks':checks,'cohorts':cohorts}
(E/'passive-analysis.json').write_text(json.dumps(result,indent=2))
for c in cohorts:
 f=c['first_complete_days'];print(c['seed'],c['id'],'gen',c['generation'],'birthN',c['birth_soil_N'],'end',c['end_paid_nodes'],c['end_living_nodes'],'firstdays',f['complete_days'],'N/W/fixed/operating',*[round(f[k],8)for k in ['uptake_N','uptake_W','fixed_C','operating_C']],'hydration',round(f['hydration_ratio'] or 0,3),'rootNage',c['first_root_N_only_refusal']['age']if c['first_root_N_only_refusal']else None,'death',c['all_dead']['tick']if c['all_dead']else None,'closure',c['carbon_stock_closure_max_abs'])
