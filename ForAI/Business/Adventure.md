# 探索事件与远征 Demo

关键词：Adventure、事件、选择、条件、奖励、营地、探索、结算、战斗 Demo。

## 文档目录

正文：流程与状态 / 配置与使用 / 验证；关键入口：规则 / 桥接 / 展示。

## 正文

- `AdventureChoiceTable.obstacleAction` 将 tool/manual/leave 选项委托给当前[工具障碍交互](ToolWeapons.md)，无匹配障碍上下文时不能执行；仍复用 StoryEvent、选择消费和结果返回流程。清障结果使用实际执行者、消耗与成功状态生成文案并写经历。

- 世界事件中的战斗进入持久 `Battlefield` 小地图，胜利后自动打开背包/战利品结算窗口，关闭后可留场探索剩余掉落；重进该地点不会重复触发已结算事件。搜索、逐件拖拽和满包保留见[宝箱与敌人掉落](Loot.md)。
- 运行场景默认以正式配方 3 随机开启 10000 格远征；HUD 菜单提供 2500 / 10000 / 30000 / 100000 格新游戏、继续与手动保存。新游戏使用独立随机种子、三人基础队伍与 60 金币，地图预生成成功后才替换会话；营地位于首个剧情集市相邻可通行格。缺剧情集市或通路明确报错，不重抽隐藏种子。旧 `start` / `start_story` 命令保留供定向验证。

