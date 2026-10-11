"""Summarize raw evidence without converting strict JSON mismatches into passes."""
from pathlib import Path
import json,hashlib,shutil
P=Path(__file__).resolve().parent;E=P/'evidence'
for project in ['shared-atmosphere27','juvenile-allocation30','seedling-diagnostics28']:
 for f in (P/'work'/project/'evidence').glob('*'):
  if f.name.startswith('cloud-') or f.name in ['model-tests.json','fixture-tests.json']:
   shutil.copy2(f,E/(project+'-'+f.name))
 package=P/'packages'/project
 if package.exists():
  for f in (package/'evidence').glob('*.json'):shutil.copy2(f,E/(project+'-package-'+f.name))
checks=[]
for f in sorted(E.glob('*.json')):
 d=json.loads(f.read_text())
 if isinstance(d,dict) and isinstance(d.get('checks'),list) and all(isinstance(x,dict) and 'pass' in x for x in d['checks']):
  checks.append({'source':f.name,'passed':sum(x['pass'] for x in d['checks']),'total':len(d['checks'])})
golden=[]
for f in sorted(E.glob('*-cloud-golden-*.json')):
 d=json.loads(f.read_text());numeric=[];nonnumeric=[]
 for checkpoint in d.get('metric_differences',[]):
  for value in checkpoint['differences']:
   if isinstance(value.get('actual'),(int,float)) and isinstance(value.get('expected'),(int,float)):numeric.append(abs(value['actual']-value['expected']))
   else:nonnumeric.append(value)
 golden.append({'source':f.name,'seed':d['seed'],'mode':d['mode'],'horizon':d['horizon'],'reverse':d['reverse'],'hourly_hash_mismatches':d.get('hourly_hash_mismatches',sum(x['kind']=='hourly fingerprint' for x in d['mismatch'])),'endpoint_exact':d['checks']['endpoint'],'healthy':d['checks']['healthy'],'strict_json_metrics_exact':all(x['match'] for x in d['checkpoints']),'max_recorded_metric_difference':max(numeric,default=None),'nonnumeric_differences':nonnumeric,'max_error':d['max_error'],'max_plant_error':d['max_plant_error'],'allocation_policy':d.get('allocation_policy'),'lineage':d['lineage'],'plants':[{'id':p['id'],'generation':p['generation'],'paid_nodes':p['data']['nodes'],'living_nodes':p['data']['living'],'leaf_nodes_including_dead':p['data']['leaves']} for p in d['end']['plants']]})
survival=[]
for f in sorted(E.glob('*-cloud-survival-*.json')):
 d=json.loads(f.read_text());original=json.loads((E/f"juvenile-allocation30-cloud-golden-{d['seed']}-1-8160-forward.json").read_text())
 transitions=[]
 for plant in d['end']['plants']:
  pid=plant['id'];history=[{'tick':day['tick'],**next(p for p in day['plants'] if p['id']==pid)} for day in d['daily'] if any(p['id']==pid for p in day['plants'])]
  initial=next((p for p in original['end']['plants'] if p['id']==pid),None)
  transitions.append({'id':pid,'generation':plant['generation'],'initial_paid_nodes':initial['data']['nodes'] if initial else None,'initial_living_nodes':initial['data']['living'] if initial else None,'final_paid_nodes':plant['data']['nodes'],'final_living_nodes':plant['data']['living'],'final_leaf_nodes_including_dead':plant['data']['leaves'],'max_daily_paid_nodes':max((p['nodes'] for p in history),default=0),'first_daily_zero_living':next((p['tick'] for p in history if p['living']==0),None)})
 survival.append({'source':f.name,'seed':d['seed'],'horizon':d['horizon'],'origin_exact':d['origin_exact'],'allocation_order_exact_every_hour':d['allocation_order_exact_every_hour'],'new_births':[x for x in d['lineage'] if x['birth_tick']>8160],'lineage':d['lineage'],'plants':transitions,'max_error':d['max_error'],'max_plant_error':d['max_plant_error'],'error':d['error'],'censored':d['censored']})
runtimes=[]
for f in E.glob('*.runtime.json'):
 d=json.loads(f.read_text());runtimes.append({'source':f.name,**{k:d[k] for k in ['exit','stop_reason','wall_seconds','peak_rss_bytes','minimum_headroom_bytes']}})
packages=[]
for f in E.glob('*-linux-package-manifest.json'):
 name=f.name.removesuffix('-linux-package-manifest.json');manifest=json.loads(f.read_text());bad=[p for p,sha in manifest.items() if hashlib.sha256((P/'packages'/name/p).read_bytes()).hexdigest()!=sha];packages.append({'project':name,'files':len(manifest),'mismatches':bad})
summary={'baseline_commit':'c7ec213793fb82817ba66e63e8a0b5b16b784762','promoted':False,'checks':checks,'golden':golden,'survival':survival,'packages':packages,'runtimes':runtimes,'recorded_final_run_wall_seconds_sum':sum(d['wall_seconds'] for d in runtimes),'recorded_final_run_peak_rss_bytes':max(d['peak_rss_bytes'] for d in runtimes),'minimum_observed_headroom_bytes':min(d['minimum_headroom_bytes'] for d in runtimes),'unavailable':['hardware GPU parity','Windows runtime/native package/shortcut checks','two original W27 desktop replay records omitted from reduced snapshot'],'remaining_failure':'Strict archived JSON metrics equality; binary full-state hashes are assessed separately.'}
numeric=E/'numeric-analysis.json'
if numeric.exists():
 d=json.loads(numeric.read_text());summary['numeric_report_diagnostics']={'criterion':d['criterion'],'results':[{k:v for k,v in x.items() if k not in ['rows','parser_probes']}for x in d['results']],'strict_failures_retained':True}
(E/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps({'check_suites':checks,'golden_cases':len(golden),'survival':survival,'packages':packages,'peak_rss_MiB':summary['recorded_final_run_peak_rss_bytes']/2**20,'minimum_headroom_GiB':summary['minimum_observed_headroom_bytes']/2**30},indent=2))
