from pathlib import Path
import subprocess,json
from preflight import require_headroom,require_model_evidence
r=Path(__file__).resolve().parent;require_model_evidence();require_headroom('native-launch');exe=r/'windows/Plant Growth Lab.exe';assert exe.exists() and (r/'windows/Plant Growth Lab.pck').exists()
with (r/'evidence/native-out.txt').open('w') as out,(r/'evidence/native-err.txt').open('w') as err:
 p=subprocess.Popen([str(exe)],cwd=exe.parent,stdout=out,stderr=err,creationflags=0x08000000)
(r/'evidence/ui-pid.txt').write_text(str(p.pid));print(json.dumps({'pid':p.pid,'target':str(exe),'normal_shortcuts_changed':False}))
