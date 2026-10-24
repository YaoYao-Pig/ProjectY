# 城镇随机委托与 NPC 任务标记
关键词：随机任务、日常委托、城镇委托、护送商队、附身、清剿、材料交付、感叹号、TownMission。

## 文档目录
正文：生成与身份 / 目标与奖励 / 护送 / 展示与存档 / 验证；关键入口：运行时、数据、配置、模型。

## 正文

- 与配置驱动的单次 Mission 分开：`TownMissionTable` 是可重复使用的模板，`TownMissionData` 保存递增的独立实例；Lua 不持有权威进度。通过 `TownMissionData.For(NarrativeData)` 和 `Prepared` 访问，沿现有反射桥保留类型。
- 每个营业城镇按游戏日刷新 1–5 个委托，范围由 `TownMissionSettingsTable` 配置。进入/停留在该城镇时惰性生成，随机流由世界种子、城镇和日期决定；同日重进不重抽。次日只移除未接取实例，已接、就绪、完成和失败记录保留。没有可达城镇时排除护送模板，仍提供其他类型。
- 委托由普通居民发布；发布者以 `SiteId + stableId` 标识，不保存场景对象或临时 NPC 索引。居民 stableId 为 100000＋生成序号；服务 NPC 使用设施配置 ID，剧情 NPC 使用 200000＋稳定剧情身份。居民移动不改变归属。
- 状态为 offered→active→ready→completed；商队全灭时 active→failed。接取和交付都重新检查发布城镇、营业状态、同一委托人、存在状态及沿街道相邻距离。任务手记可查看进度，但不能远程接取/领奖。
- 材料任务只使用 `material` 类堆叠物，检查真实共享背包。达到数量转 ready，交付时再次检查库存；奖励预检通过后扣除材料、发放正数金币与全队经验，最后完成，重复交付拒绝。ready 后材料被消耗时不显示绿色可交标记。
- 清剿只统计接取后玩家 side 1 击败的敌对、未驯服目标，复用 Narrative 的击杀归因；战斗地点相对发布城镇的大地图六边形距离须在模板 radius 内。其他势力独立互战、友军击杀和远方战斗不计入。
- 护送生成一支拥有真实货物、编制与陆路的商队，先在出发镇等待，玩家回大地图后启程。附近可随行，玩家坐标与路段进度随商队更新，保留玩家旅行随机流和地点编号；也可脱离后独立行动。暂停/倍速沿用旅行系统，战后需显式继续。
- 商队遇敌复用 [势力冲突](Factions.md)；随行时自动加入真实战斗，独立行动时须靠近并主动援助。商队为本场盟友，不改全局声望；伤亡保留，幸存继续前往原目的地。抵达后等待玩家在附近确认成功，转 ready 并恢复普通贸易；全灭失败且自动脱离。护送 LOD 约束见 [世界队伍](WorldParties.md)。
- `MissionJournal` 的“城镇委托”页列出已接任务；与带委托的居民交互会自动打开该居民的委托页，关闭后释放交互。护送页提供赶往商队、随行、离开商队、加入战斗按钮；大地图护送队有名称前缀，接触窗口也提供随行/援助入口。不能把已暂停面板的命令阻塞在角色动画上。
- `Rows` 分别提供 `description/objective/publisher/location/rewards/turnInHint`，接取前展示报酬，目标达成后明确提示回原委托人交付。`Claim` 在扣料、发奖及完成状态写入后发送 `RewardSettled(kind='town')`；弹窗和 `EXP+` 卡片复用[任务奖励结算](Narrative.md)，不改变领取地点或奖励规则。
- NPC 快照 `missionMarker`：0 隐藏、1 金色可接、2 绿色可交（优先）。普通委托由实例派生；剧情 NPC 从当前可用对话分支的 accept/claim 动作派生，复用动作预检；只有进行中任务时隐藏。缓存随叙事/背包/金币变化失效。
- `TownNpcRenderer` 只消费标记状态，使用 `PawnView.HealthTarget`，在最终相机定位后更新标记朝向；NPC 消失时隐藏，离开区域释放。模型 88 三角面、纯色 URP Lit；AdventureDemo 显式绑定 Prefab 与绿色材质，不依赖运行时查找。
- 实例、每日刷新记录、护送队伍/目的地与附身状态随 Narrative 一起保存。旧档缺字段时初始化空集合；准备阶段检查编号、日期、进度、身份与真实城镇/布局/商队引用，提交保留 Data 对象身份；已领取任务不会重发奖励。
- 配置通过叙事 CLI `review → patch → export`，模板的材料动态引用与奖励动作同步进入关系图和语义校验。两表均可在叙事工坊中维护。

## 关键入口

- [TownMissions.lua](../../Lua/Game/Narrative/TownMissions.lua) / [EscortMissions.lua](../../Lua/Game/Adventure/EscortMissions.lua) / [NpcMissionMarkers.lua](../../Lua/Game/Narrative/NpcMissionMarkers.lua)。
- [TownMissionData.cs](../../Assets/GameFramework/Runtime/Data/TownMissionData.cs) / [NarrativeData.cs](../../Assets/GameFramework/Runtime/Data/NarrativeData.cs) / [ExpeditionSave.lua](../../Lua/Game/Adventure/ExpeditionSave.lua)。
- [模板](../../Config/Tables/Narrative/TownMissionTable.json) / [规则](../../Config/Tables/Narrative/TownMissionSettingsTable.json) / [叙事校验](../../Tools/Narrative/rules.mjs)。
- [TownNpcRenderer.cs](../../Assets/GameFramework/Samples/Adventure/TownNpcRenderer.cs) / [Blender 源](../../Art/TownMissionMarker/Source/TownMissionMarker.blend) / [Prefab](../../Assets/DynamicAsset/TownMissionMarker/Prefabs/TownMissionMarker.prefab) / [预览](../../Art/TownMissionMarker/Previews/mission-markers.png)。
- 最小检查：[数据边界与真实 Lua 反射](../../Tools/Tests/town_mission_data_editmode.cs)、[真实配置/接取/扣料/存档/UI/两种护送参战](../../Tools/Tests/town_missions_editmode.cs)（调用 [Lua 夹具](../../Tools/Tests/town_missions_integration.lua)）、[护送定向 Lua](../../Tools/Tests/escort_missions.lua)、[剧情任务标记](../../Tools/Tests/npc_mission_markers.lua)、[标记生命周期](../../Art/TownMissionMarker/Scripts/validate_marker.cs)。Edit Mode 片段使用独立数据/预览和临时存档，不进入 Play。
- 配置定向检查：`node --test Tools/Narrative/tests/town-missions.test.mjs`；Lua 护送检查：`python -B Tools/Tests/run_lua.py Tools/Tests/escort_missions.lua`。
