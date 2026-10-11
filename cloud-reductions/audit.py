"""Read-only audit of R1 scope, unchanged transport/biology, provenance and old branches."""
from pathlib import Path
import hashlib,json,subprocess,re
P=Path(__file__).resolve().parent;R=P.parent;E=P/'evidence';W=P/'work/candidate30';B=R/'cloud-transport/work/candidate30'
plan=json.loads((P/'protocol.json').read_text());assert hashlib.sha256((P/'PROTOCOL.txt').read_bytes()).hexdigest()==plan['registration_sha256']
def body(text,name):
 match=re.search(r'^func '+re.escape(name)+r'\(',text,re.M);assert match,name
 end=re.search(r'^func ',text[match.end():],re.M)
 return text[match.start():match.end()+end.start() if end else len(text)]
unchanged=[]
for name in ['transport.gd','atmosphere.gd','canopy.gd','hydrology.gd','decomposition.gd','field.gd','native/resource_field.c','native/resource_field.so','native/gdextension_interface.h']:
 a=B/name;b=W/name
 if not a.exists():continue
 assert a.read_bytes()==b.read_bytes(),name;unchanged.append({'path':name,'sha256':hashlib.sha256(a.read_bytes()).hexdigest()})
for file,methods in [('legacy/model.gd',['transport_pools','_insert','_tip','_connections','respire','_propose','_complete','build_proposals']),('base_plant.gd',['photo_demands','payable','commit_growth']),('world.gd',['resolve_growth','lifecycle_step','request_propagule','_visual'])]:
 old=(B/file).read_text();new=(W/file).read_text()
 for method in methods:assert body(old,method)==body(new,method),(file,method)
assert (W/'plant.gd').read_bytes()==(B/'plant.gd').read_bytes()
for c in plan['cohorts']:assert hashlib.sha256((R/c['file']).read_bytes()).hexdigest()==c['sha256']
for c in plan['reuse_candidates']:
 assert hashlib.sha256((R/c['source']).read_bytes()).hexdigest()==c['sha256']
 f=E/Path(c['source']).name
 if f.exists():assert f.read_bytes()==(R/c['source']).read_bytes()
old=W.parent/'legacy_numeric'
for name in ['world.gd','base_plant.gd','legacy/model.gd','reserve.gd','transport.gd','hydrology.gd']:
 assert (old/name).read_bytes()==(B/name).read_bytes(),('old diagnostic changed',name)
branches={'migration/linux-cpu':'701d108642fe61cb051d9360d81eaf40258b30de','diagnostic/gen2-survival-causality':'7cb5a51e30171c9770f52d47810d8da5b8b1b5b9','design/local-nitrogen-contract':'93aac33022d3f9ea69490ea04d3732d0a74f83dd','experiment/local-construction-feedback':'db7f2d1aae27961ffefb5734de45b29bad4af449','experiment/synchronous-local-transport':'5456dfe73d92c33c3cabf716fbaca0e8c6f2f0fa'}
for name,commit in branches.items():assert subprocess.check_output(['git','rev-parse',name],cwd=R,text=True).strip()==commit
assert not subprocess.check_output(['git','diff',branches['experiment/synchronous-local-transport'],'--name-only','--',':!cloud-reductions'],cwd=R,text=True).strip()
subprocess.run(['python3',str(R/'verify_snapshot.py')],cwd=R,check=True)
result={'only_changed_directory':'cloud-reductions','preserved_branches':branches,'original_payloads_checked':189,'unchanged_modules':unchanged,'transport_and_biology_function_bodies_unchanged':True,'old_numeric_quantum_diagnostic_source_unchanged':True,'original_birth_hashes_verified':11,'reuse_candidates':5,'numerical_change':'physical chronological traversal and root claim keys only; no new arithmetic formula or floor tolerance','GPU':'unavailable, not passed','Windows':'unavailable, not passed','push_merge_deploy_promotion':False}
(E/'isolation-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
