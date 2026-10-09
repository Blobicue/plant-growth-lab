import desktop as d,time

def value(x,y,text):
 d.click(x,y);w=d.hwnd();d.u.SendMessageW(w,0x100,0x24,0);d.u.SendMessageW(w,0x101,0x24,0)
 for _ in range(20):d.u.SendMessageW(w,0x100,0x2e,0);d.u.SendMessageW(w,0x101,0x2e,0)
 for char in str(text):d.u.SendMessageW(w,0x102,ord(char),0)
 d.u.SendMessageW(w,0x100,0x0d,0);d.u.SendMessageW(w,0x101,0x0d,0);time.sleep(.2)
if __name__=='__main__':raise SystemExit('QA helper; import value from the scoped native test harness.')
