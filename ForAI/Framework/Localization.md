# 默认文本与本地化入口

关键词：text、本地化、Language.lua、LuaTxt、UITxt、PrefabTxt、i18n、TMP。

## 文档目录

正文：三类入口 / 同步规则与边界 / 修改与验证；关键入口：源文本 / 提取 / 运行时。

## 正文

- 当前范围：配置与默认文本可运行；各语言 i18n 汇总、翻译管理、语言切换尚未实现。规划为表内 text、LuaTxt.txt、PrefabTxt.txt 统一进入各语言 i18n；不要把现有默认字符串导出称为多语言导出。
- 普通表字段 `type: "text"` 标记需要本地化；当前读写与 string 相同，保留字段类型供未来汇总。表结构规则见 [配置管线](Config.md)。
- `local Language = require('Language')` 后用 `Language.Confirm`。返回空代理，__index 优先查询已导出的 LuaTxt；缺 id 回退到 Language.lua 的 defaults；两边都无键返回 nil，空字符串覆盖有效。未导出的新键仍能工作。
- 在 Language.lua 的 `@localization-begin/end` 之间每行新增 `Confirm = "确认", -- 用途`。只提取字面量，不执行 Lua；支持单/双引号、转义引号/换行、十进制/十六进制字节转义。长字符串、拼接、函数表达式需改为单行字面量，否则明确报错。
- 导出或网页“同步 Language.lua”会向 LuaTxt 增加缺失键，并用行尾注释更新 desc；保留已有 txt 覆盖和表中手工键，不自动删行。已有键的默认值改动不会覆盖表内 txt，需要在表中修改或删除覆盖行后重新同步。
- LuaTxt / PrefabTxt 固定结构为 `id:string, txt:text, desc:string`，key 为 id。PrefabTxt 在网页维护；UITxt 的 LocalizationId 查 PrefabTxt，缺失时使用 DefaultText。字体、材质沿用 TMP，字体资产需覆盖要显示的字符。
- `LocalizationSystem` 依赖 Config，在 UI 启动前把两张文本表加载到 C# LocalizationService，并绑定 Language 查询。UITxt OnEnable 订阅 Changed，OnDisable 退订；编辑态显示 DefaultText。当前没有文件热重载；修改配置后导出并重新 Play。

修改与验证：提取器用 Node 测试；查表优先级/回退用 Lua 测试；UITxt/桥接用 Unity 集成检查及 Play。修改 C# API 后重新生成 xLua 桥接。TMP 资源入口为 **Project Y → UI → Import TMP Resources**，组件创建入口为 **GameObject → UI → Project Y UITxt**。

## 关键入口

- [Language.lua](../../Lua/Language.lua)：开发默认值；[LuaTxt.json](../../Config/Tables/Localization/LuaTxt.json) / [PrefabTxt.json](../../Config/Tables/Localization/PrefabTxt.json)：默认文本表。
- [language.mjs](../../Tools/ConfigEditor/language.mjs)：`parseLanguage / mergeLanguage`；[LanguageProxy.lua](../../Lua/Config/LanguageProxy.lua)：元表回退。
- [LocalizationSystem.lua](../../Lua/Config/LocalizationSystem.lua)：加载/解绑；[LocalizationService.cs](../../Assets/GameFramework/Runtime/Data/LocalizationService.cs)：共享查找边界，未来 i18n 在此接入。
- [UITxt.cs](../../Assets/GameFramework/Runtime/UI/UITxt.cs) / [UITxtEditor.cs](../../Assets/GameFramework/Editor/UITxtEditor.cs)：TMP 派生组件/Inspector；[UITxtAssets.cs](../../Assets/GameFramework/Editor/UITxtAssets.cs)：资源导入。
