"""Narrow same-user coupled-field lab adapter. No install, sockets, credentials or registration.
CLI: python adapter.py status | step | run --target 56
MCP compatibility: python adapter.py --stdio (protocol2025-11-25).
The host must separately authorize/register a stdio server; this file does not.
"""
import argparse,json,os,pathlib,sys,time,uuid
DEFAULT=pathlib.Path(os.environ.get('APPDATA',str(pathlib.Path.home())))/'BlobusPlantJuvenile30/juvenile30/control'
TOOLS={
 'status':('Read this enabled window and run.',{}),
 'pause':('Pause visible work without resetting.',{}),
 'stop':('Cancel work and revoke local control.',{}),
 'step':('Advance one visible fixed tick.',{}),
 'run':('Schedule visible bounded growth, returning immediately.',{'target':{'type':'integer','minimum':1,'maximum':12288}}),
 'scenario':('Reset both visible plants to a named paired comparison.',{'carbon_access':{'type':'integer','minimum':0,'maximum':1},'decomposition':{'type':'integer','minimum':0,'maximum':1},'recycling':{'type':'integer','minimum':0,'maximum':1},'radiation':{'type':'integer','minimum':0,'maximum':2},'lifecycle':{'type':'integer','minimum':0,'maximum':3},'scenario':{'type':'integer','minimum':0,'maximum':5},'backend':{'type':'integer','minimum':0,'maximum':1},'seed':{'type':'integer','minimum':0,'maximum':999999}}),
 'inspect':('Highlight a funded cell in the watched window.',{'world':{'type':'integer','minimum':0,'maximum':31},'cell':{'type':'integer','minimum':0,'maximum':511}}),
 'save':('Save this run, measurements and exact replay under its run ID.',{}),
 'replay':('Pace the loaded/saved run visibly against its exact fingerprint.',{})}
def read(path,limit=2_000_000):
 deadline=time.monotonic()+1
 while True:
  try:
   if path.stat().st_size>limit:raise ValueError('Oversized adapter response')
   return json.loads(path.read_text(encoding='utf-8-sig'))
  except (FileNotFoundError,PermissionError):
   if time.monotonic()>=deadline:raise
   time.sleep(.01)

def atomic(path,data):
 temporary=path.with_suffix(path.suffix+'.client-tmp')
 temporary.write_text(json.dumps(data,allow_nan=False),encoding='utf-8')
 deadline=time.monotonic()+2
 while True:
  try:os.replace(temporary,path);return
  except PermissionError:
   if time.monotonic()>=deadline:raise
   time.sleep(.01)
def call(command,args=None,base=DEFAULT,caller='cli',request_id=None):
 if command not in TOOLS:raise ValueError('Unsupported command')
 args={} if args is None else args
 schema=TOOLS[command][1]
 if not isinstance(args,dict) or set(args)!=set(schema):raise ValueError('Invalid tool arguments')
 for key,rule in schema.items():
  value=args[key]
  if type(value) is not int or not rule['minimum']<=value<=rule['maximum']:raise ValueError('Invalid '+key)
 base=pathlib.Path(base).resolve();active=read(base/'active.json',32768)
 if not active.get('enabled') or time.time()-active.get('heartbeat',0)>5:raise ValueError('App control is off or its heartbeat expired; enable it in the window')
 instance=active.get('instance_id','')
 if not isinstance(instance,str) or not instance.startswith('session-') or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in instance):raise ValueError('Invalid instance identity')
 folder=(base/instance).resolve()
 if folder.parent!=base or pathlib.Path(active.get('folder','')).resolve()!=folder:raise ValueError('Invalid adapter directory')
 identifier=request_id or uuid.uuid4().hex
 request={'request_id':identifier,'instance_id':instance,'run_id':active['run_id'],'expected_tick':active['tick'],'command':command,'args':args,'created_at':time.time(),'caller':caller}
 lock=folder/'client.lock'
 try:fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
 except FileExistsError:raise ValueError('Another local command is pending')
 try:
  os.close(fd);atomic(folder/'request.json',request);deadline=time.monotonic()+4
  while time.monotonic()<deadline:
   try:
    answer=read(folder/'response.json')
    if answer.get('request_id')==identifier:return answer
   except (OSError,ValueError):pass
   time.sleep(.025)
  raise TimeoutError('App did not acknowledge the request; it may be closed or disconnected')
 finally:lock.unlink(missing_ok=True)
