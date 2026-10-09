from pathlib import Path
import ctypes as c,json,datetime
ROOT=Path(__file__).resolve().parent
class M(c.Structure):_fields_=[('length',c.c_ulong),('load',c.c_ulong)]+[(n,c.c_ulonglong) for n in ['total','available','commit','freecommit','virtual','freevirtual','extended']]
def require_headroom(tag):
 m=M();m.length=c.sizeof(m);c.windll.kernel32.GlobalMemoryStatusEx(c.byref(m));data={'tag':tag,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'free_commit':m.freecommit,'required_commit':8*1024**3};(ROOT/'evidence'/f'{tag}-preflight.json').write_text(json.dumps(data,indent=2))
 with (ROOT/'evidence/memory-watch.jsonl').open('a') as f:f.write(json.dumps(data)+'\n')
 if m.freecommit<8*1024**3:raise SystemExit('BLOCKED: unchanged8GiB free-commit guard; no engine process started')
 return data
def source_digest():
 import hashlib
 h=hashlib.sha256()
 for p in sorted(ROOT.rglob('*')):
  rel=p.relative_to(ROOT)
  if p.is_file() and rel.parts[0] not in ['evidence','windows','build-source','.godot','__pycache__'] and p.suffix in ['.gd','.py','.godot','.tscn','.txt','.dll','.gdextension']:
   h.update(str(rel).replace('\\','/').encode())
   with p.open('rb') as f:
    for chunk in iter(lambda:f.read(262144),b''):h.update(chunk)
 return h.hexdigest()
def require_model_evidence():
 digest=source_digest()
 for mode in ['tests','matrix','parity','fixture']:
  run=json.loads((ROOT/'evidence'/f'{mode}-run.json').read_text())
  assert run.get('complete') is True and run.get('source_digest')==digest,mode+' current-source evidence required'
 for name in ['model-tests.json','parity-tests.json','fixture-tests.json']:
  checks=json.loads((ROOT/'evidence'/name).read_text())['checks'];assert checks and all(x['pass'] for x in checks)
