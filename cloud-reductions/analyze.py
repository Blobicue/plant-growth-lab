"""Analyze every registered result, including numerical shadows and pending cases."""
from pathlib import Path
import json,csv,collections,math
P=Path(__file__).resolve().parent;R=P.parent;E=P/'evidence';plan=json.loads((P/'protocol.json').read_text())
rows=[];pending=[];pairs=[];raw={}
for c in plan['cohorts']:
 for mode in [0,24,48]:
  f=E/f'trial-{c["seed"]}-{c["id"]}-{mode}.json'
  if not f.exists():pending.append({'seed':c['seed'],'id':c['id'],'mode':mode});continue
  d=json.loads(f.read_text());raw[c['seed'],c['id'],mode]=d
  assert d['origin_fingerprint']==c['fingerprint'] and not d['error'] and not d['censored'] and d['duration']==768
  budget=collections.Counter();early=collections.Counter();closure=0.
  def stock(r):return r['pools']['c']+r['pools']['disconnected_c']+sum(r['reserve'][k]['c'] for k in ['balance','released','disposed'])
  for a,b in zip(d['daily'],d['daily'][1:]):
   v=b['budget'];budget.update(v)
   if b['age']<=96:early.update(v)
   closure=max(closure,abs(stock(b)-stock(a)+v['construction_C']-v['operating_C']))
  assert closure<1e-9,(f.name,closure)
  first=lambda prefix:next((e for e in d['events'] if e['event'].startswith(prefix)),None)
  roots=[e['age'] for e in d['events'] if e['event'].startswith('built_node_') and e['data']['kind']=='root']
  end=d['daily'][-1];initial=d['daily'][0];off=[x for x in d['lineage'] if x['parent']==c['id'] and x['birth_tick']>d['birth_tick']]
  if mode==0:
   source=json.loads((R/f'cloud-diagnostics/evidence/observer-{c["seed"]}-12288.json').read_text());p=next(p for p in source['plants'] if p['id']==c['id'])
   def paid(events):return [(e['age'],e['data']['kind'],e['data']['position'],e['data']['proposal']) for e in events if e['event'].startswith('built_node_') and e['age']<=768]
   assert paid(p['events'])==paid(d['events']),f.name+' archived paid events'
   prior=R/f'cloud-diagnostics/evidence/control-{c["seed"]}-{c["id"]}-0-768.json'
   if prior.exists():assert json.loads(prior.read_text())['endpoint']['fingerprint']==d['endpoint_fingerprint']
  result={'seed':c['seed'],'id':c['id'],'generation':c['generation'],'mode':mode,'paid_roots':end['roots'],'connected_roots':end['connected_roots'],'paid_nodes':end['nodes'],'living_nodes':end['living'],'leaf_packets':end['leaves'],'third_root_age':roots[1] if len(roots)>1 else None,'all_dead_age':first('all_tissue_dead')['age'] if first('all_tissue_dead') else None,'first_unpaid_age':first('unpaid')['age'] if first('unpaid') else None,'first_tissue_death_age':first('death')['age'] if first('death') else None,'maturity_age':first('maturity32')['age'] if first('maturity32') else None,'new_offspring':len(off),'expired_proposals':end['totals']['expired']-initial['totals']['expired'],'fixed_C':budget['fixed_C'],'absorbed_light_E':budget['light_receipt_E'],'uptake_N':budget['uptake_N'],'uptake_W':budget['uptake_W'],'unpaid_C':budget['unpaid_C'],'repair_C':budget['repair_C'],'operating_C':budget['operating_C'],'construction_C':budget['construction_C'],'construction_N':budget['construction_N'],'construction_W':budget['construction_W'],'first96h_budget':dict(early),'budget':dict(budget),'carbon_stock_closure_max_abs':closure,'max_world_error':d['max_world_error'],'max_plant_error':d['max_plant_error'],'maximum_sender_fraction':d['max_sender_fraction'],'world_endpoint':d['world_daily'][-1],'initial_world_ids':[p['id'] for p in d['world_daily'][0]],'new_world_births':[{'parent':x['parent'],'child':x['child'],'age':x['birth_tick']-d['birth_tick'],'generation':x['generation']} for x in d['lineage'] if x['birth_tick']>d['birth_tick']]}
  rows.append(result)
 for mode in [0,24]:
  if not (E/f'verify-{c["seed"]}-{c["id"]}-{mode}.json').exists():pending.append({'seed':c['seed'],'id':c['id'],'verification_mode':mode})
 if all((c['seed'],c['id'],m) in raw for m in [0,24,48]):
  rr={r['mode']:r for r in rows if r['seed']==c['seed'] and r['id']==c['id']};b,t,f=rr[0],rr[24],rr[48]
  def event_seq(mode):return [(e['age'],e['data']['kind'],e['data']['position']) for e in raw[c['seed'],c['id'],mode]['events'] if e['event'].startswith('built_node_')]
  sensitive={k:{'N24':t[k],'N48':f[k]} for k in ['paid_roots','connected_roots','paid_nodes','living_nodes','third_root_age','all_dead_age','first_unpaid_age','first_tissue_death_age','maturity_age','new_offspring'] if t[k]!=f[k]}
  pairs.append({'seed':c['seed'],'id':c['id'],'generation':c['generation'],'baseline_roots':b['paid_roots'],'T1_roots':t['paid_roots'],'refinement_roots':f['paid_roots'],'root_difference':t['paid_roots']-b['paid_roots'],'baseline_living':b['living_nodes'],'T1_living':t['living_nodes'],'refinement_living':f['living_nodes'],'baseline_third_root_age':b['third_root_age'],'T1_third_root_age':t['third_root_age'],'refinement_third_root_age':f['third_root_age'],'fixed_C_difference':t['fixed_C']-b['fixed_C'],'unpaid_C_difference':t['unpaid_C']-b['unpaid_C'],'repair_C_difference':t['repair_C']-b['repair_C'],'operating_C_difference':t['operating_C']-b['operating_C'],'expiry_difference':t['expired_proposals']-b['expired_proposals'],'refinement_construction_timeline_exact':event_seq(24)==event_seq(48),'refinement_discrete_differences':sensitive,'refinement_fixed_C_difference':f['fixed_C']-t['fixed_C'],'baseline_new_world_births':b['new_world_births'],'T1_new_world_births':t['new_world_births'],'refinement_new_world_births':f['new_world_births'],'existing_non_target_living_difference':sum(p['living'] for p in t['world_endpoint'] if p['id'] in b['initial_world_ids'] and p['id']!=c['id'])-sum(p['living'] for p in b['world_endpoint'] if p['id'] in b['initial_world_ids'] and p['id']!=c['id']),'non_target_living_difference':sum(p['living'] for p in t['world_endpoint'] if p['id']!=c['id'])-sum(p['living'] for p in b['world_endpoint'] if p['id']!=c['id'])})
