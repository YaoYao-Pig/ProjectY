# 网状任务、对话与 NPC
关键词：Mission、Quest、Condition、网状叙事、任务、招募、NPC、对话、好感、阵营、声望、日程、Cinemachine。

## 文档目录
正文：模型与流转 / 对话与镜头 / NPC 和存档 / 修改与验证；关键入口：运行时 / 状态 / UI / 配置。

## 正文

- `Narrative` 依赖 Adventure 与 [Condition](../Framework/Condition.md)，在 OnInit 注册条件处理器，OnStart 监听战斗击败事件。可变进度、事实、NPC 好感/声望、招募身份、游戏分钟数和临时对话会话统一归 C# `AdventureData.Narrative`；Lua 保存配置索引和查询缓存。
- `MissionTable` 的 category 只表示 basic/main/side/recruit 分类；Quest 用 missionId 归属 Mission，没有固定 nextQuest 链。startConditionId 决定可接取/可激活，completeConditionId 决定就绪；通过共享条件表达多前置、并行、择一路线与汇合。任务默认单次完成，不支持重置循环任务、放弃或失败状态。
- 可变状态为 inactive→active→ready→completed；inactive 是尚未创建进度记录。Mission 可自动或显式接取，Quest 在所属 Mission active 时自动激活。ready 是锁定的达成记录，后续库存减少不撤销；奖励成功后才 completed。Mission 停止 active 后不再激活/推进阶段，配置完成条件须纳入仍需完成的阶段。
- `item_count` 读取当前共享背包数量；不计已装备武器/防具和安装的弹匣，不自动扣除物品。`kill_count` 相对所属任务/阶段激活时的全局击杀起点统计；只收战斗系统敌方未被招募动物/敌人的 defeated 事件。无任务上下文的接取/对话条件禁止使用 kill_count。
- 其他叶子包括 mission_state、quest_state、flag、coins、npc_relation、faction_reputation、npc_recruited、time_window；条件只查询，不能发奖或推进。条件图必须无环，任务状态依赖可以组成网络，但完成状态前置环会在工具侧给出可达性警告。
- `NarrativeActionTable` 执行 set_flag、add_coins、grant_item、accept_mission、claim_mission、recruit_npc、add_relation、add_reputation。任务/阶段奖励不能递归接受或领取其他 Mission，后续内容通过 Condition 响应。整组动作先检查金币、物品容量、重复任务操作、队伍容量和新队员站位，再顺序执行；开发契约异常直接报错。满队/满包保留 ready；已 completed 不再发放。
- 对话通过 `NpcTable.dialogueIds` 顺序选取首个条件满足的入口。DialogueNode 的 choiceIds 决定展示顺序，Choice 的 nextNodeId=0 结束；同一会话节点可以循环，跳转必须属于同一 Dialogue。失败选项按 hideWhenLocked 隐藏或展示原因；提交校验所属节点和 DialogueVersion，拒绝陈旧点击。
- `Dialogue` 是右侧对白区：历史与底部选项分开滚动，姓名强调、旁白斜体，锁定选项展示条件原因并禁用。复用 UISystem、LuaReference 和 NarrativeEntry Widget；模态暂停、关闭/返回/场景释放及镜头恢复契约不变。`MissionJournal` 从右侧任务按钮进入，按基础/主线/支线/招募分 Tab，左侧 Mission 列表、右侧说明与 Quest；已完成阶段使用 TMP 删除线，活动阶段强调。同行者按钮保留人物关系、城镇和日程查询。
- `AdventureRuntimeDemo.SendCommand` 的 dialogue_choose/dialogue_close 不等待世界角色动画；进入会暂停世界的对话后也不追加 PlayInteraction。不能将对话输入绑到依赖缩放时间的 ActionBusy 上，否则 timeScale=0 会同时锁住选项与关闭。
- Cinemachine **2.10.7** 对话控制器独占输出相机的 Brain，使用 ManualUpdate 和忽略 timeScale 的混合；双人、NPC、玩家、返回镜头由 DialogueCameraTable 配置。位置来自现有真实棋子显示器，重用城镇障碍与地形检查。右侧 UI 占据的宽度从世界视口扣除；退出恢复进入前投影、位置、旋转和裁剪参数。原有漫游镜头仍保留。
- NPC 身份全局稳定；NpcPlacementTable 在本次世界的第一个匹配城镇安置一次，未生成匹配地点时不生成替身。城镇临时 npc.id 只用于位置/交互。外观引用 MapAreaTownNpcTable，招募角色模板引用 CombatUnitTable；招募 actorId=10000+npcId，招募后世界 NPC 在会话结束时隐藏并释放占格。
- 特殊 NPC 可经 [NPC 商店](Shop.md)绑定商品模板；保留原有对白，并在对话底部增加“查看商品”。普通城镇商人直接交互打开库存，交易不占用 NarrativeAction 或任务事实键。
- NPC 好感与玩家阵营声望分别保存，初始值/上下界配表；增量动作钳制在配置边界。日程按 [startMinute,endMinute) 连续覆盖一天 0–1440，在当前城镇沿同一导航图逐格移向设施；拥堵等待，交谈/暂停时不移动。离开地图不进行后台移动，重进保留位置后继续前往当前时段目标。尚无 NPC 彼此关系、阵营战争或队伍编成/遣散 UI。
- 游戏时钟按 NarrativeSettingsTable.environmentId 引用 MapEnvironmentTable 的 startHour、cycleSeconds、autoCycle 推进，探索时运行、战斗/对话/暂停时停止。昼夜显示读取同一时钟；旧纯视觉调时按钮已移除，天气预览保留。
- [角色存档](CharacterSave.md) 同时保存任务、击杀起点、事实、关系/声望、招募记录和游戏时间；不保存对话中间节点，交谈中禁止保存/读取。恢复仍重新生成地图，已完成任务不重发，NPC 根据招募记录恢复存在状态。
- HUD 大地图的“新建叙事示例 · 三人远征”读取独立 AdventureDemoTable #2，保留一格招募位；默认 #1 四人开局不变。示例 Mission #100 为补给＋了解莱雅并行，武力/证言分支汇合；#200 为招募。NPC 位于首个集市城镇，姓名与日程见任务手记。
- 调试时按 F8 打开[GM NPC 查找](../Tools/GM.md)，可按名称/稳定 ID 搜索并传送到目标附近，关闭 GM 后按 E 交谈；不需要手动寻找具体城镇或重开三人示例。
- 修改源表后使用[叙事工坊或 Agent CLI](../Tools/Narrative.md)共享校验并导出。最小数据检查为 Unity 菜单 `Project Y/叙事/验证任务对话与 NPC`，使用独立 LuaEnv、真实 C# 数据和临时存档；不进入 Play、不读写用户存档。Condition 的原生 Lua 检查见其模块文档。
- [内容编辑中心](../Tools/ContentCenter.md)统一编辑特殊 NPC 的能力、特质、技能、任务线、安置和初始装备。CharacterLoadoutTable 按角色模板 unitId 定义装备/固定外观；Prepare 将招募装备与奖励合并检查容量，Recruit 才创建实例、装备并重算生命。读档不调用初始授予；固定外观也传给城镇 NPC。
- `Project Y/叙事/验证对话 UI 与镜头` 在独立 PreviewScene 使用真实 Prefab、Lua 控制器与 Cinemachine，检查选择按钮、历史、缓存重开、暂停释放、双人构图和镜头恢复，输出 `Docs/Previews/Narrative-*.png`。预览以独立全屏 UI 相机模拟运行期 Overlay，不能把 UI 随世界视口一起裁切。
- 输入暂停回归使用 [dialogue_pause_command.cs](../../Tools/Tests/dialogue_pause_command.cs)，在当前 AdventureDemo 的 Edit Mode 创建独立预览副本，初始化真实 GameBootstrap/Demo，通过真正的 UGUI 按钮调用 SendCommand；主动保留一个未结束角色动画，检查 timeScale=0 时选择/关闭仍可执行。它不进入 Play、不读取或改写玩家存档，也不以直接调用 Lua 业务方法代替 C# 命令门禁。

