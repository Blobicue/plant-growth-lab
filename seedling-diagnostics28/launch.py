from pathlib import Path
import subprocess,sys,time,json,datetime
from preflight import require_headroom,source_digest
r=Path(__file__).resolve().parent
engine=r.parent.parent/'elemental-voxel-lab/artifacts/godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
for seed in [12011,4242,7301]:
 while True:
  try:require_headroom('diagnose-'+str(seed));break
  except SystemExit:time.sleep(600)
 status={'seed':seed,'source_digest':source_digest(),'complete':False,'started':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 path=r/'evidence'/f'run-{seed}.json';path.write_text(json.dumps(status,indent=2))
 with (r/'evidence'/f'run-{seed}-out.txt').open('w') as out,(r/'evidence'/f'run-{seed}-err.txt').open('w') as err:
  p=subprocess.run([str(engine),'--headless','--path',str(r),'--script','res://diagnose.gd','--',str(seed)],stdout=out,stderr=err,timeout=7200,creationflags=0x08000000)
 status['exit']=p.returncode;status['complete']=p.returncode==0 and not (r/'evidence'/f'run-{seed}-err.txt').read_text().strip() and status['source_digest']==source_digest();path.write_text(json.dumps(status,indent=2))
 if not status['complete']:raise SystemExit('failed; inspect durable evidence')
