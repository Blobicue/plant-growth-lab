from pathlib import Path
import subprocess,ctypes as c,json,sys,datetime
from preflight import source_digest
r=Path(__file__).resolve().parent
mode=sys.argv[1] if len(sys.argv)>1 else 'tests'
scripts={'tests':'tests.gd','matrix':'matrix.gd','parity':'parity.gd','negative':'negative.gd','fixture':'fixture.gd'}
if mode not in scripts:raise SystemExit('Choose tests, matrix, parity or negative')
class M(c.Structure):_fields_=[('length',c.c_ulong),('load',c.c_ulong)]+[(n,c.c_ulonglong) for n in ['total','available','commit','freecommit','virtual','freevirtual','extended']]
m=M();m.length=c.sizeof(m);c.windll.kernel32.GlobalMemoryStatusEx(c.byref(m))
status={'mode':mode,'free_commit':m.freecommit,'required_commit':8*1024**3,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(r/'evidence'/f'{mode}-preflight.json').write_text(json.dumps(status,indent=2))
with (r/'evidence/memory-watch.jsonl').open('a') as f:f.write(json.dumps(status)+'\n')
if m.freecommit<8*1024**3:raise SystemExit('BLOCKED: unchanged8GiB free-commit guard; no model process started')
status['source_digest']=source_digest();status['complete']=False
(r/'evidence'/f'{mode}-run.json').write_text(json.dumps(status,indent=2))
engine=r.parent.parent/'elemental-voxel-lab/artifacts/godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
args=[str(engine),'--path',str(r),'--script','res://'+scripts[mode]]
if mode!='parity':args.insert(1,'--headless')
with (r/'evidence'/f'{mode}-out.txt').open('w') as out,(r/'evidence'/f'{mode}-err.txt').open('w') as err:
 p=subprocess.run(args,stdout=out,stderr=err,timeout=3600 if mode=='matrix' else 2400,creationflags=0x08000000)
status['exit']=p.returncode;status['complete']=p.returncode==0 and not (r/'evidence'/f'{mode}-err.txt').read_text().strip() and status['source_digest']==source_digest();(r/'evidence'/f'{mode}-run.json').write_text(json.dumps(status,indent=2))
assert p.returncode==0 and not (r/'evidence'/f'{mode}-err.txt').read_text().strip()
print(json.dumps(status))
