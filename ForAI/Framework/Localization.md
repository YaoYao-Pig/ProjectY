# 玩家可见文本与本地化约束

关键词：text、本地化、i18n、禁止硬编码、中文字符串、玩家提示、UI 文案、格式模板、Language.lua、LuaLanguage、LuaTxt、UITxt、PrefabTxt、TMP。

## 文档目录

正文：必须遵守的要求 / 文本入口与当前能力 / 交付检查；关键入口：源文本 / 提取 / 运行时。

## 正文

### 必须遵守的要求

- **新增和修改的玩家可见文本必须使用下述本地化入口，禁止在 Lua/C# 业务代码中写死自然语言文案。** 范围包括标题、按钮、HUD、提示、Tooltip、任务／对话标签、通知，以及业务层返回后会显示给玩家的失败原因。中文、英文都适用；临时功能、Demo、动态生成界面也适用。
- **先确定文本来源再写代码。** Lua/C# 通用界面文案走 Language/LuaTxt；配置驱动的任务、对白、物品、技能、人物等正文直接维护在所属表的 `type: "text"` 字段；Prefab 固定文字使用已保存的语言键绑定。不要把配置正文复制到控制器，也不要用 `type: "string"` 新增需要翻译的名称或描述。
- **完整句子使用完整模板。** 数字、人物名、物品名、按键名作为参数传入；单位、前后缀、标点和语序随模板维护。禁止通过拼接中文片段、C# 插值字符串或临时标签字典绕过语言表。Lua 的 `%s/%d` 与 C# 的 `{0}/{1}` 分别使用对应格式的模板，不能直接混用。
- **语言键必须有效且可追溯。** 先复用语义与用途相同的键；新增键写明用途、参数含义，不因当前中文相同就混用不同含义的词条。缺键应补齐，不写 `Language.SomeKey or "中文"` 之类回退；默认值由 Language.lua、文本表及现有文本服务管理。更改默认文案时必须检查 LuaTxt 中是否存在覆盖值。
- **区分文案与业务身份。** 命令、枚举、事实键、资源路径等内部标识保持稳定，不翻译；禁止用翻译后的显示文字决定业务分支。注释、测试样例和仅写入开发日志的诊断不要求进入语言表；同一诊断一旦作为玩家提示显示，就必须本地化。
- **Prefab 的编辑预览文字不能替代运行时绑定。** 编辑态 DefaultText、UI 生成器中的默认编辑文案只用于预览或既有回退；交付时相应固定文案必须有有效语言键，动态内容检查其配置 `text` 或语言模板来源。新增文字组件与生成器一起检查，不能只检查 Lua/C# 的 `.text` 赋值。

### 文本入口与当前能力

- 当前范围：配置与默认文本可运行；各语言 i18n 汇总、翻译管理、语言切换尚未实现。规划为表内 text、LuaTxt.txt、PrefabTxt.txt 统一进入各语言 i18n；不要把现有默认字符串导出称为多语言导出。
- 普通表字段 `type: "text"` 标记需要本地化；当前读写与 string 相同，保留字段类型供未来汇总。表结构规则见 [配置管线](Config.md)。
- `local Language = require('Language')` 后用 `Language.Confirm`。返回空代理，__index 优先查询已导出的 LuaTxt；缺 id 回退到 Language.lua 的 defaults；两边都无键返回 nil，空字符串覆盖有效。未导出的新键仍能工作。
- 在 Language.lua 的 `@localization-begin/end` 之间每行新增 `Confirm = "确认", -- 用途`。只提取字面量，不执行 Lua；支持单/双引号、转义引号/换行、十进制/十六进制字节转义。长字符串、拼接、函数表达式需改为单行字面量，否则明确报错。
- 导出或网页“同步 Language.lua”会向 LuaTxt 增加缺失键，并用行尾注释更新 desc；保留已有 txt 覆盖和表中手工键，不自动删行。已有键的默认值改动不会覆盖表内 txt，需要在表中修改或删除覆盖行后重新同步。
- LuaTxt / PrefabTxt 固定结构为 `id:string, txt:text, desc:string`，key 为 id。PrefabTxt 在网页维护；UITxt 的 LocalizationId 查 PrefabTxt，缺失时使用 DefaultText。字体、材质沿用 TMP，字体资产需覆盖要显示的字符。
- `LocalizationSystem` 依赖 Config，在 UI 启动前把两张文本表加载到 C# LocalizationService，并绑定 Language 查询。UITxt OnEnable 订阅 Changed，OnDisable 退订；编辑态显示 DefaultText。当前没有文件热重载；修改配置后导出并重新 Play。
- 玩家 UI 的动态文案统一用 `local LuaLanguage = require('Language')`（原有 `L` 别名仍等价）。数字、名称等动态内容放完整格式模板中，由 `string.format` 注入；不要把可翻译句子拆成硬编码前后缀。模块级标签映射使用 `LanguageProxy.Map` 保存键并延迟查询，避免在 Localization 初始化前缓存默认中文。
- C# UI 使用 `ProjectY.UI.LuaLanguage.Get/Format`，优先读取同一个 `LocalizationService.Shared` 的 LuaTxt 覆盖，未初始化时读取现有 `_Gen/Config/LuaTxt.bytes` 默认表，供 Edit Mode 预览和启动提示使用。没有额外词典资源或第二份文本源。读取器只接受固定 `id/txt/desc` 字符串列；修改其结构需同步读取器。Lua 模板采用 `%s/%d`，C# Format 模板采用 `{0}/{1}`，表内 desc 标明参数含义。
- 存量 UGUI Text、TMP、UITxt 固定标题/按钮由 Prefab 根 LuaReference 的 `localizedTexts` 保存 **Component + LuaTxt ID**。UIHost 在 CreateView/CreateWidget 时、Lua Bind/OnShow/SetData 之前应用，避免覆盖随后写入的动态内容；嵌入子控件的初始文案随宿主映射保存。此迁移不转换 Text 组件、不破坏原有 LuaReference 与 C# 序列化引用。已有 UITxt.LocalizationId → PrefabTxt 入口继续有效。
- 绑定清单在 [ui-text-bindings.json](../../Art/Localization/ui-text-bindings.json)，通过 Unity 菜单 `Project Y/UI/同步 UI 多语言绑定` 保存；新文本先补 Language.lua 与导表，再更新清单并同步。`Project Y/UI/验证 UI 多语言绑定` 检查 UI Prefab 中的中文固定文案是否有语言键。不要手改 Prefab YAML；UI 生成器保留默认编辑文案时，交付前也必须完成该绑定检查。
- [Lua/源码定向检查](../../Tools/Tests/ui_localization.lua) / [来源审计](../../Tools/Tests/ui_localization_sources.mjs) 检查查表覆盖、格式参数、空覆盖、延迟标签映射与 UI 层硬编码回归。物品/技能/角色等配置正文继续由所属表的 `text` 字段管理；营地设施、配方、地图地点/设施/NPC 与天气名称也须使用 `text`。
- [Edit Mode 覆盖验证](../../Tools/Tests/ui_localization_editmode.cs) 经 Unity MCP `execute_code` 执行，逐个创建注册界面检查表值替换，并使用真实 Lua 骰子控制器、按钮与 C# 文案生成英文预览；结束恢复原文本服务与时间状态，不进入 Play。实际检查范围见 [验证记录](../../Art/Localization/validation.json)。

