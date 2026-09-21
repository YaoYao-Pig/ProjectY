"""使用 Unity 工程自带的 Windows x64 xLua 插件执行指定 Lua 测试文件。"""
import pathlib
import os
import sys
import argparse

parser = argparse.ArgumentParser(description="Run a selected Lua test file using the project's native xLua plugin.")
parser.add_argument('script', nargs='?', default='Tools/Tests/framework.lua')
args = parser.parse_args()

root = pathlib.Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / 'Tools'))
from LuaRuntime.runtime import LuaRuntime

try:
    with LuaRuntime(root) as runtime:
        script = (root / args.script).resolve()
        runtime.execute(script.read_bytes(), '@' + str(script))
except RuntimeError as error:
    print(error, file=sys.stderr)
    sys.exit(1)
