# 验证记录

2026-09-19，Windows x64 / Unity 2022.3.55f1c1 / Node.js 23.11.0。

- `node --test Tools/ConfigEditor/tests/config.test.mjs`：12 组测试通过。包含字段/主键/引用校验、公式语法和数值异常、导出可重复性、失败不更新产物、旧文件清理、本地 HTTP token/origin 和并发保存冲突。
- `python Tools/Tests/run_lua.py`：10 组测试通过。使用工程中实际 xLua DLL（Lua 5.3），验证导出二进制与生成 Lua 结构、Unicode/数组/float/公式、格式错误拒绝、只读记录、System 生命周期与回滚、Signal 重入、UI 生命周期与模态。
- Unity 成功编译 C# runtime/editor 程序集，并生成、编译 32 个 xLua C# 桥接文件。
- Unity 编辑模式集成检查在生成桥接前、生成桥接后均通过；最后一次为 21:15（UTC+8）。检查真实 Button → Lua → C# Data → Widget 刷新、缓存 Panel 重开不重复订阅、模态窗口反复开关、引用类型校验、数据越界保护与 LuaEnv 释放。
- 浏览器已实际打开配表工具并操作校验、公式试算和表切换。窄窗口布局已目视检查。

以上为第一版验证。没有进行 Play 画面目视检查（用户按 Escape 停止了桌面自动操作）。

可重复验证入口：Unity 菜单 **Project Y → Tests → Run Integration Checks**。正式测试保留；用于本次触发验证的一次性编辑器脚本已移除。

## 原生 Lua 文件加载改造

同日完成，将 22 个业务/生成模块迁到工程根目录 `Lua/**/*.lua`，移除旧 Unity Lua 资源目录。

- 12 组 Node 测试通过，额外检查生成结构只写入 `Lua/Generated/*.lua`，删除表时同步清理该目录的旧生成文件。
- 10 组原生 xLua Lua 测试在新目录布局下通过。
- 独立 Unity 验证工程成功编译，编辑模式集成检查通过；新增模块名映射、非法路径/缺失文件、UTF-8 BOM、构建文件筛选、模拟 Player 目录加载测试。
- 实际构建 **Windows x64 / Mono / Development** 成功。构建回调将 22 个 `.lua` 原文件加入成品 `StreamingAssets/Lua/`。
- 成品以无图形 batchmode 启动，通过 GameBootstrap 执行入口、C# 查询 Lua 配置、真实按钮回调与 Widget 刷新后正常退出，退出码 0 且没有异常。日志标记：`LUA_MIGRATION_PLAYER_PASS`。无图形模式的 shader 不支持提示不属于渲染验证。
- 构建过程中修正 xLua 生成配置：排除仅编辑器可用的 `LuaReference.SetEditorBindings` 和 `Text.OnRebuildRequested`，并重新生成桥接文件。
- 成品退出检查发现并修复 Mono 委托栈保活问题：在不内联的独立方法中调用 Shutdown 并清空回调，待该调用栈返回后再 Dispose LuaEnv，避免清空字段后桥接仍被当前栈引用。

本次验证使用 `Tools/ConfigEditor/.cache/LuaValidationProject` 独立副本，没有操作当前 Unity 窗口；最终构建和 Player 日志在同级 `lua-migration-build-shutdown.log` / `lua-migration-player-final.log`。IL2CPP 和非 Windows 平台尚未验证。

## 目录、共享定义与默认本地化

同日新增，本节描述这次扩展的验证；前面的构建结论属于此前版本。

- Node：19 组通过。新增共享整数/字符串枚举、常量约束、列新增/改名、递归目录、跨目录表名唯一、模块解绑/目录移动、Language 字面量与注释提取、保留表覆盖、源修订冲突的检查。
- 原生 xLua：13 组通过。新增 Language 的表优先/未导出回退/空字符串覆盖、只读枚举常量、text 字段以及整数枚举与后续字段字节对齐检查。
- Unity 在独立验证副本中重新生成并编译 xLua 桥接，编辑模式集成检查通过：新增 UITxt 引用、启停退订、默认文本查找及 LocalizationSystem 启动/退出验证。
- 独立副本的无图形 Play Mode 检查通过并正常退出（exit 0，标记 `CONFIG_UPGRADE_PLAY_PASS`）：真实 Bootstrap 读 LuaTxt，UITxt 从 PrefabTxt 查找、收到通知刷新、停用后不刷新、重新启用恢复、缺 id 回退，并正常停止 LuaEnv。
- TMP Essential Resources 已导入并复制回主工程；UGUI 1.0.0 / TMP 3.0.7 已嵌入，主工程 packages-lock 确认为 embedded。
- 浏览器操作验证新增枚举列、选值、整表校验、常量浏览、跨模块检索和定位；测试列仅为草稿，已放弃。窄窗口界面已检查。
- 本次未重新构建独立 Player，也未验证多语言 i18n 导出或语言切换（本次明确延期）。无图形 Play 检查不等于 TMP 字形渲染验证。

