# 网状任务、对话与 NPC
关键词：Mission、Quest、Condition、网状叙事、任务、招募、NPC、对话、队员插话、特质、经历、好感、阵营、声望、日程、Cinemachine。

## 文档目录
正文：模型与流转 / 对话与镜头 / NPC 和存档 / 修改与验证；关键入口：运行时 / 状态 / UI / 配置。

## 正文

- `NpcTable.locationKind=event` 的角色来源与同实例招募见 [特殊事件与骑士审判](SpecialEvents.md)；不使用城镇安置/日程，也不重复创建装备。

- `NpcTable.locationKind` 区分城镇身份与 `world_party` 传奇身份；后者通过大地图队伍接触进入对话，不要求城镇安置/日程，也不使用城镇镜头。`DialogueChoiceTable.worldAction` 的开战出口及双路线委托见[传奇生物与具名人物](Legends.md)。

- `Narrative` 依赖 Adventure 与 [Condition](../Framework/Condition.md)，在 OnInit 注册条件处理器，OnStart 监听战斗击败事件。可变进度、事实、NPC 好感/声望、招募身份、游戏分钟数和临时对话会话统一归 C# `AdventureData.Narrative`；Lua 保存配置索引和查询缓存。
- `MissionTable` 的 category 只表示 basic/main/side/recruit 分类；Quest 用 missionId 归属 Mission，没有固定 nextQuest 链。startConditionId 决定可接取/可激活，completeConditionId 决定就绪；通过共享条件表达多前置、并行、择一路线与汇合。任务默认单次完成，不支持重置循环任务、放弃或失败状态。
- 每日随机居民委托采用独立实例，支持护送、附近清剿、实际扣料交付及 3D 金/绿色感叹号，见[城镇随机委托](TownMissions.md)；不重置上述单次剧情任务。
- 可变状态为 inactive→active→ready→completed；inactive 是尚未创建进度记录。Mission 可自动或显式接取，Quest 在所属 Mission active 时自动激活。ready 是锁定的达成记录，后续库存减少不撤销；奖励成功后才 completed。Mission 停止 active 后不再激活/推进阶段，配置完成条件须纳入仍需完成的阶段。
- `item_count` 读取当前共享背包数量；不计已装备武器/防具和安装的弹匣，不自动扣除物品。`kill_count` 相对所属任务/阶段激活时的全局击杀起点统计；`defeated.sourceId` 必须对应玩家 side 1，目标未被驯服且 `Battle:IsHostile(source,target)` 成立。盟军 AI 击杀、独立势力互杀、玩家友伤和中立死亡均不计；敌对第三方可以计入。无任务上下文的接取/对话条件禁止使用 kill_count。
- 其他叶子包括 mission_state、quest_state、flag、coins、npc_relation、faction_reputation、npc_recruited、time_window。`party_attribute` 以 targetId 引用 GrowthAttributeTable、value 为正阈值，key/state 必须为空；读取任一存活队员的实时 CombatStats（含成长、装备与效果），失败显示队伍最高值。条件只查询，不能发奖或推进。条件图必须无环，任务状态依赖可以组成网络，但完成状态前置环会在工具侧给出可达性警告。
- `NarrativeActionTable` 执行 set_flag、add_coins、grant_item、accept_mission、claim_mission、recruit_npc、add_relation、add_reputation、grant_experience。任务/阶段奖励不能递归接受或领取其他 Mission，后续内容通过 Condition 响应。整组动作先检查金币、物品容量、重复任务操作、队伍容量和新队员站位，再顺序执行；开发契约异常直接报错。满队/满包保留 ready；已 completed 不再发放。`grant_experience` 要求 targetId=0、key 为空、value>0，向预检时已在队的每位成员（含倒地者）授予经验；预检不改成长，Apply 复用 Growth:AddExperience，升级与学习机会沿用成长规则。
- 对话通过 `NpcTable.dialogueIds` 顺序选取首个条件满足的入口。DialogueNode 的 choiceIds 决定展示顺序，Choice 的 nextNodeId=0 结束；同一会话节点可以循环，跳转必须属于同一 Dialogue。失败选项按 hideWhenLocked 隐藏或展示原因；提交校验所属节点和 DialogueVersion，拒绝陈旧点击。
- `DialogueInterjectionTable` 按 nodeId/order/id 配置队员插话。每个存活队员分别携带 `context.actor` 求值完整 Condition；auto 在主对白后按队伍顺序让全部满足者发言，optional 在选项区列出每位候选，由玩家选一人，可通过 nextNodeId 接续同一 Dialogue 的节点（0 留在原节点；auto 禁止跳转）。每条插话在一次会话中消费一次，节点循环不重播；关闭/重开重置。发言、角色 ID、缘由及消费集合归 C# NarrativeData，会话不写入存档。主动入口 `dialogue_interject(id,actorId,version)` 提交时重新校验节点、版本、队员存活/条件与世界队伍接触状态，不执行隐式任务奖励。
- 队员条件 `actor_trait` 用 targetId 引用 CombatTraitTable；`actor_attribute` 用 targetId/value 检查该队员的实时属性；`actor_history` 用 key 指定 StoryLogTemplateTable.kind、value 指定最少次数、state 指定 participant/subject/object，读取已保存 Chronicle 的精确参与者或主客体。targetId=0 不限定事件，正数仅用于 key=event 并引用 AdventureEventTable。不按正文字符串猜经历；组合条件始终检查同一队员，不能混合甲的特质和乙的经历。这些叶子仅可用于插话，普通任务/入口/选项在工具和运行时拒绝 actor 条件。既有 party_attribute 仍为队伍整体查询。
- `Dialogue` 是右侧深色对白卡片流：历史与底部选项分开滚动，NPC/同行者/玩家/旁白使用角色色、姓名与缘由区分，锁定选项展示条件原因并禁用。使用独立 DialogueEntry Widget，所有组件走 LuaReference；仅新增对白时滚到底部，普通刷新保留回看位置。模态暂停、关闭/返回/场景释放及镜头恢复契约不变。`MissionJournal` 继续使用 NarrativeEntry，从右侧任务按钮进入，按基础/主线/支线/招募分 Tab，左侧 Mission 列表、右侧说明与 Quest；已完成阶段使用 TMP 删除线，活动阶段强调。同行者按钮保留人物关系、城镇和日程查询。
- `AdventureRuntimeDemo.SendCommand` 的 dialogue_choose/dialogue_interject/dialogue_close 不等待世界角色动画；进入会暂停世界的对话后也不追加 PlayInteraction。不能将对话输入绑到依赖缩放时间的 ActionBusy 上，否则 timeScale=0 会同时锁住选项与关闭。
- Cinemachine **2.10.7** 对话控制器独占输出相机的 Brain，使用 ManualUpdate 和忽略 timeScale 的混合；双人、NPC、玩家、返回镜头由 DialogueCameraTable 配置。位置来自现有真实棋子显示器，重用城镇障碍与地形检查。右侧 UI 占据的宽度从世界视口扣除；退出恢复进入前投影、位置、旋转和裁剪参数。原有漫游镜头仍保留。
- NPC 身份全局稳定；NpcPlacementTable 在本次世界的第一个匹配城镇安置一次，未生成匹配地点时不生成替身。城镇临时 npc.id 只用于位置/交互。外观引用 MapAreaTownNpcTable，招募角色模板引用 CombatUnitTable；招募 actorId=10000+npcId，招募后世界 NPC 在会话结束时隐藏并释放占格。
- `NpcSystem:SyncPresence` 对被占据据点关闭普通居民及未招募剧情 NPC 的存在状态；解放后普通居民恢复，可招募 NPC 按 `WorldFactions:NpcAvailable` 随游戏分钟逐步回归。已招募身份优先，恢复不会重生同一 NPC；仍在当前招募对话中的 NPC 沿原规则保留至关闭。`PrepareRecruit` 再次检查安置地点、封锁与回归状态，不能通过任务奖励绕过恢复限制。服务库存另见[商店](Shop.md)。
- 特殊 NPC 可经 [NPC 商店](Shop.md)绑定商品模板；保留原有对白，并在对话底部增加“查看商品”。普通城镇商人直接交互打开库存，交易不占用 NarrativeAction 或任务事实键。
- NPC 好感与玩家阵营声望分别保存，初始值/上下界配表；增量动作钳制在配置边界。日程按 [startMinute,endMinute) 连续覆盖一天 0–1440，在当前城镇沿同一导航图逐格移向设施；拥堵等待，交谈/暂停时不移动。离开地图不进行后台移动，重进保留位置后继续前往当前时段目标。世界势力战争由 Adventure 的 WorldFactions/WorldConflicts 管理；NPC 彼此关系和玩家队伍编成/遣散 UI 仍未实现。
- 游戏时钟按 NarrativeSettingsTable.environmentId 引用 MapEnvironmentTable 的 startHour、cycleSeconds、autoCycle 推进，探索时运行、战斗/对话/暂停时停止。昼夜显示读取同一时钟；旧纯视觉调时按钮已移除，天气预览保留。
- [角色存档](CharacterSave.md) 同时保存任务、击杀起点、事实、关系/声望、招募记录和游戏时间；不保存对话中间节点，交谈中禁止保存/读取。恢复仍重新生成地图，已完成任务不重发，NPC 根据招募记录恢复存在状态。
- HUD 大地图的“新建叙事示例 · 三人远征”读取独立 AdventureDemoTable #2，保留一格招募位；默认 #1 四人开局不变。示例 Mission #100 为补给＋了解莱雅并行，武力/证言分支汇合；#200 为招募。NPC 位于首个集市城镇，姓名与日程见任务手记。
- 调试时按 F8 打开[GM NPC 查找](../Tools/GM.md)，可按名称/稳定 ID 搜索并传送到目标附近，关闭 GM 后按 E 交谈；不需要手动寻找具体城镇或重开三人示例。
- 长剧情 #300「灰烬账本」与 #400「钟楼无声」自动进入任务手记，可任意顺序推进；领取任意一案后自动开启 #500「三方议约」，完成两案后汇合。共 29 阶段，账本处置、公开证人、警钟用途通过事实交叉影响备料和四种终局；属性锁均有付费或保守方案。阶段击杀必须在激活后完成，物资盘点不扣库存。NPC #3–6 与原两人同在首个集市城镇；夜间分散到公会/商店/酒馆/广场，新增日程必须检查真实生成的可达停留格容量。入口、奖励与验收路线见[三线剧情测试说明](../../Docs/NarrativeCampaignPlaytest.md)。
- 「边城拾遗」支线 #801–810 与招募 #901–905 共 46 阶段；旧 NPC #2–6 的“镇上还有几件事”入口保留原对白，支线由话题发现接取。#810 在 #801/#803/#807 任意两案已有结果后开放。新 NPC #201–205 同在首个集市城镇，分别使用角色模板 #901–905，具独立成长、特质、初始装备、外观和全天日程；不扩大队伍容量。招募谈妥为 ready，确认后通过 claim_mission 的原子预检加入，满员等阻碍不吞任务。事实前缀为 `bt_` / `recruit_`；对话属性门槛保持确定性查询。任务入口、分支、相互影响与检查范围见[十五条任务说明](../../Docs/BorderTownStories.md)。
- 修改源表后使用[叙事工坊或 Agent CLI](../Tools/Narrative.md)共享校验并导出。最小数据检查为 Unity 菜单 `Project Y/叙事/验证任务对话与 NPC`，使用独立 LuaEnv、真实 C# 数据和临时存档；不进入 Play、不读写用户存档。Condition 的原生 Lua 检查见其模块文档。
- [内容编辑中心](../Tools/ContentCenter.md)统一编辑特殊 NPC 的能力、特质、技能、任务线、安置和初始装备。CharacterLoadoutTable 按角色模板 unitId 定义装备/固定外观；Prepare 将招募装备与奖励合并检查容量，Recruit 才创建实例、装备并重算生命。读档不调用初始授予；固定外观也传给城镇 NPC。
- `Project Y/叙事/验证对话 UI 与镜头` 在独立 PreviewScene 使用真实 Prefab、Lua 控制器与 Cinemachine，检查选择按钮、历史、缓存重开、暂停释放、双人构图和镜头恢复，输出 `Docs/Previews/Narrative-*.png`。预览以独立全屏 UI 相机模拟运行期 Overlay，不能把 UI 随世界视口一起裁切。
- 输入暂停回归使用 [dialogue_pause_command.cs](../../Tools/Tests/dialogue_pause_command.cs)，在当前 AdventureDemo 的 Edit Mode 创建独立预览副本，初始化真实 GameBootstrap/Demo，通过真正的 UGUI 按钮调用 SendCommand；主动保留一个未结束角色动画，检查 timeScale=0 时选择/关闭仍可执行。它不进入 Play、不读取或改写玩家存档，也不以直接调用 Lua 业务方法代替 C# 命令门禁。

