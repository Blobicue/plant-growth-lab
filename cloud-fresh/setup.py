"""Build isolated F1 observer; all numerical/biological modules unchanged."""
from pathlib import Path
import shutil,hashlib,json,difflib
P=Path(__file__).resolve().parent;R=P.parent;src=R/'cloud-reductions/work/candidate30';dst=P/'work/model';assert not dst.exists()
shutil.copytree(src,dst,ignore=shutil.ignore_patterns('.godot','evidence','golden','*.log'));(dst/'evidence').mkdir()
s=(dst/'plant.gd').read_text();old=s
# Widen passive budget/event observation to founders; inherited equations unchanged.
s=s.replace('if generation>0:', 'if true:').replace('if generation>0 else []','if true else []').replace('if generation>0 and ','if ')
s=s.replace('var obs_hour={}\n','var obs_hour={}\nvar f1_total={}\nvar f1_windows={"0_96":{},"0_768":{},"576_768":{}}\nvar f1_fronts=[]\nvar f1_calls=[]\nvar f1_record=false\n',1)
s=s.replace(' var paid=super.respire(n,amount)\n',' var paid=super.respire(n,amount)\n if f1_record:f1_calls.append({"position":n.pos,"paid":paid})\n')
s=s.replace('var before=nodes.duplicate(true) if true else [];super.maintain()','var before=nodes.duplicate(true);f1_calls=[];f1_record=true;super.maintain();f1_record=false\n var cursor=0;var upkeep=0.0;var recovery=0.0\n for i in NumericalOrder.ids(self):\n  var old=before[i]\n  if not old.active:continue\n  var demand=old.solid_c*UPKEEP[old.kind]*(1+1.8*(1-old.w/(old.w+.002)));var required=demand*.65\n  assert(f1_calls[cursor].position==old.pos);var paid=float(f1_calls[cursor].paid);upkeep+=paid;cursor+=1\n  var damage=(required-paid)/required if required>0 else 0.0\n  if damage<1e-10 and old.stress+damage>0 and required>0:\n   assert(f1_calls[cursor].position==old.pos);recovery+=float(f1_calls[cursor].paid);cursor+=1\n var tip=0.0\n for i in range(cursor,f1_calls.size()):tip+=float(f1_calls[i].paid)\n obs_hour.upkeep_respired_C=upkeep;obs_hour.stress_recovery_C=recovery;obs_hour.tip_respired_C=tip\n assert(absf(upkeep+recovery+tip-obs_hour.direct_respired_C)<1e-12)')
s=s.replace('"path_size":p.path.size()', '"path_size":p.path.size(),"payment_local":nodes[p.front].duplicate(true),"pools":pools()')
s=s.replace(' obs_seen[key]=true;obs_events.append', ''' if data.has("local"):
  var kind=data.get("kind",data.get("before",{}).get("kind",""));var cost={"c":PACK[kind]/(.8 if kind=="leaf" else 1.0),"n":PACK[kind]*NR[kind],"w":PACK[kind]*.3};var short=[]
  for k in cost:
   if data.local[k]<cost[k]:short.append(k)
  data["actual_short_at_record"]=short;data["cost_at_record"]=cost
 obs_seen[key]=true;obs_events.append''')
s=s.replace(' for k in obs_hour:obs_day[k]=float(obs_day.get(k,0.0))+obs_hour[k]', ''' for k in obs_hour:
  obs_day[k]=float(obs_day.get(k,0.0))+obs_hour[k];f1_total[k]=float(f1_total.get(k,0.0))+obs_hour[k]
  var age=tick-birth_tick
  for window in f1_windows:
   var limits=window.split("_")
   if age>int(limits[0]) and age<=int(limits[1]):f1_windows[window][k]=float(f1_windows[window].get(k,0.0))+obs_hour[k]
 if generation>0 and tick-birth_tick in [4,16]:
  var fs=[]
  for q in proposals:
   if q.state=="developing":fs.append({"kind":q.kind,"front":nodes[q.front].duplicate(true),"blocked_previous":q.blocked,"deadline":q.deadline,"pools":pools()})
  f1_fronts.append({"age":tick-birth_tick,"fronts":fs})''')
(dst/'plant.gd').write_text(s)
# Preserve observer state in saved restarts; the physical serialization is unchanged.
f=dst/'state.gd';ss=f.read_text().replace(',"obs_hour","obs_day","obs_events","obs_seen","obs_last_totals"','');f.write_text(ss)
for f in (P/'scripts').glob('*.gd'):shutil.copy2(f,dst/f.name)
(P/'evidence/observer-source.diff').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='R1/plant.gd',tofile='F1/plant.gd')))
mods={}
for f in src.rglob('*'):
 if f.is_file() and f.suffix in ['.gd','.so','.c','.h','.gdextension'] and f.name not in ['plant.gd','state.gd']:
  q=dst/f.relative_to(src)
  if q.exists():assert q.read_bytes()==f.read_bytes();mods[str(f.relative_to(src))]=hashlib.sha256(f.read_bytes()).hexdigest()
(P/'evidence/unchanged-modules.json').write_text(json.dumps(mods,indent=2)+'\n')
print(dst)
