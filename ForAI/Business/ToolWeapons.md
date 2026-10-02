# 工具武器与临时障碍
关键词：工具性武器、武器标签、斧子、镐子、铲子、撬棍、清障、坍塌石堆、木箱、土堆、开锁。

## 文档目录
正文：标签与装备 / 生成和持久性 / 交互与代价 / 验证；关键入口：规则 / 状态 / 资源。

## 正文

- 武器标签和详情 UI 归[装备](Equipment.md)。标签表 `tool` 标记探索工具能力，`EquipmentRules:IsUtilityWeapon` 据此判断逻辑工具武器；不改变攻击 `kind`、手数和持握匹配。两种斧子共享 `axe`，其余为 `pickaxe/shovel/crowbar`；破盾尚未实现。
- 物品 70–74 是伐木斧、钢制战斧、矿工镐、铁铲、撬棍。地牢入口补给和森林入口附近生成“勘探工具箱”，物品经原搜刮界面拖入共享背包；初始背包不自动追加工具。仅存活队员实际装备的主手或副手参与工具判定，携带、倒地队员和未装备武器不生效。
- `MapAreaObstacleTable` 配置地点、数量、距离、间距、模型、工具、事件、劳损、回合和成功率。地牢/森林当前保留石堆和土堆；木箱与上锁箱的旧生成数置零，改由[容器系统](Loot.md)安置并接受真实攻击/技能伤害。避开陈设、容器、队伍、NPC 和敌人；同种子计划一致。
- 临时障碍叠加在只读布局上，石堆/木箱覆盖中心及相邻可走地格，优先选择通道；狭窄处可能断路，宽阔处允许绕行。探索路径与原地战斗占格共用动态阻挡，清除不修改静态地形；土堆和上锁箱子仅是交互点。显示快照只公开当前可见的障碍地格。
- `ObstacleInteractions` 持有 C# `MapObstacleData`，按地点记录占格、清除、尝试次数、预抽奖励和当前交互；Lua 不保存第二份持久状态。离开重进不刷新，开始新远征清空。新 Data 类型由反射桥接，`Runtime/Data/link.xml` 保留；未修改生成 Wrapper。
- 点击障碍或经过被阻断的已知路线会先规划到障碍边缘，再触发已有 StoryEvent；相邻处可按 E 或使用 HUD 交互。选项新增 `obstacleAction`（tool/manual/leave），要求当前障碍事件匹配；先消费选择，重复提交不会再次伤血或发奖。
- 徒手处理剩余障碍时选择生命最多的存活角色，直接承担非战斗劳损并至少保留 1 HP；工具免劳损。徒手 3 探索回合、工具 1 回合，推进世界回合与效果。旧开锁事件模板保留供配置引用，但当前地图中的上锁容器走新的工具开启/耐久破坏规则。
- 土堆和上锁箱子在生成时固定奖励，处理成功后生成真实[搜刮容器](Loot.md)；背包满时物品仍留在容器中，重试和重进均不重抽、不重复生成。
- 定向检查：`python -B Tools/Tests/run_lua.py Tools/Tests/tool_obstacles.lua`；真实 C# 状态检查为 `tool_obstacles_integration.lua`（独立 Edit Mode LuaEnv 注入 FrameworkServices）。资源同步 `EquipmentAssets.SyncSelected({70..74},{80,81,82})`，同时调用 `EquipmentIconExporter.ExportItems` 导出所选图标；不运行全量装备资源同步、不进入 Play。

## 关键入口

- [配置](../../Config/Tables/MapArea/MapAreaObstacleTable.json) / [生成计划](../../Lua/Game/MapArea/ObstacleGenerator.lua) / [交互规则](../../Lua/Game/MapArea/ObstacleInteractions.lua)。
- [持久状态](../../Assets/GameFramework/Runtime/Data/MapObstacleData.cs) / [地图移动](../../Lua/Game/MapArea/MapAreaSystem.lua) / [障碍显示](../../Assets/GameFramework/Samples/Adventure/AreaObstacleRenderer.cs)。
- [源模型](../../Art/EquipmentDemo/Source/EquipmentTools.blend) / [制作脚本](../../Art/EquipmentDemo/Scripts/build_tools.py) / [算法检查](../../Tools/Tests/tool_obstacles.lua) / [状态检查](../../Tools/Tests/tool_obstacles_integration.lua)。
