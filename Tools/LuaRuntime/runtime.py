"""复用 Unity 工程 Windows x64 xLua DLL 的最小宿主，供测试与地图预览共用。"""
import ctypes
from pathlib import Path


class LuaRuntime:
    """持有一个独立 Lua 状态；通过 with 管理关闭，不跨请求缓存 Lua 对象。"""
    def __init__(self, root: Path):
        # 显式声明指针和参数类型，避免 ctypes 默认整数截断 64 位地址。
        self.lua = ctypes.CDLL(str(root / 'Assets/Plugins/x86_64/xlua.dll'))
        self.lua.luaL_newstate.restype = ctypes.c_void_p
        self.lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
        self.lua.xluaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p]
        self.lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        self.lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        self.lua.lua_tolstring.restype = ctypes.c_void_p
        self.lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.lua.lua_close.argtypes = [ctypes.c_void_p]
        self.state = self.lua.luaL_newstate()
        if not self.state:
            raise RuntimeError('Cannot create Lua state')
        self.lua.luaL_openlibs(self.state)

    def execute(self, source: bytes, name: str):
        """编译并执行片段，读取单个字符串返回值；错误统一抛给宿主调用方。"""
        result = self.lua.xluaL_loadbuffer(self.state, source, len(source), name.encode('utf-8'))
        if not result:
            result = self.lua.lua_pcall(self.state, 0, 1, 0)
        length = ctypes.c_size_t()
        pointer = self.lua.lua_tolstring(self.state, -1, ctypes.byref(length))
        text = ctypes.string_at(pointer, length.value).decode('utf-8') if pointer else None
        # 返回值或错误读出后清空栈，后续执行不继承上一次调用的栈内容。
        self.lua.lua_settop(self.state, 0)
        if result:
            raise RuntimeError(text or 'Lua execution failed without a string error')
        return text

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.lua.lua_close(self.state)
        self.state = None
