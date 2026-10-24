# 角色养成与经历

关键词：Growth、职业、自由转职、主动选学、准备技能、奥术兵装、紧握武器、免疫、immunityTags、iconAttribute、升级、属性、被动天赋、潜力、经历、CharacterGrowth。

## 文档目录

正文：职责与规则 / 配置 / UI 与验证；关键入口：状态 / 规则 / 资源。

## 正文

- 战士课程“创伤打击”及其部位伤害/创伤概率规则见[身体健康与创伤](BodyInjuries.md)，技能与图鉴ID均为1630。

- 动物亲和与驯服技能方向、骑乘亲密度解锁技能见[森林动物与骑乘](Animals.md)；`skillDirection` 独立于属性分组，生活属性也可按配置参与研习。
- 巧匠研习、材料施工与高台/挖掘规则见[巧匠营造](Construction.md)。
- `SkillAtlas` 是独立的暂停世界浏览 Panel，从 HUD 菜单或角色手记的“技能图鉴”进入；顶部一级领域、左侧二级目录、中央主动技能图谱，全局搜索可跳转分类。初始目录取所选角色当前职业的初始技能（无初始技能时取职业首门课程、无课程时取首目录），不固定打开巧匠。手记入口传递角色与原页面，关闭图鉴回到原页面；直接从 HUD 打开则直接关闭。`SkillDiscipline/SkillCategory/SkillAtlasTable` 定义目录、唯一主归属、关联目录、坐标、标签与 all/any 前置；关联目录不复制技能身份。全部主动技能必须有图谱记录，初始化拒绝循环依赖。
- 图谱依角色投影已掌握/固有/装备或骑乘授予、满足研习条件、条件不足或特殊来源；来源身份不代表当前可以施放。法术 Tips 与手记已学行通过装备规则显示触媒/专精条件，缺触媒不禁止学习。浏览不产生机会或直接学习；`SkillAtlas` 前置与 `ProfessionRules/GrowthSystem.Learn` 共用查询，学习入口为角色手记技艺页。被动图仅使用 PassiveSkillTable。
- 选中 Cell 的 Tips 显示效果、AP、距离、冷却、材料/工具、属性与获取途径，前置可点击跳转。浮窗锚定 Cell、贴边翻转并限制在页面内；随滚动更新，Cell 离屏时关闭，空白/关闭按钮/Esc 关闭。`SkillAtlasView` 只负责几何表现，Lua 组件引用全部走 LuaReference。
- Unity MCP 调用 `SkillAtlasAssets.Create`（菜单“创建技能图谱”）生成并注册本模块 Prefab，重复执行保留布局；同步角色手记的图谱入口绑定。纯 Lua 检查为 `skill_atlas_core.lua`，真实 UI 检查通过 MCP 执行 `Tools/Construction/run_checks.cs`，在 PreviewScene 验证分类、搜索、锚点和缓存生命周期并生成 `Docs/Previews/SkillAtlas/` 图片。
- 指定队伍槽位升级、按 ID 直接授予技能由独立 [GMSystem](../Tools/GM.md) 提供；正常升级与研习入口保持原规则。

