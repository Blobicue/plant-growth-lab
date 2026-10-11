"""Report all preregistered cases, including null/negative outcomes, with C closure."""
from pathlib import Path
import json,collections
P=Path(__file__).resolve().parent;E=P/'evidence';plan=json.loads((P/'control-plan.json').read_text());primary_count=len(plan['cases']);followup=P/'followup-plan.json'
if followup.exists():plan['cases']+=json.loads(followup.read_text())['cases']
rows=[];pending=[]
for c in plan['cases']:
 name='control-'+'-'.join(str(c[k])for k in ['seed','id','arm','duration'])+'.json';f=E/name
 if not f.exists():pending.append(c);continue
 d=json.loads(f.read_text());daily=d['daily'];total=collections.Counter();early=collections.Counter();closure=0.
 def stock(r):return r['pools']['c']+r['pools']['disconnected_c']+sum(r['reserve'][k]['c']for k in ['balance','released','disposed'])
 for a,b in zip(daily,daily[1:]):
  v=b['budget'];total.update(v)
  if b['age']<=192:early.update(v)
  closure=max(closure,abs(stock(b)-stock(a)+v['construction_C']-v['operating_C']))
 assert closure<1e-9,(name,closure)
 first=lambda prefix:next((e for e in d['events']if e['event'].startswith(prefix)),None)
 target=d['endpoint']['target'];world=d['endpoint']['world'];initial=d['origin'];allN=sum(p['mobile']['n']for p in initial['plants']);otherN=sum(p['mobile']['n']for p in initial['plants']if p['id']!=c['id'])
 rows.append({**c,'source':name,'origin_fingerprint':d['origin_fingerprint'],'origin_exact':d['origin_exact'],'healthy':not d['error']and not d['censored'],'baseline_known_hashes':d['baseline_known_hashes'],'paid_nodes':target['nodes'],'living_nodes':target['living'],'paid_roots':target['roots'],'connected_roots':next(p['connected_roots']for p in world['plants']if p['id']==c['id']),'leaf_packets':target['leaves'],'birth_soil_N':initial['matter']['N']['soil'],'birth_other_plant_mobile_N':otherN,'birth_soil_W':initial['matter']['W']['soil'],'initial_ledger':initial['ledger'],'end_ledger':world['ledger'],'budget':dict(total),'first192h_budget':dict(early),'carbon_stock_closure_max_abs':closure,'first_unpaid':first('unpaid'),'first_death':first('death'),'all_dead':first('all_tissue_dead'),'maturity':first('maturity32'),'new_target_offspring':[x for x in d['endpoint']['lineage']if x['parent']==c['id']and x['birth_tick']>daily[0]['tick']],'max_error':d['max_error'],'max_plant_error':d['max_plant_error'],'non_target_connected_roots':{str(p['id']):p['connected_roots']for p in world['plants']if p['id']!=c['id']}})
for seed,pid in [(12011,3),(4242,4),(7301,3),(12011,2),(4242,2),(7301,2),(4242,5),(4242,6),(7301,4)]:
 r=[x for x in rows if x['seed']==seed and x['id']==pid];assert len({x['origin_fingerprint']for x in r})<=1
result={'preregistered_cases':len(plan['cases']),'primary_cases':primary_count,'separately_registered_followup_cases':len(plan['cases'])-primary_count,'completed':len(rows),'pending':pending,'cases':rows,'interpretation':'Access-gated counterfactuals only, never ordinary viability or production policy. Physical origin hashes and original finite ledgers remain mandatory. Root counts distinguish paid from connected tissue.'}
(E/'control-analysis.json').write_text(json.dumps(result,indent=2))
for r in rows:print(r['seed'],r['id'],'gen',r['generation'],'arm',r['arm'],'paid/living/root',r['paid_nodes'],r['living_nodes'],r['paid_roots'],'N',round(r['budget']['uptake_N'],8),'W',round(r['budget']['uptake_W'],8),'fixed',round(r['budget']['fixed_C'],8),'operating',round(r['budget']['operating_C'],8),'death',r['all_dead']['age']if r['all_dead']else None)
print('completed',len(rows),'pending',len(pending))
