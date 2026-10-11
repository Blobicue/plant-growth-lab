"""Reproduce an isolated diagnostic project after cloud-port/setup.py; refuse overwrite."""
from pathlib import Path
import shutil,json,hashlib
P=Path(__file__).resolve().parent;R=P.parent;src=R/'cloud-port/work/juvenile-allocation30';dst=P/'work/candidate30'
assert not dst.exists(),f'Refusing to overwrite {dst}'
shutil.copytree(src,dst,ignore=shutil.ignore_patterns('.godot','evidence','golden','*.log'));(dst/'evidence').mkdir()
shutil.copy2(src/'plant.gd',dst/'base_plant.gd')
for f in (P/'scripts').glob('*.gd'):
 if f.name=='observer_plant.gd':shutil.copy2(f,dst/'plant.gd')
 else:shutil.copy2(f,dst/f.name)
s=(src/'state.gd').read_text().replace('"hour","previous","events"','"hour","previous","events","obs_hour","obs_day","obs_events","obs_seen","obs_last_totals"');(dst/'state.gd').write_text(s)
if (P/'make_controls.py').exists():
 import subprocess
 subprocess.run(['python3',str(P/'make_controls.py')],check=True)
print('Isolated observer project ready; science sources unchanged except observer dispatch.')
