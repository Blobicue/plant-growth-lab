"""Read-only F1 adapter and isolated workstation build. Never rewrites source evidence."""
from pathlib import Path
import csv,gzip,hashlib,json,shutil,subprocess
P=Path(__file__).resolve().parent;R=P.parent;W=P/'work/model';F=R/'cloud-fresh';E=F/'evidence'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
if W.exists():raise SystemExit('Refusing to overwrite work/model; use sync_ui.py for UI-only updates.')
W.mkdir(parents=True);(W/'data').mkdir();(W/'evidence').mkdir()
source=F/'work/model'
files=[p for p in source.iterdir() if p.is_file() and p.suffix in ['.gd','.tscn','.godot','.txt']]
for p in files:shutil.copy2(p,W/p.name)
for name in ['legacy','native']:
 shutil.copytree(source/name,W/name,ignore=shutil.ignore_patterns('*.dll','*.exe','__pycache__'))
unchanged={str(p.relative_to(W)):sha(p) for p in W.rglob('*') if p.is_file()}
inputs={}
def track(p):inputs[str(p.relative_to(R))]=sha(p)
a=read(E/'analysis.json');track(E/'analysis.json');track(E/'audit.json');assert read(E/'audit.json')['pass']
runs=[]
for s in a['summaries']:
 seed,mode=s['seed'],s['mode'];name=f'f1-{seed}-{mode}';d=E/'runs'/name;out=W/'data'/name;out.mkdir()
 initial=read(d/'initial.json');track(d/'initial.json');track(d/'complete.json');track(d/'checkpoint-sha256.json')
 files={}
 for tick in [0,6144,12288]:
  p=d/f'state-{tick:05d}.bin';assert sha(p)==read(d/'checkpoint-sha256.json')[p.name]
  shutil.copy2(p,out/p.name);track(p);files[str(tick)]={'path':f'res://data/{name}/{p.name}','sha256':sha(p)}
 hashes={'0':initial['fingerprint']};days=[];track(d/'daily.jsonl.gz')
 with gzip.open(d/'daily.jsonl.gz','rt') as f:
  for line in f:
   day=json.loads(line);tick=day['tick']
   for i,h in enumerate(day['hashes']):hashes[str(tick-23+i)]=h
   # scalar environment rows are derived separately below; exact original hashes retained
 rows=[x for x in csv.DictReader((E/'environment-days.csv').open()) if int(x['seed'])==seed and int(x['mode'])==mode]
 track(E/'environment-days.csv')
 runs.append({'id':name,'seed':seed,'mode':mode,'contract':'Candidate30 + R1 / '+('ordered legacy transport' if mode==0 else 'T1 simultaneous transport, 24 substeps'),'horizon':12288,'summary':s,'plants':[p for p in a['plants'] if p['seed']==seed and p['mode']==mode],'states':files,'hashes':hashes,'daily_environment':rows,'source':str(d.relative_to(R))})
texts={}
for rel in ['cloud-fresh/REPORT.txt','cloud-fresh/SYNTHESIS.txt','cloud-port/REPORT.txt','cloud-budget/REPORT.txt','cloud-reductions/REPORT.txt']:
 p=R/rel;track(p);texts[rel]=p.read_text()
cat={'version':'workstation-f1-v1','evidence_commit':'5b92effb1b20e290d9fcbfdc24c55d7f2bbb80f8','science_commit':'5d3a8efaf70efaefefaa19329e8d069dfe9b54ee','runs':runs,'guard_summary':a['guard_summary'],'texts':texts,'source_sha256':inputs,'scope':'Six F1 runs; W27 and original candidate30 are provenance/report entries, not F1 binary adapters.'}
(W/'data/catalog.json').write_text(json.dumps(cat,separators=(',',':')))
(P/'evidence/adapter-manifest.json').write_text(json.dumps({'catalog_sha256':sha(W/'data/catalog.json'),'original_inputs':inputs,'copied_modules':unchanged,'source_runtime':str(source),'scope':cat['scope']},indent=2)+'\n')
subprocess.run(['python3',str(P/'sync_ui.py')],check=True)
print('Created isolated workstation; six F1 records, exact checkpoints and hourly hashes.')
