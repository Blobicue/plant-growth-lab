"""Create isolated Linux copies; original source/evidence are never modified."""
from pathlib import Path
import shutil, subprocess, hashlib, json
ROOT=Path(__file__).resolve().parent.parent
PORT=ROOT/'cloud-port'
for name in ('shared-atmosphere27','juvenile-allocation30','seedling-diagnostics28'):
    src=ROOT/name; dst=PORT/'work'/name
    if dst.exists(): raise SystemExit(f'Refusing to overwrite {dst}')
    shutil.copytree(src,dst,ignore=shutil.ignore_patterns('.godot','__pycache__'))
    shutil.copytree(src/'evidence',dst/'golden')
    c=dst/'native/resource_field.c'
    text=c.read_text(); assert text.count('__declspec(dllexport)')==1
    c.write_text(text.replace('__declspec(dllexport)','__attribute__((visibility("default")))'))
    ext=dst/'native/resource_field.gdextension'
    ext.write_text(ext.read_text()+'\nlinux.x86_64="res://native/resource_field.so"\n')
    if name=='juvenile-allocation30':
        ui=dst/'lab.gd';ui.write_text(ui.read_text().replace('BLOBUS / PLANT LAB 27','PLANT LAB 30 / UNPROMOTED').replace('Plant Growth Lab / Shared Finite Air 27','Plant Growth Lab / Candidate30 / Unpromoted'))
    subprocess.run(['gcc','-O3','-g','-std=c11','-fPIC','-shared','-o',str(dst/'native/resource_field.so'),str(c)],check=True)
    for script in (PORT/'scripts').glob('*.gd'):
        if name=='seedling-diagnostics28' and script.name!='birth_checks.gd':continue
        if name!='seedling-diagnostics28' and script.name=='birth_checks.gd':continue
        if name!='juvenile-allocation30' and script.name in ['continue_survival.gd','snapshot_view.gd']:continue
        shutil.copy2(script,dst/script.name)
manifest=json.loads((ROOT/'juvenile-allocation30/evidence/scientific-runtime-manifest.json').read_text())
checks=[]
for entry in manifest['files']:
    path=ROOT/'juvenile-allocation30'/entry['path']
    if not path.exists():
        assert entry['path']=='native/resource_field.dll', entry['path']
        checks.append({'path':entry['path'],'unavailable':'omitted original Windows binary'})
    else:
        checks.append({'path':entry['path'],'pass':hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256']})
(PORT/'evidence/runtime-provenance.json').write_text(json.dumps(checks,indent=2))
assert all(c.get('pass',True) for c in checks)
print('Built isolated W27 and candidate30; runtime provenance verified')
