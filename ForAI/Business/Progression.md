# 角色养成与经历

关键词：Growth、升级、经验、加点、网状天赋、被动技能、主动技能池、潜力、特质标签、经历、CharacterGrowth。

## 文档目录

正文：职责与规则 / 配置 / UI 与验证；关键入口：状态 / 规则 / 资源。

## 正文

- 动物亲和与驯服技能方向、骑乘亲密度解锁技能见[森林动物与骑乘](Animals.md)；`skillDirection` 独立于属性分组，生活属性也可按配置参与研习。
- 巧匠研习、材料施工与高台/挖掘规则见[巧匠营造](Construction.md)。
- `SkillAtlas` 是独立的暂停世界浏览 Panel，从 HUD 菜单或角色手记进入；顶部一级领域、左侧二级目录、中央主动技能图谱，全局搜索可跳转分类。`SkillDiscipline/SkillCategory/SkillAtlasTable` 定义目录、唯一主归属、关联目录、坐标、标签与 all/any 前置；关联目录不复制技能身份。全部主动技能必须有图谱记录，初始化拒绝循环依赖。
- 图谱依角色投影已掌握/当前可用、满足研习条件、条件不足或特殊来源；查看、搜索、切队员和重开不产生研习候选、不直接学习。`SkillAtlas` 前置与 `GrowthRules.Draw/GrowthSystem.Learn` 共用查询；被动天赋图仍仅使用 PassiveSkillTable。
- 选中 Cell 的 Tips 显示效果、AP、距离、冷却、材料/工具、属性与获取途径，前置可点击跳转。浮窗锚定 Cell、贴边翻转并限制在页面内；随滚动更新，Cell 离屏时关闭，空白/关闭按钮/Esc 关闭。`SkillAtlasView` 只负责几何表现，Lua 组件引用全部走 LuaReference。
- Unity MCP 调用 `SkillAtlasAssets.Create`（菜单“创建技能图谱”）生成并注册本模块 Prefab，重复执行保留布局；同步角色手记的图谱入口绑定。纯 Lua 检查为 `skill_atlas_core.lua`，真实 UI 检查通过 MCP 执行 `Tools/Construction/run_checks.cs`，在 PreviewScene 验证分类、搜索、锚点和缓存生命周期并生成 `Docs/Previews/SkillAtlas/` 图片。
- 指定队伍槽位升级、按 ID 直接授予技能由独立 [GMSystem](../Tools/GM.md) 提供；正常升级与研习入口保持原规则。

