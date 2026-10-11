"""Resume28 unfinished trials; certify/reuse5 historical trajectories without replacement."""
from pathlib import Path
import hashlib,json,subprocess,shutil
P=Path(__file__).resolve().parent;R=P.parent;W=P/'work/candidate30/evidence';E=P/'evidence'
plan=json.loads((P/'protocol.json').read_text());assert hashlib.sha256((P/'PROTOCOL.txt').read_bytes()).hexdigest()==plan['registration_sha256']
assert json.loads((E/'reduction-checks.json').read_text())['pass'] and json.loads((E/'boundary-checks.json').read_text())['pass']
reuse={(c['seed'],c['id'],c['mode']):c for c in plan['reuse_candidates']}
provenance=[]
def invoke(script,c,mode,name):
 f=W/name
 if not f.exists():
  print('START',name,flush=True);subprocess.run(['python3',str(P/'run.py'),'candidate30',script,str(c['seed']),str(c['id']),str(mode)],check=True)
 d=json.loads(f.read_text());assert d.get('pass',not d.get('error') and not d.get('censored'))
 shutil.copy2(f,E/name)
 for b in W.glob(name.removesuffix('.json')+'-*.bin'):shutil.copy2(b,E/b.name)
 print('VERIFIED' if name.startswith('verify') else 'COMPLETE',name,flush=True)
 return d
for c in plan['cohorts']:
 assert hashlib.sha256((R/c['file']).read_bytes()).hexdigest()==c['sha256']
 for mode in [0,24,48]:
  name=f'trial-{c["seed"]}-{c["id"]}-{mode}.json';verification=f'verify-{c["seed"]}-{c["id"]}-{mode}.json';key=c['seed'],c['id'],mode
  if key in reuse:
   previous=reuse[key];assert hashlib.sha256((R/previous['source']).read_bytes()).hexdigest()==previous['sha256']
   assert (W/name).read_bytes()==(R/previous['source']).read_bytes()
   v=invoke('verify_trial.gd',c,mode,verification);assert v['reverse_saved_replay_hours_exact']==768
   shutil.copy2(R/previous['source'],E/name)
   for b in (R/'cloud-transport/evidence').glob(name.removesuffix('.json')+'-*.bin'):shutil.copy2(b,E/b.name)
   provenance.append({**previous,'R1_hourly_hashes_exact':768,'R1_verification':verification,'reused_without_replacement':True})
   (E/'reuse-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
   print('REUSED CERTIFIED',name,flush=True)
  else:
   d=invoke('trial.gd',c,mode,name);assert d['origin_fingerprint']==c['fingerprint'] and len(d['hashes'])==768
   if mode in [0,24]:invoke('verify_trial.gd',c,mode,verification)
 print('COHORT COMPLETE',c['seed'],c['id'],flush=True)
print('ALL11 COHORTS COMPLETE; no promotion',flush=True)
