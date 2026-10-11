"""Finalize the complete diagnostic evidence without changing registrations or physics."""
from pathlib import Path
import json,csv,subprocess,datetime,fcntl,os
P=Path(__file__).resolve().parent;E=P/'evidence'
subprocess.run(['python3',str(P/'analyze_controls.py')],check=True,stdout=subprocess.DEVNULL)
a=json.loads((E/'passive-analysis.json').read_text());c=json.loads((E/'control-analysis.json').read_text())
assert c['completed']==24 and not c['pending'];assert len(a['checks'])==3
assert all(x['origin_exact']and x['healthy']and all(z['exact']for z in x['baseline_known_hashes'])for x in c['cases'])
assert all(x['physical_checkpoints_exact']and not x['error']and not x['censored']for x in a['checks'])
rt=[{'source':f.name,**json.loads(f.read_text())}for f in E.glob('*.runtime.json')]
assert all(x['exit']==0 and not x['stop_reason']for x in rt)
comparisons=[]
for seed,pid in [(12011,3),(4242,4),(4242,5),(4242,6),(7301,3),(7301,4)]:
 arms={x['arm']:x for x in c['cases']if x['seed']==seed and x['id']==pid}
 assert set(arms)=={0,1,2} and len({r['origin_fingerprint']for r in arms.values()})==1
 comparisons.append({'seed':seed,'gen2_id':pid,'duration':2040,'baseline':{k:arms[0][k]for k in ['paid_nodes','living_nodes','paid_roots']},'other_N_off':{k:arms[1][k]for k in ['paid_nodes','living_nodes','paid_roots']},'other_W_off':{k:arms[2][k]for k in ['paid_nodes','living_nodes','paid_roots']},'N_off_death_age_unchanged':arms[0]['all_dead']['age']==arms[1]['all_dead']['age'],'W_off_maturity':arms[2]['maturity'],'W_off_target_offspring':arms[2]['new_target_offspring']})
with (E/'control-results.csv').open('w',newline='')as f:
 keys=['seed','id','generation','arm','duration','paid_nodes','living_nodes','paid_roots','connected_roots','birth_soil_N','birth_other_plant_mobile_N','carbon_stock_closure_max_abs'];w=csv.DictWriter(f,fieldnames=keys+['uptake_N','uptake_W','fixed_C','direct_respired_C','repair_C','operating_C','death_age']);w.writeheader()
 for r in c['cases']:w.writerow({**{k:r[k]for k in keys},**{k:r['budget'][k]for k in ['uptake_N','uptake_W','fixed_C','direct_respired_C','repair_C','operating_C']},'death_age':r['all_dead']['age']if r['all_dead']else ''})
with (E/'ordinary-cohorts.csv').open('w',newline='')as f:
 keys=['seed','id','generation','parent','birth_tick','birth_soil_N','birth_soil_W','end_paid_nodes','end_living_nodes','carbon_stock_closure_max_abs'];w=csv.DictWriter(f,fieldnames=keys+['first_unpaid_age','death_tick']);w.writeheader()
 for r in a['cohorts']:w.writerow({**{k:r[k]for k in keys},'first_unpaid_age':r['first_unpaid']['age']if r['first_unpaid']else '', 'death_tick':r['all_dead']['tick']if r['all_dead']else ''})
summary={'parent_commit':'701d108642fe61cb051d9360d81eaf40258b30de','branch':'diagnostic/gen2-survival-causality','primary_preregistration_commit':'96a600c','followup_preregistration_commit':'5c0e7e0','passive_trajectories':3,'passive_exact_checkpoints':21,'saved_descendant_births':11,'primary_control_cases':15,'separately_registered_followup_cases':9,'matched_control_origins_exact':24,'unchanged_controls_known_hash_checks':sum(len(x['baseline_known_hashes'])for x in c['cases']),'all_runs_healthy':True,'gen2_comparisons':comparisons,'max_passive_carbon_stock_closure':max(x['carbon_stock_closure_max_abs']for x in a['cohorts']),'max_control_carbon_stock_closure':max(x['carbon_stock_closure_max_abs']for x in c['cases']),'max_passive_error':max(x['max_error']for x in a['checks']),'max_control_error':max(x['max_error']for x in c['cases']),'max_control_plant_error':max(x['max_plant_error']for x in c['cases']),'total_engine_wall_seconds':sum(x['wall_seconds']for x in rt),'peak_engine_rss_bytes':max(x['peak_rss_bytes']for x in rt),'minimum_effective_headroom_bytes':min(x['minimum_headroom_bytes']for x in rt),'production_model_correction':False,'promoted':False,'publication_performed':False,'unavailable':['hardware GPU','Windows runtime and packages'],'runtimes':[{k:x[k]for k in ['source','wall_seconds','peak_rss_bytes','minimum_headroom_bytes','exit','stop_reason']}for x in rt]}
(E/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps({k:v for k,v in summary.items()if k!='runtimes'},indent=2))
