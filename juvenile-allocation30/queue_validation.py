from pathlib import Path
import subprocess,json,time,datetime,sys
from preflight import require_headroom,source_digest
r=Path(__file__).resolve().parent
# Detached modest monitor. Every engine stage has its own unchanged8GiB check.
for stage in ['tests','fixture','parity']:
 while True:
  try:require_headroom('queue-'+stage);break
  except SystemExit:
   (r/'evidence/queue-state.json').write_text(json.dumps({'stage':stage,'status':'waiting for unchanged8GiB guard','utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}));time.sleep(600)
 (r/'evidence/queue-state.json').write_text(json.dumps({'stage':stage,'status':'running','digest':source_digest()}))
 code=subprocess.call([sys.executable,'-u','run.py',stage],cwd=r)
 if code:raise SystemExit('Validation stage failed: '+stage)
(r/'evidence/queue-state.json').write_text(json.dumps({'stage':'model validation','status':'complete','digest':source_digest()}))
