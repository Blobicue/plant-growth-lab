from pathlib import Path
import json,hashlib,time
r=Path(__file__).resolve().parent;layout=json.loads((r/'evidence/ui-map.json').read_text());assert hashlib.sha256((r/'evidence'/layout['reviewed_screenshot']).read_bytes()).hexdigest()==layout['reviewed_sha256']
import desktop as d
from ui_input import value
assert d.pid==layout['pid'];checks=[];trace=[]
def check(v,name):
 checks.append({'pass':bool(v),'name':name})
 if not v:raise AssertionError(name)
def call(cmd,args=None):
 state=d.call(cmd,args);trace.append({'command':cmd,'args':args,'state':state});return state
try:
 active=d.adapter.DEFAULT/'active.json';check(not active.exists() or not d.adapter.read(active)['enabled'],'fresh local control OFF');d.click(*layout['local_checkbox']);value(*layout['rate_input'],'60');d.click(*layout['step']);check(call('status')['tick']==1,'physical Step advances model');call('run',{'target':96});time.sleep(.2);call('pause');check(call('status')['paused'],'Pause holds simulation')
 for mode in [0,1]:
  call('scenario',dict(seed=4242,scenario=3,backend=0,lifecycle=3,radiation=2,recycling=1,decomposition=1,carbon_access=mode));call('run',{'target':960});s=d.wait();ref=json.loads((r/'evidence'/f'matrix-4242-{mode}.json').read_text());expected=next(x for x in ref['samples'] if x['tick']==960);check(s['metrics']==expected and not s['failure'],'native matches audited mode'+str(mode));d.capture('native-mode-'+str(mode)+'.png')
 cpu=call('status');call('scenario',dict(seed=4242,scenario=3,backend=1,lifecycle=3,radiation=2,recycling=1,decomposition=1,carbon_access=1));call('run',{'target':960});gpu=d.wait();check(gpu['metrics']==cpu['metrics'] and not gpu['failure'],'native CPU GPU carbon and lineage equality');check(gpu['metrics']['air']['received_by_plants_C']>0 and gpu['metrics']['air']['external_C_imports']==0,'inspectable real uptake with zero external carbon import');call('save');call('replay');s=d.wait();check(s['job']=='complete' and not s['failure'],'native exact shared-air replay');d.capture('native-replayed.png');call('stop');check(not d.adapter.read(active)['enabled'],'Stop revokes local control');d.capture('native-stopped.png')
finally:
 (r/'evidence/live-tests.json').write_text(json.dumps({'checks':checks,'trace':trace},indent=2))
 try:
  if active.exists() and d.adapter.read(active)['enabled']:d.call('stop')
 except Exception:pass
 try:d.u.PostMessageW(d.hwnd(),0x10,0,0)
 except Exception:pass
