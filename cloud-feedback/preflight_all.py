"""Fixed gate2 only: all11 origins; no treatment or768h biological cases."""
from pathlib import Path
import hashlib,json,shutil,subprocess
P=Path(__file__).resolve().parent; R=P.parent
plan=json.loads((P/'protocol.json').read_text())
assert hashlib.sha256((P/'PROTOCOL.txt').read_bytes()).hexdigest()==plan['registration_sha256']
for c in plan['cohorts']:
 assert hashlib.sha256((R/c['file']).read_bytes()).hexdigest()==c['sha256']
 name=f'relabel-{c["seed"]}-{c["id"]}.json'; produced=P/'work/candidate30/evidence'/name
 if not produced.exists():subprocess.run(['python3',str(P/'run.py'),'candidate30','relabel_preflight.gd',str(c['seed']),str(c['id'])],check=True)
 d=json.loads(produced.read_text());assert d['origin_fingerprint']==c['fingerprint'] and d['initial_canonical_state_exact']
 assert not d['baseline_error'] and not d['relabelled_error']
 shutil.copy2(produced,P/'evidence'/name)
 print(json.dumps({k:d[k] for k in ['seed','id','gate_pass']}),flush=True)
