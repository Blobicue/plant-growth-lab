from pathlib import Path
import subprocess,time,json,datetime
from preflight import require_headroom,source_digest
r=Path(__file__).resolve().parent
engine=r.parent.parent/'elemental-voxel-lab/artifacts/godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
for seed in [12011,4242,7301]:
 for mode in [4,5,6]:
  while not (r.parent/'seedling-diagnostics28/evidence'/f'run-{seed}.json').exists() or not json.loads((r.parent/'seedling-diagnostics28/evidence'/f'run-{seed}.json').read_text()).get('complete'):time.sleep(60)
  while True:
   try:require_headroom(f'diagnose-{seed}-{mode}');break
   except SystemExit:time.sleep(600)
  tag=f'run-{seed}-{mode}';status={'seed':seed,'mode':mode,'source_digest':source_digest(),'complete':False,'started':datetime.datetime.now(datetime.timezone.utc).isoformat()};path=r/'evidence'/f'{tag}.json';path.write_text(json.dumps(status,indent=2))
  with (r/'evidence'/f'{tag}-out.txt').open('w') as out,(r/'evidence'/f'{tag}-err.txt').open('w') as err:
   p=subprocess.run([str(engine),'--headless','--path',str(r),'--script','res://diagnose.gd','--',str(seed),str(mode)],stdout=out,stderr=err,timeout=3600,creationflags=0x08000000)
  status['exit']=p.returncode;status['complete']=p.returncode==0 and not (r/'evidence'/f'{tag}-err.txt').read_text().strip() and status['source_digest']==source_digest();path.write_text(json.dumps(status,indent=2))
  if not status['complete']:raise SystemExit('failed; inspect durable evidence')
