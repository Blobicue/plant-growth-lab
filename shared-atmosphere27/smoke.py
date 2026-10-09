from pathlib import Path
import subprocess,json
from preflight import require_headroom
r=Path(__file__).resolve().parent;require_headroom('compile-smoke')
engine=r.parent.parent/'elemental-voxel-lab/artifacts/godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
with (r/'evidence/smoke-out.txt').open('w') as out,(r/'evidence/smoke-err.txt').open('w') as err:
 p=subprocess.run([str(engine),'--headless','--path',str(r),'--script','res://smoke.gd'],stdout=out,stderr=err,timeout=90,creationflags=0x08000000)
print(p.returncode);print((r/'evidence/smoke-out.txt').read_text()[-1800:]);print((r/'evidence/smoke-err.txt').read_text()[-3500:])
