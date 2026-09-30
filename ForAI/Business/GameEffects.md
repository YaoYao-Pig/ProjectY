# GameEffect
关键词：GameEffect、GAS、持续效果、周期伤害、治疗、Buff、属性增减、叠层、状态图标、战后保留。

## 文档目录
正文：配置与入口 / 生命周期 / 存档与 UI / 验证；关键入口：数据 / 规则 / 配置。

## 正文

- `CombatEffectTable` 是技能组合和独立效果的统一定义。既有 `CombatSkillTable.effectIds` 保留；普通业务通过 `BattleSystem:ApplyEffect(effectId, source, target)` 独立施加，不要求消耗技能 AP。换弹仍依赖装备技能事务，驯服和位移仍需要各自的技能目标/占格上下文。
- `duration` 为 instant/duration/infinite；有限效果使用 durationTurns，无限实例 Remaining=-1。持续效果支持 damage/heal/modifier；modifier 的 attribute 指定角色属性、amount 可以为负，periodTurns 必须为 0；伤害/治疗的 periodTurns 必须大于 0。
- magnitude 在施加时用现有受限公式求值并保存快照；技能伤害缩放仍沿用原接口，独立施加时 proficiency 为 0。属性增减参与 `CombatStats:Get`，生命上限变化按原 SetMaxHP 契约保留已受伤害。
- `tickPhase` 配置 turn_start 或 turn_end，在目标回合的对应阶段推进一次计时。先触发到期周期，再移除耗尽的实例；首次周期不会在施加瞬间执行。回合开始死亡会跳过行动，结束阶段死亡仍检查胜负；区域战斗先进入 battle 阶段，再结算首个回合效果，允许保留的效果在开场直接结束遭遇。
- `stacking` 按“目标 + 效果 ID”聚合：refresh 使用最新施加者/数值并重置时长与周期；independent 产生独立实例；stack 增层至 maxStacks，并使用最新数值、重置时长与周期。界面状态仅投影实例，不维护计时副本。
- `removeOnBattleEnd` 决定战斗结束是否移除；保留的效果进入探索后，随现有探索世界回合推进开始/结束阶段，暂停/对话和没有执行路线时不累计新世界回合。`removeOnDeath` 决定倒地是否清除；普通治疗仍不复活。
- 角色及坐骑的 `Effects` 是 C# `GameEffectCollectionData`；包含实例 ID、效果 ID、施加者、数值快照、剩余回合、周期进度与层数。[角色存档](CharacterSave.md) v3 保存这些记录，旧 v1/v2 明确迁移为空效果列表；读档核对当前配置的持续方式、层数和周期。
- 探索周期结算后移除倒地队员的移动编队；全员倒地返回大地图。敌人死亡继续发送 defeated 事件并使用原掉落标记防止重复掉落。挂在坐骑上的效果同样推进，坐骑死亡释放骑乘关系。
- [MainHud](MainHud.md) 的各角色头顶 HudHealth 使用 HudStatusEffect Widget 显示实际实例的图标、层数和剩余回合，按六列换行并悬停查看来源与说明；不使用独立屏幕状态区。iconId 复用 BattleIconTable，空 Sprite 使用名称首字作为可读徽记。
- 最小原生 Lua 检查：`python -B Tools/Tests/run_lua.py Tools/Tests/game_effects_core.lua`。真实桥接检查为 `Tools/Tests/game_effects_integration.lua`，需要独立 UIHost、FrameworkServices 与临时存档路径，在现有 Edit Mode LuaEnv 中运行；不读写玩家存档。

## 关键入口

- [GameEffectData.cs](../../Assets/GameFramework/Runtime/Data/GameEffectData.cs)：唯一实例状态与存档结构。
- [GameEffects.lua](../../Lua/Game/Battle/GameEffects.lua)：Prepare / ApplyPrepared / TickActor / Clear / Rows / ValidateSaved。
- [BattleSystem.lua](../../Lua/Game/Battle/BattleSystem.lua) / [CombatStats.lua](../../Lua/Game/Battle/CombatStats.lua)：技能组合、回合与属性。
- [CombatEffectTable](../../Config/Tables/Adventure/CombatEffectTable.json) / [MapAreaSystem.lua](../../Lua/Game/MapArea/MapAreaSystem.lua)：配置与探索时钟接入。
