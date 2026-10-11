"""Summarize completed F1 arms; compare worlds by seed/time, never descendants by ID."""
from pathlib import Path
from collections import Counter
import json,gzip,csv,hashlib
P=Path(__file__).resolve().parent;E=P/'evidence';runs=E/'runs';summaries=[];plants=[];dayplants=[];envrows=[];budget_errors=[];births=[];initials={};source={};golden_births=0
reference_births=json.loads((P.parent/'cloud-reductions/protocol.json').read_text())['cohorts']
def read(path):source[str(path.relative_to(P))]=hashlib.sha256(path.read_bytes()).hexdigest();return json.loads(path.read_text())
def csvout(name,rows):
 if not rows:return
 fields=list(dict.fromkeys(k for r in rows for k in r))
 with (E/name).open('w') as f:
  w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');w.writeheader();w.writerows(rows)
def mobile(p):return p['pools']['c']+p['pools']['disconnected_c']+p['reserve']['balance']['c']
def retained_plus_exports(p):return mobile(p)+p['reserve']['released']['c']+p['reserve']['disposed']['c']
def flat_env(e):
 out={f'{r}_{k}':v for r in ['C','N','W'] for k,v in e['matter'][r].items()}
 for r in ['C','N','W']:out[r+'_total']=sum(e['matter'][r].values())
 for k in ['contested','limited','space_conflicts']:out[k]=e[k]
 for k in ['input_total','output_total','stored_inside','energy_error']:out['energy_'+k]=e['radiation'][k]
 return out
