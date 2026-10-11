"""Independent graph diffusion reference; no plant simulation or biological tuning."""
from pathlib import Path
import json, numpy as np
P=Path(__file__).resolve().parent
rng=np.random.default_rng(73419); cases=[]
graphs=[]
for degree in [1,2,4,6,16,64]:graphs.append((f'star{degree}',degree+1,[(0,i) for i in range(1,degree+1)]))
for n in [3,7,20]:
 graphs.append((f'chain{n}',n,[(i,i+1) for i in range(n-1)]))
 graphs.append((f'cycle{n}',n,[(i,(i+1)%n) for i in range(n)]))
graphs += [('disconnected',8,[(0,1),(1,2),(3,4)]),('isolated',4,[])]
def advance(x,edges,g,keys,steps):
 pairs=sorted([(min(a,b,key=lambda i:keys[i]),max(a,b,key=lambda i:keys[i]),rate) for (a,b),rate in zip(edges,g)],key=lambda t:keys[t[0]]+'|'+keys[t[1]])
 rows=np.zeros(len(x))
 for a,b,k in pairs:rows[a]+=k;rows[b]+=k
 n=max(steps,1+int(np.floor(max(rows,default=0))));retain=1-rows/n
 for _ in range(n):
  before=x;x=before*retain[:,None]
  for a,b,k in pairs:x[b]+=k/n*before[a];x[a]+=k/n*before[b]
 return x,n
for name,n,edges in graphs:
 for profile in ['depleted','heterogeneous','uniform','tiny','zero']:
  keys=[f'vertex-{i:04}' for i in range(n)]
  health=np.ones(n) if profile in ['depleted','uniform'] else rng.uniform(.05,1,n)
  g=np.array([.72*min(health[a],health[b]) for a,b in edges]);g[::7]=0 if profile=='heterogeneous' else g[::7]
  x=np.zeros((n,3));x[0]=[1,.17,2]
  if profile in ['heterogeneous','tiny']:x=rng.uniform(0,1,(n,3));x[::3]=0
  if profile=='uniform':x[:]=[.001,.2,.03]
  if profile=='tiny':x*=1e-18
  if profile=='zero':x[:]=0
  L=np.zeros((n,n))
  for (a,b),k in zip(edges,g):L[a,a]+=k;L[b,b]+=k;L[a,b]-=k;L[b,a]-=k
  lam,V=np.linalg.eigh(L);exact=V@(np.exp(-lam)[:,None]*(V.T@x))
  errors={};outputs={};effective={}
  for steps in [3,6,12,24,48,96]:
   y,eff=advance(x.copy(),edges,g,keys,steps);outputs[str(steps)]=y.tolist();effective[str(steps)]=eff
   errors[str(steps)]=[float(np.abs(y[:,c]-exact[:,c]).sum()/x[:,c].sum()) if x[:,c].sum()>0 else 0 for c in range(3)]
  assert max(errors['24'])<=.02,(name,profile,errors)
  assert all(errors['96'][c]<=errors['48'][c]+1e-12 and errors['48'][c]<=errors['24'][c]+1e-12 for c in range(3))
  cases.append(dict(name=name+'-'+profile,values=x.tolist(),edges=edges,rates=g.tolist(),keys=keys,expected24=outputs['24'],expected_steps=effective['24'],normalized_l1_errors=errors,effective_steps=effective))
result={'fixture_count':len(cases),'fixed_random_seed':73419,'nominal_conductance_per_hour':.72,'max24_normalized_l1_error':max(max(c['normalized_l1_errors']['24']) for c in cases),'cases':cases,'biological_parameters_tuned':False}
(P/'evidence/fixtures.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='cases'}))
