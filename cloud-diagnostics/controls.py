"""Execute the fixed preregistered matrix serially; preserve completed evidence."""
from pathlib import Path
import json,subprocess,shutil,hashlib,sys
P=Path(__file__).resolve().parent;W=P/'work/candidate30/evidence'
plan=json.loads((P/(sys.argv[1] if len(sys.argv)>1 else 'control-plan.json')).read_text());assert hashlib.sha256((P/plan.get('registration_file','CONTROL-PLAN.txt')).read_bytes()).hexdigest()==plan['preregistration_sha256']
a=json.loads((P/'evidence/passive-analysis.json').read_text());assert len(a['checks'])==3 and all(c['physical_checkpoints_exact'] and not c['error'] and not c['censored'] for c in a['checks'])
for c in plan['cases']:
 args=[str(c[k])for k in ['seed','id','arm','duration']];name='control-'+'-'.join(args)+'.json';f=W/name
 if f.exists():
  d=json.loads(f.read_text());assert d['origin_exact'] and not d['error'] and not d['censored'];print('Completed; skip',name,flush=True)
 else:
  print('START',name,flush=True);subprocess.run(['python3',str(P/'run.py'),'candidate30','control.gd',*args],check=True)
 shutil.copy2(f,P/'evidence'/name);print('COMPLETE',name,flush=True)