for seed in [12011,4242,7301]:
 for mode in [0,24]:
  d=runs/f'f1-{seed}-{mode}'
  if not (d/'complete.json').exists():continue
  last=read(d/'complete.json');initial=read(d/'initial.json');bb=read(d/'births.json');initials[seed,mode]=initial
  assert last['complete'] and last['tick']==12288 and not last['error'] and not last['censored']
  if mode==0:
   for birth in bb:
    old=next(c for c in reference_births if (c['seed'],c['id'])==(seed,birth['plant']['id']));assert old['fingerprint']==birth['fingerprint'];golden_births+=1
  starts={p['row']['id']:p['row'] for p in initial['plants']}
  for b in bb:starts[b['plant']['id']]=b['plant'];births.append({'seed':seed,'mode':mode,'tick':b['tick'],'id':b['plant']['id'],'parent':b['plant']['parent'],'generation':b['plant']['generation'],'genotype':b['plant']['genotype'],'nodes':b['nodes']})
  for p in last['plants']:
   start=starts[p['id']];c=p['cumulative'];events=p['events'];die=next((e['tick'] for e in events if e['event']=='all_tissue_dead'),None);mature=next((e['tick'] for e in events if e['event']=='maturity32'),None)
   ownbirths=[b for b in bb if b['plant']['parent']==p['id']]
   closure=retained_plus_exports(p)-retained_plus_exports(start)-(c.get('operating_C',0)-c.get('construction_C',0));assert abs(closure)<1e-9,(seed,mode,p['id'],closure);budget_errors.append(abs(closure))
   construction_solid=p['totals']['built_c']-start['totals']['built_c'];construction_loss=c.get('construction_C',0)-construction_solid
   reproduction_fee=(p['reserve']['released']['c']-start['reserve']['released']['c'])/51.0
   repair_loss=p['totals']['respired_c']-start['totals']['respired_c']-c.get('direct_respired_C',0)-construction_loss-reproduction_fee
   assert repair_loss>-1e-9 and construction_loss>-1e-9
   row={'seed':seed,'mode':mode,'id':p['id'],'parent':p['parent'],'generation':p['generation'],'birth_tick':p['birth_tick'],'endpoint_age':p['age'],'paid':p['paid'],'living':p['living'],'paid_roots':p['roots'],'connected_roots':p['connected_roots'],'leaves':p['leaves'],'death_tick':die,'death_age':die-p['birth_tick'] if die is not None else None,'survival_right_censored':die is None,'maturity_tick':mature,'paid_offspring':len(ownbirths),'initial_mobile_C':mobile(start),'final_mobile_C':mobile(p),'reserve_released_C':p['reserve']['released']['c'],'reserve_deposited_C':p['reserve']['deposited']['c'],'reserve_refunded_C':p['reserve']['refunded']['c'],'reserve_disposed_C':p['reserve']['disposed']['c'],'lifetime_operating_C':c.get('operating_C',0),'lifetime_fixed_C':c.get('fixed_C',0),'lifetime_upkeep_respired_C':c.get('upkeep_respired_C',0),'lifetime_stress_respired_C':c.get('stress_recovery_C',0),'lifetime_tip_respired_C':c.get('tip_respired_C',0),'lifetime_repair_C':c.get('repair_C',0),'lifetime_turnover_C':c.get('turnover_C',0),'lifetime_construction_C':c.get('construction_C',0),'lifetime_construction_yield_loss_C':construction_loss,'lifetime_repair_yield_loss_C':repair_loss,'lifetime_reproductive_assembly_C':reproduction_fee,'lifetime_uptake_W':c.get('uptake_W',0),'lifetime_uptake_N':c.get('uptake_N',0),'lifetime_light_E':c.get('light_receipt_E',0),'lifetime_hydrated_demand_C':c.get('hydrated_demand_C',0),'lifetime_actual_demand_C':c.get('actual_demand_C',0),'lifetime_mean_leaf_water':c.get('leaf_water_sum',0)/c['connected_leaves'] if c.get('connected_leaves',0) else None,'mobile_budget_closure':closure,'complete_768h_window':p['age']>=768}
   for window in ['0_96','0_768','576_768']:
    b=p['windows'][window]
    for k in ['operating_C','fixed_C','direct_respired_C','repair_C','construction_C','turnover_C','upkeep_respired_C','stress_recovery_C','tip_respired_C','uptake_W','uptake_N','light_receipt_E','hydrated_demand_C','actual_demand_C','unpaid_C']:
     row[window+'_'+k]=b.get(k,0)
    row[window+'_mean_leaf_water']=b.get('leaf_water_sum',0)/b['connected_leaves'] if b.get('connected_leaves',0) else None
   for age in [4,16]:
    seen=next((v for v in p['fronts'] if v['age']==age),None);rs=[v['front'] for v in seen['fronts'] if v['kind']=='root'] if seen else []
    row[f'age{age}_root_front_observed']=bool(rs);row[f'age{age}_root_N_only']=any(n['c']>=.0018 and n['n']<.000108 and n['w']>=.00054 for n in rs) if seen else None
    row[f'age{age}_root_recorded_N_block']=any(q['kind']=='root' and q['blocked_previous']=='N' and q['front']['c']>=.0018 and q['front']['n']<.000108 and q['front']['w']>=.00054 for q in seen['fronts']) if seen else None
   row['leaf_N_only_refusal_observed']=any(e['event'].startswith('refusal_leaf_') and e['data'].get('actual_short_at_record')==['n'] for e in events)
   row['new_leaf_packets']=sum(e['event'].startswith('built_node_') and e['data']['kind']=='leaf' for e in events)
   plants.append(row)
  last_plants=last['plants'];living=Counter();paid=Counter();offspring_parents=Counter()
  for p in last_plants:
   paid[p['generation']]+=1
   if p['living']>0:living[p['generation']]+=1
   if any(b['plant']['parent']==p['id'] for b in bb):offspring_parents[p['generation']]+=1
  summaries.append({'seed':seed,'mode':mode,'tick':12288,'initial_fingerprint':initial['fingerprint'],'endpoint_fingerprint':last['fingerprint'],'paid_births':len(bb),'paid_plants_by_generation':dict(paid),'living_plants_by_generation':dict(living),'offspring_producing_parents_by_generation':dict(offspring_parents),'living_tissue':sum(p['living'] for p in last_plants),'generation3_births':sum(b['plant']['generation']==3 for b in bb),'death_count':sum(next((True for e in p['events'] if e['event']=='all_tissue_dead'),False) for p in last_plants),'max_world_error':last['max_world_error'],'max_plant_error':last['max_plant_error'],'environment_initial':flat_env(initial['environment']),'environment_end':flat_env(last['environment'])})
  path=d/'daily.jsonl.gz';source[str(path.relative_to(P))]=hashlib.sha256(path.read_bytes()).hexdigest();ndays=0;nhashes=0
  with gzip.open(path,'rt') as f:
   for line in f:
    day=json.loads(line);ndays+=1;nhashes+=len(day['hashes']);assert day['tick']==ndays*24 and len(day['hashes'])==24
    envrows.append({'seed':seed,'mode':mode,'tick':day['tick'],**flat_env(day['environment'])})
    for p in day['plants']:
     b=p['budget'];dayplants.append({'seed':seed,'mode':mode,'tick':day['tick'],'id':p['id'],'generation':p['generation'],'parent':p['parent'],'age':p['age'],'paid':p['paid'],'living':p['living'],'roots':p['roots'],'connected_roots':p['connected_roots'],'leaves':p['leaves'],'mobile_C':mobile(p),'reserve_C':p['reserve']['balance']['c'],'reserve_released_C':p['reserve']['released']['c'],**{k:b.get(k,0) for k in ['operating_C','fixed_C','upkeep_respired_C','stress_recovery_C','tip_respired_C','repair_C','turnover_C','construction_C','uptake_W','uptake_N','light_receipt_E','hydrated_demand_C','actual_demand_C','unpaid_C','connected_leaves','leaf_water_sum']}})
  assert ndays==512 and nhashes==12288
