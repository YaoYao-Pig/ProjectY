# 探索事件与远征 Demo

关键词：Adventure、事件、选择、条件、奖励、营地、探索、结算、战斗 Demo。

## 文档目录

正文：流程与状态 / 配置与使用 / 验证；关键入口：规则 / 桥接 / 展示。

## 正文

- 来源：[玩法](https://my.feishu.cn/wiki/EcbNwrZ4Ii0BzykmlTCcceFmnRd)。当前可见策划无独立事件页；本版条件→选择→结果框架和 demo 内容按用户确认的范围实现。
- `AdventureSystem` 持有一次远征的只读大地图布局和地点定义，调用已有 MapSystem 生成，不修改 MapSystem 的快照契约。营地/野外地点以有限扫描放置；聚落优先经配表映射到 [MapArea 局部地图](MapArea.md)，未映射的建筑仍使用旧事件映射。直接选择目的地进入事件或局部探索，尚无队伍大地图行走、寻路、视野或资源采集。
- `services.Adventure` 的 C# `AdventureData` 持有队伍、地点访问记录和阶段：事件为 map → event → resolving → battle/result → map；局部探索为 map ↔ area，地牢原地战斗为 area → battle → resolving → area/map。`AreaEncounterId` 区分原地战斗上下文，结算后清零；战斗结果先离开 battle 才发奖，避免重复结算。
- `AdventureEvents` 依赖 Battle、PlayerModel，处理最高存活侦察值、金币费用、队伍存活条件以及恢复生命/金币/特质/进入遭遇。选项必须属于当前事件；条件不足不改变任何状态。事件可配置重复访问，普通地点离开也消耗一次访问；营地和补给站可重访。
- `AdventureSystem:BattleCommand` 限制玩家只能操作己方回合，AI 按单个敌人回合推进。胜利奖励由遭遇配置指定；失败/轮数耗尽不发战利品。队伍伤势保留，倒地角色可在营地恢复；特质授予首名存活队员。完整战斗契约见[战斗](Battle.md)。
- `AdventureDemoTable` 定义默认种子、Region 配方、队伍人数上限/模板、营地、野外和建筑事件映射；`AdventureEventTable` 定义文案、重访和选项；`AdventureChoiceTable` 定义条件、费用与结果；遭遇引用 `CombatEncounterTable`。默认队伍模板为 1/2/3/6，最多四人；模板 4/5 为敌人。没有存档、完整招募/升级或完整 GAS 实现。
- Adventure 依赖 Equipment：Start 在重置后发放初始装备，Visit 在进入地图后初始化持久搜刮点，area_loot 转发搜刮命令；Snapshot 附加可见掉落和装备外观。按 I 的[装备工坊](Equipment.md)使用 UI 框架暂停租约，暂停期间不触发新敌群。
- 金币复用 PlayerData；“开始新远征”重置队伍与地点，保留本次运行的金币。关闭运行时后数据释放。新增会话状态只加 C# Data，不在 Lua 另存余额、HP、AP 或选择阶段。
- Unity 菜单 `Project Y/远征/打开战斗与事件 Demo` 打开/首次生成独立场景；按 Play 运行。点地图编号或地点按钮查看事件；选迎战后，绿色地格可移动，选技能后点高亮角色，点“结束回合”推进；敌方默认自动行动。结算后返回地图，营地可以休整。
- 首次接入这些 C# Data 或修改桥接 API 后，先在 Edit Mode 完成 C# 编译，再执行 `XLua/Generate Code` 并等待生成代码编译完成，最后进入 Play。仅编译 C# 不会自动更新 `FrameworkServices` 的生成 getter；旧绑定会使 Lua 读到 `services.Adventure == nil`。
- 战斗操作区使用既有 UISystem/LuaReference 的[战斗 HUD](BattleHUD.md)，进入/离开 battle 自动开关；地图/事件的演示界面、世界标签及旧二维棋盘仍使用 C# IMGUI。地形复用 MapPreviewRenderer，业务状态和命令继续由同一 Lua 运行时处理。
- `DemoBridge` 通过 GameBootstrap.CallModule 使用同一常驻 LuaEnv；`MapPreviewData.Read` 和 `AdventureViewData.Read` 在调用内复制纯显示数据并释放 LuaTable，不持有长期 Lua 句柄。新场景独立于现有地图预览，尚未加入 Build Settings。
- 显示快照的 `cells` 与 `reachable` 共用 C# Cell 结构，均须提供 `q/r/blocked/cellIndex`；角色统一提供初始 `appearance` 和 `cellIndex`（旧棋盘为 0）。Lua 地格索引从 1 起，C# 显示读取时减 1；值类型字段不能用 nil 表示默认值。
- 队伍与敌人外观均由[棋子资源配置](PawnArt.md)解析。`area` 快照在探索及原地战斗阶段都存在，显示宿主据此保持地形/相机/模型生命周期；地牢战斗使用真实场景、地格拾取和现有技能按钮，旧事件战斗继续显示二维棋盘。MapArea 与战后恢复规则见[局部地图](MapArea.md)，城镇第三人称与交互见[城镇](TownArea.md)。
- 改表后执行 `node Tools/ConfigEditor/exporter.mjs`；资源路径变化后在退出 Play 的新场景执行 `Project Y/远征/同步地图资源引用`。改 Lua 在下一次 Play 生效，不做运行时热重载。
- 最小验证：原生 xLua `adventure_core.lua`；Edit Mode 菜单 `Project Y/远征/验证战斗与事件` 运行独立真实 C# 状态检查；获授权后在新 demo 验收事件→战斗→结算。检查源码见下方入口；不自动扩展到全量地图测试或 Player 构建。
- 显示快照改动运行 `python -B Tools/Tests/run_lua.py Tools/Tests/adventure_snapshot.lua`，覆盖地图、事件、入战、移动用尽和结算的必需字段类型；使用只读状态/配置夹具和真实 Lua 快照、查询实现，不触发 Unity 编译。

## 关键入口

- [AdventureSystem.lua](../../Lua/Game/Adventure/AdventureSystem.lua) / [EventSystem.lua](../../Lua/Game/Adventure/EventSystem.lua)：地点、条件、状态与结算；[AdventureData.cs](../../Assets/GameFramework/Runtime/Data/AdventureData.cs)：会话状态。
- [DemoBridge.lua](../../Lua/Game/Adventure/DemoBridge.lua) / [AdventureViewData.cs](../../Assets/GameFramework/Samples/Adventure/AdventureViewData.cs)：命令和显示快照。
- [AdventureRuntimeDemo.cs](../../Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs) / [AdventureDemoMenu.cs](../../Assets/GameFramework/Editor/AdventureDemoMenu.cs)：运行展示、场景创建与序列化绑定。
- [AdventureDemoTable.json](../../Config/Tables/Adventure/AdventureDemoTable.json) / [事件表](../../Config/Tables/Adventure/AdventureEventTable.json) / [选项表](../../Config/Tables/Adventure/AdventureChoiceTable.json)：首版玩法配置。
- [AdventureValidation.cs](../../Assets/GameFramework/Editor/AdventureValidation.cs) / [adventure_integration.lua](../../Tools/Tests/adventure_integration.lua)：真实数据与桥接检查，独立于正在编辑的场景。
