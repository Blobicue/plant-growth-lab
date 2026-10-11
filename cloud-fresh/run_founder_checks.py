"""Run the three fixed always-available founder canonical correctness replays."""
from pathlib import Path
import json,subprocess,shutil,sys
P=Path(__file__).resolve().parent;E=P/'evidence';W=P/'work/model/evidence'
selected=list(map(int,sys.argv[1:])) if len(sys.argv)>1 else [12011,4242,7301]
assert all(seed in [12011,4242,7301] for seed in selected)
for seed in selected:
 assert json.loads((W/f'f1-{seed}-24/complete.json').read_text())['complete']
 name=f'verify-{seed}-24-founder_canonical.json';tag=f'model-verify_f1-{seed}-24-founder_canonical'
 if not (W/name).exists():
  n=len(list((E/'attempts').glob(tag+'-*.runtime.json')))+1
  rc=subprocess.run(['python3',str(P/'run.py'),'--timeout','300','model','verify_f1.gd',str(seed),'24','founder_canonical']).returncode
  for suffix in ['log','runtime.json']:shutil.copy2(E/(tag+'.'+suffix),E/'attempts'/f'{tag}-{n:02d}.{suffix}')
  assert rc==0,(seed,'founder canonical check failed')
 d=json.loads((W/name).read_text());assert d['pass'] and d['hours']==96 and d['canonical_nodes_and_field_exact'];shutil.copy2(W/name,E/name)
 print('VERIFIED',name,flush=True)
