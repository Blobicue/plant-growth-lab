"""Fetch a matching official engine with vendor checksum verification; no credentials."""
from pathlib import Path
import hashlib,subprocess,zipfile
P=Path(__file__).resolve().parent
T=P/'toolchain';T.mkdir(exist_ok=True)
BASE='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/'
NAME='Godot_v4.7.2-stable_linux.x86_64'
for remote,local in [(NAME+'.zip','godot.zip'),('SHA512-SUMS.txt','SHA512-SUMS.txt')]:
 if not (T/local).exists():subprocess.run(['curl','-fL','--max-time','120',BASE+remote,'-o',str(T/local)],check=True)
expected=next(line.split()[0] for line in (T/'SHA512-SUMS.txt').read_text().splitlines() if line.endswith(NAME+'.zip'))
actual=hashlib.sha512((T/'godot.zip').read_bytes()).hexdigest()
if actual!=expected:raise SystemExit('Official archive checksum mismatch')
with zipfile.ZipFile(T/'godot.zip') as z:
 if z.namelist()!=[NAME]:raise SystemExit('Unexpected official archive layout')
 if not (T/NAME).exists():z.extractall(T)
 elif hashlib.sha512((T/NAME).read_bytes()).digest()!=hashlib.sha512(z.read(NAME)).digest():raise SystemExit("Installed engine differs from verified archive")
(T/NAME).chmod(0o755)
(P/'evidence').mkdir(exist_ok=True)
print('Verified official Godot archive:',actual)