- 通用 TabButton Widget 在选中时放大；NarrativeEntry 使用 UITxt/TMP，动态文字设置 DefaultText，以兼容 Edit Mode 预览和组件重新启用。字体为项目内 Noto Sans CJK，源字体和 [OFL 许可](../../Assets/DynamicAsset/UI/Fonts/OFL.txt) 一起保存；动态 SDF 资产显式绑定。布局迁移入口见 [UXLayoutAssets](../../Assets/GameFramework/Editor/UXLayoutAssets.cs)。
- `MissionJournal` 将说明、目标/交付地点、报酬卡片和阶段分开，状态分别用金/蓝/绿/灰/红表示；接取与领取使用滚动区外的固定主按钮。`MissionRewards.Preview` 为任务与阶段提供 `rewards` 展示行，不能用于发奖。
- `Actions.Apply` 返回实际到账行；`NarrativeSystem.RewardSettled` 在完成状态写入后通知 `{title,kind,id,rows}`，对话 `claim_mission` 则在整组动作与部署成功后通知。自动完成且没有奖励的 Quest 不弹窗。MainHud 显示订阅打开 `MissionSettlement`，连续完成按队列确认；确认不修改奖励、不重新领取。队列为临时展示，随面板关闭/场景释放清理，不进存档。
- `MissionReward` 复用背包图标目录（`ItemIconView`），经验使用蓝色 `EXP+` 文字图标、数量按每位队员标注；实际经验行携带预检时收奖队员 ID，招募的新成员不混入该次经验。关系与声望展示钳制后的实际差值。

