"""Recreate only the preserved old numeric project for the named quantum diagnostic."""
from pathlib import Path
import shutil
P=Path(__file__).resolve().parent;src=P.parent/'cloud-transport/work/candidate30';dst=P/'work/legacy_numeric'
assert not dst.exists(),f'Refusing to overwrite {dst}'
shutil.copytree(src,dst,ignore=shutil.ignore_patterns('.godot','evidence','golden','*.log'));(dst/'evidence').mkdir()
shutil.copy2(P/'scripts/quantum_outcomes.gd',dst/'quantum_outcomes.gd')
print(dst)