- 来源：[战斗总览](https://my.feishu.cn/wiki/XvPvw2sk2ih7BTkAonGcjmR7nlg)、[游戏玩法](https://my.feishu.cn/wiki/AjNMwkcNHisPnukqnESc78azn0b)、[一些想法](https://my.feishu.cn/wiki/OHZhwsGudiXWfIkywDDcczNunfe)。属性沿用六个一级属性与战斗/生活二级属性；初始数值与升级策略为用户授权的可配置 Demo。
- `GrowthSystem` 依赖 Battle；`CombatActorData.Growth` 的 `CharacterGrowthData` 持有等级、经验、属性投入、被动阶数、开放树、潜力、已学技能、学习机会、当前职业与已加入职业。Lua 只解释配置与产生显示投影。成长与特质通过[角色存档](CharacterSave.md)跨运行恢复，经历日志不在保存范围内。
- `CombatStats` 统一叠加基础、特质、属性投入、被动与装备数值；生命上限变化保留已受伤害，倒地不会因加点复活。主动技能合并到原有装备/战斗技能查询，既有模板和装备技能保留。
- `GrowthSystem.PrepareActor` 只初始化独立角色的养成/特质，不写经历；[招募](Narrative.md)预检使用它，正式加入队伍后调用 `RecordJoined`。原 `Initialize` 仍组合这两步，供已在队伍中的初始角色使用。
- 属性点与被动点是独立资源；加点/学习仅允许 map/area 阶段。天赋图只引用 `PassiveSkillTable`，支持多属性加算和 `immunityTags` 声明式免疫；没有主动技能节点、重置返还或通用被动触发器。`GrowthRules:Immunity(actor,tag)` 仅查询已学习且阶数大于0的节点，返回授予免疫的被动定义或nil，不按被动名称判断。
- `adjacent_any`：从根节点开始，可沿任一已学习邻居扩展，边视为无向；`prerequisite_all`：边 from→to 是前置，全部前置已学习才可投点。节点支持阶数、费用和角色等级门槛；初始化拒绝跨树边、重复边、不可达节点和有向死锁。
- `ProfessionTable` 定义战士、游侠、法师、巧匠及开放树；`ProfessionSkillTable` 定义课程、角色等级与全部属性门槛，额外使用图谱前置。探索阶段免费 `ChangeProfession`，已经学习的能力永久保留，装备不受职业限制；当前没有分职业等级。初始职业赠送自身准备技一次，转职不赠技能，其他职业准备技须选学。
- `GrowthSystem.Learn` 从当前职业全部合格课程主动选择，每次消费 `PendingCount` 的一次机会；已掌握/固有技能不能重复学习，道具动作不属于课程。空目录、条件不足、浏览和转职均不消耗机会。旧 `PrepareOffers` 保留为无副作用兼容入口，正常玩法不再生成随机候选；旧随机规则仅留作兼容工具。
- `GrowthRuleTable` 管初始点数、初始学习次数、属性门槛是否包含装备与日志条数；`GrowthLevelTable` 每行定义经验、点数与是否学习，连续 2..N 行确定上限。当前初始 2 属性点/2 被动点/1 学习机会，每级 2 属性点/1 被动点，偶数级追加学习机会。连续升级全部保留，学习不消耗养成 RNG。
- `GrowthAttributeTable` 注册属性；`GrowthProfileTable` 配置初始职业/树/特质/潜力；`TalentTree/Node/EdgeTable` 定义被动图；`PassiveSkillTable` 定义每阶收益。法师职业开放树 3，「奥术兵装」节点 301 要求角色等级 2、1 天赋点并加 1 智力，触媒适配器以节点阶数判定专精。新增配置后导表，不手改 `_Gen`。
- 「紧握武器」为被动14、节点10，位于远行者之路，通过4→10接在剑术修习之后，1级可学、消耗1点、最高1阶；`immunityTags=['disarm']` 完全免疫缴械。它使用空属性数组和 `iconAttribute='strength'`，不附带占位属性加成；缴械拒绝与资源契约见[战斗](Battle.md)。纯免疫被动必须显式配置已有属性图标，初始化拒绝无效果、重复免疫标记和无效图标。
- `Chronicle` 与事件共用 `StoryLogTemplateTable`；`AdventureData` 持有带序号、地点、参与者、事件与选项 ID 的经历快照。个人页按参与者过滤，游戏日志只显示配置条数，完整经历不裁剪；没有虚构游戏日期或关系值。
- `CharacterGrowth` 是暂停世界的模态 Panel，按 C 或游戏内日志上的“同行者”打开，分“属性加点 / 职业与天赋 / 旅途经历”。职业与天赋页的“职业技能 / 被动天赋”互斥显示：职业页左侧宽课程列表、右侧详情与学习按钮，选中课程只预览，点击学习才消费机会；课程按可学习、条件未满足、已掌握排序，其他来源能力附后。免费转职使用独立目录，保留已学能力；被动页左侧天赋图、右侧节点详情与投入按钮、右下天赋树目录。经历页倒排并分页；属性页保留特质、关系、荣誉展示。
- 两种技艺模式复用现有 `PreviousTree/NextTree` 按钮、`SkillRowsScroll/viewport`、`GraphScroll` 与详情绑定，仅改变已有 RectTransform 的尺寸及可见性；不创建结构或绕过 LuaReference 搜索组件。`PreviousTree` 表示职业模式，`NextTree` 表示被动模式，树选择改由右下目录完成。真实 UI 验证入口为 `growth_ui_integration.lua`，覆盖选择不学习、显式学习、模式尺寸、图鉴往返与缓存生命周期；独立控制器回归为 `growth_navigation_core.lua`。
- 角色手记采用纸色界面、真实角色预览、紧凑属性/特质标签和图标天赋图；`InventoryCharacterView` 支持 0 个引线的纯肖像与 8 个引线的装备模式，关闭即释放预览。`CharacterJournalAssets` 菜单“重建角色手记布局”显式覆盖本模块布局并生成 JournalAttribute/Skill/Entry 与图标；日常同步使用原创建菜单保留布局。图标是可编辑资源，未把按钮或文字烘焙到背景中。
- `Project Y/UI/同步角色手记图标` 同步 CharacterGrowth 及已注册 SkillAtlas 的 glyphs 绑定，保留手工布局。`CharacterJournalAssets.CreateGlyphBindings` 从 GrowthAttributeTable.code 和被动所需图标收集绑定；被动优先使用 `iconAttribute`，为空时沿用 `attributeNames[1]`，TalentNode Widget 使用同一规则。技能图谱生成复用此入口，“创建事件与养成 UI”执行同一同步。已有 Journal Sprite 原样保留，缺少资源且未定义绘制配方时明确报错；动物亲和与魅力使用各自图标，不以占位图掩盖遗漏。
- 两个界面的图标定向回归通过 Unity MCP 执行 `Tools/Construction/check_glyphs.cs`，使用 `skill_glyphs_integration.lua` 在独立 PreviewScene 打开角色总览、逐个浏览全部技能分类并检查动物技能 Tips 与缓存重开；不进入 Play，不改变角色学习状态。
- 图标/属性扩展后执行该同步，再用 `growth_ui_integration.lua` 检查当前配置的全部属性行及 Sprite 引用；测试不写死旧的 17 项，也覆盖 animalAffinity/charisma，运行时仍拒绝缺失或空 Sprite 绑定。
- `StoryGrowthAssets.Create` 经 Unity MCP/菜单 `Project Y/UI/创建事件与养成 UI` 生成和注册 Prefab，重复执行保留已有布局并同步图片。新增图的配置路径必须为 Sprite，资源直接序列化在 `StoryGrowthView`，构建可收集；Lua 不搜索组件、不运行时创建界面结构。
- 最小检查：`profession_core.lua`、`growth_core.lua`、`skill_atlas_core.lua` 经 `Tools/Tests/run_lua.py` 执行。真实 C# 状态用 `Project Y/远征/验证角色养成与故事`；UI 用 `Project Y/UI/验证事件与养成 UI`，在独立 PreviewScene 验证转职、选学按钮、缓存与暂停恢复，输出 `Docs/Previews/StoryGrowth-*.png`。新增 C# API 后须集中编译并生成 xLua 桥接；这些入口不代表授权操作 Editor。
- 紧握接入的定向检查：[growth_core.lua](../../Tools/Tests/growth_core.lua) 5组与 [disarm_immunity.lua](../../Tools/Tests/disarm_immunity.lua) 4组已通过，覆盖图连通、可学习/满阶、实际免疫查询、无额外属性、缴械拒绝事务及真实概率边界；本次未进入Play。

## 关键入口

- [GrowthSystem.lua](../../Lua/Game/Progression/GrowthSystem.lua) / [GrowthRules.lua](../../Lua/Game/Progression/GrowthRules.lua) / [Chronicle.lua](../../Lua/Game/Progression/Chronicle.lua)：命令、规则与记录模板。
- [ProfessionRules.lua](../../Lua/Game/Progression/ProfessionRules.lua) / [职业配置](../../Config/Tables/Progression/ProfessionTable.json) / [职业课程](../../Config/Tables/Progression/ProfessionSkillTable.json)：职业目录、学习条件与来源；[定向检查](../../Tools/Tests/profession_core.lua)。
- [SkillAtlas.lua](../../Lua/Game/Progression/SkillAtlas.lua) / [SkillAtlasCtr.lua](../../Lua/UI/Panel/SkillAtlasCtr.lua) / [SkillAtlasView.cs](../../Assets/GameFramework/Runtime/UI/SkillAtlasView.cs) / [SkillAtlasAssets.cs](../../Assets/GameFramework/Editor/SkillAtlasAssets.cs)：图谱规则、控制器、锚定浮窗与可编辑资源。
- [CharacterGrowthData.cs](../../Assets/GameFramework/Runtime/Data/CharacterGrowthData.cs) / [ChronicleEntryData.cs](../../Assets/GameFramework/Runtime/Data/ChronicleEntryData.cs)：权威状态与不可变经历。
- [配置目录](../../Config/Tables/Progression/) / [设计与默认规则](../../Docs/StoryGrowth.md)：配表、边界和参考来源。
- [CharacterGrowthCtr.lua](../../Lua/UI/Panel/CharacterGrowthCtr.lua) / [AdventureUIBridge.lua](../../Lua/UI/AdventureUIBridge.lua) / [StoryGrowthAssets.cs](../../Assets/GameFramework/Editor/StoryGrowthAssets.cs)：UI 接入与资源生成。
- [CharacterJournalAssets.cs](../../Assets/GameFramework/Editor/CharacterJournalAssets.cs)：配置驱动的图标同步与显式布局重建；[StoryGrowthView.cs](../../Assets/GameFramework/Runtime/UI/StoryGrowthView.cs)：序列化 Sprite 查询。
- [纯 Lua 检查](../../Tools/Tests/growth_core.lua) / [真实状态检查](../../Tools/Tests/growth_integration.lua) / [Prefab 检查](../../Tools/Tests/growth_ui_integration.lua)。