## 关键入口

- [NarrativeSystem.lua](../../Lua/Game/Narrative/NarrativeSystem.lua) / [NarrativeRules.lua](../../Lua/Game/Narrative/NarrativeRules.lua) / [条件适配](../../Lua/Game/Narrative/NarrativeConditions.lua) / [动作](../../Lua/Game/Narrative/NarrativeActions.lua)。
- [NpcSystem.lua](../../Lua/Game/Narrative/NpcSystem.lua) / [Dialogue.lua](../../Lua/Game/Narrative/Dialogue.lua) / [NarrativeData.cs](../../Assets/GameFramework/Runtime/Data/NarrativeData.cs) / [存档配置检查](../../Lua/Game/Narrative/NarrativeSave.lua)。
- [配置源目录](../../Config/Tables/Narrative/) / [ConditionTable](../../Config/Tables/Condition/ConditionTable.json) / [示例配方](../../Config/Tables/Adventure/AdventureDemoTable.json)。
- [DialogueCtr.lua](../../Lua/UI/Panel/DialogueCtr.lua) / [MissionJournalCtr.lua](../../Lua/UI/Panel/MissionJournalCtr.lua) / [NarrativeAssets.cs](../../Assets/GameFramework/Editor/NarrativeAssets.cs) / [DialogueCamera.cs](../../Assets/GameFramework/Samples/Adventure/DialogueCamera.cs)。
- [MissionRewards.lua](../../Lua/Game/Narrative/MissionRewards.lua) / [MissionSettlementCtr.lua](../../Lua/UI/Panel/MissionSettlementCtr.lua) / [MissionReward.lua](../../Lua/UI/Widget/MissionReward.lua) / [ItemIconView.cs](../../Assets/GameFramework/Runtime/UI/ItemIconView.cs)。
- [mission_ui_assets.cs](../../Tools/Tests/mission_ui_assets.cs)：Unity MCP 的 Edit Mode 定向资源迁移，只保存 MissionJournal、MissionSettlement、MissionReward、绑定提示和注册条目；全量 UX 布局迁移后需要重用此入口恢复任务页新增区块。
- [mission_rewards.lua](../../Tools/Tests/mission_rewards.lua)：`python -B Tools/Tests/run_lua.py Tools/Tests/mission_rewards.lua` 覆盖奖励预检、实际变动、手动/自动/对话/城镇结算及防重复；[mission_reward_ui_editmode.cs](../../Tools/Tests/mission_reward_ui_editmode.cs) 经 Unity MCP 调用 [真实 UI 检查](../../Tools/Tests/mission_reward_ui.lua)，独立预览场景完成材料交付、卡片图标、排队确认、缓存重开和暂停释放，输出 [领取页](../../Docs/Previews/Missions/journal.png) 与 [结算页](../../Docs/Previews/Missions/settlement.png)，不进入 Play。
- [DialogueInterjectionTable.json](../../Config/Tables/Narrative/DialogueInterjectionTable.json) / [DialogueEntry.lua](../../Lua/UI/Widget/DialogueEntry.lua)：插话编排及独立卡片。示例 #1–6 覆盖特质、战斗经历、同人组合条件、共同经历、巧匠及 NPC 接续。
- [dialogue_interjections.lua](../../Tools/Tests/dialogue_interjections.lua) 与 [interjections.test.mjs](../../Tools/Narrative/tests/interjections.test.mjs)：使用 run_lua.py / node --test 的定向检查，覆盖逐人条件、全部自动发言、点名分支、重复/陈旧点击、历史参与者、条件作用域与图引用。真实 C# 会话和按钮检查并入 [narrative_ui.lua](../../Tools/Tests/narrative_ui.lua)。
- [NarrativeValidation.cs](../../Assets/GameFramework/Editor/NarrativeValidation.cs) / [narrative_integration.lua](../../Tools/Tests/narrative_integration.lua)：独立最小集成检查。
- [narrative_campaign_core.lua](../../Tools/Tests/narrative_campaign_core.lua)：原生 Lua 离线 12 路线、真实导表/流转/奖励及城镇 NPC 占位检查；[narrative_campaign_integration.lua](../../Tools/Tests/narrative_campaign_integration.lua)：调用方提供临时 Services 的独立 LuaEnv 真实 Data、交互和存档检查。
- [border_town_stories.lua](../../Tools/Tests/border_town_stories.lua)：十条支线与五条招募的路线、插话、属性门槛、交叉条件、真实 Lua 招募/成长/初始装备与阻碍预检；C# 容器使用替身。覆盖 11 位城镇 NPC 的实际生成可达性；不代表实机 UI 验收。
- [faction_services.lua](../../Tools/Tests/faction_services.lua)：NPC 封锁/恢复、已招募身份优先和多方击杀归因的原生 Lua 定向检查。
