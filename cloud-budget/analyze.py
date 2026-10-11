"""Read-only causal budget assessment of fixed, committed R1/T1 histories."""
from pathlib import Path
from collections import Counter
import csv,hashlib,json,subprocess
R=Path(__file__).resolve().parent.parent;P=R/'cloud-budget';E=P/'evidence';E.mkdir(exist_ok=True)
A=json.loads((R/'cloud-reductions/evidence/analysis.json').read_text());rows=[];periods=[];fronts=[];early_fronts=[];sources={}
def digest(f):sources[str(f.relative_to(R))]=hashlib.sha256(f.read_bytes()).hexdigest()
for c in A['cases']:
 f=R/f'cloud-reductions/evidence/trial-{c["seed"]}-{c["id"]}-{c["mode"]}.json';digest(f);d=json.loads(f.read_text());b=c['budget'];start,end=d['daily'][0],d['daily'][-1]
 def stock(r):return sum(r['pools'][k] for k in ['c','disconnected_c'])+sum(r['reserve'][k]['c'] for k in ['balance','released','disposed'])
 def sum_budget(lo,hi):
  z=Counter()
  for day in d['daily'][1:]:
   if lo<day['age']<=hi:z.update(day['budget'])
  return dict(z)
 assert b['unpaid_C']==0
 assert all(x['data']['kind']!='leaf' for x in d['events'] if x['event'].startswith('built_node_'))
 total_resp=end['totals']['respired_c']-start['totals']['respired_c'];repair_loss=total_resp-b['direct_respired_C'] # no new leaf packets: no construction yield loss
 upkeep=b['turnover_C']*.65/.35;tip=b['direct_respired_C']-upkeep
 solid_repaired=b['repair_C']-repair_loss
 assert abs(solid_repaired-b['turnover_C'])<1e-10
 assert abs(tip-768*2*.00001)<1e-10 # two alive tips, no stress-recovery respiration
 assert abs(stock(end)-stock(start)-(b['operating_C']-b['construction_C']))<1e-9
 row={k:c[k] for k in ['seed','id','generation','mode','paid_roots','living_nodes','leaf_packets']}
 row.update({k:b[k] for k in ['fixed_C','direct_respired_C','repair_C','turnover_C','construction_C','operating_C','uptake_W','uptake_N','light_receipt_E','actual_demand_C','hydrated_demand_C','unshaded_hydrated_C','unpaid_C','refused_C','refused_N','refused_W']})
 cost=b['direct_respired_C']+b['repair_C'];H=b['hydrated_demand_C'];F=b['fixed_C'];G=b['construction_C']
 row.update(upkeep_respiration_C=upkeep,tip_respiration_C=tip,repair_yield_respiration_C=repair_loss,total_respired_C=total_resp,repair_leaf_input_C=5*repair_loss,repair_other_input_C=b['repair_C']-5*repair_loss,operating_breakeven_fixation_C=cost,operating_deficit_C=max(0,cost-F),extra_fixation_pct=max(0,cost/F-1)*100,growth_inclusive_breakeven_C=cost+G,net_mobile_C=F-cost-G,initial_mobile_C=stock(start),final_mobile_C=stock(end),atmospheric_claim_gap_C=b['actual_demand_C']-F,local_water_demand_gap_C=H-b['actual_demand_C'],hydrated_fraction=F/H,hydrated_fraction_needed=cost/H,hydrated_fixed_cost_margin_C=H-cost,mean_leaf_water=b['leaf_water_sum']/b['connected_leaves'],carbon_closure_abs=abs(stock(end)-stock(start)-(F-cost-G)))
 rows.append(row)
 for lo,hi in [(0,96),(96,768),(0,192),(192,384),(384,576),(576,768)]:
  z=sum_budget(lo,hi);periods.append({'seed':c['seed'],'id':c['id'],'mode':c['mode'],'start_age':lo,'end_age':hi,**{k:z[k] for k in ['fixed_C','direct_respired_C','repair_C','construction_C','operating_C','uptake_W','uptake_N','hydrated_demand_C','light_receipt_E']}})
 for e in d['events']:
  if not e['event'].startswith(('refusal','cancel')):continue
  q=e['data'];kind=q.get('kind',q.get('before',{}).get('kind'));n=q['local'];mass={'root':.0018,'stem':.0024,'leaf':.0012}[kind];costs={'c':mass/(.8 if kind=='leaf' else 1),'n':mass*{'root':.06,'stem':.024,'leaf':.11}[kind],'w':mass*.3}
  short=[k for k in costs if n[k]<costs[k]]
  fronts.append({'seed':c['seed'],'id':c['id'],'mode':c['mode'],'age':e['age'],'event':e['event'],'kind':kind,'record_type':'payment_refusal' if e['event'].startswith('refusal') else 'expiry_after_new_hour_maintenance','short_now':short,'stored_previous_blocked':q.get('before',{}).get('blocked'),'local':{k:n[k] for k in costs},'cost':costs,'whole_connected_pool':q['pools'],'whole_pool_can_pay':all(q['pools'][k]>=costs[k] for k in costs)})
 for h in d['hourly']:
  if h['age'] not in [4,16]:continue
  for q in h['fronts']:
   if q['kind']!='root':continue
   early_fronts.append({'seed':c['seed'],'id':c['id'],'mode':c['mode'],'age':h['age'],'local_C':q['C'],'local_N':q['N'],'local_W':q['W'],'N_only':q['C']>=.0018 and q['N']<.000108 and q['W']>=.00054,'whole_mobile_N':h['pools']['n'],'root_count':h['roots']})
