from pathlib import Path
import subprocess,shutil,json,hashlib
P=Path(__file__).resolve().parent
for name in ['shared-atmosphere27','juvenile-allocation30']:
 dst=P/'packages'/name;dst.mkdir(parents=True,exist_ok=True);(dst/'native').mkdir(exist_ok=True);(dst/'evidence').mkdir(exist_ok=True)
 subprocess.run(['python3',str(P/'run.py'),name,'pack_linux.gd',str(dst/'lab.pck')],check=True)
 shutil.copy2(P/'work'/name/'native/resource_field.so',dst/'native/resource_field.so')
 shutil.copy2(P/'toolchain/Godot_v4.7.2-stable_linux.x86_64',dst/'godot')
 shutil.copy2(P.parent/name/'native/GODOT-LICENSE.txt',dst/'GODOT-LICENSE.txt')
 shutil.copy2(P/'launcher.py',dst/'launcher.py')
 shutil.copy2(P.parent/'workstation-app/Plant-Growth-Lab/THIRD-PARTY-LICENSES.json',dst/'THIRD-PARTY-LICENSES.json')
 (dst/'launch.sh').write_text('#!/bin/sh\nset -eu\nplant_package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec python3 "$plant_package_dir/launcher.py" "$@"\n')
 (dst/'launch.sh').chmod(0o755)
 manifest={name:hashlib.sha256((dst/name).read_bytes()).hexdigest() for name in ['lab.pck','native/resource_field.so','godot','GODOT-LICENSE.txt','launch.sh','launcher.py','THIRD-PARTY-LICENSES.json']}
 (P/'evidence'/(name+'-linux-package-manifest.json')).write_text(json.dumps(manifest,indent=2))
 for script in ['smoke.gd','ui_checks.gd','restart_checks.gd']:
  subprocess.run(['python3',str(P/'run.py'),name,script,'--package'],check=True)
