"""Serial registered matrix plus fixed numerical/replay checks; resume without duplicates."""
from pathlib import Path
import hashlib,json,subprocess,shutil
P=Path(__file__).resolve().parent;R=P.parent;W=P/'work/candidate30/evidence';E=P/'evidence'
if (E/'STOP.json').exists():raise SystemExit('Registered matrix is STOPPED; see evidence/STOP.json. Do not silently resume.')
plan=json.loads((P/'protocol.json').read_text());assert hashlib.sha256((P/'PROTOCOL.txt').read_bytes()).hexdigest()==plan['registration_sha256']
assert json.loads((E/'kernel-checks.json').read_text())['pass'] and json.loads((E/'birth-preflight.json').read_text())['pass']
def run(script,c,mode,name):
 path=W/name
 if path.exists():
  result=json.loads(path.read_text());assert result.get('pass',not result.get('error') and not result.get('censored'))
  print('PRESERVED',name,flush=True)
 else:
  print('START',name,flush=True);subprocess.run(['python3',str(P/'run.py'),'candidate30',script,str(c['seed']),str(c['id']),str(mode)],check=True)
 result=json.loads(path.read_text());shutil.copy2(path,E/name)
 for f in W.glob(name.removesuffix('.json')+'-*.bin'):shutil.copy2(f,E/f.name)
 print('COMPLETE',name,flush=True)
 return result
for c in plan['cohorts']:
 assert hashlib.sha256((R/c['file']).read_bytes()).hexdigest()==c['sha256']
 for mode in [0,24,48]:
  d=run('trial.gd',c,mode,f'trial-{c["seed"]}-{c["id"]}-{mode}.json')
  assert d['origin_fingerprint']==c['fingerprint'] and len(d['hashes'])==768
  if mode in [0,24]:run('verify_trial.gd',c,mode,f'verify-{c["seed"]}-{c["id"]}-{mode}.json')
 print('COHORT COMPLETE',c['seed'],c['id'],flush=True)
