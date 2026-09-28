# 探索事件与远征 Demo

关键词：Adventure、事件、选择、条件、奖励、营地、探索、结算、战斗 Demo。

## 文档目录

正文：流程与状态 / 配置与使用 / 验证；关键入口：规则 / 桥接 / 展示。

## 正文

- 世界事件中的战斗改为进入持久 `Battlefield` 小地图，胜利后留场走动拾取；重进该地点不会重复触发已结算事件。敌人概率掉落及满包保留见[宝箱与敌人掉落](Loot.md)。

- 来源：[玩法](https://my.feishu.cn/wiki/EcbNwrZ4Ii0BzykmlTCcceFmnRd)。当前可见策划无独立事件页；本版条件→选择→结果框架和 demo 内容按用户确认的范围实现。
- `AdventureSystem` 持有一次远征的只读大地图布局和地点定义，调用已有 MapSystem 生成，不修改 MapSystem 的快照契约。营地/野外地点以有限扫描放置；聚落优先经配表映射到 [MapArea 局部地图](MapArea.md)，未映射的建筑仍使用旧事件映射。直接选择目的地进入事件或局部探索，尚无队伍大地图行走、寻路、视野或资源采集。
- `services.Adventure` 的 C# `AdventureData` 持有队伍、地点访问记录和阶段：普通事件为 map → event → resolving → result → map；战斗事件转入 Battlefield 后走 area → battle → resolving → area/map；局部探索为 map ↔ area。`AreaEncounterId` 区分原地战斗上下文，结算后清零；战斗结果先离开 battle 才发奖，避免重复结算。
- `AdventureEvents` 依赖 Battle、PlayerModel、Growth，处理侦察、金币、队伍存活与主角特质条件；选项必须属于当前事件，条件不足不改状态。结果支持恢复/金币/特质增减/进入遭遇，以及[养成](Progression.md)的经验、潜力与树解锁。事件可配置重复访问，普通地点离开也消耗一次访问；营地和补给站可重访。
- `AdventureSystem:BattleCommand` 限制玩家只能操作己方回合，AI 按单个敌人回合推进。胜利奖励由遭遇配置指定；失败/轮数耗尽不发战利品。队伍伤势保留，倒地角色可在营地恢复；战斗奖励特质授予首名存活队员，事件特质按选项的受益者范围发放。完整战斗契约见[战斗](Battle.md)。
- `AdventureDemoTable` 定义种子、Region 配方、小队和地点映射；`AdventureEventTable` 定义 simple/complex、文案、重访、主角属性、图片路径、日志类别与选项；`AdventureChoiceTable` 定义条件和结果。默认队伍模板 1/2/3/6，最多四人，模板 4/5 为敌人；已有[可配置升级](Progression.md)，已接[角色与背包存档](CharacterSave.md)，尚无整场远征存档、完整招募或完整 GAS。
- Adventure 依赖 Equipment：Start 在重置后发放初始装备，Visit 在进入地图后初始化持久搜刮点，area_loot 转发搜刮命令；Snapshot 附加可见掉落和装备外观。按 I 的[装备工坊](Equipment.md)使用 UI 框架暂停租约，暂停期间不触发新敌群。
- 金币复用 PlayerData；“开始新远征”重置队伍与地点，保留本次运行的金币。关闭运行时后会话数据释放；手动保存的角色档案可在下次运行读取。新增会话状态只加 C# Data，不在 Lua 另存余额、HP、AP 或选择阶段。
- Unity 菜单 `Project Y/远征/打开战斗与事件 Demo` 打开/首次生成独立场景；按 Play 运行。点地图编号或地点按钮查看事件；选迎战后，绿色地格可移动，选技能后点高亮角色，点“结束回合”推进；敌方默认自动行动。胜利后留在战场搜刮，可自行返回地图；败退后可在营地休整。
- 首次接入这些 C# Data 或修改桥接 API 后，先在 Edit Mode 完成 C# 编译，再执行 `XLua/Generate Code` 并等待生成代码编译完成，最后进入 Play。仅编译 C# 不会自动更新 `FrameworkServices` 的生成 getter；旧绑定会使 Lua 读到 `services.Adventure == nil`。
- 常驻地点、资金、入口、探索操作、队伍、交互、日志和战斗内容统一归 [MainHud](MainHud.md)。复杂事件使用 `StoryEvent` 通用图文选项 Prefab；简单事件检查条件后自动结算，只写游戏内日志，不写 Console。`AdventureUIBridge` 同步窗口；养成与故事使用模态输入和暂停租约。世界血条已用 Overlay UIFollower；地图标记、旧二维棋盘及可选画面调试仍由 C# 绘制。
- 主角在 Begin 时按配置选出，`AdventureData.EventActorId/EventLocation` 固定本次上下文；`Chronicle` 按通用模板记录参与者和结果。复杂事件图片通过 `StoryGrowthView` 序列化 Sprite 引用，菜单 `Project Y/UI/创建事件与养成 UI` 生成资源和同步图路径，重复执行保留已编辑布局。经历和配置入口见[养成文档](Progression.md)。
- `ExplorationEventTable` 把事件接到 enter/explore/loot/victory/facility；可限制 areaIds、来源 ID、入口距离与每地点一次。`ExplorationEvents` 不保存消费状态，`AdventureData` 持有地点:规则 ID 记录和 `EventReturnPhase`。区域故事仅允许非战斗选项，期间保留区域显示、停止路线；完成后回原区域/位置。原地战斗优先于探索故事。新远征清除消费记录，重进同地点不刷新。
- `AdventureChoiceTable.itemIds/itemCounts` 发放真实共享背包物品；先检查金币与整组物品容量，再消费事件。搜刮、购买写【获得】明细。铁匠/商店/酒馆沿原有靠近设施并按 E 的校验进入服务事件；其余设施保持介绍。不是独立商店库存、制作或任务系统。
- `DemoBridge` 通过 GameBootstrap.CallModule 使用同一常驻 LuaEnv；`MapPreviewData.Read` 和 `AdventureViewData.Read` 在调用内复制纯显示数据并释放 LuaTable，不持有长期 Lua 句柄。新场景独立于现有地图预览，尚未加入 Build Settings。
- 显示快照的 `cells` 与 `reachable` 共用 C# Cell 结构，均须提供 `q/r/blocked/cellIndex`；角色统一提供初始 `appearance` 和 `cellIndex`（旧棋盘为 0）。Lua 地格索引从 1 起，C# 显示读取时减 1；值类型字段不能用 nil 表示默认值。
- 队伍与敌人外观均由[棋子资源配置](PawnArt.md)解析。`area` 快照在探索及原地战斗阶段都存在，显示宿主据此保持地形/相机/模型生命周期；地牢战斗使用真实场景、地格拾取和现有技能按钮，旧事件战斗继续显示二维棋盘。MapArea 与战后恢复规则见[局部地图](MapArea.md)，城镇第三人称与交互见[城镇](TownArea.md)。
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
