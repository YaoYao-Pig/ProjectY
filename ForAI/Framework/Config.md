# 配置管线

关键词：配表、JSON、schema、导表、二进制、公式、枚举、常量、Catalog、C# 查表、_Gen、生成目录、产物迁移。

## 文档目录

正文：源与产物 / 运行契约 / 修改与验证；关键入口：导出器 / Lua 读表 / 示例。

## 正文

- 表源为 `Config/Tables/**/*.json`：`version/name/description/key/fields/rows`。字段含可读 description；类型为 int（int32）、float（float64）、bool、string、text、enum、formula，以及 int/float/bool/string/enum 数组；支持默认值、约束和跨表 ref，不接受 null。目录变化不改变表名，表名全局唯一。
- 共享枚举/常量源为 `Config/Catalog.json`。模块 ID 稳定，folder 可为 null；绑定目录只管理归属。枚举成员显式填写 name/value/description，值为 int 或 string；enum/enum[] 字段及常量通过 `enumRef: "Demo.Rarity"` 引用，字段的旧 values 内联枚举仍兼容。枚举数组逐项校验成员，允许空数组；删改定义必须校验所有表与常量的引用。
- Catalog 导出 `Lua/_Gen/Catalog.lua`，由 `Config.Catalog` 提供递归只读代理；`ConfigSystem:GetEnum(module,name)` / `GetConstant(module,name)` 访问。示例 Demo 常量尚未接入玩法。
- 导出全量校验主键、类型、引用和公式，生成 `Lua/_Gen/*.lua`（schema、LuaLS 注释、Manifest）及 `Assets/GameFramework/Resources/_Gen/Config/*.bytes`；`Config/_Gen/export-manifest.json` 管理产物清理。以上产物不手改。
- 生成目录按加载位置统一命名 `_Gen`：Lua 模块以 `_Gen.*` require，Unity 二进制用 Resources 路径 `_Gen/Config/<表名>`；编辑器与构建检查同步使用新清单。导出器支持从旧清单迁移已登记产物和 `.meta`，保留 Unity GUID；先验证完整清单及元数据冲突，只清理登记产物和已空旧目录，未知文件保留。
- 二进制头为 `YCFG` + uint16 版本 1 + schema 指纹字符串 + uint32 行数，再按字段顺序编码。修改格式必须同时改 exporter 与 Lua reader；详细布局按需读 [完整架构](../../Docs/Architecture.md)。文件逐个原子替换，不保证整批输出原子事务。
- `ConfigSystem:GetTable(name)` 按 Manifest 校验并惰性加载缓存；`Get(id)` 缺行报错，`Find(id)` 返回 nil，`All()` 返回行集合，`Count` 是属性。记录/数组提供只读代理；当前没有运行中热重载。
- formula 导出为受限 RPN 指令，Lua `Evaluate(variables)` 求值；两端操作符/函数需一致，禁止用 eval/load 执行公式源码。
- text 当前以默认字符串编码；整数 enum 根据 schema.enumType 编码为 int32，字符串 enum 仍为 UTF-8。导出会同步 Language.lua 字面量/注释到 LuaTxt，规则见 [本地化](Localization.md)；尚未实现各语言 i18n 汇总导出。
- C# 经 `GameBootstrap.GetConfigRow(name, id)` 访问同一份 Lua 数据，id 仅 int/string；启动后在 Unity 主线程调用，返回 LuaTable 由调用方及时 Dispose，不能跨越 LuaEnv 生命周期。

路径迁移最小检查：`node --test Tools/ConfigEditor/tests/generated-layout.test.mjs`（[测试文件](../../Tools/ConfigEditor/tests/generated-layout.test.mjs)）覆盖 GUID 保留、重复导出、过期清理、未知文件保护和异常清单；Lua 读表与 Web 快照还需定向验证。

修改与验证：改表后运行 `node Tools/ConfigEditor/exporter.mjs`；改 schema/格式/公式时运行 `node --test Tools/ConfigEditor/tests/config.test.mjs` 与 `python Tools/Tests/run_lua.py`。涉及桥接读取再跑 Unity 集成检查。编辑网页行为另读 [配置编辑器](../Tools/ConfigEditor.md)。

枚举数组最小检查：`node --test Tools/ConfigEditor/tests/enum-array.test.mjs`，覆盖校验、默认值、常量和 Node 导出 → 项目 xLua 只读数组往返；使用现有 Windows x64 插件，不启动 Unity。

## 关键入口

- [表源目录](../../Config/Tables/)：可编辑 JSON；[exporter.mjs](../../Tools/ConfigEditor/exporter.mjs)：`validateTable / validateTables / encodeTable / exportTables`；`generatedPaths / readOutputManifest` 定义产物目录与清单校验。
- [Catalog.json](../../Config/Catalog.json)：模块定义；[definitions.mjs](../../Tools/ConfigEditor/definitions.mjs)：`validateCatalog / resolveEnum`；[Catalog.lua](../../Lua/Config/Catalog.lua)：只读枚举/常量。
- [formula.mjs](../../Tools/ConfigEditor/formula.mjs)：`compileFormula / evaluateFormula`；[Formula.lua](../../Lua/Config/Formula.lua)：运行时解释。
- [ConfigSystem.lua](../../Lua/Config/ConfigSystem.lua)：缓存；[ConfigTable.lua](../../Lua/Config/ConfigTable.lua)：`Load`；[BinaryReader.lua](../../Lua/Config/BinaryReader.lua)：字节读取。
- [FrameworkServices.cs](../../Assets/GameFramework/Runtime/Lua/FrameworkServices.cs)：`ReadConfig`；[GameBootstrap.cs](../../Assets/GameFramework/Runtime/Lua/GameBootstrap.cs)：C# 查询入口。
- [Rewards.json](../../Config/Tables/Rewards.json) / [RewardGroups.json](../../Config/Tables/RewardGroups.json)：公式、数组与跨表引用示例。
