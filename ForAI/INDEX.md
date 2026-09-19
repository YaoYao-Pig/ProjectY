# ForAI · 入口

关键词：框架、业务、Lua、UI、配表、编辑器、文档维护。

## 文档目录

| 任务关键词 | 按需读取 |
| --- | --- |
| Lua 风格、需求澄清、过度防御、Unity MCP、最小测试、编译、SubAgent | [开发约束 Skill](../.agents/skills/lua-code-style/SKILL.md) |
| LuaConsole、Python、运行时注入、执行片段、调试控制台 | [LuaConsole](Tools/LuaConsole.md) |
| 启动、LuaSystem、注册、Tick、require、Lua 文件、构建、xLua 桥接、退出 | [运行时](Framework/Runtime.md) |
| Panel、Widget、MVC、LuaReference、UIRoot、WorldUIRoot、WorldUI、暂停、场景切换 | [UI](Framework/UI.md) |
| JSON 表、导表、二进制、读表、公式、枚举、常量、Catalog、C# 查表 | [配置管线](Framework/Config.md) |
| text、本地化、Language.lua、LuaTxt、UITxt、PrefabTxt、i18n、TMP | [本地化](Framework/Localization.md) |
| Player、金币、等级、奖励、示例流程、Data、ModelSystem | [玩家示例](Business/Player.md) |
| PanelGenerator、生成 Prefab、PanelConfig 编辑、模块目录、EmmyLua | [UI 生成器](Tools/PanelGenerator.md) |
| 配表网页、增列、表头、目录、模块根节点、总览、保存、409、前端 | [配置编辑器](Tools/ConfigEditor.md) |
| 新增文档、更新文档、索引、阅读规则、skill | [维护约定](MAINTENANCE.md) |

## 正文

- 起步只读本索引和最相关的一篇；跨模块才追加对应文档。实现或排错时按“关键入口”定位符号，再读取必要代码。
- `Framework/` 记录通用契约，`Business/` 记录实际玩法，`Tools/` 记录开发工具；尚未实现的模块不建空文档。
- 模块文档只记录当前实现及修改约束。代码与文档不符时核对代码并修正文档；不把规划视为现有能力。

## 关键入口

- [README](../README.md)：运行步骤；[完整架构](../Docs/Architecture.md)：需要详细示例或协议说明时读取。
- [验证记录](../Docs/Validation.md)：历史验证范围，不代表本次修改已测试。
- [AGENTS.md](../AGENTS.md)：自动阅读入口；[维护约定](MAINTENANCE.md)：写文档时才展开。
