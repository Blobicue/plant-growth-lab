import ctypes as c,time,json,pathlib,importlib.util,sys
from PIL import ImageGrab
root=pathlib.Path(__file__).resolve().parent;e=root/'evidence';pid=int((e/'ui-pid.txt').read_text(encoding='utf-8-sig'));u=c.windll.user32;u.GetForegroundWindow.restype=c.c_void_p
for name,args in [('GetWindowThreadProcessId',[c.c_void_p,c.c_void_p]),('IsWindowVisible',[c.c_void_p]),('GetWindowRect',[c.c_void_p,c.c_void_p]),('SetForegroundWindow',[c.c_void_p]),('ShowWindow',[c.c_void_p,c.c_int]),('SendMessageW',[c.c_void_p,c.c_uint,c.c_size_t,c.c_ssize_t]),('PostMessageW',[c.c_void_p,c.c_uint,c.c_size_t,c.c_ssize_t])]:getattr(u,name).argtypes=args
u.SendMessageW.restype=c.c_ssize_t
spec=importlib.util.spec_from_file_location('adapter',root/'tools/adapter.py');adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
def hwnd():
 found=[]
 @c.WINFUNCTYPE(c.c_bool,c.c_void_p,c.c_void_p)
 def cb(w,l):
  v=c.c_ulong();u.GetWindowThreadProcessId(w,c.byref(v))
  if v.value==pid and u.IsWindowVisible(w):found.append(w)
  return True
 u.EnumWindows(cb,0)
 if not found:raise RuntimeError('intended app absent')
 return found[0]
def capture(name):
 w=hwnd();u.ShowWindow(w,9);time.sleep(.5);capture_window(w,name)

def click(x,y):
 w=hwnd();at=x+(y<<16);u.SendMessageW(w,0x201,1,at);u.SendMessageW(w,0x202,0,at);time.sleep(.3)
def call(name,args=None):
 r=adapter.call(name,args or {},adapter.DEFAULT,'qa')
 if not r['ok']:raise RuntimeError(r)
 return r['state']
def wait():
 end=time.monotonic()+180
 while time.monotonic()<end:
  s=call('status')
  if s['paused']:return s
  time.sleep(.25)
 raise TimeoutError('visible run exceeded180s')
def capture_window(w,name):
 # Focus may be owned by the desktop transport. Print only this authorized HWND.
 from PIL import Image
 g=c.windll.gdi32
 u.GetDC.argtypes=[c.c_void_p];u.GetDC.restype=c.c_void_p;u.ReleaseDC.argtypes=[c.c_void_p,c.c_void_p]
 u.PrintWindow.argtypes=[c.c_void_p,c.c_void_p,c.c_uint];u.PrintWindow.restype=c.c_int
 for fn,args in [('CreateCompatibleDC',[c.c_void_p]),('CreateCompatibleBitmap',[c.c_void_p,c.c_int,c.c_int]),('SelectObject',[c.c_void_p,c.c_void_p])]:
  getattr(g,fn).argtypes=args;getattr(g,fn).restype=c.c_void_p
 g.DeleteObject.argtypes=[c.c_void_p];g.DeleteDC.argtypes=[c.c_void_p]
 g.GetDIBits.argtypes=[c.c_void_p,c.c_void_p,c.c_uint,c.c_uint,c.c_void_p,c.c_void_p,c.c_uint]
 rect=(c.c_long*4)();u.GetWindowRect(w,c.byref(rect));width=rect[2]-rect[0];height=rect[3]-rect[1]
 dc=u.GetDC(w);mem=g.CreateCompatibleDC(dc);bitmap=g.CreateCompatibleBitmap(dc,width,height);old=g.SelectObject(mem,bitmap)
 class Header(c.Structure):_fields_=[('size',c.c_uint),('width',c.c_int),('height',c.c_int),('planes',c.c_ushort),('bits',c.c_ushort),('compression',c.c_uint),('image',c.c_uint),('xppm',c.c_int),('yppm',c.c_int),('colors',c.c_uint),('important',c.c_uint)]
 header=Header(c.sizeof(Header),width,-height,1,32,0,width*height*4,0,0,0,0);pixels=c.create_string_buffer(width*height*4)
 try:
  if not u.PrintWindow(w,mem,2):raise RuntimeError('Target-only PrintWindow failed')
  if not g.GetDIBits(mem,bitmap,0,height,pixels,c.byref(header),0):raise RuntimeError('Target-only bitmap unavailable')
  img=Image.frombytes('RGB',(width,height),pixels.raw,'raw','BGRX')
  if len(img.resize((100,100)).getcolors(10001) or [])<20:raise RuntimeError('Target-only capture appears blank')
  img.save(e/name);print('captured target HWND with PrintWindow',name,width,height)
 finally:g.SelectObject(mem,old);g.DeleteObject(bitmap);g.DeleteDC(mem);u.ReleaseDC(w,dc)

if __name__=='__main__':capture(sys.argv[1] if len(sys.argv)>1 else 'ui-fresh.png')