- 通用 TabButton Widget 在选中时放大；NarrativeEntry 使用 UITxt/TMP，动态文字设置 DefaultText，以兼容 Edit Mode 预览和组件重新启用。字体为项目内 Noto Sans CJK，源字体和 [OFL 许可](../../Assets/DynamicAsset/UI/Fonts/OFL.txt) 一起保存；动态 SDF 资产显式绑定。布局迁移入口见 [UXLayoutAssets](../../Assets/GameFramework/Editor/UXLayoutAssets.cs)。

## 关键入口

- [NarrativeSystem.lua](../../Lua/Game/Narrative/NarrativeSystem.lua) / [NarrativeRules.lua](../../Lua/Game/Narrative/NarrativeRules.lua) / [条件适配](../../Lua/Game/Narrative/NarrativeConditions.lua) / [动作](../../Lua/Game/Narrative/NarrativeActions.lua)。
- [NpcSystem.lua](../../Lua/Game/Narrative/NpcSystem.lua) / [Dialogue.lua](../../Lua/Game/Narrative/Dialogue.lua) / [NarrativeData.cs](../../Assets/GameFramework/Runtime/Data/NarrativeData.cs) / [存档配置检查](../../Lua/Game/Narrative/NarrativeSave.lua)。
- [配置源目录](../../Config/Tables/Narrative/) / [ConditionTable](../../Config/Tables/Condition/ConditionTable.json) / [示例配方](../../Config/Tables/Adventure/AdventureDemoTable.json)。
- [DialogueCtr.lua](../../Lua/UI/Panel/DialogueCtr.lua) / [MissionJournalCtr.lua](../../Lua/UI/Panel/MissionJournalCtr.lua) / [NarrativeAssets.cs](../../Assets/GameFramework/Editor/NarrativeAssets.cs) / [DialogueCamera.cs](../../Assets/GameFramework/Samples/Adventure/DialogueCamera.cs)。
- [NarrativeValidation.cs](../../Assets/GameFramework/Editor/NarrativeValidation.cs) / [narrative_integration.lua](../../Tools/Tests/narrative_integration.lua)：独立最小集成检查。
