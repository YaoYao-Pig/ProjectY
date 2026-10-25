# 具名传奇装备
关键词：传奇武器、传奇盾牌、骑枪、折光、残样、返场、共债、冲势、活榫迁筑、LegendaryEquipment。

## 文档目录
正文：配置与激活 / 战斗事务 / 位移与工事 / 验证；关键入口：规则 / 状态 / 检查。

## 正文

- `LegendaryEquipmentTable` 用物品 ID 连接稳定 `kind`、有序 `skillIds/effectIds/values`；名称与描述不参与判定。数值顺序由 [LegendaryEquipment.lua](../../Lua/Game/Battle/LegendaryEquipment.lua) 各机制消费，技能基础伤害/AP/命中/触媒继续来自普通技能表与装备规则。
- 武器只在可用主手激活；归乡盾在可用副手盾位额外激活，允许枪盾或剑盾同时生效。专属技能由 `AddSkills/Budget` 复核实际装备；不会因为学会某职业而赠送整套职业技能。主要武器命中特性不转移到副手武器攻击。
- 折光、残样、返场、冲势、架势、护符等可显示状态使用普通 C# `Effects`；每轮/每场限制和链接身份使用角色 C# `ProfessionMarks`。Lua 只保存本次命令的预检路径与命中快照。卸装清资源而保留次数，破损不再激活；战斗结束随现有状态/计数统一清理。
- 资源在合法命令提交时消费，落空不返还；同一传奇主动的火/奥术或火/毒变体共享冷却。主要行动、消耗品、借机反应、材料、命中、暴击、免疫、护甲耐久与护卫沿用原流程。
- 条件增伤在 `ProfessionCombat.Damage` 与破绽/咒印共享基础直接伤害的 50% 总上限；农民武器按角色记录每轮首个本武器主要命中，落空不消费，多目标/多发不重复增益。共债仅使用该次命中剩余预算，并沿用原命中伤害类型检查第二目标免疫、防御和护卫，不复制暴击、咒印或再次触发共债。伤前快照保留致死命中的状态与原承誓受保护者。
- 共债 Buff 使用 infinite 时钟，由 C# 角色计数中的 `debt_owner/debt_deadline` 指定施法者及其下一回合末期限；接收者自己的行动顺序与 turn_end 不推进它。施法者下一回合仍可攻击触发，回合结束才清理；任一端被驱散/死亡、施法者死亡或卸下来源武器时清除链接两端。
- 承誓仍由 [职业规则](ProfessionCombat.md) 单次重定向，不递归；归乡护符与原守命护符取高。余恩式护卫只统计本次主动对其他友军的实际治疗。旗帜命中只由下一次主要伤害攻击消费，治疗和其他支持动作不消费。
- 留踪箭、并肩追猎、折冠冲锋复用角色→落点两阶段入口；逐格校验完整占地、实际邻接与机关。退步不触发借机；动物位移逐步检查借机，骑枪仅在起步贴敌时承担一次借机检查。倒地/受控/截停取消余段，骑枪失去坐骑同时取消移动与枪击，AP不退。驯兽师占用动物当轮额外移动和攻击额度，救援禁攻继续生效。
- 活榫迁筑使用 `NeedsCellLanding/CellLandingCells/TrySkillAtWithLanding` 的工事→目的格入口，只移动本人建造的栅栏或木墙。`LegendaryEquipmentState.MoveConstruction` 原子修改同一记录位置并增加 Revision，保留耐久、队伍与实际材料快照；入口出口、上层、人物/陈设/战利品占位不合法。
- 工事新增 `OwnerActorId` 随既有存档 Capture/Prepare 往返；旧档缺字段为 0，作者未知，不能迁筑。其余工事契约见 [营造](Construction.md)。
- 最小离线检查：`python -B Tools/Tests/run_lua.py Tools/Tests/legendary_equipment_core.lua`。使用真实导出表和 Lua 战斗/效果程序，仅隔离 C# 状态边界；覆盖 15 件机制、真实提交/落空事务、占地/资源/冷却与卸装边界。原有 `profession_combat_core.lua` 检查共享职业流程。
- 原生定向检查 [legendary_equipment_state.cs](../../Tools/Tests/legendary_equipment_state.cs) 是 Unity MCP `execute_code` body；在已获准的现有 Edit Mode 中运行，使用隔离对象与临时 LuaEnv，验证权威工事作者、迁移、存档准备及真实反射桥。不启动 Editor、不进入 Play，不读写玩家存档；离线检查通过不等于原生或完整实机验收。
- 固定品质与每世界唯一来源由[战利品契约](Loot.md)管理：5件任务预留、1件现有传奇敌装、9件副本搜集；旧区域只补未投放容器，既有敌装不重发。[本批清单](../../Art/LegendaryEquipment202610/README.md)列出实际来源、模型与接入顺序。
- 通用持续辉光、粒子和有限点光按[特效](VisualEffects.md)配置，不与传奇身份绑定。传奇外框与详情见[装备展示](Equipment.md)，工事选格见[战斗HUD](BattleHUD.md)。[验收记录](../../Art/LegendaryEquipment202610/Integration/validation.md)区分离线、原生与未执行Play范围。

## 关键入口

- [LegendaryEquipmentTable](../../Config/Tables/Equipment/LegendaryEquipmentTable.json) / [LegendaryEquipment.lua](../../Lua/Game/Battle/LegendaryEquipment.lua)：具名身份、状态、资源、技能和移动规则。
- [BattleSystem.lua](../../Lua/Game/Battle/BattleSystem.lua) / [ProfessionCombat.lua](../../Lua/Game/Battle/ProfessionCombat.lua) / [ProjectileCombat.lua](../../Lua/Game/Battle/ProjectileCombat.lua) / [GameEffects.lua](../../Lua/Game/Battle/GameEffects.lua)：动作预检/提交、命中快照、条件预算、实际损伤与治疗观察。
- [LegendaryEquipmentState.cs](../../Assets/GameFramework/Runtime/Data/LegendaryEquipmentState.cs) / [ExpeditionSaveState.cs](../../Assets/GameFramework/Runtime/Data/ExpeditionSaveState.cs)：工事作者与迁移的反射桥和存档字段。
- [legendary_equipment_core.lua](../../Tools/Tests/legendary_equipment_core.lua) / [legendary_equipment_state.cs](../../Tools/Tests/legendary_equipment_state.cs)：离线与原生最小验证入口。
