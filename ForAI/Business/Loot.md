# 宝箱生成与敌人掉落

关键词：宝箱、掉落、战利品、概率、掉落池、ChestGenerator、LootPool、战后探索、事件战场、满包。

## 文档目录

正文：生成与配置 / 状态与领取 / 事件战场 / 验证；关键入口：规则 / 权威状态 / 检查。

## 正文

- [持续 GameEffect](GameEffects.md) 在探索中造成的死亡，经 `GenerateActorDrops / MapLoot:ActorDrops` 复用同一套掉落规则与 DropResolved 标记；战斗结算的 `EnemyDrops` 也委托此入口。

- `Game.Loot` 集中管理掉落解释、宝箱生成计划与地图掉落事务；`EquipmentSystem` 保留原有 `InitializeLoot/Loot/LootSnapshot` 门面并提供背包 `CanGrant/Grant`。地图布局只负责可达性，实际随机内容与领取状态在 C# `MapAreaLootData` 中保存，不在 Lua 保存第二份库存。
- `MapAreaChestRuleTable` 按 areaId 配置宝箱类型、数量区间、距入口的寻路距离范围、宝箱间格距和独立种子盐；`reachable` 选择可达地格，`rooms` 限定房间/林间空地。避开入口、目标、地图陈设、NPC 和角色完整占格，不改变导航阻挡；空间不足明确报告配置错误，不静默减量。首版地牢和森林各新增 2～4 个随机宝箱，原入口补给保留。
- `EquipmentLootTable` 定义箱子/地面战利品名称及关闭/开启模型。poolId=0 使用原固定 itemIds/counts，poolId>0 引用 `LootPoolTable`，随机容器不再填写固定物品。原地牢入口补给继续沿用 EquipmentDemoTable 的固定距离配方，新增宝箱使用独立策略。
- `LootEntryTable` 的每一行独立按 chance（0～100%）判定，命中后在 minCount..maxCount 中抽数量；允许同次获得多种物品或空结果，同物品重复命中合并数量。`LootPoolTable.seedSalt` 隔离随机流。箱子生成时就把结果存进容器，打开窗口、领取失败或重新进入均不重抽；空箱可正常打开。
- `EnemyDropTable.unitId` 关联战斗模板与地面战利品定义。未配置的模板无掉落；首版近战敌人示例掉铁剑/盾牌/组件，弓手示例掉长弓/护具/符文，概率在对应池条目中。只对 HP=0、Team=2 且未驯服的敌人结算，`CombatActorData.DropResolved` 防止再次结算；空结果也标记完成。
- 原地战斗结束时，无论胜利或败退，已死亡敌人的战利品都留在其真实地格；活着或被驯服的敌人不生成击杀掉落。同格多个来源可以共存，显示层作小幅偏移；规则仍使用原格。胜利后继续探索，败退按既有流程返回大地图，可治疗后重返。
- 靠近一格通过 E 或 HUD“搜刮”领取；先检查整包容量，再发放全部内容并标记领取。满包不发一部分、不销毁容器、不重抽。打开的宝箱保留开启模型，领取完的地面战利品隐藏。获得日志使用实际随机内容，空箱记录明确说明。
- 旧世界事件的战斗也转入 `E_MapAreaType.Battlefield` 的持久小地图：`BattlefieldGenerator` 沿用原 CombatEncounterTable 的半径、障碍概率与敌方坐标，战斗/战后共用同一布局。`Loot.EventBattlefieldAreaId` 指定地图定义；当前世界事件由 resolving 经 `BeginEventArea` 进入区域战斗。胜利后可走动拾取、离开和重进，不重复触发旧事件或奖励；战場缓存与其他小地图在新远征时统一清空。当前配置的带战斗事件均来自大地图，不支持把已有区域内事件替换成另一张独立战场。
- 状态持久性沿用同次远征的地图记录；角色存档仍按原约定保存队伍/背包并重建地图，不把地面未领取物品当作跨运行存档。
- 最小离线检查：`python -B Tools/Tests/run_lua.py Tools/Tests/loot_core.lua`。真实 C#、满包事务、敌人一次性掉落、旧事件留场与重进通过 Unity MCP 执行 `Tools/Loot/run_checks.cs`，使用独立 LuaEnv，不启动 Play。

## 关键入口

- [LootRules](../../Lua/Game/Loot/LootRules.lua) / [ChestGenerator](../../Lua/Game/Loot/ChestGenerator.lua) / [MapLoot](../../Lua/Game/Loot/MapLoot.lua)。
- [掉落源表](../../Config/Tables/Loot/) / [容器表现](../../Config/Tables/Equipment/EquipmentLootTable.json) / [配表制作脚本](../../Tools/Loot/configure_loot.py)。
- [地图与容器状态](../../Assets/GameFramework/Runtime/Data/MapAreaData.cs) / [击杀结算标记](../../Assets/GameFramework/Runtime/Data/CombatActorData.cs) / [战斗结算](../../Lua/Game/Adventure/AdventureSystem.lua)。
- [事件战场生成](../../Lua/Game/MapArea/BattlefieldGenerator.lua) / [规则检查](../../Tools/Tests/loot_core.lua) / [真实状态检查](../../Tools/Tests/loot_integration.lua)。
