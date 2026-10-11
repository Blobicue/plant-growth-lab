"""Isolated read-only-source preflight project. Refuse overwrite."""
from pathlib import Path
import shutil
P=Path(__file__).resolve().parent; R=P.parent
src=R/'cloud-diagnostics/work/candidate30'; dst=P/'work/candidate30'
assert not dst.exists(),dst
shutil.copytree(src,dst,ignore=shutil.ignore_patterns('.godot','evidence','golden','control*.gd','*.log'))
(dst/'evidence').mkdir()
for f in (P/'scripts').glob('*.gd'):shutil.copy2(f,dst/f.name)
print(dst)