- 来源：[玩法](https://my.feishu.cn/wiki/EcbNwrZ4Ii0BzykmlTCcceFmnRd)。当前可见策划无独立事件页；本版条件→选择→结果框架和 demo 内容按用户确认的范围实现。
- `AdventureSystem` 持有一次远征的只读大地图布局和地点定义，调用已有 MapSystem 生成，不修改 MapSystem 的快照契约。营地/野外地点以有限扫描放置；聚落优先经配表映射到 [MapArea 局部地图](MapArea.md)，未映射的建筑仍使用旧事件映射。选择目的地先启动[大地图旅行](WorldTravel.md)，到达后 `EnterSite` 才进入事件或局部探索；途中随机遇敌生成独立战场。尚无大地图视野或资源采集。
- `services.Adventure` 的 C# `AdventureData` 持有队伍、地点访问记录和阶段：普通事件为 map → event → resolving → result → map；战斗事件转入 Battlefield 后走 area → battle → resolving → area/map；局部探索为 map ↔ area。`AreaEncounterId` 区分原地战斗上下文，结算后清零；战斗结果先离开 battle 才发奖，避免重复结算。
- `AdventureEvents` 依赖 Battle、PlayerModel、Growth，处理侦察、金币、队伍存活与主角特质条件；选项必须属于当前事件，条件不足不改状态。结果支持恢复/金币/特质增减/进入遭遇，以及[养成](Progression.md)的经验、潜力与树解锁。事件可配置重复访问，普通地点离开也消耗一次访问；营地和补给站可重访。
- `AdventureSystem:BattleCommand` 限制玩家只能操作己方回合，AI 按单个敌人回合推进。胜利奖励由遭遇配置指定；失败/轮数耗尽不发战利品。队伍伤势保留，倒地角色可在营地恢复；战斗奖励特质授予首名存活队员，事件特质按选项的受益者范围发放。完整战斗契约见[战斗](Battle.md)。
- `AdventureDemoTable` 定义种子、Region 配方、小队、初始装备配方和地点映射；`AdventureEventTable` 定义 simple/complex、文案、重访、主角属性、图片路径、日志类别与选项；`AdventureChoiceTable` 定义条件和结果。原演示配方仍为 1/2/3/6，正式配方为 1/2/3，留一个招募位置；已有[可配置升级](Progression.md)和[远征存档](CharacterSave.md)。
- Adventure 依赖 Equipment：Start 在重置后发放初始装备，Visit 在进入地图后初始化持久搜刮点，area_loot 转发搜刮命令；Snapshot 附加可见掉落和装备外观。按 I 的[装备工坊](Equipment.md)使用 UI 框架暂停租约，暂停期间不触发新敌群。
- 金币复用 PlayerData；正式新游戏重置到起始资金，旧调试 `start` 保留原金币契约。新增会话状态只加 C# Data，不在 Lua 另存余额、HP、AP 或选择阶段。保存范围、旧档迁移与读档原子校验见[远征存档](CharacterSave.md)。
- Unity 菜单 `Project Y/远征/打开战斗与事件 Demo` 打开/首次生成独立场景；按 Play 运行。点地图编号或地点按钮查看事件；选迎战后，绿色地格可移动，选技能后点高亮角色，点“结束回合”推进；敌方默认自动行动。胜利后留在战场搜刮，可自行返回地图；败退后可在营地休整。
- 首次接入这些 C# Data 或修改桥接 API 后，先在 Edit Mode 完成 C# 编译，再执行 `XLua/Generate Code` 并等待生成代码编译完成，最后进入 Play。仅编译 C# 不会自动更新 `FrameworkServices` 的生成 getter；旧绑定会使 Lua 读到 `services.Adventure == nil`。
- 常驻地点、资金、入口、探索操作、队伍、交互、日志和战斗内容统一归 [MainHud](MainHud.md)。复杂事件使用 `StoryEvent` 通用图文选项 Prefab；大地图简单事件检查条件后自动结算，保留 result 阶段显示结果窗口，玩家确认后才回地图。区域探索的简单事件仍自动结算并回原区域，只写游戏内日志。`AdventureUIBridge` 同步窗口；养成与故事使用模态输入和暂停租约。世界血条已用 Overlay UIFollower；地图标记、旧二维棋盘及可选画面调试仍由 C# 绘制。
- 主角在 Begin 时按配置选出，`AdventureData.EventActorId/EventLocation` 固定本次上下文；`Chronicle` 按通用模板记录参与者和结果。复杂事件图片通过 `StoryGrowthView` 序列化 Sprite 引用，菜单 `Project Y/UI/创建事件与养成 UI` 生成资源和同步图路径，重复执行保留已编辑布局。经历和配置入口见[养成文档](Progression.md)。
- `ExplorationEventTable` 把事件接到 enter/explore/loot/victory/facility；可限制 areaIds、来源 ID、入口距离与每地点一次。`ExplorationEvents` 不保存消费状态，`AdventureData` 持有地点:规则 ID 记录和 `EventReturnPhase`。区域故事仅允许非战斗选项，期间保留区域显示、停止路线；完成后回原区域/位置。原地战斗优先于探索故事。新远征清除消费记录，重进同地点不刷新。
- 旅行扩展事件201–220共20个（8 simple/12 complex、46选项），通过 WorldTravel 权重与地貌筛选接入，每个事件单独配置图片；没有复用现有事件ID。简单物品事件沿用 `CanVisit` 的背包容量预检，满包时不入随机池；复杂事件都保留无门槛退出选项。
- `AdventureChoiceTable.effectIds/timeMinutes` 复用 GameEffects 和 Narrative 游戏时钟：先编译效果并验证选择，再消费一次选择，推进耗时后发放结果与效果；长效Buff从耗时结束时计时，对已倒地目标停止追加效果。recipient同时决定成长与效果受益范围，伤害/治疗仍不替代 healParty 的复活契约。`hideRewards` 用于隐藏解谜选项的奖励摘要，条件不足提示仍显示，避免提前泄露答案。
- `AdventureChoiceTable.itemIds/itemCounts` 发放真实共享背包物品；先检查金币与整组物品容量，再消费事件。搜刮、购买写【获得】明细。绑定商人的设施与 NPC 接入 [NPC 商店](Shop.md)，独立库存按模板随机补货；未绑定商人的铁匠、酒馆等设施保留原服务事件。
- `DemoBridge` 通过 GameBootstrap.CallModule 使用同一常驻 LuaEnv；`MapPreviewData.Read` 和 `AdventureViewData.Read` 在调用内复制纯显示数据并释放 LuaTable，不持有长期 Lua 句柄。新场景独立于现有地图预览，尚未加入 Build Settings。
- 显示快照的 `cells` 与 `reachable` 共用 C# Cell 结构，均须提供 `q/r/blocked/cellIndex`；角色统一提供初始 `appearance` 和 `cellIndex`（旧棋盘为 0）。Lua 地格索引从 1 起，C# 显示读取时减 1；值类型字段不能用 nil 表示默认值。
- 队伍与敌人外观均由[棋子资源配置](PawnArt.md)解析。`area` 快照在探索及原地战斗阶段都存在，显示宿主据此保持地形/相机/模型生命周期；地牢战斗使用真实场景、地格拾取和现有技能按钮，旧事件战斗继续显示二维棋盘。MapArea 与战后恢复规则见[局部地图](MapArea.md)，城镇走格子与交互见[城镇](TownArea.md)。
- 改表后执行 `node Tools/ConfigEditor/exporter.mjs`；资源路径变化后在退出 Play 的新场景执行 `Project Y/远征/同步地图资源引用`。改 Lua 在下一次 Play 生效，不做运行时热重载。
- 最小验证：原生 xLua `adventure_core.lua`；Edit Mode 菜单 `Project Y/远征/验证战斗与事件` 运行独立真实 C# 状态检查；获授权后在新 demo 验收事件→战斗→结算。检查源码见下方入口；不自动扩展到全量地图测试或 Player 构建。
- 探索接入检查：`Project Y/远征/验证探索与故事接入` 运行 [exploration_story_integration.lua](../../Tools/Tests/exploration_story_integration.lua)，使用真实生成地点与逐格移动，核对搜刮→安装、距离触发→原地恢复、设施→付费获取和重复提交；无需 Play。
- 显示快照改动运行 `python -B Tools/Tests/run_lua.py Tools/Tests/adventure_snapshot.lua`，覆盖地图、事件、入战、移动用尽和结算的必需字段类型；使用只读状态/配置夹具和真实 Lua 快照、查询实现，不触发 Unity 编译。

## 关键入口

- [AdventureSystem.lua](../../Lua/Game/Adventure/AdventureSystem.lua) / [EventSystem.lua](../../Lua/Game/Adventure/EventSystem.lua)：地点、条件、状态与结算；[AdventureData.cs](../../Assets/GameFramework/Runtime/Data/AdventureData.cs)：会话状态。
- [DemoBridge.lua](../../Lua/Game/Adventure/DemoBridge.lua) / [AdventureViewData.cs](../../Assets/GameFramework/Samples/Adventure/AdventureViewData.cs)：命令和显示快照。
- [AdventureRuntimeDemo.cs](../../Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs) / [AdventureDemoMenu.cs](../../Assets/GameFramework/Editor/AdventureDemoMenu.cs)：运行展示、场景创建与序列化绑定。
- [AdventureDemoTable.json](../../Config/Tables/Adventure/AdventureDemoTable.json) / [事件表](../../Config/Tables/Adventure/AdventureEventTable.json) / [选项表](../../Config/Tables/Adventure/AdventureChoiceTable.json)：首版玩法配置。
- [AdventureValidation.cs](../../Assets/GameFramework/Editor/AdventureValidation.cs) / [adventure_integration.lua](../../Tools/Tests/adventure_integration.lua)：真实数据与桥接检查，独立于正在编辑的场景。

- [20事件内容与配图场景](../../Art/AdventureExpansion202610/events.json) / [幂等内容写入](../../Art/AdventureExpansion202610/Scripts/author_events.py) / [内容/引用/冲突检查](../../Tools/Tests/adventure_expansion_content.py) / [实际效果与时间结算](../../Tools/Tests/event_choice_effects.lua)：脚本默认只读review，`--apply`写源表后另行导表；同ID不同内容明确拒绝，不覆盖已有事件。

- [20张配图与完整提示词](../../Art/AdventureExpansion202610/Illustrations/manifest.json) / [图片哈希与尺寸](../../Art/AdventureExpansion202610/Illustrations/validation.json) / [实际结算检查记录](../../Art/AdventureExpansion202610/Integration/runtime-validation.json) / [Unity图片绑定](../../Art/AdventureExpansion202610/Integration/unity-art.json) / [真实事件窗口预览](../../Art/AdventureExpansion202610/Previews/story-event-unity.png)。图片使用内置image_gen逐场景生成，均落入项目资源目录；完整Play流程仍未运行。
