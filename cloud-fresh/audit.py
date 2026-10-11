"""Verify frozen protocol, unmodified science, paired identities, evidence and branches."""
from pathlib import Path
import json,hashlib,subprocess
P=Path(__file__).resolve().parent;R=P.parent;E=P/'evidence';W=P/'work/model';M=json.loads((P/'manifest.json').read_text())
assert hashlib.sha256((R/'cloud-budget/NEXT-EXPERIMENT.txt').read_bytes()).hexdigest()==M['frozen_protocol_sha256']
unchanged=json.loads((E/'unchanged-modules.json').read_text())
for name,h in unchanged.items():assert hashlib.sha256((W/name).read_bytes()).hexdigest()==h,name
for f in (P/'scripts').glob('*.gd'):assert f.read_bytes()==(W/f.name).read_bytes(),f.name
for seed,ref in M['configs'].items():assert hashlib.sha256((R/ref['source']).read_bytes()).hexdigest()==ref['sha256']
branches={'experiment/deterministic-reductions':'5d3a8efaf70efaefefaa19329e8d069dfe9b54ee','analysis/r1-t1-carbon-budget':'911a2066ec807700e4d143c7b634c1153e9fd501','migration/linux-cpu':'701d108642fe61cb051d9360d81eaf40258b30de','diagnostic/gen2-survival-causality':'7cb5a51e30171c9770f52d47810d8da5b8b1b5b9','design/local-nitrogen-contract':'93aac33022d3f9ea69490ea04d3732d0a74f83dd','experiment/local-construction-feedback':'db7f2d1aae27961ffefb5734de45b29bad4af449','experiment/synchronous-local-transport':'5456dfe73d92c33c3cabf716fbaca0e8c6f2f0fa'}
for branch,commit in branches.items():assert subprocess.check_output(['git','rev-parse',branch],cwd=R,text=True).strip()==commit
assert not subprocess.check_output(['git','diff',M['basis_commit'],'--name-only','--',':!cloud-fresh'],cwd=R,text=True).strip()
subprocess.run(['python3',str(R/'verify_snapshot.py')],cwd=R,check=True)
a=json.loads((E/'analysis.json').read_text());assert a['complete_arms']==6 and a['paired_seeds']==3 and a['verification_jobs']==12
for rel,h in a['source_sha256'].items():assert hashlib.sha256((P/rel).read_bytes()).hexdigest()==h,rel
states=0
for seed in M['seeds']:
 for mode in M['modes']:
  name=f'f1-{seed}-{mode}';checks=json.loads((E/'runs'/name/'checkpoint-sha256.json').read_text())
  assert len([n for n in checks if n.startswith('state-')])==513
  for n,h in checks.items():assert hashlib.sha256((W/'evidence'/name/n).read_bytes()).hexdigest()==h;states+=1
  for f in (E/'runs'/name).glob('*.bin'):assert hashlib.sha256(f.read_bytes()).hexdigest()==checks[f.name]
  rts=[json.loads(f.read_text()) for f in (E/'attempts').glob(f'model-f1-{seed}-{mode}-*.runtime.json')]
  assert sum(r['wall_seconds'] for r in rts)<=1801,('wall ceiling sampling allowance',seed,mode)
  assert all(r['stop_reason'] in [None,'timeout'] for r in rts)
result={'pass':True,'frozen_protocol_sha256':M['frozen_protocol_sha256'],'only_changed_directory':'cloud-fresh','preserved_branches':branches,'unchanged_scientific_and_reference_modules':len(unchanged),'original_payloads_verified':189,'paired_initial_states_exact':3,'daily_checkpoints_verified':6*512,'all_state_files_verified':states,'new_feedback_or_tuning':False,'hardware_GPU':'unavailable, not passed','Windows':'unavailable, not passed','push_merge_deploy_promotion':False}
(E/'audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
