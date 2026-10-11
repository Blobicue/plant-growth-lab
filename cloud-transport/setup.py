"""Prepare isolated T1 project; refuse overwrite, preserve old science."""
from pathlib import Path
import shutil,difflib
P=Path(__file__).resolve().parent;R=P.parent;src=R/'cloud-diagnostics/work/candidate30';dst=P/'work/candidate30'
assert not dst.exists(),dst
shutil.copytree(src,dst,ignore=shutil.ignore_patterns('.godot','evidence','golden','control*.gd','*.log'));(dst/'evidence').mkdir()
for f in (P/'scripts').glob('*.gd'):shutil.copy2(f,dst/f.name)
s=(dst/'base_plant.gd').read_text();t=s+'''\n# Isolated T1 experiment: zero retains exact legacy dispatch.\nconst T1=preload("res://transport.gd")\nvar transport_substeps=0\nvar transport_last={}\nfunc transport_pools():\n if transport_substeps==0:super.transport_pools()\n else:transport_last=T1.apply(self,transport_substeps)\n''';(dst/'base_plant.gd').write_text(t)
u=(dst/'world.gd').read_text();v=u.replace('extends RefCounted\n','extends RefCounted\nvar transport_substeps=0\n',1).replace(' for p in order:p.transport_pools()',' for p in order:\n  p.transport_substeps=transport_substeps;p.transport_pools()');assert v!=u;(dst/'world.gd').write_text(v)
(P/'evidence/source.diff').write_text(''.join(difflib.unified_diff(s.splitlines(True),t.splitlines(True),fromfile='original/base_plant.gd',tofile='T1/base_plant.gd'))+''.join(difflib.unified_diff(u.splitlines(True),v.splitlines(True),fromfile='original/world.gd',tofile='T1/world.gd')))
print(dst)
