# LuaConsole

关键词：LuaConsole、Python、运行时注入、LuaEnv、调试、Editor 菜单、执行片段。

## 文档目录

正文：入口与命令 / 执行契约 / 验证；关键入口：Python / Unity 桥接 / Lua 执行器。

## 正文

- Editor 顶部菜单 Project Y → Lua Console → Open 打开 Python tkinter 窗口并开启本机连接。Start Connection (CLI) 只开启连接；Stop Connection 关闭。手动进入包含 GameBootstrap 的 Play Mode 后点击“检查连接”，再执行片段。
- 需要带 tkinter 的 Python 3.10+，无 pip 依赖。Python 路径依次取 PROJECT_Y_PYTHON、Select Python Executable 菜单设置、PATH 中的 python。
- AI 先执行 `python -X utf8 Tools/LuaConsole/console.py status --json`，检查 ok 和 ready。执行用 `exec --code 'return console.systems.state' --json`；多行优先 `exec --file <UTF-8片段.lua> --json` 或 `exec --stdin --json`。可在子命令前指定 --project / --timeout。
- Python 连到当前工程 Library/LuaConsole/connection.json 指定的本机端口，使用会话凭据；不要输出或提交该文件。网络线程只收发，Editor update 每次最多执行一个请求；不创建第二个 LuaEnv。
- `console.systems` 是 require('Main') 返回的现有 SystemRegistry，`console.services` 是既有 C# Services。全局赋值保留至当前 LuaEnv 结束，local 仍是片段局部；print/console 为片段提供的工具变量。
- 返回 ok、output、result、error、ready、playing、paused、session、elapsedMs；result 是带位置/类型的文本预览，保留 nil 返回位，表预览限制深度与数量。print 收集仅覆盖片段环境中的调用；已有模块的普通日志仍在 Unity Console。
- 片段报错保留 traceback，不回滚已发生的副作用。CLI 退出码 0 表示请求成功（status 仍需检查 ready），1 是 Unity 返回失败，2 是本地/连接错误。断线或超时可能已执行，outcomeUnknown=true 时不能自动重发。
- Lua 指令预算用于中断普通 Lua 死循环，保留/恢复已有 Lua debug hook；原生 debugger hook 不可替换时拒绝执行。这不是沙箱，阻塞 C# 调用或片段主动移除 hook 不受指令预算保护。
- 切换 Play 会话会使排队的旧请求失效；超时未开始的请求会被丢弃。编译 Reload / Editor 退出关闭监听，已启用的连接在 Reload 后恢复。工具不启动 Play、不刷新 Assets、不触发编译。
- 当前操作窗口编辑的是执行片段；载入文件仅填充输入区。执行不自动保存源文件或重载 require 缓存，运行时补丁会随 LuaEnv 结束消失；PanelConfig 的热切标记不受此工具影响。
- 接入仅存在于 UNITY_EDITOR / Editor 目录；Lua 执行器位于 Tools 下，不打进 Player。AI 使用规则见项目技能 [unity-lua-console](../../.agents/skills/unity-lua-console/SKILL.md)，并继续遵守 lua-code-style。

最小验证：`python -X utf8 -m unittest discover -s Tools/LuaConsole/tests -p test_client.py`；`python -X utf8 Tools/Tests/run_lua.py Tools/LuaConsole/tests/console.lua`。真实注入只在用户已开启连接和 Play 会话时做定向检查，不默认启动 Editor 或做全量测试。

## 关键入口

- [console.py](../../Tools/LuaConsole/console.py)：命令行；[gui.py](../../Tools/LuaConsole/gui.py)：Python 窗口；[client.py](../../Tools/LuaConsole/client.py)：连接文件、协议和结果未知处理。
- [LuaConsoleBridge.cs](../../Assets/GameFramework/Editor/LuaConsoleBridge.cs)：菜单、连接生命周期、主线程派发；[GameBootstrap.cs](../../Assets/GameFramework/Runtime/Lua/GameBootstrap.cs)：ExecuteEditorConsole / ReleaseCallbacks。
- [runtime.lua](../../Tools/LuaConsole/runtime.lua)：片段环境、输出、指令预算；[Main.lua](../../Lua/Main.lua)：返回当前注册器。
- [test_client.py](../../Tools/LuaConsole/tests/test_client.py) / [console.lua](../../Tools/LuaConsole/tests/console.lua)：定向测试。
