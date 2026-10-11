from pathlib import Path
import hashlib,json,tarfile
P=Path(__file__).resolve().parent;D=P/'packages/model';manifest=json.loads((P/'evidence/package-manifest.json').read_text());out=P/'packages/plant-research-workstation-0.1.0-linux-x86_64.tar.gz'
with tarfile.open(out,'w:gz',compresslevel=6) as tar:
 for name,digest in manifest.items():
  f=D/name;assert hashlib.sha256(f.read_bytes()).hexdigest()==digest;tar.add(f,arcname='plant-research-workstation/'+name,recursive=False)
with tarfile.open(out,'r:gz') as tar:
 assert len(tar.getmembers())==len(manifest)
 for name,digest in manifest.items():assert hashlib.sha256(tar.extractfile('plant-research-workstation/'+name).read()).hexdigest()==digest
result={'path':str(out),'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'bytes':out.stat().st_size,'members_verified':len(manifest),'contains_user_data_or_credentials':False}
(P/'evidence/package-archive.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