paired=[];epairs=[];envindex={(r['seed'],r['mode'],r['tick']):r for r in envrows}
for seed in [12011,4242,7301]:
 if not all((seed,m) in initials for m in [0,24]):continue
 a,b=initials[seed,0],initials[seed,24]
 assert a['fingerprint']==b['fingerprint'] and a['config']==b['config'] and a['environment']==b['environment'] and a['plants']==b['plants'],('initial pairing',seed)
 s0=next(s for s in summaries if (s['seed'],s['mode'])==(seed,0));s1=next(s for s in summaries if (s['seed'],s['mode'])==(seed,24))
 paired.append({'seed':seed,'initial_state_exact':True,'legacy':s0,'T1':s1,'living_tissue_difference':s1['living_tissue']-s0['living_tissue'],'paid_birth_difference':s1['paid_births']-s0['paid_births']})
 for tick in range(24,12289,24):
  a,b=envindex[seed,0,tick],envindex[seed,24,tick];epairs.append({'seed':seed,'tick':tick,**{k:b[k]-a[k] for k in a if k not in ['seed','mode','tick']}})
founder_pairs=[]
for row in plants:
 enddays=[d for d in dayplants if (d['seed'],d['mode'],d['id'])==(row['seed'],row['mode'],row['id']) and d['tick']>12096]
 row['final_world192_observed_hours']=min(192,row['endpoint_age'])
 row['final_world192_operating_C']=sum(d['operating_C'] for d in enddays)
 row['final_world192_construction_C']=sum(d['construction_C'] for d in enddays)
for pair in paired:
 for id in [0,1]:
  a=next(p for p in plants if (p['seed'],p['mode'],p['id'])==(pair['seed'],0,id));b=next(p for p in plants if (p['seed'],p['mode'],p['id'])==(pair['seed'],24,id))
  out={'seed':pair['seed'],'founder':id}
  for k in ['living','paid','paid_roots','leaves','paid_offspring','maturity_tick','death_tick','lifetime_fixed_C','lifetime_operating_C','lifetime_upkeep_respired_C','lifetime_stress_respired_C','lifetime_tip_respired_C','lifetime_repair_C','lifetime_construction_C','lifetime_uptake_W','lifetime_uptake_N','lifetime_light_E','reserve_deposited_C','reserve_refunded_C','reserve_released_C','final_mobile_C','final_world192_operating_C']:
   out['legacy_'+k]=a[k];out['T1_'+k]=b[k]
  founder_pairs.append(out)
