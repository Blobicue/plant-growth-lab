"""Verify evidence-only scope, arithmetic source hashes and preserved checkpoints."""
from pathlib import Path
import hashlib,json,subprocess,time
P=Path(__file__).resolve().parent;R=P.parent;E=P/'evidence';a=json.loads((E/'analysis.json').read_text())
for rel,h in a['source_sha256'].items():assert hashlib.sha256((R/rel).read_bytes()).hexdigest()==h,rel
reg=json.loads((E/'next-experiment-registration.json').read_text());assert hashlib.sha256((P/'NEXT-EXPERIMENT.txt').read_bytes()).hexdigest()==reg['protocol_sha256']
branches={'experiment/deterministic-reductions':'5d3a8efaf70efaefefaa19329e8d069dfe9b54ee','migration/linux-cpu':'701d108642fe61cb051d9360d81eaf40258b30de','diagnostic/gen2-survival-causality':'7cb5a51e30171c9770f52d47810d8da5b8b1b5b9','design/local-nitrogen-contract':'93aac33022d3f9ea69490ea04d3732d0a74f83dd','experiment/local-construction-feedback':'db7f2d1aae27961ffefb5734de45b29bad4af449','experiment/synchronous-local-transport':'5456dfe73d92c33c3cabf716fbaca0e8c6f2f0fa'}
for branch,commit in branches.items():assert subprocess.check_output(['git','rev-parse',branch],cwd=R,text=True).strip()==commit
assert not subprocess.check_output(['git','diff',a['basis_commit'],'--name-only','--',':!cloud-budget'],cwd=R,text=True).strip()
subprocess.run(['python3',str(R/'verify_snapshot.py')],cwd=R,check=True)
# Reproducibility is deterministic evidence arithmetic, not a biological rerun.
files=['analysis.json','cohort-budgets.csv','period-budgets.csv','front-events.json','early-root-fronts.csv'];before={f:hashlib.sha256((E/f).read_bytes()).hexdigest() for f in files}
t=time.monotonic();r=subprocess.run(['python3',str(P/'analyze.py')],cwd=R,check=True,capture_output=True,text=True);seconds=time.monotonic()-t
assert all(hashlib.sha256((E/f).read_bytes()).hexdigest()==h for f,h in before.items())
result={'pass':True,'basis_commit':a['basis_commit'],'preserved_branches':branches,'original_payloads_verified':189,'only_changed_directory':'cloud-budget','source_hashes_verified':len(a['source_sha256']),'deterministic_analysis_outputs_verified':5,'analysis_wall_seconds':seconds,'new_engine_runs':0,'new_biological_instrumentation':False,'simulation_or_biology_source_changes':False,'F1_executed':False,'push_merge_deploy_promotion':False}
(E/'audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
