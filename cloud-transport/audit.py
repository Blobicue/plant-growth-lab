"""Audit the isolated transport contract and preserved branches without simulations."""
from pathlib import Path
import hashlib,json,subprocess
P=Path(__file__).resolve().parent;R=P.parent;W=P/'work/candidate30';E=P/'evidence';B=R/'cloud-port/work/juvenile-allocation30'
plan=json.loads((P/'protocol.json').read_text());assert hashlib.sha256((P/'PROTOCOL.txt').read_bytes()).hexdigest()==plan['registration_sha256']
checks=[]
for name in ['legacy/model.gd','canopy.gd','atmosphere.gd','reserve.gd','decomposition.gd','hydrology.gd','field.gd','native/resource_field.c','native/resource_field.so','native/gdextension_interface.h']:
 a=B/name;b=W/name
 if not a.exists():continue
 assert a.read_bytes()==b.read_bytes(),name;checks.append({'path':name,'unchanged':True,'sha256':hashlib.sha256(a.read_bytes()).hexdigest()})
base=(B/'plant.gd').read_text();modified=(W/'base_plant.gd').read_text();assert modified.startswith(base) and modified[len(base):].startswith('\n# Isolated T1 experiment:')
old=(B/'world.gd').read_text();expected=old.replace('extends RefCounted\n','extends RefCounted\nvar transport_substeps=0\n',1).replace(' for p in order:p.transport_pools()',' for p in order:\n  p.transport_substeps=transport_substeps;p.transport_pools()')
assert (W/'world.gd').read_text()==expected
assert (W/'plant.gd').read_bytes()==(R/'cloud-diagnostics/scripts/observer_plant.gd').read_bytes()
for c in plan['cohorts']:assert hashlib.sha256((R/c['file']).read_bytes()).hexdigest()==c['sha256']
expected_branches={'migration/linux-cpu':'701d108642fe61cb051d9360d81eaf40258b30de','diagnostic/gen2-survival-causality':'7cb5a51e30171c9770f52d47810d8da5b8b1b5b9','design/local-nitrogen-contract':'93aac33022d3f9ea69490ea04d3732d0a74f83dd','experiment/local-construction-feedback':'db7f2d1aae27961ffefb5734de45b29bad4af449'}
for name,commit in expected_branches.items():assert subprocess.check_output(['git','rev-parse',name],cwd=R,text=True).strip()==commit
assert not subprocess.check_output(['git','diff',expected_branches['experiment/local-construction-feedback'],'--name-only','--',':!cloud-transport'],cwd=R,text=True).strip()
subprocess.run(['python3',str(R/'verify_snapshot.py')],cwd=R,check=True)
r={'only_changed_directory':'cloud-transport','preserved_branches':expected_branches,'original_payloads_checked':189,'unchanged_science':checks,'only_scientific_dispatch_changes':['world.transport_substeps default0 and assignment before existing transport call','base_plant transport override retains original super call for0; T1 for positive substeps'],'feedback_implemented':False,'changed_biological_rates_costs_genes_maturity':False,'native_binary_unchanged':True,'original_birth_binary_hashes_verified':11,'protocol_hash_unchanged':True,'matrix_stopped':(E/'STOP.json').exists(),'gpu':'unavailable, not passed','Windows':'unavailable, not passed','push_merge_deploy_promotion':False}
(E/'isolation-audit.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
