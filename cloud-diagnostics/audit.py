"""Audit isolation and completed evidence without rerunning migration suites."""
from pathlib import Path
import hashlib,json,subprocess
P=Path(__file__).resolve().parent;R=P.parent;W=P/'work/candidate30';baseline=R/'cloud-port/work/juvenile-allocation30'
science=['world.gd','legacy/model.gd','canopy.gd','atmosphere.gd','reserve.gd','decomposition.gd','hydrology.gd','field.gd','native/resource_field.c','native/resource_field.so','native/gdextension_interface.h']
checks=[]
for name in science:
 a=baseline/name;b=W/name
 if not a.exists():continue
 assert a.read_bytes()==b.read_bytes(),name;checks.append({'path':name,'unchanged':True,'sha256':hashlib.sha256(a.read_bytes()).hexdigest()})
assert (W/'base_plant.gd').read_bytes()==(baseline/'plant.gd').read_bytes()
assert (W/'plant.gd').read_bytes()==(P/'scripts/observer_plant.gd').read_bytes()
assert subprocess.check_output(['git','rev-parse','migration/linux-cpu'],cwd=R,text=True).strip()=='701d108642fe61cb051d9360d81eaf40258b30de'
assert not subprocess.check_output(['git','diff','701d108642fe61cb051d9360d81eaf40258b30de','--name-only','--',':!cloud-diagnostics'],cwd=R,text=True).strip()
subprocess.run(['python3',str(R/'verify_snapshot.py')],cwd=R,check=True)
plan=json.loads((P/'control-plan.json').read_text());assert hashlib.sha256((P/'CONTROL-PLAN.txt').read_bytes()).hexdigest()==plan['preregistration_sha256']
followup=json.loads((P/'followup-plan.json').read_text())
assert hashlib.sha256((P/'FOLLOWUP-PLAN.txt').read_bytes()).hexdigest()==followup['preregistration_sha256']
assert hashlib.sha256((P/'evidence/primary-control-analysis.json').read_bytes()).hexdigest()==followup['completed_primary_analysis_sha256']
result={'migration_branch_unchanged':'701d108642fe61cb051d9360d81eaf40258b30de','original_snapshot_verified':True,'all_changes_under':'cloud-diagnostics','unchanged_science':checks,'base_plant_unchanged':True,'preregistration_hash_unchanged':True,'followup_registration_and_frozen_primary_analysis_unchanged':True,'native_binary_reused_without_changes':True,'production_model_correction_performed':False}
(P/'evidence/isolation-audit.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
