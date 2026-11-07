# 称号授勋与士气
关键词：授勋、称号、Title、自定义称号、捏称号、声望点数、TitleForge、个人挑战、击杀统计、传奇击杀、任务次数、勇气、士气、Morale、白环、溃逃。

## 文档目录
正文：称号归属与配置 / 士气 / 界面与保存 / 验证；关键入口：规则 / 数据 / 配置 / 资源。

## 正文

- [死门检定](DeathDoor.md)直接读取当前士气比例：士气越低死亡率越高；每次幸存大幅扣除士气，可触发已有逃跑与重整行为。士气的存活判断包括0血死门角色。

- `ReputationState` 持有全队共享的称号声望，独立于阵营关系声望；普通/传奇击杀和完整 Mission/城镇委托金额来自 `ReputationRuleTable`。传奇金额替代普通金额；Quest 中间阶段不重复发放。任务按 kind+实例永久去重，真实敌对击杀按本场目标去重；任务预览与结算奖励卡片展示全队声望。
- `TitleForgeEffectTable` 定义每档效果、价格与上限，覆盖 `GrowthAttributeTable` 的全部20项属性；`TitleForgeRules` 启动校验覆盖性。自定义称号支持属性加算、攻击伤害、击杀回血/士气、低血量增伤、战斗回合回血及承伤/勇气减益。正面费用减去有上限的负面抵扣（当前50%），必须至少一项正面；制作时重新校验并永久扣费，不自动装备，卸下不返还。
- 自定义称号是角色自己的负ID实例，与正ID配置授勋共用一个装备槽；保存名称、效果ID/档位、制作时实际支付费用。名称经同一C#边界Trim并限制1–16个Unicode字符，拒绝控制符、尖括号与非法代理对；玩家输入不进入语言表。界面从手记称号页进入原生 `TitleForge`，按基础/战斗/生活/特殊/负面分组加减档位，实时展示价格、余额与效果预览；当前提供制作和装备，不提供已制成实例改造。
- `TitleCombat` 从 `GameEffects` 的真实伤害致死路径取击杀证据，校验参战对象、敌对和非驯服目标；GM合成 defeated 不加声望。持续伤害保留sourceId归属；击杀回血/额外士气共用每个持有者自身回合最多两次的上限，声望不受该次数限制。0HP不触发称号回血/士气，回合回血仅战斗内回合结束；低血量增伤仅0<HP<30%的实际非周期攻击伤害，承伤减益同时影响即时/周期伤害。临时凭据/次数由 `TitleCombatState` 持有，不入档。

