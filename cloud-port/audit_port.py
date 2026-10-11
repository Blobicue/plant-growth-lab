from pathlib import Path
import hashlib,json,subprocess
P=Path(__file__).resolve().parent;R=P.parent
report={}
for name in ['shared-atmosphere27','juvenile-allocation30','seedling-diagnostics28']:
 changes=[];identical=0
 for src in (R/name).rglob('*'):
  if not src.is_file() or 'evidence' in src.parts:continue
  rel=src.relative_to(R/name);dst=P/'work'/name/rel
  if src.read_bytes()==dst.read_bytes():identical+=1
  else:changes.append(str(rel))
 expected=['native/resource_field.c','native/resource_field.gdextension']+(['lab.gd'] if name=='juvenile-allocation30' else [])
 assert set(changes)==set(expected),(name,changes)
 c=(P/'work'/name/'native/resource_field.c').read_text().replace('__attribute__((visibility("default")))','__declspec(dllexport)')
 assert c==(R/name/'native/resource_field.c').read_text()
 report[name]={'identical_source_files':identical,'changed_source_files':changes,'c_change_only_export_declaration':True}
(P/'evidence/port-diff.json').write_text(json.dumps(report,indent=2))
subprocess.run(['python3',str(R/'verify_snapshot.py')],check=True,cwd=R)
print(json.dumps(report))