def tool_list():
 return [{'name':'plant_'+name,'description':description,'inputSchema':{'type':'object','properties':properties,'required':list(properties),'additionalProperties':False},'annotations':{'readOnlyHint':name=='status','destructiveHint':name=='scenario','idempotentHint':name in ['status','pause','stop'],'openWorldHint':False}} for name,(description,properties) in TOOLS.items()]
def stdio(base):
 # Deliberately pinned compatibility binding, not a latest-protocol claim.
 for line in sys.stdin:
  message=None
  try:
   if len(line)>32768:raise ValueError('Request too large')
   message=json.loads(line)
   if not isinstance(message,dict) or message.get('jsonrpc')!='2.0':raise ValueError('Invalid JSON-RPC envelope')
   identifier=message.get('id');method=message.get('method');params=message.get('params',{})
   if not isinstance(params,dict):raise ValueError('Invalid params')
   if identifier is None:continue
   if method=='initialize':result={'protocolVersion':'2025-11-25','capabilities':{'tools':{'listChanged':False}},'serverInfo':{'name':'plant-workstation-local','version':'1.0.0'},'instructions':'Local app must explicitly enable control. Same-user file IPC; no network. Commands operate only on that visible instance. Stop revokes access.'}
   elif method=='ping':result={}
   elif method=='tools/list':result={'tools':tool_list()}
   elif method=='tools/call':
    name=params.get('name','')
    if not isinstance(name,str) or not name.startswith('plant_'):raise ValueError('Unknown tool')
    try:
     answer=call(name[6:],params.get('arguments',{}),base,'mcp')
     result={'content':[{'type':'text','text':json.dumps(answer)}],'structuredContent':answer,'isError':not answer.get('ok',False)}
    except (OSError,ValueError,TimeoutError) as exc:result={'content':[{'type':'text','text':str(exc)}],'isError':True}
   else:
    print(json.dumps({'jsonrpc':'2.0','id':identifier,'error':{'code':-32601,'message':'Method not found'}}),flush=True);continue
   print(json.dumps({'jsonrpc':'2.0','id':identifier,'result':result}),flush=True)
  except (ValueError,TypeError,KeyError) as exc:
   print(json.dumps({'jsonrpc':'2.0','id':message.get('id') if isinstance(message,dict) else None,'error':{'code':-32600,'message':str(exc)}}),flush=True)
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('command',nargs='?',choices=list(TOOLS));parser.add_argument('--stdio',action='store_true');parser.add_argument('--directory',type=pathlib.Path,default=DEFAULT);parser.add_argument('--target',type=int);parser.add_argument('--scenario',type=int);parser.add_argument('--seed',type=int);parser.add_argument('--backend',type=int);parser.add_argument('--lifecycle',type=int);parser.add_argument('--radiation',type=int);parser.add_argument('--decomposition',type=int);parser.add_argument('--carbon-access',dest='carbon_access',type=int);parser.add_argument('--recycling',type=int);parser.add_argument('--world',type=int);parser.add_argument('--cell',type=int)
 a=parser.parse_args()
 if a.stdio:stdio(a.directory);return
 if not a.command:parser.error('Choose a command or --stdio')
 args={key:getattr(a,key) for key in TOOLS[a.command][1]}
 try:answer=call(a.command,args,a.directory);print(json.dumps(answer,indent=2));sys.exit(0 if answer.get('ok') else 2)
 except (OSError,ValueError,TimeoutError) as exc:print(json.dumps({'ok':False,'error':str(exc)}));sys.exit(2)
if __name__=='__main__':main()