- `CombatActorData` 持有个人称号、已装备 ID、计数和任务结算凭据；`TitleState` 提供反射桥，Lua 只解释配置。称号永久归角色所有，获得不自动装备；探索阶段通过 `title_equip(actorId,titleId)` 切换，0 卸下，每次只有一个生效。成长、特质、装备、称号属性统一进入 `CombatStats`；攻击技能伤害倍率和额外士气上限由装备中的称号提供，持续伤害沿用施加时的技能快照。
- `TitleTable` 以 `requirementIds` 引用 `TitleRequirementTable`，支持 all/any 组合。条件 kind 为 kill、legend、mission、quest、town、rescue，targetId=0 表示任意，非零引用对应类型配置。kill 归真实玩家击杀者，排除友伤、中立与被驯服对象，同场同目标去重；legend 使用现有 `LegendaryEncounters.byUnit` 身份。rescue 复用 [同行经历](PartyStory.md) 的真实危急救援次数。
- 剧情任务、任务阶段和城镇委托在成功完成后，为当时全部在队成员（含倒地者）记录进度。结算凭据按 kind+实例 ID 去重；城镇委托按定义统计但按实例去重。mission:0 包括剧情 Mission 和城镇委托，不包括中间 Quest；quest 条件独立。失败发奖和预览不记进度，后加入成员不追溯过去任务。
- 勇气是 `GrowthAttributeTable` 的 combat 属性。基础勇气来自 `MoraleRuleTable.baseCourage`，再叠加角色二级属性、投入、装备和称号；旧角色缺少这个二级值时仍使用统一基础值，不重新随机出生属性。
- `MoraleRuleTable` 定义勇气→上限公式、初始比例、成功率上下界、友军支持、敌军压力、受伤阈值和重整距离；`MoraleStageTable` 定义逃跑/崩溃/动摇/稳定/自信的递增比例阈值、命中/防御倍率和检定修正。`MoraleEventTable` 定义伤势、队友倒下或逃跑、击杀/目睹敌人倒下、寡不敌众及重整的难度与点数变化。
- 首版基础勇气40、上限50+勇气、开战取上限75%向下取整；自信≥90%、稳定≥60%、动摇≥40%、崩溃≥20%、逃跑<20%。称号的额外上限在公式后相加；自信命中/防御×1.1，动摇×0.9，崩溃×0.8，逃跑禁止行动且防御×0.7。首批十个称号的设计与具体数值见[设计表](../../Docs/TitlesAndMoraleDesign.md)，源表是唯一运行配置。
- 检定复用 BattleData 的随机流（0–99 转为 1–100）。负面事件失败扣点，正面事件成功加点；仅跨入逃跑时向附近友军传播压力，已逃跑者不重复传播。重伤使用实际生命损失，零伤害不检定；死亡事件同场去重，盟友/敌对关系使用多势力关系查询。
- 士气为战斗临时状态，每场初始化、结束/清理后释放，不写入远征存档。低士气改变命中和防御；逃跑者不能攻击、使用道具或发动借机攻击，回合由系统选择远离敌人的可达格并结束，移动仍会受借机攻击。受击使移动距离下降时，只在本次反应结算后重选可达格，不额外触发第二轮借机攻击。逃跑不直接删除角色、判死亡或制造战利品；拉开距离后回合开始可检定重整到动摇状态。场景边界与战斗最大回合仍沿用原规则。
- 角色手记新增“称号”页，显示全部配置、解锁状态、个人进度和单槽装备按钮；长条件详情使用独立滚动区。总览显示当前称号与士气状态。`HudHealth.Morale` 是红色 HP 环外侧的白色 Filled Image，沿用 HealthRingMesh、WorldUI 跟随和遮挡，不拦截点击；探索时显示下一场初始比例。
- 角色身份名牌统一由 `Game.Presentation.CharacterIdentity.Read/Format` 投影为“已装备称号（可选、富文本金色）→较大名字→较小当前职业”。没有称号时不产生空行；未加入职业的单位只在拥有出生职业时显示该职业，无职业动物不补标签。兼容旧人物模板的“名字 · 初始职业”，当前职业始终取角色状态；NPC 名称沿用侦察身份解析或调用方明确提供的名字，不修改对白、日志等句子内的人名。手记/图谱/背包/工坊选择器、队伍 HUD、战斗行动条、侦察列表与详情、营地编组已接入；HUD 投影保留原 `name`，另提供 `identity`，不得把富文本写入业务名称。
- 名牌复用现有 Text/TMP 与 LuaReference；富文本、按钮高度与装饰安全区由 [原生布局同步](../../Tools/UICharacterIdentity/apply_layout.cs) 保存。重建相关 UI 或换皮后，在空闲 Edit Mode 通过 Unity MCP 重新应用该脚本；工坊自适应布局与营地标题自适应高度由各自 View 维护，不依赖运行时查找子节点。标题括号模板为 `Language.CharacterIdentityTitle`，称号/姓名/职业正文仍来自对应配置 `text`。
- 保存版本为45（角色）/46（远征）。顶层 `reputation` 保存全队余额与任务凭据；`ActorSave.titles` format=2 在原 owned/equipped/counters/settlements 外保存 custom 与下一个负ID。旧1–44档声望从0开始，不追溯奖励；旧称号format=1保留原成就与进度，1–36档仍为空称号迁移。拒绝坏名称、未知效果、超限档位、重复实例/计数及未拥有的装备称号。历史支付费用不按当前价重算；士气与称号战斗计数不入档。
- 验证：首版十称号与士气表已导出；离线条件与士气规则、原生状态JSON回读、6项真实Prefab检查、本地化源检查均通过。真实配置+C#系统检查覆盖致死伤害击杀归属、传奇身份、任务领取/重复拒绝、十称号可达、装备替换、临时v38存档及缺勇气字段的v36迁移；实际UI检查覆盖十行列表、锁定查看、装备/卸下、换人、勇气图标和缓存重开；真实战斗检查覆盖自动逃跑、受击缩距后的重选、单次借机攻击与回合交接。未进入Play，尚未做实机整场战斗视觉和长期平衡验收。

## 关键入口

