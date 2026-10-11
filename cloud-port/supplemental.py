from pathlib import Path
import json,subprocess,shutil
P=Path(__file__).resolve().parent
jobs=[('shared-atmosphere27','fixture.gd',[]),('juvenile-allocation30','fixture.gd',[]),('shared-atmosphere27','json_roundtrip.gd',[]),('juvenile-allocation30','json_roundtrip.gd',[]),('juvenile-allocation30','ui_checks.gd',['--gui'])]
for project,script,args in jobs:
 subprocess.run(['python3',str(P/'run.py'),project,script,*args],check=True)
 for f in (P/'work'/project/'evidence').glob('*'):
  if f.name.startswith('cloud-') or f.name=='fixture-tests.json':shutil.copy2(f,P/'evidence'/(project+'-'+f.name))
