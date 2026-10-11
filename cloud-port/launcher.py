"""Standalone guarded Linux package launcher; CPU simulation is the default."""
from pathlib import Path
import fcntl,json,os,resource,subprocess,sys,time
P=Path(__file__).resolve().parent

def headroom():
    avail=next(int(line.split()[1])*1024 for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemAvailable:'))
    c=Path('/sys/fs/cgroup');limit=(c/'memory.max').read_text().strip()
    return min(avail,int(limit)-int((c/'memory.current').read_text())) if limit!='max' else avail

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
    cmd=[str(P/'godot'),'--path',str(P),'--main-pack',str(P/'lab.pck'),'--rendering-method','gl_compatibility','--audio-driver','Dummy',*sys.argv[1:]]
    env=os.environ.copy();env.setdefault('XDG_CACHE_HOME',str(P/'cache'));env.setdefault('XDG_DATA_HOME',str(P/'data'))
    start=time.monotonic();lowest=headroom();reason=None
    proc=subprocess.Popen(cmd,env=env)
    try:
        while proc.poll() is None:
            lowest=min(lowest,headroom())
            if lowest<8*1024**3:reason='8GiB headroom guard'
            if time.monotonic()-start>600:reason='600s runtime limit; relaunch to continue saved replay'
            if reason:
                proc.terminate()
                try:proc.wait(5)
                except subprocess.TimeoutExpired:proc.kill();proc.wait()
                break
            time.sleep(.1)
    finally:
        if proc.poll() is None:proc.terminate();proc.wait()
    report={'command':cmd,'exit':proc.returncode,'stop_reason':reason,'wall_seconds':time.monotonic()-start,'peak_rss_bytes':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024,'minimum_headroom_bytes':lowest}
    (P/'evidence').mkdir(exist_ok=True);(P/'evidence/launcher-runtime.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
    raise SystemExit(proc.returncode or (1 if reason else 0))
