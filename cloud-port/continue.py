"""Gate further biology on exact physical correctness, then extend without tuning."""
from pathlib import Path
import json,subprocess,shutil
P=Path(__file__).resolve().parent
for project in ['shared-atmosphere27','juvenile-allocation30']:
 for suite in ['model-tests.json','cloud-cpu-checks.json']:
  d=json.loads((P/'work'/project/'evidence'/suite).read_text());assert all(x['pass'] for x in d['checks']), (project,suite)
 for seed in [12011,4242,7301]:
  for mode in ([0,1] if project=='shared-atmosphere27' else [1]):
   f=P/'evidence'/f'{project}-cloud-golden-{seed}-{mode}-8160-forward.json';d=json.loads(f.read_text())
   assert d['checks']['endpoint'] and d['checks']['healthy'],f
   assert d.get('hourly_hash_mismatches',0)==0 and not any(x['kind']=='hourly fingerprint' for x in d['mismatch']),f
   if project=='juvenile-allocation30':assert d['allocation_policy']['juvenile_no_new_deposits'] and d['allocation_policy']['mature_deposit_hours']>0,f
for project in ['shared-atmosphere27','juvenile-allocation30']:
 for seed in [12011,4242,7301]:
  f=P/'evidence'/f'{project}-cloud-golden-{seed}-1-960-reverse.json';d=json.loads(f.read_text())
  assert d['checks']['endpoint'] and d['checks']['healthy'] and d['hourly_hash_mismatches']==0,f
print('Mandatory full-state reproduction and conservation gates pass. Strict JSON-text-derived metric differences remain separately recorded.',flush=True)
for seed in [12011,4242,7301]:
 existing=P/'work/juvenile-allocation30/evidence'/f'cloud-survival-{seed}.json'
 final_state=existing.with_name(f'cloud-final-{seed}.bin')
 if existing.exists():
  d=json.loads(existing.read_text())
  assert d['seed']==seed and d['origin_tick']==8160 and d['horizon']==12288 and d['origin_exact'] and d['allocation_order_exact_every_hour'] and not d['error'] and not d['censored'] and final_state.exists(),existing
  print(f'Completed seed{seed}; preserving evidence and skipping rerun.',flush=True)
  continue
 subprocess.run(['python3',str(P/'run.py'),'juvenile-allocation30','continue_survival.gd',str(seed),'--timeout','1200'],check=True)
 for f in (P/'work/juvenile-allocation30/evidence').glob('cloud-survival-*'):shutil.copy2(f,P/'evidence'/('juvenile-allocation30-'+f.name))