# Preserve source identity and explain lineage, not infer rates from descendants as independent samples.
birth_audit=[]
for seed in [12011,4242,7301]:
 f=R/f'cloud-diagnostics/evidence/observer-{seed}-12288.json';digest(f)
 for b in json.loads(f.read_text())['births']:
  ns=b['nodes'];assert len(ns)==7 and all(n['birth']==b['tick'] and n['stress']==0 for n in ns)
  assert all(n[k]==0 for n in ns[1:] for k in ['c','n','w'])
  assert abs(ns[0]['c']-.0363)<1e-15 and ns[0]['n']==.0012488 and ns[0]['w']==.03658
  birth_audit.append({'seed':seed,'id':b['plant'],'newborn_never_experienced_legacy_transport':True,'age_zero_identical_collar_CNW':[ns[0][k] for k in ['c','n','w']]})
assert len(birth_audit)==11
for f in [R/'cloud-reductions/scripts/trial.gd',R/'cloud-diagnostics/scripts/observer_plant.gd',R/'cloud-reductions/evidence/reduction-source.diff',R/'cloud-reductions/protocol.json',R/'cloud-reductions/evidence/analysis.json']:digest(f)
for f in [R/'cloud-reductions/work/candidate30'/x for x in ['legacy/model.gd','base_plant.gd','world.gd','plant.gd','canopy.gd','transport.gd']]:digest(f)
for name,data in [('cohort-budgets',rows),('period-budgets',periods),('early-root-fronts',early_fronts)]:
 with (E/(name+'.csv')).open('w') as f:
  w=csv.DictWriter(f,fieldnames=list(data[0]),lineterminator='\n');w.writeheader();w.writerows(data)
(E/'front-events.json').write_text(json.dumps(fronts,indent=2)+'\n')
neg=[r for r in rows if r['mode']==24 and r['operating_C']<0]
assert [(r['seed'],r['id']) for r in neg]==[(12011,4),(4242,4),(4242,5),(7301,3),(7301,4)]
assert all((r['operating_C']<0)==(next(x for x in rows if (x['seed'],x['id'],x['mode'])==(r['seed'],r['id'],48))['operating_C']<0) for r in rows if r['mode']==24)
assert sum(v['mode']==24 and v['age']==16 and v['N_only'] for v in early_fronts)==11
result={'basis_commit':'5d3a8efaf70efaefefaa19329e8d069dfe9b54ee','new_engine_runs':0,'birth_audit':birth_audit,'negative_T1_cohorts':[[r['seed'],r['id']] for r in neg],'rows':rows,'periods':periods,'source_sha256':sources,'assertions':{'all33_no_unpaid_upkeep':True,'all33_no_new_leaf_packets':True,'all33_repair_restores_all_turnover':True,'all33_direct_respiration_equals_upkeep_plus_two_tip_costs':True,'all33_mobile_budget_closes':True,'all11_T1_fourth_root_N_only_at_age16':True,'24_vs_48_budget_signs_agree':True},'limits':'Event records retain first occurrence of each label, not all refusals; expiry blocked is previous hour, local is current hour. Diagnostic hydrated envelope retains observed geometry/light and is not a feasible intervention or an unshaded counterfactual.'}
(E/'analysis.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'negative_T1_cohorts':result['negative_T1_cohorts'],'checks':result['assertions'],'new_engine_runs':0}))
