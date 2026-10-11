"""Build declared access-only counterfactuals in the isolated project, never production."""
from pathlib import Path
import difflib
P=Path(__file__).resolve().parent;W=P/'work/candidate30'
s=(W/'world.gd').read_text();needle='   if not demands.has(index):demands[index]=[]'
assert s.count(needle)==1
injection='''   # Diagnostic access gates only. No transfer, rate/cost/gene edits or added resource.
   if diagnostic_arm==1 and p.plant_id!=diagnostic_target:want[1]=0
   if diagnostic_arm==2 and p.plant_id!=diagnostic_target:want[0]=0
   if diagnostic_arm==3 and p.plant_id==diagnostic_target:want[1]=0
'''
control=s.replace('extends RefCounted\n','extends RefCounted\nvar diagnostic_arm=0\nvar diagnostic_target=-1\n',1).replace(needle,injection+needle)
(W/'control_world.gd').write_text(control)
(W/'control_state.gd').write_text((W/'state.gd').read_text().replace('preload("res://world.gd")','preload("res://control_world.gd")'))
(P/'evidence/control-source.diff').write_text(''.join(difflib.unified_diff(s.splitlines(True),control.splitlines(True),fromfile='unchanged_world.gd',tofile='control_world.gd')))
