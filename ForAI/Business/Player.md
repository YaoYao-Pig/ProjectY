# 玩家示例

关键词：Player、Data、ModelSystem、金币、等级、奖励、StatsWidget、Demo。

## 文档目录

正文：当前流程 / 修改边界与验证；关键入口：数据 / 转发 / 展示。

## 正文

- 当前业务仅为框架演示，无存档。C# `PlayerData` 持有 Coins（初始 0）与 Level（初始 1）；`AddCoins / TrySpendCoins / AdvanceLevel` 修改状态并通知，Lua 不维护副本。
- `PlayerModelSystem` 引用 `services.Player`；把 C# Changed 转成 Lua Signal，转发命令。Shutdown 移除 C# 监听并清空 Signal。
- 奖励按钮 → `GrantReward` → `Rewards:Get(1)` → amount 公式读取当前 level 与该行 base → 检查结果为非负 int32 整数 → `PlayerData.AddCoins` → Changed → StatsWidget 在 OnShow 注册的 `refresh` 回调。
- 升级按钮调用 `AdvanceLevel`；StatsWidget 在 OnShow 立即刷新并订阅 Changed，订阅归 visibleScope。窗口标题/描述则在 DemoPanel 的 Bind 读取一次。
- Demo 是 Main 层缓存窗口且不能 Back 关闭；Info 是 Popup 层模态窗口，关闭即销毁。窗口机制见 [UI](../Framework/UI.md)。
- 当前奖励固定 id=1；Rewards 的 enabled/category/tags 及 RewardGroups 不参与演示结算，不能仅改这些配置就宣称已有相应业务功能。

修改与验证：新增状态先改 C# Data 与通知，再补 Model 转发和 Ctrl 展示；新公式变量同时改表声明与求值参数，参见 [配置管线](../Framework/Config.md)。新常驻业务模块才需 [System 注册](../Framework/Runtime.md)。运行 Lua 测试；涉及 C# 数据/事件运行 Unity 集成检查，并在演示场景验证操作。

## 关键入口

- [PlayerData.cs](../../Assets/GameFramework/Runtime/Data/PlayerData.cs)：状态与通知；[PlayerModelSystem.lua](../../Lua/Game/PlayerModelSystem.lua)：`GrantReward / AdvanceLevel / OnShutdown`。
- [DemoCtr.lua](../../Lua/UI/Panel/DemoCtr.lua)：按钮命令；[Stats.lua](../../Lua/UI/Widget/Stats.lua)：订阅与刷新。
- [Rewards.json](../../Config/Tables/Rewards.json)：当前奖励源；[PanelConfig.asset](../../Assets/DynamicAsset/UI/Resources/PanelConfig.asset)：Demo / Info 定义。
- [FrameworkDemo.unity](../../Assets/GameFramework/Samples/FrameworkDemo.unity)：Play 验证入口；[FrameworkValidation.cs](../../Assets/GameFramework/Editor/FrameworkValidation.cs)：集成检查。