- [TitleForgeRules.lua](../../Lua/Game/Progression/TitleForgeRules.lua) / [ReputationState.cs](../../Assets/GameFramework/Runtime/Data/ReputationState.cs)：配置报价、全属性覆盖、共享钱包和永久结算凭据；[效果表](../../Config/Tables/Progression/TitleForgeEffectTable.json) / [声望规则](../../Config/Tables/Progression/ReputationRuleTable.json)。
- [TitleCombat.lua](../../Lua/Game/Battle/TitleCombat.lua)：实际伤害/死亡与回合钩子；[TitleForgeCtr.lua](../../Lua/UI/Panel/TitleForgeCtr.lua) / [原生布局同步](../../Tools/UITitleForge/apply_layout.cs)：通过Unity MCP在空闲Edit Mode保存Prefab与语言绑定，不手改YAML。
- [制作规则检查](../../Tools/Tests/title_forge_rules.lua) / [战斗检查](../../Tools/Tests/title_combat.lua) / [原生状态检查](../../Tools/Tests/reputation_state_editmode.cs)：前两项通过 `run_lua.py` 执行，原生片段通过MCP，不进入Play。实际验证范围以本轮交付为准。
- [真实UI检查与截图](../../Tools/Tests/title_forge_preview.cs)调用[控制器检查](../../Tools/Tests/title_forge_ui.lua)，覆盖20属性加减、五组跳转、余额与报价、制作/返回/装备、缓存重开及嵌套暂停释放；[临时存档检查](../../Tools/Tests/title_forge_save_editmode.cs)调用[真实系统检查](../../Tools/Tests/title_forge_save.lua)，覆盖全部属性实际数值、生命上限与伤势保持、v44迁移、v46准备/验证/恢复、坏候选隔离。2026-11-01上述定向检查已通过，预览见[制作页](../../Docs/Previews/TitleForge/title-forge.png)；本轮仅主动触发一次项目C#编译，未进入Play，未验证长期平衡。

- [CharacterIdentity.lua](../../Lua/Game/Presentation/CharacterIdentity.lua)：跨界面的只读名牌投影与富文本格式；[定向预览入口](../../Tools/Tests/character_identity_preview.cs)执行[实际控制器检查](../../Tools/Tests/character_identity_ui.lua)，覆盖装备/卸下、转职、无称号/动物、四个真实面板与紧凑名牌高度，并保存[预览与结果](../../Docs/Previews/CharacterIdentity/validation.txt)。不启动 Play 或访问玩家存档。
- [TitleRules.lua](../../Lua/Game/Progression/TitleRules.lua) / [Titles.lua](../../Lua/Game/Progression/Titles.lua)：条件、加成、事件归属与装备门禁。
- [TitleState.cs](../../Assets/GameFramework/Runtime/Data/TitleState.cs) / [MoraleState.cs](../../Assets/GameFramework/Runtime/Data/MoraleState.cs)：权威状态、结算凭据、保存与战斗生命周期。
- [Morale.lua](../../Lua/Game/Battle/Morale.lua)：检定、档位、连锁压力、自动移动与重整。
- [TitleTable](../../Config/Tables/Progression/TitleTable.json) / [TitleRequirementTable](../../Config/Tables/Progression/TitleRequirementTable.json) / [MoraleRuleTable](../../Config/Tables/Adventure/MoraleRuleTable.json) / [MoraleStageTable](../../Config/Tables/Adventure/MoraleStageTable.json) / [MoraleEventTable](../../Config/Tables/Adventure/MoraleEventTable.json)：唯一配置源，修改后导表。
- [TitleMoraleAssets.cs](../../Assets/GameFramework/Editor/TitleMoraleAssets.cs)：Unity MCP 调用 `TitleMoraleAssets.Sync` 保存原生 Prefab、LuaReference、本地化绑定和 View 提示；不手改 YAML。
- [title_morale_core.lua](../../Tools/Tests/title_morale_core.lua)：`python -B Tools/Tests/run_lua.py Tools/Tests/title_morale_core.lua`，离线条件、归属、去重、档位、连锁与逃跑；[title_morale_data_editmode.cs](../../Tools/Tests/title_morale_data_editmode.cs)：原生状态与 JSON 回读；[title_morale_ui_editmode.cs](../../Tools/Tests/title_morale_ui_editmode.cs)：保存后的Prefab、白环与长文本滚动。后两项通过MCP独立执行，不进入Play。
- [系统集成检查](../../Tools/Tests/title_morale_integration_editmode.cs) / [实际战斗检查](../../Tools/Tests/title_morale_battle_integration.lua) / [实际UI检查与预览](../../Tools/Tests/title_morale_ui_preview.cs)：独立Services/PreviewScene，使用临时存档；[称号页预览](../../Docs/Previews/TitlesAndMorale/title-page.png)使用测试角色与展示进度，不代表玩家存档。