### 交付检查

1. 检查本次改动中所有会显示给玩家的字符串，包括 UI 调用的业务代码、错误原因、模块级标签映射、C# 插值、Prefab 及生成器。确保每一处都能定位到语言键或配置 `text` 字段；新增源码文件也必须纳入检查。
2. 使用语言键时核对 Language.lua 默认值、LuaTxt 覆盖值和参数格式。新增键完成同步与导出；修改已有中文时同步检查表内覆盖，不能只改 defaults。配置正文按所属模块校验和导出，不手改 `_Gen`。
3. 改动代码文案时运行 `node Tools/Tests/ui_localization_sources.mjs`。该脚本扫描 `Lua/UI`、`Lua/Game/Presentation` 的中文字符串，并核对迁移清单等指定文件的键；**它不覆盖全部 Lua 业务代码、C# 或英文硬编码**，仍需检查本次改动中的这些部分。当前对话“旁白”身份判断属于存量扫描特例，不能据此新增用显示文字判定身份的代码。
4. 改动查表、格式参数或标签映射时，按需执行 `python -B Tools/Tests/run_lua.py Tools/Tests/ui_localization.lua`。Prefab 文字变更完成已授权的原生绑定同步及定向检查；缺少验证条件时保留待验证说明，不能以预览里显示中文作为完成依据。
5. 交付时说明实际检查结果和未验证部分。发现本次新增或修改的文案仍有硬编码、缺键、旧覆盖或缺少绑定，先修复再交付；仅修改本文或 Skill 时只检查文档链接与规则一致性，不运行游戏测试。

上述命令和 Unity 菜单是检查入口，不自动授权启动 Editor、进入 Play、编译或全量测试；执行范围遵循[项目开发约束](../../.agents/skills/lua-code-style/SKILL.md)。提取器用 Node 测试；UITxt/桥接使用获准的定向 Unity 检查。修改 C# API 后按流程重新生成 xLua 桥接。TMP 资源入口为 **Project Y → UI → Import TMP Resources**，组件创建入口为 **GameObject → UI → Project Y UITxt**。

## 关键入口

- [Language.lua](../../Lua/Language.lua)：开发默认值；[LuaTxt.json](../../Config/Tables/Localization/LuaTxt.json) / [PrefabTxt.json](../../Config/Tables/Localization/PrefabTxt.json)：默认文本表。
- [language.mjs](../../Tools/ConfigEditor/language.mjs)：`parseLanguage / mergeLanguage`；[LanguageProxy.lua](../../Lua/Config/LanguageProxy.lua)：元表回退。
- [LocalizationSystem.lua](../../Lua/Config/LocalizationSystem.lua)：加载/解绑；[LocalizationService.cs](../../Assets/GameFramework/Runtime/Data/LocalizationService.cs)：共享查找边界，未来 i18n 在此接入。
- [LuaLanguage.cs](../../Assets/GameFramework/Runtime/UI/LuaLanguage.cs) / [UILocalizationAssets.cs](../../Assets/GameFramework/Editor/UILocalizationAssets.cs)：C# UI 查表与原生 Prefab 绑定维护。
- [UITxt.cs](../../Assets/GameFramework/Runtime/UI/UITxt.cs) / [UITxtEditor.cs](../../Assets/GameFramework/Editor/UITxtEditor.cs)：TMP 派生组件/Inspector；[UITxtAssets.cs](../../Assets/GameFramework/Editor/UITxtAssets.cs)：资源导入。
