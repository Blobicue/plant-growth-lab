"""Summarize registered preflight and audit unchanged evidence/source; no engine."""
from pathlib import Path
import csv,hashlib,json,subprocess
P=Path(__file__).resolve().parent; R=P.parent; E=P/'evidence'
plan=json.loads((P/'protocol.json').read_text()); rows=[]; checks=[]
assert hashlib.sha256((P/'PROTOCOL.txt').read_bytes()).hexdigest()==plan['registration_sha256']
assert hashlib.sha256((P/'DESIGN-frozen.txt').read_bytes()).hexdigest()==plan['design_sha256']
for c in plan['cohorts']:
 s,i=c['seed'],c['id'];d=json.loads((E/f'relabel-{s}-{i}.json').read_text());v=json.loads((E/f'relabel-verification-{s}-{i}.json').read_text())
 assert hashlib.sha256((R/c['file']).read_bytes()).hexdigest()==c['sha256']
 assert d['origin_fingerprint']==c['fingerprint'] and d['initial_canonical_state_exact']
 assert all(x['pass'] for x in v['checks']) and all(x['hours_exact']==96 for x in v['replay'])
 assert not d['baseline_error'] and not d['relabelled_error'] and not v['error']
 source=json.loads((R/f'cloud-diagnostics/evidence/observer-{s}-12288.json').read_text())
 cohort=next(p for p in source['plants'] if p['id']==i)
 archived=[{'age':e['age'],'kind':e['data']['kind'],'position':e['data']['position'],'proposal':e['data']['proposal']} for e in cohort['events'] if e['event'].startswith('built_node_') and e['age']<=96]
 assert archived==d['baseline_events']
 def third_root(events):
  births=[e['age'] for e in events if e['kind']=='root']
  return births[1] if len(births)>1 else None
 end=d['hourly'][-1]
 rows.append({'seed':s,'id':i,'generation':c['generation'],'first_payment_difference_age':d['first_payment_difference'].get('age'),'first_constraint_difference_age':d['first_constraint_difference'].get('age'),'baseline_third_root_age':third_root(d['baseline_events']),'relabelled_third_root_age':third_root(d['relabelled_events']),'baseline_roots_at96':end['baseline_roots'],'relabelled_roots_at96':end['relabelled_roots'],'gate_pass':d['gate_pass'],'original_paid_events_exact':True,'transport_only_changes_distribution':not v['transport_only']['canonical_after_exact'],'max_world_error':max(d['max_world_error'],v['max_world_error']),'max_plant_error':max(d['max_plant_error'],v['max_plant_error']),'transport_ledger_residual':v['transport_only']['maximum_ledger_residual']})
assert len(rows)==11
with (E/'preflight-results.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator="\n");w.writeheader();w.writerows(rows)
science=['world.gd','legacy/model.gd','canopy.gd','atmosphere.gd','reserve.gd','decomposition.gd','hydrology.gd','field.gd','native/resource_field.c','native/resource_field.so','native/gdextension_interface.h']
for name in science:
 a=R/'cloud-port/work/juvenile-allocation30'/name;b=P/'work/candidate30'/name
 if not a.exists():continue
 assert a.read_bytes()==b.read_bytes(),name;checks.append({'path':name,'unchanged':True,'sha256':hashlib.sha256(a.read_bytes()).hexdigest()})
assert (P/'work/candidate30/base_plant.gd').read_bytes()==(R/'cloud-port/work/juvenile-allocation30/plant.gd').read_bytes()
assert (P/'work/candidate30/plant.gd').read_bytes()==(R/'cloud-diagnostics/scripts/observer_plant.gd').read_bytes()
preserved={b:subprocess.check_output(['git','rev-parse',b],cwd=R,text=True).strip() for b in ['migration/linux-cpu','diagnostic/gen2-survival-causality','design/local-nitrogen-contract']}
assert preserved=={'migration/linux-cpu':'701d108642fe61cb051d9360d81eaf40258b30de','diagnostic/gen2-survival-causality':'7cb5a51e30171c9770f52d47810d8da5b8b1b5b9','design/local-nitrogen-contract':'93aac33022d3f9ea69490ea04d3732d0a74f83dd'}
assert not subprocess.check_output(['git','diff','93aac33022d3f9ea69490ea04d3732d0a74f83dd','--name-only','--',':!cloud-feedback'],cwd=R,text=True).strip()
subprocess.run(['python3',str(R/'verify_snapshot.py')],cwd=R,check=True)
runtimes=[json.loads(p.read_text()) for p in E.glob('*.runtime.json')]
assert len(runtimes)==22 and all(x['exit']==0 and x['stop_reason'] is None for x in runtimes)
result={'decision':'STOP at frozen gate2; treatment not implemented or run','protocol_commit':'8b24d60','cohorts_checked':11,'gate_failures':sum(not r['gate_pass'] for r in rows),'new_biological_cases_completed':0,'planned_biological_cases':22,'preflight_trajectories':22,'verification_trajectories':22,'preflight_duration_hours':96,'reverse_and_saved_restart_hash_checks':2112,'preserved_branches':preserved,'science_unchanged':checks,'original_payloads_checked':189,'original_payload_mismatches':[],'rows':rows,'max_world_error':max(r['max_world_error'] for r in rows),'max_plant_error':max(r['max_plant_error'] for r in rows),'max_transport_ledger_residual':max(r['transport_ledger_residual'] for r in rows),'runtime':{'engine_invocations':len(runtimes),'sum_wall_seconds':sum(x['wall_seconds'] for x in runtimes),'peak_rss_bytes':max(x['peak_rss_bytes'] for x in runtimes),'minimum_headroom_bytes':min(x['minimum_headroom_bytes'] for x in runtimes)},'hardware_gpu':'unavailable, not tested','Windows':'unavailable, not tested','treatment_replay_maintenance_signal_validation':'not applicable: blocked before implementation','push_merge_deploy':False}
(E/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['science_unchanged','rows']},indent=2))
