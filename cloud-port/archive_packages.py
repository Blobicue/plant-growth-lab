"""Archive only verified runtime files, excluding personal saves, control and caches."""
from pathlib import Path
import gzip,hashlib,io,json,tarfile
P=Path(__file__).resolve().parent
reports=[]
for name in ['shared-atmosphere27','juvenile-allocation30']:
    root=P/'packages'/name
    manifest=json.loads((P/'evidence'/(name+'-linux-package-manifest.json')).read_text())
    payload={path:(root/path).read_bytes() for path in manifest}
    assert all(hashlib.sha256(payload[path]).hexdigest()==sha for path,sha in manifest.items())
    payload['README-LINUX.txt']=(f'''Plant Growth Lab / {name} / Linux CPU
Tested with official Godot 4.7.2 ed1daf0bf in the dedicated Linux CPU environment.

Run: ./launch.sh
Headless smoke check: ./launch.sh --headless --script res://smoke.gd
GUI requires a local display; the cloud screenshot used Mesa llvmpipe software GL.
The launcher serializes owned runs, requires 8 GiB effective memory headroom and
bounds each session to 600 seconds. Save an exact replay before closing.
No credentials, network service, personal saves or local-control state are included.
Candidate30 remains UNPROMOTED. W27 is the preserved reviewed fallback.
Hardware GPU and Windows package validation are not claimed by this Linux build.
Refer to cloud-port/REPORT.txt and evidence/summary.json in the migration branch.
''').encode()
    manifest={path:hashlib.sha256(data).hexdigest() for path,data in payload.items()}
    payload['MANIFEST.json']=json.dumps(manifest,indent=2).encode()
    target=P/'packages'/(name+'-linux-x86_64.tar.gz')
    with target.open('wb') as raw, gzip.GzipFile(filename='',mode='wb',fileobj=raw,compresslevel=6,mtime=0) as gz, tarfile.open(mode='w',fileobj=gz) as tar:
        directory=tarfile.TarInfo(name+'/evidence');directory.type=tarfile.DIRTYPE;directory.mode=0o755;tar.addfile(directory)
        for path,data in sorted(payload.items()):
            info=tarfile.TarInfo(name+'/'+path);info.size=len(data);info.mode=0o755 if path in ['godot','launch.sh'] else 0o644;tar.addfile(info,io.BytesIO(data))
    with tarfile.open(target) as tar:
        for path,sha in manifest.items():assert hashlib.sha256(tar.extractfile(name+'/'+path).read()).hexdigest()==sha
    reports.append({'path':str(target),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size,'verified_files':len(manifest)})
(P/'evidence/package-archives.json').write_text(json.dumps(reports,indent=2));print(json.dumps(reports,indent=2))
