"""Run only missing passive trajectories, with exact original checkpoint gates."""
from pathlib import Path
import subprocess,shutil,json
P=Path(__file__).resolve().parent;W=P/'work/candidate30/evidence'
for seed in [12011,4242,7301]:
 f=W/f'observer-{seed}-12288.json'
 if f.exists():
  d=json.loads(f.read_text());assert d['horizon']==12288 and all(x['exact']for x in d['fingerprints'])and not d['error']and not d['censored'];print('Completed; preserving',seed,flush=True)
 else:subprocess.run(['python3',str(P/'run.py'),'candidate30','observe.gd',str(seed),'12288','--timeout','900'],check=True)
 for f in W.glob('*'):
  if f.name.startswith(('birth-','observations-','observer-')):shutil.copy2(f,P/'evidence'/f.name)
