"""Run Lua tests against the exact Windows x64 xLua native plugin used by Unity."""
import ctypes
import pathlib
import os
import sys
import argparse

parser = argparse.ArgumentParser(description="Run a selected Lua test file using the project's native xLua plugin.")
parser.add_argument('script', nargs='?', default='Tools/Tests/framework.lua')
args = parser.parse_args()

root = pathlib.Path(__file__).resolve().parents[2]
os.chdir(root)
lua = ctypes.CDLL(str(root / 'Assets/Plugins/x86_64/xlua.dll'))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.xluaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_void_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
if not state:
    raise RuntimeError('Cannot create Lua state')
try:
    lua.luaL_openlibs(state)
    script = (root / args.script).resolve()
    source = script.read_bytes()
    result = lua.xluaL_loadbuffer(state, source, len(source), ('@' + str(script)).encode('utf-8'))
    if not result:
        result = lua.lua_pcall(state, 0, 0, 0)
    if result:
        length = ctypes.c_size_t()
        pointer = lua.lua_tolstring(state, -1, ctypes.byref(length))
        print(ctypes.string_at(pointer, length.value).decode('utf-8'), file=sys.stderr)
        sys.exit(1)
finally:
    lua.lua_close(state)
