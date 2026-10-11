"""Run CPU validation serially, retaining failures and all raw evidence."""
import subprocess,json,shutil,time
from pathlib import Path
P=Path(__file__).resolve().parent
jobs=[('juvenile-allocation30','tests.gd',[]),('juvenile-allocation30','cpu_checks.gd',[])]
for project in ['shared-atmosphere27','juvenile-allocation30']:
 for seed in [12011,4242,7301]:
  for mode in ([0,1] if project=='shared-atmosphere27' else [1]):
   jobs.append((project,'golden_cpu.gd',[str(seed),str(mode),'8160']))
  jobs.append((project,'golden_cpu.gd',[str(seed),'1','960','reverse']))
results=[]
for project,script,args in jobs:
 print('START',project,script,args,flush=True)
 r=subprocess.run(['python3',str(P/'run.py'),project,script,*args])
 results.append({'project':project,'script':script,'args':args,'exit':r.returncode})
 for file in (P/'work'/project/'evidence').glob('cloud-*'):
  shutil.copy2(file,P/'evidence'/(project+'-'+file.name))
 for name in ['model-tests.json']:
  shutil.copy2(P/'work'/project/'evidence'/name,P/'evidence'/(project+'-'+name))
 (P/'evidence/validation-jobs.json').write_text(json.dumps(results,indent=2))
 print('FINISHED',r.returncode,flush=True)

raise SystemExit(1 if any(row["exit"] for row in results) else 0)
