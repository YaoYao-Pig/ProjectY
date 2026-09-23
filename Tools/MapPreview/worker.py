"""每个请求使用全新的工程 xLua 状态；标准输出仅返回预览 JSON。"""
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'Tools'))
from LuaRuntime.runtime import LuaRuntime


def lua_string(value):
    """按 UTF-8 字节转义 Lua 字符串，兼容中文路径并避免路径成为代码。"""
    return '"' + ''.join('\\%03d' % byte for byte in value.encode('utf-8')) + '"'


def main():
    # 进程边界再次校验输入，Lua 自身继续负责配置与生成规则的校验。
    request = json.load(sys.stdin)
    seed, region_ids = request['seed'], request['regionIds']
    target_cells = request.get('targetCells')
    if target_cells is not None and (type(target_cells) is not int or target_cells < 1):
        raise ValueError('targetCells must be a positive integer')
    if type(seed) is not int or not 0 <= seed <= 0xffffffff:
        raise ValueError('seed must be uint32')
    if not isinstance(region_ids, list) or not region_ids or any(type(value) is not int or value <= 0 for value in region_ids):
        raise ValueError('regionIds must be positive integer IDs')
    snapshot = Path(sys.argv[1]).resolve().as_posix()
    os.chdir(root)
    source = (
        'return assert(loadfile("Tools/MapPreview/preview.lua"))('
        + lua_string(snapshot) + ', ' + str(seed) + ', {'
        + ','.join(str(value) for value in region_ids) + '}, '
        + ('nil' if target_cells is None else str(target_cells)) + ')'
    )
    with LuaRuntime(root) as runtime:
        result = runtime.execute(source.encode('utf-8'), '@MapPreviewRequest')
    # 完整 JSON 由父进程解析校验，避免十万格在 Python 中再建一份对象树。
    sys.stdout.write(result)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