verifications=[json.loads(f.read_text()) for f in E.glob('verify-*.json')];assert all(v['pass'] for v in verifications)
runtimes=[json.loads(f.read_text()) for f in E.glob('*.runtime.json')]
result={'numerical_contract':'R1; legacy versus T1/24 with fixed48 refinement','registered_primary_cases':22,'registered_numerical_shadows':11,'completed_trials':len(rows),'completed_verifications':len(verifications),'pending':pending,'cases':rows,'pairs':pairs,'max_carbon_closure':max((r['carbon_stock_closure_max_abs'] for r in rows),default=0),'max_world_error':max((r['max_world_error'] for r in rows),default=0),'max_plant_error':max((r['max_plant_error'] for r in rows),default=0),'exact_hourly_replay_checks':sum(v['reverse_saved_replay_hours_exact'] for v in verifications),'canonical_node_field_hourly_checks':sum(v['canonical_node_and_field_hours_checked'] for v in verifications),'runtime':{'completed_invocations':len(runtimes),'wall_seconds':sum(r['wall_seconds'] for r in runtimes),'peak_rss_bytes':max((r['peak_rss_bytes'] for r in runtimes),default=0),'minimum_headroom_bytes':min((r['minimum_headroom_bytes'] for r in runtimes),default=0),'failed_invocations':[r['command'] for r in runtimes if r['exit'] or r['stop_reason']]},'interpretation':'Fixed768h matched legacy birth states; all-plant T1; numerical shadows never selected for outcome. No feedback, rate tuning, promotion or sustained-replacement claim.'}
(E/'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
if rows:
 fields=[k for k in rows[0] if k not in ['first96h_budget','budget','world_endpoint','initial_world_ids','new_world_births']]
 with (E/'cohort-results.csv').open('w') as f:
  w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');w.writeheader();w.writerows({k:r[k] for k in fields} for r in rows)
if pairs:
 fields=[k for k in pairs[0] if k not in ['refinement_discrete_differences','baseline_new_world_births','T1_new_world_births','refinement_new_world_births']]
 with (E/'paired-results.csv').open('w') as f:
  w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');w.writeheader();w.writerows({k:r[k] for k in fields} for r in pairs)
print(json.dumps({'completed_trials':len(rows),'completed_verifications':len(verifications),'pending_count':len(pending),'pairs':pairs},indent=2))
