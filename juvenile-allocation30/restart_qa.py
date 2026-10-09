from pathlib import Path
import json,hashlib
r=Path(__file__).resolve().parent
layout=json.loads((r/'evidence/restart-ui-map.json').read_text())
shot=r/'evidence'/layout['reviewed_screenshot']
assert hashlib.sha256(shot.read_bytes()).hexdigest()==layout['reviewed_sha256']
import desktop as d
from ui_input import value
assert layout['pid']==d.pid
prior=json.loads((r/'evidence/live-tests.json').read_text())
assert prior['checks'] and all(x['pass'] for x in prior['checks'])
saved=next(x['state'] for x in prior['trace'] if x['command']=='save')
folder=d.adapter.DEFAULT.parent/'runs'
expected_path=folder/(saved['run_id']+'.json')
assert expected_path.stat().st_size<=5_000_000
expected=json.loads(expected_path.read_text())
assert sorted(folder.glob('juvenile30-*.json'))[-1]==expected_path, 'Review saved-run selection before replay'
checks=[];state={}
def check(ok,name):
 checks.append({'pass':bool(ok),'name':name})
 if not ok:raise AssertionError(name)
active=d.adapter.DEFAULT/'active.json'
try:
 check(not active.exists() or not d.adapter.read(active)['enabled'],'fresh process local commands OFF')
 d.click(*layout['local_checkbox']);value(*layout['rate_input'],'60')
 fresh=d.call('status');check(fresh['tick']==0 and fresh['config']['carbon_access']==1,'fresh process selects shared finite air')
 d.click(*layout['load_record']);d.call('replay');state=d.wait()
 check(state['tick']==expected['tick'] and state['config']==expected['config'] and not state['failure'] and state['job']=='complete','persisted settings and exact replay complete after restart')
 d.call('save');actual_path=folder/(state['run_id']+'.json')
 check(actual_path.stat().st_size<=5_000_000,'saved replay remains within native file bound')
 actual=json.loads(actual_path.read_text())
 check(actual['fingerprint']==expected['fingerprint'],'fresh-process full-state fingerprint exactly matches original save')
 check(len(json.dumps(state).encode())<=2_000_000,'source inspector fits adapter response bound')
 d.capture('native-restart-replayed.png');d.call('stop')
 check(not d.adapter.read(active)['enabled'],'restart Stop revokes local control')
 d.capture('native-restart-stopped.png')
finally:
 (r/'evidence/restart-tests.json').write_text(json.dumps({'checks':checks,'state':state,'original_record':str(expected_path)},indent=2))
 try:
  if active.exists() and d.adapter.read(active)['enabled']:d.call('stop')
 except Exception:pass
 try:d.u.PostMessageW(d.hwnd(),0x10,0,0)
 except RuntimeError:pass
