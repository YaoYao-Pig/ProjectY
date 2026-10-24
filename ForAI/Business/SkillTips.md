# 技能说明与协同发现

关键词：技能 Tips、Tooltip、彩色标签、TMP、link、术语、下划线、技能参数、协同效应、问号遮罩、bitset。

## 文档目录

正文：配置与投影 / 交互与资源 / 发现与持久化 / 验证；关键入口：配置、模型、原生视图。

## 正文

- 战斗技能与道具共用结构化说明卡：标题、彩色标签、效果正文、参数和协同效应。`BattleHUDModel` 提供真实装备及 Buff 修正后的 `skill` 与剩余冷却；`SkillTipModel` 只读投影，不用示例目标猜测伤害。弹道、追踪、高低差及转施通过术语链接展开。
- `SkillTagTable` 配置标签文字及前景/背景色；`SkillDescriptionTable` 以技能 ID 关联正文、标签和复用片段；`SkillTipTextTable` 同时提供术语和片段。正文使用原生 `<link="term:hit">命中</link>`，`SkillTipCatalog.Rich` 校验目标并统一颜色/下划线。术语可继续链接其他术语；缺失链接在配置加载时明确失败。
- `SkillSynergyTable` 用稳定正整数 ID、`runeIds`、可选 `skillIds`、名称及正文声明说明关系；不改变战斗规则。当前单组件协同 ID 直接沿用符文 ID，组合要求同一武器同时具有全部组件；ID 不随排序重排或回收。候选按真实技能组及影响字段过滤，当前生效按装备规则解析的 `appliedRuneIds` 判断。
- `SkillTipPresenter` 管每张说明卡的导航栈，返回上层或重复链接时回到已有页；隐藏/切换技能清理导航。原生 `SkillTooltipView` 管 TMP、可复用行、滚动、定位及卡片 PointerEnter/Exit；按钮 `UIPointerState` 与卡片用 Enter 携带的实时 `PointerEventData.pointerCurrentRaycast` 校验旧 hover，当前命中离开自身或子节点即失效，不能依赖 Exit 必然送达。HUD 每帧将按钮 hover 传给 `KeepOpen(anchorHovered)`，不能短路计时，也不以矩形包含或射线命中重新开启已移出的 hover。离开按钮和卡片超过 0.4 秒关闭，间隙内移入卡片可继续术语导航；隐藏清理 hover。链接点击不产生战斗命令。未知协同只投影空名称/正文并显示问号遮罩，没有隐藏可点击文本。
- 编辑器 `Project Y/UI/同步技能说明卡` 经 Unity MCP 调用 `SkillTooltipAssets.SyncBattleHUD`，在已有 BattleHUD SafeArea 下持久创建独立卡片并绑定 `SkillTip`；旧 Tooltip 保留给目标命中预览。组件和模板引用全部序列化，不在 Lua 搜索节点。MainHud 的嵌套 BattleHUD 继承此绑定。
- 成功装配符文、成功装备已有组合的武器、完成初始队伍装备时记录发现；失败命令、只浏览、获得未装配物品、敌人装备及读档不解锁。拆下后保留发现。状态归 `AdventureData`，全队共享，重开远征清空；Lua 不持有副本。存档版本、bitset 编码与准备/提交契约见[角色存档](CharacterSave.md)。
- 最小离线检查：`python -B Tools/Tests/run_lua.py Tools/Tests/skill_tooltip_core.lua`，覆盖真实表、术语引用、修正后参数、未知文本隔离、装配失败/成功、组合和导航。原生 UI 与存档检查分别见下方入口；这些命令不授权启动 Editor、Play 或全量测试。
- 本轮已通过一次集中 C# 编译、Prefab 同步、离线核心及 HUD 基本回归；隔离 Edit Mode 中通过实际 TMP 点击/两层返回、滚动/窄屏、真实 HUD 悬停/缓存生命周期、MainHud 嵌套绑定与 bitset 存读/坏档/旧档迁移。未进入 Play；[预览](../../Docs/Previews/SkillTooltip/skill-card.png)与[协同区域](../../Docs/Previews/SkillTooltip/synergies.png)来自真实 Prefab 渲染。

## 关键入口

- [SkillTipCatalog.lua](../../Lua/Game/Presentation/SkillTipCatalog.lua) / [SkillTipModel.lua](../../Lua/Game/Presentation/SkillTipModel.lua)：配置校验、复用正文和结构化参数。
- [SkillTipPresenter.lua](../../Lua/UI/SkillTipPresenter.lua) / [BattleHUDContent.lua](../../Lua/UI/Widget/BattleHUDContent.lua)：链接导航及 HUD 生命周期。
- [SkillTooltipView.cs](../../Assets/GameFramework/Runtime/UI/SkillTooltipView.cs) / [资源同步](../../Assets/GameFramework/Editor/SkillTooltipAssets.cs)：TMP 交互、滚动、自适应与持久绑定。
- [原生说明卡检查](../../Tools/Tests/skill_tooltip_editmode.cs) / [HUD 接入检查](../../Tools/Tests/skill_tooltip_hud_integration.lua)：隔离 PreviewScene 的实际 TMP、LuaReference、悬停与缓存测试。
- [hover 关闭回归](../../Tools/Tests/skill_tooltip_hover.lua)：`python -B Tools/Tests/run_lua.py Tools/Tests/skill_tooltip_hover.lua`，覆盖长时间悬停后跨间隙、空白处超时关闭、术语卡移出、技能/道具切换、模态遮挡与隐藏；[原生 hover 检查](../../Tools/Tests/skill_tooltip_hover_editmode.cs) 验证计时、导航及缓存重开；[真实射线检查](../../Tools/Tests/skill_tooltip_raycast_editmode.cs) 使用保存的按钮/卡片 Prefab、GraphicRaycaster 与 InputModule 事件分派，覆盖 TMP 子节点及 Exit 未送达时的失效，均在隔离 PreviewScene 中执行、不进入 Play。
- [SkillSynergies.lua](../../Lua/Game/Equipment/SkillSynergies.lua) / [EquipmentSystem.lua](../../Lua/Game/Equipment/EquipmentSystem.lua)：只读候选及成功命令的发现时机。
- [SkillSynergyDiscovery.cs](../../Assets/GameFramework/Runtime/Data/SkillSynergyDiscovery.cs) / [存档检查](../../Tools/Tests/skill_synergy_save_integration.lua)：bitset 与真实隔离服务测试。