lineage_events=[]
for p in plants:
 gene=next((b['genotype']['branch_seed'] for b in births if (b['seed'],b['mode'],b['id'])==(p['seed'],p['mode'],p['id'])),None)
 if p['generation']==0:gene=initials[p['seed'],p['mode']]['plants'][p['id']]['row']['genotype']['branch_seed']
 base={'seed':p['seed'],'mode':p['mode'],'id':p['id'],'parent':p['parent'],'generation':p['generation'],'inherited_branch_seed':gene}
 lineage_events.append({**base,'tick':p['birth_tick'],'event':'initial_founder' if p['generation']==0 else 'paid_birth'})
 for field,event in [('maturity_tick','paid_maturity32'),('death_tick','all_tissue_dead')]:
  if p[field] is not None:lineage_events.append({**base,'tick':p[field],'event':event})
 if p['survival_right_censored']:lineage_events.append({**base,'tick':12288,'event':'alive_at_fixed_endpoint_right_censored'})
lineage_events.sort(key=lambda r:(r['seed'],r['tick'],r['mode'],r['id'],r['event']))
checks=[json.loads(f.read_text()) for f in E.glob('verify-*.json')];assert all(v.get('pass') or v.get('available') is False for v in checks)
# Attempt records include each bounded slice exactly once; top-level launcher files duplicate last attempts.
rts=[json.loads(f.read_text()) for f in (E/'attempts').glob('*.runtime.json')]
matter_drift={r:max((abs(d[r+'_total']-flat_env(initials[d['seed'],d['mode']]['environment'])[r+'_total']) for d in envrows),default=0) for r in ['C','N','W']}
energy_daily=max((abs(d['energy_energy_error']) for d in envrows),default=0)
assert all(v<1e-9 for v in matter_drift.values()) and energy_daily<=1e-7
result={'complete_arms':len(summaries),'paired_seeds':len(paired),'summaries':summaries,'paired':paired,'plants':plants,'paired_founders':founder_pairs,'births':births,'guard_summary':{'daily_matter_max_abs_drift':matter_drift,'daily_reported_energy_max_abs_error':energy_daily,'hourly_world_max_error':max((s['max_world_error'] for s in summaries),default=0),'hourly_plant_max_error':max((s['max_plant_error'] for s in summaries),default=0),'unchanged_limits':{'C_N_W':1e-9,'per_plant':1e-9,'open_energy':1e-7}},'max_mobile_budget_closure':max(budget_errors,default=0),'verification_jobs':len(checks),'exact_reverse_restart_hours':sum(v.get('hours',0) for v in checks),'canonical_hours':sum(v.get('hours',0) for v in checks if v.get('canonical_nodes_and_field_exact')),'runtime':{'invocations':len(rts),'wall_seconds':sum(r['wall_seconds'] for r in rts),'peak_rss_bytes':max((r['peak_rss_bytes'] for r in rts),default=0),'minimum_headroom_bytes':min((r['minimum_headroom_bytes'] for r in rts),default=0),'timed_slices':sum(r['stop_reason']=='timeout' for r in rts),'other_stops':[r for r in rts if r['stop_reason'] not in [None,'timeout']]},'source_sha256':source,'legacy_birth_fingerprints_exact':golden_births,'no_individual_descendant_pairing':True,'hardware_GPU':'unavailable, not passed','Windows':'unavailable, not passed'}
(E/'analysis.json').write_text(json.dumps(result,indent=2)+'\n');csvout('lineage-events.csv',lineage_events);csvout('plants.csv',plants);csvout('paired-founders.csv',founder_pairs);csvout('plant-days.csv',dayplants);csvout('environment-days.csv',envrows);csvout('paired-environment-differences.csv',epairs)
print(json.dumps({'complete_arms':len(summaries),'paired_seeds':len(paired),'summary':[{'seed':s['seed'],'mode':s['mode'],'births':s['paid_births'],'living':s['living_plants_by_generation'],'gen3':s['generation3_births']} for s in summaries],'verification_jobs':len(checks),'max_mobile_budget_closure':result['max_mobile_budget_closure']},indent=2))
