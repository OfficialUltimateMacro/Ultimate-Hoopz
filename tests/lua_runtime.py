import ctypes,pathlib,os
D=ctypes.CDLL(os.environ.get('LUA_DLL',r'C:\Lua\lua55.dll'))
for n,args,res in [('luaL_newstate',[],ctypes.c_void_p),('luaL_openselectedlibs',[ctypes.c_void_p,ctypes.c_int,ctypes.c_int],None),('luaL_loadstring',[ctypes.c_void_p,ctypes.c_char_p],ctypes.c_int),('lua_pcallk',[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p],ctypes.c_int),('lua_tolstring',[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)],ctypes.c_void_p)]:
 f=getattr(D,n);f.argtypes=args;f.restype=res

def run(s):
 L=D.luaL_newstate();D.luaL_openselectedlibs(L,1023,0)
 rc=D.luaL_loadstring(L,s.encode())
 if not rc:rc=D.lua_pcallk(L,0,1,0,0,None)
 z=ctypes.c_size_t();p=D.lua_tolstring(L,-1,ctypes.byref(z));v=ctypes.string_at(p,z.value) if p else b''
 if rc: raise RuntimeError(v.decode(errors='replace'))
 return v
if __name__=='__main__': print(run('return _VERSION'))

