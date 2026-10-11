"""Run frozen F1 serially; recover timed slices only with verified day progress."""
from pathlib import Path
import json,hashlib,subprocess,shutil,gzip,time
P=Path(__file__).resolve().parent;R=P.parent;E=P/'evidence';W=P/'work/model/evidence';M=json.loads((P/'manifest.json').read_text())
assert hashlib.sha256((R/'cloud-budget/NEXT-EXPERIMENT.txt').read_bytes()).hexdigest()==M['frozen_protocol_sha256']
assert json.loads((W/'preflight.json').read_text())['pass']
shutil.copy2(W/'preflight.json',E/'preflight.json');(E/'attempts').mkdir(exist_ok=True);(E/'runs').mkdir(exist_ok=True)
def invoke(script,args,timeout):
 tag='model-'+Path(script).stem+('-'+'-'.join(map(str,args)) if args else '')
 n=len(list((E/'attempts').glob(tag+'-*.runtime.json')))+1
 print('START',tag,'attempt',n,'timeout',timeout,flush=True)
 rc=subprocess.run(['python3',str(P/'run.py'),'--timeout',str(timeout),'model',script,*map(str,args)]).returncode
 for suffix in ['log','runtime.json']:
  src=E/(tag+'.'+suffix)
  if src.exists():shutil.copy2(src,E/'attempts'/f'{tag}-{n:02d}.{suffix}')
 report=json.loads((E/(tag+'.runtime.json')).read_text());return rc,report
for seed in M['seeds']:
 for mode in M['modes']:
  name=f'f1-{seed}-{mode}';d=W/name
  spent=sum(json.loads(f.read_text())['wall_seconds'] for f in (E/'attempts').glob(f'model-f1-{seed}-{mode}-*.runtime.json'))
  while not (d/'complete.json').exists():
   before=json.loads((d/'latest.json').read_text())['tick'] if (d/'latest.json').exists() else 0
   remaining=1800-spent
   assert remaining>1,('primary1800s bound exhausted',name,before,spent)
   rc,report=invoke('f1.gd',[seed,mode],max(1,int(min(600,remaining))));spent+=report['wall_seconds']
   after=json.loads((d/'latest.json').read_text())['tick'] if (d/'latest.json').exists() else 0
   if rc:
    assert report['stop_reason']=='timeout' and after>before and spent<1800,('stop; no correctness/resource failure bypass',name,report,after)
    print('RECOVER TIMED SLICE',name,'completed tick',after,'cumulative seconds',spent,flush=True)
  complete=json.loads((d/'complete.json').read_text());assert complete['complete'] and complete['tick']==12288 and not complete['error'] and not complete['censored']
  target=E/'runs'/name;target.mkdir(exist_ok=True)
  for name2 in ['initial.json','complete.json']:shutil.copy2(d/name2,target/name2)
  daily=sorted(d.glob('day-*.json'));assert len(daily)==512
  with gzip.GzipFile(filename=str(target/'daily.jsonl.gz'),mode='wb',mtime=0) as out:
   for f in daily:out.write(f.read_bytes()+b'\n')
  births=[json.loads(f.read_text()) for f in sorted(d.glob('birth-*.json'))];(target/'births.json').write_text(json.dumps(births,indent=2)+'\n')
  states={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(d.glob('*.bin'))};(target/'checkpoint-sha256.json').write_text(json.dumps(states,indent=2)+'\n')
  for fn in ['state-06144.bin','state-12288.bin']:
   shutil.copy2(d/fn,target/fn)
  print('PRIMARY COMPLETE',seed,mode,'wall',spent,'plants',len(complete['plants']),flush=True)
  for kind in ['restart','canonical'] if mode else ['restart']:
   vf=f'verify-{seed}-{mode}-{kind}.json'
   if not (W/vf).exists():
    rc,report=invoke('verify_f1.gd',[seed,mode,kind],300);assert rc==0,(vf,report)
   v=json.loads((W/vf).read_text());assert v.get('pass') or v.get('available') is False;shutil.copy2(W/vf,E/vf)
   print('VERIFIED',vf,flush=True)
print('ALL SIX F1 TRAJECTORIES COMPLETE',flush=True)
