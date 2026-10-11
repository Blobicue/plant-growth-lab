"""Isolate R1; no existing model/evidence modifications. Refuse overwrite."""
from pathlib import Path
import shutil,difflib
P=Path(__file__).resolve().parent;R=P.parent;src=R/'cloud-transport/work/candidate30';dst=P/'work/candidate30'
assert not dst.exists(),dst
shutil.copytree(src,dst,ignore=shutil.ignore_patterns('.godot','evidence','golden','diagnostic*','diagnose*','*.log'));(dst/'evidence').mkdir()
for f in (P/'scripts').glob('*.gd'):shutil.copy2(f,dst/f.name)
diffs=[]
def write(name,text):
 f=dst/name;before=f.read_text();assert before!=text,name;f.write_text(text)
 diffs.append(''.join(difflib.unified_diff(before.splitlines(True),text.splitlines(True),fromfile='T1/'+name,tofile='R1/'+name)))
def scoped(s,start,end,old,new):
 a=s.index(start);b=s.index(end,a);chunk=s[a:b];assert old in chunk,(start,old);return s[:a]+chunk.replace(old,new)+s[b:]
s=(dst/'legacy/model.gd').read_text();s=s.replace('extends RefCounted\n','extends RefCounted\nconst NumericalOrder=preload("res://reduction_order.gd")\n',1)
s=scoped(s,'func maintain()','func moisture_gradient',' for node in nodes:\n',' for canonical_id in NumericalOrder.ids(self):\n  var node=nodes[canonical_id]\n')
s=scoped(s,'func ledger()','func max_error',' for node in nodes:\n',' for canonical_id in NumericalOrder.ids(self):\n  var node=nodes[canonical_id]\n')
s=scoped(s,'func metrics()','func fingerprint',' for n in nodes:\n',' for canonical_id in NumericalOrder.ids(self):\n  var n=nodes[canonical_id]\n');write('legacy/model.gd',s)
s=(dst/'base_plant.gd').read_text();s=s.replace(' var total=0.0\n for want in photo_demands():total+=want',' var total=0.0;var wants=photo_demands()\n for i in NumericalOrder.ids(self):total+=wants[i]')
s=scoped(s,'func photosynthesize()','func prepare_growth',' for i in nodes.size():',' for i in NumericalOrder.ids(self):');write('base_plant.gd',s)
s=(dst/'reserve.gd').read_text().replace('extends RefCounted\n','extends RefCounted\nconst NumericalOrder=preload("res://reduction_order.gd")\n',1)
s=s.replace(' for n in p.nodes:\n',' for canonical_id in NumericalOrder.ids(p):\n  var n=p.nodes[canonical_id]\n').replace(' for i in p.nodes.size():',' for i in NumericalOrder.ids(p):');write('reserve.gd',s)
s=(dst/'world.gd').read_text().replace('extends RefCounted\n','extends RefCounted\nconst NumericalOrder=preload("res://reduction_order.gd")\n',1)
s=s.replace('  p.tick=tick;p._connections()','  p.tick=tick;p._connections();var stable_ranks=NumericalOrder.ranks(p)')
s=s.replace('"key":p.plant_id*512+id','"key":p.plant_id*512+stable_ranks[id]')
s=scoped(s,'func audit_sample(','func radiation_report','  for n in p.nodes:\n','  for canonical_id in NumericalOrder.ids(p):\n   var n=p.nodes[canonical_id]\n')
s=scoped(s,'func hydrology_report(', 'func decomposition_report(', '  for n in p.nodes:\n','  for canonical_id in NumericalOrder.ids(p):\n   var n=p.nodes[canonical_id]\n')
s=s.replace('  for node in p.nodes:c.mobile', '  for canonical_id in NumericalOrder.ids(p):\n   var node=p.nodes[canonical_id];c.mobile');write('world.gd',s)
(P/'evidence/reduction-source.diff').write_text(''.join(diffs))
# Reuse reference files transparently; they remain archived old numerical results.
for f in (R/'cloud-transport/evidence').glob('trial-*.json'):shutil.copy2(f,dst/'evidence'/f.name)
print(dst)
