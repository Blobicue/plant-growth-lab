from pathlib import Path
import subprocess,shutil,json,hashlib
from preflight import require_headroom,require_model_evidence,source_digest
require_model_evidence();require_headroom("package-build")
r=Path(__file__).resolve().parent;stage=r/'build-source';engine=r.parent.parent/'elemental-voxel-lab/artifacts/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
for name in ['project.godot','lab.tscn','lab.gd','world.gd','atmosphere.gd','canopy.gd','plant.gd','reserve.gd','hydrology.gd','decomposition.gd','field.gd','field.compute.txt','serial.compute.txt','renderer.gd','bridge.gd','tests.gd']:
 shutil.copy2(r/name,stage/name)
for folder in ['legacy','native','control']:shutil.copytree(r/folder,stage/folder,dirs_exist_ok=True)
cfg=(r.parent/'coupled-field-lab/build-source/export_presets.cfg').read_text().replace('Plant Field Coupling Lab','Plant Growth Lab').replace('10.0.0.0','27.0.0.0');(stage/'export_presets.cfg').write_text(cfg)
# Procedural resources need no editor imports. Pack with the existing engine.
engine_gui=engine.with_name('Godot_v4.7.2-stable_win64.exe')
with (r/'evidence/pack-log.txt').open('w') as out:
 result=subprocess.run([str(engine),'--headless','--path',str(r/'pack-tools'),'--script','res://pack.gd','--',str(stage),str(r/'windows/Plant Growth Lab.pck')],stdout=out,stderr=subprocess.STDOUT,timeout=60,creationflags=0x08000000)
if result.returncode:raise RuntimeError('pack failed: '+str(result.returncode))
shutil.copy2(engine_gui,r/'windows/Plant Growth Lab.exe');(r/'windows/native').mkdir(exist_ok=True);shutil.copy2(r/'native/resource_field.dll',r/'windows/native/resource_field.dll')
for name in ['GODOT-LICENSE.txt','THIRD-PARTY-LICENSES.json','plant-icon.ico','plant-icon.png']:shutil.copy2(r.parent/'workstation-app/Plant-Growth-Lab'/name,r/'windows'/name)
shutil.copytree(r/'tools',r/'windows/tools',dirs_exist_ok=True)
print([(x.name,x.stat().st_size) for x in (r/'windows').iterdir() if x.is_file()])

files=[]
for name in ["Plant Growth Lab.exe","Plant Growth Lab.pck","native/resource_field.dll"]:
 p=r/"windows"/name
 with p.open("rb") as f:h=hashlib.file_digest(f,"sha256").hexdigest()
 files.append({"path":name,"bytes":p.stat().st_size,"sha256":h})
(r/"evidence/build-completion.json").write_text(json.dumps({"source_digest":source_digest(),"files":files},indent=2))