日志位于忽略目录 `Tools/ConfigEditor/.cache/`：`config-upgrade-integration.log`、`config-upgrade-play-final.log`。ForAI 文档随实现更新，本地链接检查通过。

## PanelConfig、生成器与 Lua View 绑定

2026-09-19，本节对应此次 UI 架构升级。

- 原生 xLua：16 组测试通过。新增 self.view 代理缓存/只读/缺键、场景变化清理隐藏缓存与保留常驻窗口、动态 Widget 绑定失败和父级销毁清理。
- Unity 独立副本编译、重新生成 xLua 桥接，真实 Button / C# Data / Lua 控制器集成检查通过。
- Run Panel Checks 通过：拒绝非法/重复/关键字配置名；重复生成保留 Lua 与组件绑定；EmmyLua 字段类型；模块移动保持 GUID；WorldSpace Canvas；多 Panel 暂停计数、恢复原 timeScale、销毁和退出释放；Widget Prefab 实例化。
- Windows x64 / Mono / Development 构建通过。成品 batchmode 启动并正常退出（exit 0，PROJECT_Y_PANEL_PLAYER_PASS）：PanelConfig 引用收集 DynamicAsset Prefab、原生 Lua 控制器、按钮/Widget 通知、世界 Canvas、缓存窗口暂停与恢复、activeSceneChanged 关闭指定窗口并保留 Demo。
- 成品确认没有 UI/Types 提示目录。SupportsHotSwitch 只保存标记，不包含重载机制。
- 最后一次 Editor 检查包含提示声明及 Inspector 组件选择相关代码；生成资产、桥接与源码已比对验证副本。文档链接检查通过。
- 无图形验证不包含生成窗口视觉排版、Canvas 实际渲染和 WorldUI 射线点击；IL2CPP/其他平台未验证。

日志仍位于忽略目录 Tools/ConfigEditor/.cache：panel-upgrade-panels-final.log、panel-upgrade-build-final.log、panel-upgrade-player-final.log。生成与运行规则见 [UI 生成器](../ForAI/Tools/PanelGenerator.md) 和 [UI](../ForAI/Framework/UI.md)。

## LuaConsole

2026-09-19，本节仅覆盖 Editor Play Mode 控制台的定向验证。

- Python 协议与 CLI：6 项通过，覆盖中文及分段传输、脚本报错、请求 ID 不匹配、连接信息校验、断线结果未知且不重发。
- 原生 xLua 执行器：5 项通过，覆盖全局状态修改、多返回值与 nil、错误堆栈、指令预算和 hook 恢复、延后调用的 print、循环表与输出限制。
- 集中执行一次 C# 编译检查：沿用当前 Unity 响应文件的编译参数与引用，调用 Unity 自带编译器，Runtime / Editor 均通过；输出和日志仅写入 Temp/LuaConsoleCompile，没有主动触发 Unity Reload。
- AI Skill 格式、ForAI 本地链接检查通过。只读 status 检查明确返回“连接未开启”。
- 没有启动 Editor、Play Mode 或 Player，没有运行全量测试；真实 Play 注入和 Python 窗口交互尚未验证。

入口和执行契约见 [LuaConsole](../ForAI/Tools/LuaConsole.md)。

## UIRoot 与 WorldUIRoot

2026-09-19，运行时将屏幕 Panel 与 WorldUI Panel 分别挂载到独立 Canvas 根节点。

- 集中执行一次 C# 编译检查，沿用 Unity 当前编译参数与引用，Runtime / Editor 均通过；日志位于 Temp/UIRootCompile。
- 4 份修改后的入口/说明文档检查了 45 个本地链接，全部通过。
- 现有 Run Panel Checks 增加根节点分离、嵌套 Canvas、屏幕拉伸/缩放、世界 UI 尺寸/变换保留、Shutdown 释放与再次 Initialize 的断言；本次未执行该 Editor 检查。
- 未主动启动 Editor、Play Mode、Reload 或 Player；真实布局、交互和销毁时序尚未验证。

运行契约见 [UI](../ForAI/Framework/UI.md)。
