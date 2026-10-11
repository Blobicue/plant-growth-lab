"""Preserve portable selected states; all daily states remain locally retained."""
from pathlib import Path
import shutil,json,hashlib
P=Path(__file__).resolve().parent;E=P/'evidence';W=P/'work/model/evidence'
for seed in [12011,4242,7301]:
 for mode in [0,24]:
  name=f'f1-{seed}-{mode}';dst=E/'runs'/name;assert json.loads((dst/'complete.json').read_text())['complete']
  checks=json.loads((dst/'checkpoint-sha256.json').read_text())
  for n in ['state-00000.bin','state-06144.bin','state-12288.bin']+(['birth-2.bin'] if mode==24 and (W/name/'birth-2.bin').exists() else []):
   assert hashlib.sha256((W/name/n).read_bytes()).hexdigest()==checks[n];shutil.copy2(W/name/n,dst/n)