- 来源：[战斗总览](https://my.feishu.cn/wiki/XvPvw2sk2ih7BTkAonGcjmR7nlg)、[游戏玩法](https://my.feishu.cn/wiki/AjNMwkcNHisPnukqnESc78azn0b)、[一些想法](https://my.feishu.cn/wiki/OHZhwsGudiXWfIkywDDcczNunfe)。属性沿用六个一级属性与战斗/生活二级属性；初始数值与升级策略为用户授权的可配置 Demo。
- `GrowthSystem` 依赖 Battle；`CombatActorData.Growth` 的 `CharacterGrowthData` 持有等级、经验、属性投入、被动节点阶数、开放树、锁住的潜力、已学技能和待选候选。Lua 只解释配置与产生显示投影。沿用远征生命周期，开始新远征/关闭运行时清空，尚无跨运行存档。
- `CombatStats` 统一叠加基础、特质、属性投入、被动与装备数值；生命上限变化保留已受伤害，倒地不会因加点复活。主动技能合并到原有装备/战斗技能查询，既有模板和装备技能保留。
- `GrowthSystem.PrepareActor` 只初始化独立角色的养成/特质，不写经历；[招募](Narrative.md)预检使用它，正式加入队伍后调用 `RecordJoined`。原 `Initialize` 仍组合这两步，供已在队伍中的初始角色使用。
- 属性点与被动点是独立资源；加点/学习仅允许 map/area 阶段。天赋图只引用 `PassiveSkillTable`，当前被动效果为可配置多属性加算；没有主动技能节点、重置返还或通用被动触发器。
- `adjacent_any`：从根节点开始，可沿任一已学习邻居扩展，边视为无向；`prerequisite_all`：边 from→to 是前置，全部前置已学习才可投点。节点支持阶数、费用和角色等级门槛；初始化拒绝跨树边、重复边、不可达节点和有向死锁。
- 技能学习在升级跨过配置等级时排队。先在配置允许参与研习且当前有可用技能的属性中按权重抽不同方向，再从每方向满足属性范围的层级池按权重取一项；排除固有/装备/已学技能及重复候选。合法空池明确记经历并消费本次机会，不伪造技能；唯一技能不足时允许少于设定候选数。
- 候选与独立随机状态存于 C#，生成发生于升级和完成上一轮学习，打开/关闭窗口不会重抽；连续跨级的机会逐次保留。装备是否影响方向与层级门槛由规则表决定。
- `GrowthRuleTable` 管初始点数、方向数量区间、权重公式、装备参与和日志显示数；`GrowthLevelTable` 每行定义到达等级的经验、点数与是否学习，连续 2..N 行确定等级上限。当前 Demo 初始各 2 点、每级 2 属性点/1 被动点、偶数等级研习，参数均在表中。
- `GrowthAttributeTable` 注册显示与可投入属性；`GrowthProfileTable` 为角色模板配置初始树/特质/潜力；`TalentTree/Node/EdgeTable` 定义树规则、节点坐标和连线；`PassiveSkillTable` 定义每阶收益；`ActiveSkillPoolTable` 定义属性方向、技能、层级、上下限和基础权重。新增配置后运行导表器，不手改 `_Gen`。
- `Chronicle` 与事件共用 `StoryLogTemplateTable`；`AdventureData` 持有带序号、地点、参与者、事件与选项 ID 的经历快照。个人页按参与者过滤，游戏日志只显示配置条数，完整经历不裁剪；没有虚构游戏日期或关系值。
- `CharacterGrowth` 是暂停世界的模态 Panel，按 C 或游戏内日志上的“同行者”打开；总览含属性与特质标签，技能页含可滚动天赋图和主动候选/已掌握技能，经历页按时间顺序倒排并分页。节点点击查看，独立按钮确认投入；UI 组件全部通过 LuaReference 绑定。
- 角色手记采用纸色界面、真实角色预览、紧凑属性/特质标签和图标天赋图；`InventoryCharacterView` 支持 0 个引线的纯肖像与 8 个引线的装备模式，关闭即释放预览。`CharacterJournalAssets` 菜单“重建角色手记布局”显式覆盖本模块布局并生成 JournalAttribute/Skill/Entry 与图标；日常同步使用原创建菜单保留布局。图标是可编辑资源，未把按钮或文字烘焙到背景中。
- `Project Y/UI/同步角色手记图标` 同步 CharacterGrowth 及已注册 SkillAtlas 的 glyphs 绑定，保留手工布局。`CharacterJournalAssets.CreateGlyphBindings` 从 GrowthAttributeTable.code 和 PassiveSkillTable.attributeNames[1] 收集所需图标，技能图谱生成也直接使用这个入口，不再复制可能过期的角色手记 Prefab 图标表；“创建事件与养成 UI”执行同一同步。已有 Journal Sprite 原样保留，缺少资源且未定义绘制配方时明确报错；动物亲和与魅力使用各自图标，不以占位图掩盖遗漏。
- 两个界面的图标定向回归通过 Unity MCP 执行 `Tools/Construction/check_glyphs.cs`，使用 `skill_glyphs_integration.lua` 在独立 PreviewScene 打开角色总览、逐个浏览全部技能分类并检查动物技能 Tips 与缓存重开；不进入 Play，不改变角色学习状态。
- 图标/属性扩展后执行该同步，再用 `growth_ui_integration.lua` 检查当前配置的全部属性行及 Sprite 引用；测试不写死旧的 17 项，也覆盖 animalAffinity/charisma，运行时仍拒绝缺失或空 Sprite 绑定。
- `StoryGrowthAssets.Create` 经 Unity MCP/菜单 `Project Y/UI/创建事件与养成 UI` 生成和注册 Prefab，重复执行保留已有布局并同步图片。新增图的配置路径必须为 Sprite，资源直接序列化在 `StoryGrowthView`，构建可收集；Lua 不搜索组件、不运行时创建界面结构。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/growth_core.lua`；真实 C# 状态用 `Project Y/远征/验证角色养成与故事`。UI 用 `Project Y/UI/验证事件与养成 UI`，在独立 PreviewScene 验证按钮、缓存重开与暂停恢复，并输出 `Docs/Previews/StoryGrowth-*.png`；不进入 Play、不切换当前编辑场景。新增 C# API 后须编译并重新生成 xLua 桥接。

## 关键入口

- [GrowthSystem.lua](../../Lua/Game/Progression/GrowthSystem.lua) / [GrowthRules.lua](../../Lua/Game/Progression/GrowthRules.lua) / [Chronicle.lua](../../Lua/Game/Progression/Chronicle.lua)：命令、规则与记录模板。
- [SkillAtlas.lua](../../Lua/Game/Progression/SkillAtlas.lua) / [SkillAtlasCtr.lua](../../Lua/UI/Panel/SkillAtlasCtr.lua) / [SkillAtlasView.cs](../../Assets/GameFramework/Runtime/UI/SkillAtlasView.cs) / [SkillAtlasAssets.cs](../../Assets/GameFramework/Editor/SkillAtlasAssets.cs)：图谱规则、控制器、锚定浮窗与可编辑资源。
- [CharacterGrowthData.cs](../../Assets/GameFramework/Runtime/Data/CharacterGrowthData.cs) / [ChronicleEntryData.cs](../../Assets/GameFramework/Runtime/Data/ChronicleEntryData.cs)：权威状态与不可变经历。
- [配置目录](../../Config/Tables/Progression/) / [设计与默认规则](../../Docs/StoryGrowth.md)：配表、边界和参考来源。
- [CharacterGrowthCtr.lua](../../Lua/UI/Panel/CharacterGrowthCtr.lua) / [AdventureUIBridge.lua](../../Lua/UI/AdventureUIBridge.lua) / [StoryGrowthAssets.cs](../../Assets/GameFramework/Editor/StoryGrowthAssets.cs)：UI 接入与资源生成。
- [CharacterJournalAssets.cs](../../Assets/GameFramework/Editor/CharacterJournalAssets.cs)：配置驱动的图标同步与显式布局重建；[StoryGrowthView.cs](../../Assets/GameFramework/Runtime/UI/StoryGrowthView.cs)：序列化 Sprite 查询。
- [纯 Lua 检查](../../Tools/Tests/growth_core.lua) / [真实状态检查](../../Tools/Tests/growth_integration.lua) / [Prefab 检查](../../Tools/Tests/growth_ui_integration.lua)。
