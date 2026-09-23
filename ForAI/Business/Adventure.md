# 探索事件与远征 Demo

关键词：Adventure、事件、选择、条件、奖励、营地、探索、结算、战斗 Demo。

## 文档目录

正文：流程与状态 / 配置与使用 / 验证；关键入口：规则 / 桥接 / 展示。

## 正文

- 来源：[玩法](https://my.feishu.cn/wiki/EcbNwrZ4Ii0BzykmlTCcceFmnRd)。当前可见策划无独立事件页；本版条件→选择→结果框架和 demo 内容按用户确认的范围实现。
- `AdventureSystem` 持有一次远征的只读大地图布局和地点定义，调用已有 MapSystem 生成，不修改 MapSystem 的快照契约。营地/野外地点以有限扫描放置；聚落优先经配表映射到 [MapArea 局部地图](MapArea.md)，未映射的建筑仍使用旧事件映射。直接选择目的地进入事件或局部探索，尚无队伍大地图行走、寻路、视野或资源采集。
- `services.Adventure` 的 C# `AdventureData` 持有队伍、地点访问记录和阶段：事件为 map → event → resolving → battle/result → map；局部探索为 map ↔ area。选择时先进入 resolving 并记录地点，拒绝重复选择；战斗结果也先离开 battle 才发奖，避免重复结算。
- `AdventureEvents` 依赖 Battle、PlayerModel，处理最高存活侦察值、金币费用、队伍存活条件以及恢复生命/金币/特质/进入遭遇。选项必须属于当前事件；条件不足不改变任何状态。事件可配置重复访问，普通地点离开也消耗一次访问；营地和补给站可重访。
- `AdventureSystem:BattleCommand` 限制玩家只能操作己方回合，AI 按单个敌人回合推进。胜利奖励由遭遇配置指定；失败/轮数耗尽不发战利品。队伍伤势保留，倒地角色可在营地恢复；特质授予首名存活队员。完整战斗契约见[战斗](Battle.md)。
- `AdventureDemoTable` 定义默认种子、Region 配方、队伍人数上限/模板、营地、野外和建筑事件映射；`AdventureEventTable` 定义文案、重访和选项；`AdventureChoiceTable` 定义条件、费用与结果；遭遇引用 `CombatEncounterTable`。默认队伍模板为 1/2/3/6（剑盾、弓手、法师、双手战士），`AdventureData.AddPartyActor` 硬性限制最多四人；模板 4/5 仍为敌人。没有存档、完整招募/升级、装备改造或完整 GAS 实现。
- 金币复用 PlayerData；“开始新远征”重置队伍与地点，保留本次运行的金币。关闭运行时后数据释放。新增会话状态只加 C# Data，不在 Lua 另存余额、HP、AP 或选择阶段。
- Unity 菜单 `Project Y/远征/打开战斗与事件 Demo` 打开/首次生成独立场景；按 Play 运行。点地图编号或地点按钮查看事件；选迎战后，绿色地格可移动，选技能后点高亮角色，点“结束回合”推进；敌方默认自动行动。结算后返回地图，营地可以休整。
- 首次接入这些 C# Data 或修改桥接 API 后，先在 Edit Mode 完成 C# 编译，再执行 `XLua/Generate Code` 并等待生成代码编译完成，最后进入 Play。仅编译 C# 不会自动更新 `FrameworkServices` 的生成 getter；旧绑定会使 Lua 读到 `services.Adventure == nil`。
- 此 demo 沿用现有地图测试的 C# IMGUI 展示方式，复用 MapPreviewRenderer，棋盘为可点击六边形与单位标记；没有绕过 LuaReference 去查找业务 UI 对象。正式面板接入应使用既有 UISystem/LuaReference，不把演示 GUI 当生产 UI 框架。
- `DemoBridge` 通过 GameBootstrap.CallModule 使用同一常驻 LuaEnv；`MapPreviewData.Read` 和 `AdventureViewData.Read` 在调用内复制纯显示数据并释放 LuaTable，不持有长期 Lua 句柄。新场景独立于现有地图预览，尚未加入 Build Settings。
- 显示快照的 `cells` 与 `reachable` 共用 C# Cell 结构，均须显式提供 `q/r/blocked`；`blocked` 即使为 false 也不可省略。其他 C# bool/int 值类型字段同样不能用 nil 表示默认值。
- 队伍显示快照额外带初始 `appearance`，由[棋子资源配置](PawnArt.md)解析，敌人旧战斗快照不要求该字段。MapArea 的四人模型与共享移动归[局部地图](MapArea.md)；旧事件战斗仍显示二维棋盘，没有自动改成原地战斗。
- 改表后执行 `node Tools/ConfigEditor/exporter.mjs`；资源路径变化后在退出 Play 的新场景执行 `Project Y/远征/同步地图资源引用`。改 Lua 在下一次 Play 生效，不做运行时热重载。
- 最小验证：原生 xLua `adventure_core.lua`；Edit Mode 菜单 `Project Y/远征/验证战斗与事件` 运行独立真实 C# 状态检查；获授权后在新 demo 验收事件→战斗→结算。检查源码见下方入口；不自动扩展到全量地图测试或 Player 构建。
- 显示快照改动运行 `python -B Tools/Tests/run_lua.py Tools/Tests/adventure_snapshot.lua`，覆盖地图、事件、入战、移动用尽和结算的必需字段类型；使用只读状态/配置夹具和真实 Lua 快照、查询实现，不触发 Unity 编译。

## 关键入口

- [AdventureSystem.lua](../../Lua/Game/Adventure/AdventureSystem.lua) / [EventSystem.lua](../../Lua/Game/Adventure/EventSystem.lua)：地点、条件、状态与结算；[AdventureData.cs](../../Assets/GameFramework/Runtime/Data/AdventureData.cs)：会话状态。
- [DemoBridge.lua](../../Lua/Game/Adventure/DemoBridge.lua) / [AdventureViewData.cs](../../Assets/GameFramework/Samples/Adventure/AdventureViewData.cs)：命令和显示快照。
- [AdventureRuntimeDemo.cs](../../Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs) / [AdventureDemoMenu.cs](../../Assets/GameFramework/Editor/AdventureDemoMenu.cs)：运行展示、场景创建与序列化绑定。
- [AdventureDemoTable.json](../../Config/Tables/Adventure/AdventureDemoTable.json) / [事件表](../../Config/Tables/Adventure/AdventureEventTable.json) / [选项表](../../Config/Tables/Adventure/AdventureChoiceTable.json)：首版玩法配置。
- [AdventureValidation.cs](../../Assets/GameFramework/Editor/AdventureValidation.cs) / [adventure_integration.lua](../../Tools/Tests/adventure_integration.lua)：真实数据与桥接检查，独立于正在编辑的场景。
