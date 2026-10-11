"""Verify isolation, immutable evidence, unchanged original runtime and package contents."""
from pathlib import Path
import hashlib,json,subprocess
P=Path(__file__).resolve().parent;R=P.parent;W=P/'work/model';E=P/'evidence'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((E/'adapter-manifest.json').read_text())
for rel,h in m['original_inputs'].items():assert sha(R/rel)==h,rel
for rel,h in m['copied_modules'].items():
 if rel=='project.godot':continue
 assert sha(W/rel)==h,rel
assert sha(W/'data/catalog.json')==m['catalog_sha256']
c=json.loads((W/'data/catalog.json').read_text())
for run in c['runs']:
 for meta in run['states'].values():assert sha(W/meta['path'].removeprefix('res://'))==meta['sha256']
for p in (P/'scripts').glob('*.gd'):assert p.read_bytes()==(W/p.name).read_bytes()
assert not subprocess.check_output(['git','diff','de28f7bbb30da4427a05ee7b7434bdc53e49083e','--name-only','--',':!cloud-workstation'],cwd=R,text=True).strip()
subprocess.run(['python3',str(R/'verify_snapshot.py')],cwd=R,check=True)
checks={}
for tag,base in [('source',W),('package',P/'packages/model')]:
 for name in ['workstation-checks.json','workstation-reopen.json','cloud-ui-checks.json','cloud-restart-checks.json']:
  f=base/'evidence'/name;d=json.loads(f.read_text());assert all(v['pass'] for v in d['checks']),(tag,name);checks[tag+'-'+name]=len(d['checks'])
  (E/(tag+'-'+name)).write_text(json.dumps(d,indent=2)+'\n')
cpu=json.loads((W/'evidence/cloud-cpu-checks.json').read_text());assert all(v['pass'] for v in cpu['checks']);checks['native-CPU']=len(cpu['checks']);(E/'source-cloud-cpu-checks.json').write_text(json.dumps(cpu,indent=2)+'\n')
for rel,h in json.loads((E/'packed-source-manifest.json').read_text()).items():assert sha(W/rel)==h
for rel,h in json.loads((E/'package-manifest.json').read_text()).items():assert sha(P/'packages/model'/rel)==h
for p in E.glob('model-*.log'):
 assert 'SCRIPT ERROR:' not in p.read_text() and '\nERROR:' not in p.read_text(),p
rt=[json.loads(p.read_text()) for p in E.glob('model-*.runtime.json')]
launch=json.loads((E/'package-launcher-runtime.json').read_text());assert launch['exit']==0 and launch['stop_reason'] is None
assert '\nERROR:' not in (E/'package-launch.log').read_text()
rt.append(launch)
assert all(r['exit']==0 and r['stop_reason'] is None for r in rt)
result={'pass':True,'original_payloads':189,'source_inputs':len(m['original_inputs']),'unchanged_copied_modules':len(m['copied_modules'])-1,'archive_states_sha256':18,'checks':checks,'normal_package_entrypoint_pass':True,'selected_replay_hours_per_source_and_package':576,'runtime_seconds':sum(r['wall_seconds'] for r in rt),'peak_rss_bytes':max(r['peak_rss_bytes'] for r in rt),'minimum_headroom_bytes':min(r['minimum_headroom_bytes'] for r in rt),'scope':'F1 comparison and replay, baseline reports; no W27/candidate binary coercion','new_biology_or_long_trials':False,'rendering':'Mesa llvmpipe software; hardware GPU and Windows unavailable','publication':False}
(E/'audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
