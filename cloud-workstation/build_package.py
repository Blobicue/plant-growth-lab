from pathlib import Path
import hashlib,json,shutil,subprocess
P=Path(__file__).resolve().parent;W=P/'work/model';D=P/'packages/model';D.mkdir(parents=True,exist_ok=True);(D/'native').mkdir(exist_ok=True);(D/'evidence').mkdir(exist_ok=True)
subprocess.run(['python3',str(P/'sync_ui.py')],check=True)
names=[str(p.relative_to(W)) for p in W.rglob('*') if p.is_file() and not any(x in p.relative_to(W).parts for x in ['.godot','evidence','native']) and (p.suffix in ['.gd','.tscn','.godot','.txt'] or 'data' in p.relative_to(W).parts)]
names.append('native/resource_field.gdextension')
(W/'pack-files.json').write_text(json.dumps(sorted(names)))
subprocess.run(['python3',str(P/'run.py'),'model','pack_workstation.gd',str(D/'lab.pck')],check=True)
for src,dst in [(W/'native/resource_field.so',D/'native/resource_field.so'),(P.parent/'cloud-port/toolchain/Godot_v4.7.2-stable_linux.x86_64',D/'godot'),(P.parent/'cloud-port/launcher.py',D/'launcher.py'),(P.parent/'juvenile-allocation30/native/GODOT-LICENSE.txt',D/'GODOT-LICENSE.txt'),(P.parent/'workstation-app/Plant-Growth-Lab/THIRD-PARTY-LICENSES.json',D/'THIRD-PARTY-LICENSES.json')]:shutil.copy2(src,dst)
(D/'launch.sh').write_text('#!/bin/sh\nset -eu\nplant_workstation_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec python3 "$plant_workstation_dir/launcher.py" "$@"\n');(D/'launch.sh').chmod(0o755)
shutil.copy2(P/'README.txt',D/'README.txt')
inputs={name:hashlib.sha256((W/name).read_bytes()).hexdigest() for name in names}
(P/'evidence/packed-source-manifest.json').write_text(json.dumps(inputs,indent=2)+'\n')
manifest={str(p.relative_to(D)):hashlib.sha256(p.read_bytes()).hexdigest() for p in D.rglob('*') if p.is_file() and 'evidence' not in p.parts}
(P/'evidence/package-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Standalone private Linux package built; no deployment or publication.')
