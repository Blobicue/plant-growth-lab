"""Corroborate gate failure; no feedback policy or biological matrix executed."""
from pathlib import Path
import json,shutil,subprocess
P=Path(__file__).resolve().parent
plan=json.loads((P/'protocol.json').read_text())
for c in plan['cohorts']:
 name=f'relabel-verification-{c["seed"]}-{c["id"]}.json'; produced=P/'work/candidate30/evidence'/name
 if not produced.exists():subprocess.run(['python3',str(P/'run.py'),'candidate30','relabel_verify.gd',str(c['seed']),str(c['id'])],check=True)
 d=json.loads(produced.read_text());assert not d['error'];shutil.copy2(produced,P/'evidence'/name)
 for f in (P/'work/candidate30/evidence').glob(f'relabel-replay-{c["seed"]}-{c["id"]}-*-48.bin'):shutil.copy2(f,P/'evidence'/f.name)
 print(json.dumps({'seed':c['seed'],'id':c['id'],'verified':True}),flush=True)
