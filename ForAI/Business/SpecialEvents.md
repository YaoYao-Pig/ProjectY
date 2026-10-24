# 特殊事件与招募

关键词：特殊事件、骑士审判、神秘逃兵、城镇附近、比武审判、专属地图、支援、盟军、自主行动、招募、受伤入队、身体创伤、定时恢复。

## 文档目录

正文：入口与流程 / 身份与结算 / 修改与验证；关键入口：配置、运行时与检查。

## 正文

- `SpecialEventTable` 将旅途事件、场内事件、选择、独立 MapArea、遭遇盟军位置及招募任务连接起来。`SpecialEvents` 只编排规则，世界地点 ID 与结局使用 `NarrativeData` 的 `flag:<key>_site/outcome/failed` 保存；角色、装备和伤势仍归既有 C# 探索记录。`outcome=0/1/2` 分别为未结算、获胜且存活、失去招募资格；失败是否处决由 `killAllyOnFailure` 配置。
- 骑士审判使用事件 301/302、区域 60、遭遇 301、NPC 301、角色 910、招募任务 1001；旅行规则 301 在城镇入口 3 格内以权重 1 进入随机池。发现后本次远征不再重复抽取；暂不参与或场内暂离都可重访同一地点，未参战不额外判死。
- 神秘逃兵使用事件 303/304、区域 61、遭遇 302、NPC 302、角色 920、招募任务 1002；旅行规则 303 权重 1，`townRadius=0` 表示不限城镇距离。逃兵初始生命35%，位于路边地图后方；`allyParticipates=false` 通过通用 `excludedActorIds` 排除行动、目标与战场半径计算，布局保证其站在战斗窗口之外。击败追兵后开放招募，失败/撤出仅失去联系并关闭入口，不套用骑士的处决。
- 流程为旅途邀请 → 专属场景 → 是否帮助 → 原地支援战斗。场内决策复用 StoryEvent；完成选择后回到已有区域再开战，不创建第二个战场。全员倒地不能消费入场或参战选项。
- 骑士场景使用 [TrialGround 生成器](MapArea.md)，包含中央平地、两侧三级木看台、围栏、南北入口与审判席；固定观众及领主等为不参与状态和存档的布景人物。`encounterPlans.actorIds/teams` 可为计划中的角色提供稳定身份与独立侧；玩家仍为 side 1，骑士为 side 4，控方为 side 2。盟军不参加玩家部署、不接受玩家命令；受伤自保策略见 [Battle](Battle.md)。HUD 显示骑士生命。
- 胜利且事件角色存活才设置成功结局，自动开放任务手记中的招募任务，由玩家确认入队。骑士死亡不开放招募；骑士审判失败或轮数耗尽时处决尚存活的骑士并关闭该审判入口。已结算场景不重新触发决定或战斗。
- `NpcTable.locationKind=event` 不使用城镇安置和日程；必须恰好绑定一个同模板特殊事件。`PrepareRecruit` 要求成功结局与原场景角色仍存活；满队保留 ready。`EncounterRecruitment` 先校验来源、容量和身份，再从原遭遇转移同一个角色与原装备到队伍，初始化成长、保留当前 HP 和装备耐久，不重复发初始装备。骑士使用职业 5，基础课程复用既有剑盾与备战技能。
- 初始创伤由 `initialInjuryPartIds/initialInjuryTypeIds/initialInjuryDamage` 对齐配置，首次创建演员时写入真实 [BodyHealth](BodyInjuries.md)。逃兵双腿、双臂、躯干各30损伤；`EventRecruitRecovery` 只在正式入队后登记剩余初始创伤的恢复额度，分别1440/2880/4320游戏分钟后恢复。满队和预检不启动计时；普通回血不清创伤，医疗用品可按既有治疗规则提前处理。健康面板显示该部位的预计恢复时间/额度。
- 存档恢复按特殊事件的 `areaId` 重建相同静态布局，再接回既有 C# 记录；已转移的骑士不会重新生成。读取和恢复不得把固定 ID 角色追加回已经初始化的遭遇。
- 内容修改遵循 [叙事工具](../Tools/Narrative.md) 的 review → patch → export；特殊事件已纳入工具白名单、引用图与语义校验。不要手改导出物。

## 关键入口

- [SpecialEvents.lua](../../Lua/Game/Adventure/SpecialEvents.lua)：城镇过滤、场内决策、独立侧战斗、结局与招募来源。
- [特殊事件表](../../Config/Tables/Narrative/SpecialEventTable.json) / [旅途池](../../Config/Tables/Travel/WorldTravelEventTable.json) / [NPC](../../Config/Tables/Narrative/NpcTable.json) / [招募任务](../../Config/Tables/Narrative/MissionTable.json)。
- [EncounterRecruitment.cs](../../Assets/GameFramework/Runtime/Data/EncounterRecruitment.cs)：反射桥接的预检与同实例转移；[NpcSystem.lua](../../Lua/Game/Narrative/NpcSystem.lua) / [NarrativeActions.lua](../../Lua/Game/Narrative/NarrativeActions.lua)：复用任务招募预检。
- [knight_trial_integration.lua](../../Tools/Tests/knight_trial_integration.lua)：在现有 Edit Mode 的隔离 LuaEnv、临时 Services/存档中核对入口、场景、控制权、三种结局、满队、装备/生命保存与重复进入；不启动 Editor/Play，不使用玩家存档。
- [trial_ground.lua](../../Tools/Tests/trial_ground.lua)、[ally_self_preservation.lua](../../Tools/Tests/ally_self_preservation.lua)、[encounter_recruitment.lua](../../Tools/Tests/encounter_recruitment.lua)：使用 `python -B Tools/Tests/run_lua.py <文件>` 的定向检查。
- [encounter_recruitment_editmode.cs](../../Tools/Tests/encounter_recruitment_editmode.cs)：已编译程序集的纯内存 C# 转移检查；[special-events.test.mjs](../../Tools/Narrative/tests/special-events.test.mjs)：`node --test` 配置语义检查。上述数据/算法检查不替代 Play 实景表现与难度验收。
- [trial_ground_preview.cs](../../Tools/Tests/trial_ground_preview.cs)：在已打开的 AdventureDemo 中只读复用模型绑定，在独立 PreviewScene 通过真实渲染器输出 [审判场静态预览](../../Docs/Previews/KnightTrial.png)，检查原场景及 dirty 状态不变。
- [EventRecruitRecovery.lua](../../Lua/Game/Narrative/EventRecruitRecovery.lua) / [恢复定向检查](../../Tools/Tests/event_recruit_recovery.lua) / [真实 C# 恢复检查](../../Tools/Tests/event_recruit_recovery_editmode.cs)：初始创伤、入队计时、新伤/治疗与恢复额度及旧档兼容。
- [deserter_integration.lua](../../Tools/Tests/deserter_integration.lua)：在临时存档的隔离 Edit Mode LuaEnv 检查路上触发、后方非参战、五部位伤势、招募、满队与分日恢复/读档；[路边场景预览](../../Docs/Previews/MysteriousDeserter.png) / [逃兵健康面板预览](../../Docs/Previews/BodyHealth/DeserterRecovery.png)。
