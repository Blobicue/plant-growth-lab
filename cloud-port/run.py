"""Serialized, bounded Linux engine launcher. Never runs Windows queue helpers."""
import argparse,fcntl,hashlib,json,os,resource,subprocess,time
from pathlib import Path
P=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('project',choices=['shared-atmosphere27','juvenile-allocation30','seedling-diagnostics28']);p.add_argument('script');p.add_argument('--timeout',type=int,default=600);p.add_argument('--gui',action='store_true');p.add_argument('--package',action='store_true');p.add_argument('args',nargs='*');a=p.parse_args()
def headroom():
    mem={s.split(':')[0]:int(s.split()[1])*1024 for s in Path('/proc/meminfo').read_text().splitlines()}
    c=Path('/sys/fs/cgroup');limit=(c/'memory.max').read_text().strip()
    return min(mem['MemAvailable'],int(limit)-int((c/'memory.current').read_text())) if limit!='max' else mem['MemAvailable']
with open(f'/tmp/plant-growth-lab-linux-{os.getuid()}.lock','w') as lock:
    deadline=time.monotonic()+600
    while True:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);break
        except BlockingIOError:
            if time.monotonic()>deadline:raise SystemExit('600s ownership wait exceeded')
            time.sleep(.2)
    while headroom()<8*1024**3:
        if time.monotonic()>deadline:raise SystemExit('8GiB free headroom unavailable')
        time.sleep(.2)
    env=os.environ.copy();env.update(XDG_CACHE_HOME=str(P/'cache'),XDG_DATA_HOME=str(P/'data'),GODOT_SILENCE_ROOT_WARNING='1')
    cmd=[str(P/'toolchain/Godot_v4.7.2-stable_linux.x86_64'),'--headless','--path',str(P/'work'/a.project),'--script','res://'+a.script]
    if a.package:
        cmd[cmd.index('--path')+1]=str(P/'packages'/a.project);cmd+=['--main-pack',str(P/'packages'/a.project/'lab.pck')]
    if a.gui:
        cmd.remove('--headless');cmd+=['--display-driver','x11','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--audio-driver','Dummy'];env.update(DISPLAY=':99',LIBGL_ALWAYS_SOFTWARE='1')
    if a.args:cmd+=['--']+a.args
    tag=a.project+('-package' if a.package else '')+'-'+Path(a.script).stem+('-'+'-'.join(Path(arg).name for arg in a.args) if a.args else '')
    project_path=Path(cmd[cmd.index('--path')+1])
    inputs={str(f.relative_to(project_path)):hashlib.sha256(f.read_bytes()).hexdigest() for f in project_path.rglob('*') if f.is_file() and '.godot' not in f.parts and f.suffix in ['.gd','.c','.h','.gdextension','.godot','.so','.pck']}
    start=time.monotonic();initial=headroom();lowest=initial;peak=0;reason=None
    with open(P/'evidence'/f'{tag}.log','w') as log:
        proc=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,env=env)
        while proc.poll() is None:
            remaining=headroom();lowest=min(lowest,remaining)
            try:
                status=Path(f'/proc/{proc.pid}/status').read_text().splitlines()
                peak=max(peak,max(int(s.split()[1])*1024 for s in status if s.startswith(('VmRSS:','VmHWM:'))))
            except (FileNotFoundError,ValueError):pass
            if 'SCRIPT ERROR:' in (P/'evidence'/f'{tag}.log').read_text():reason='script error'
            if remaining<8*1024**3:reason='8GiB headroom guard'
            if time.monotonic()-start>a.timeout:reason='timeout'
            if reason:
                proc.terminate()
                try:proc.wait(5)
                except subprocess.TimeoutExpired:proc.kill();proc.wait()
                break
            time.sleep(.1)
    report={'command':cmd,'input_sha256':inputs,'exit':proc.returncode,'stop_reason':reason,'wall_seconds':time.monotonic()-start,'peak_rss_bytes':max(peak,resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024),'initial_headroom_bytes':initial,'minimum_headroom_bytes':lowest}
    (P/'evidence'/f'{tag}.runtime.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='input_sha256'}));fcntl.flock(lock,fcntl.LOCK_UN);time.sleep(.25);raise SystemExit(proc.returncode or (1 if reason else 0))
