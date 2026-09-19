---
name: unity-lua-console
description: 在提供 Tools/LuaConsole 的 Unity 工程中，用 Python 查询 Play 状态、向现有 xLua LuaEnv 注入片段、检查或修改运行时对象并读取结果；不自动启动 Editor、编译或进入 Play。
---

# Unity LuaConsole

## 入口与准备

1. 确认目标工程有 Tools/LuaConsole/console.py；先遵守 lua-code-style，项目有 ForAI 时只读 INDEX 命中的 LuaConsole 文档。没有该工具就说明缺少入口，不猜端口或改用其他工程的连接。
2. 在目标工程根运行：python -X utf8 Tools/LuaConsole/console.py status --json。必须同时检查 ok=true、ready=true；不要把命令退出码 0 当成 LuaEnv 已就绪。
3. 未连接时，请用户在 Unity 顶部菜单选择 Project Y → Lua Console → Start Connection (CLI) 或 Open；未就绪时请用户手动进入目标场景的 Play Mode。不要自行启动 Editor、切 Play、触发 Reload 或进入等待循环。用户完成后再查一次状态。
4. Python 无需 pip 包；图形窗口需要 tkinter。连接凭据在项目 Library/LuaConsole，由客户端读取，不能打印、复制到提示词或提交。

## 执行

- 单行只读查询：python -X utf8 Tools/LuaConsole/console.py exec --code 'return console.systems.state' --json。
- 多行或包含引号的片段，写入当前任务的 UTF-8 临时文件，再使用 exec --file <文件路径> --json；或用终端的字面量多行输入配合 exec --stdin --json。PowerShell 不把 Lua 嵌入可展开的双引号或拼接成可执行命令。
- console.systems 是正在运行的 SystemRegistry；console.services 是当前 C# Services。优先通过系统 / Data 的公开接口工作，不新建 LuaEnv，不用反射取得私有运行时。
- 只查询任务需要的字段，先定位目标 System / Panel；不要一次打印整个注册器。返回文本包括序号和类型，nil 返回位会保留；大表只是受限预览。
- 状态修改、函数替换和 UI 操作仅限用户授权的任务。遵守 LuaReference 的 self.view.Key、Data 所有权、Ctrl 生命周期及监听释放约定，不用控制台绕过框架。不要用添加金币等业务变更作为连接测试。
- 片段全局赋值在当前会话保留，local 不跨片段。运行时补丁不会自动写回 .lua 文件，也不自动重载模块；需要持久化修改时按用户要求修改源码并说明运行时与文件的区别。

## 结果与停止条件

- 成功时读取 output / result；失败时读取 error 堆栈。Lua 报错不会回滚之前的副作用，修正前先判断是否已经改变状态。
- 连接超时、断线或 outcomeUnknown=true 时，**禁止自动重发变更代码**；报告结果未知，先做只读检查，确认结果后再决定下一步。
- 普通 Lua 死循环有指令预算，但阻塞的 C# 调用不能被其打断；不要为了延长执行主动移除 debug hook。
- 不自动重复或扩大测试。真实注入验证只在已就绪且获授权的会话做最小检查；缺少会话时说明未验证部分，不宣称 Play 回归通过。
