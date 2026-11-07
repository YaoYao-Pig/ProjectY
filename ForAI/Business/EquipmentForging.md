# 装备锻造与随身器灵
关键词：锻造、重铸、旧剑、成长武器、装备事迹、传奇进阶、器灵、人格、愿望、EquipmentLegacy。

## 文档目录
正文：工艺与身份 / 事迹与能力 / 器灵 / 保存与验证；关键入口：配置、权威状态、规则与界面。

## 正文

- `Adventure.forge`、`legacyCombat`、`spiritDialogue` 分别管理营地操作、真实战斗证据和随身对话。沿 Adventure 初始化、开始、重开/读档与退出生命周期；战斗临时记录存于 C# `AdventureData.LegacyBattle`，不保存 Lua 权威进度。
- 首版工艺支持练习铁剑101、铁剑40。营地一级工作台消费3铁件83及12金币，仓库优先、背包补足；材料/金币/会话/装备归属全部通过后提交。锻造直接保留同一武器对象、Id、ItemId、词缀、配件和持有者，恢复当前耐久及上限到100；首次增加20%本武器直接攻击伤害。再次重铸仅用于修复损伤，不叠加锻造收益，完整本体拒绝重复扣费。
- `EquipmentLegacyData.Of(weapon)` 是该实体成长与记忆的唯一状态，包含锻造、路线、觉醒、愿望和事迹。事迹保存规则、角色、目标、地点及游戏分钟，按 `(RuleId,TargetId)` 去重。换装、缴械、掉地、拾回及重铸不抹除。
- `EquipmentDeedTable` 配置三种真实来源：`legendary_kill` 是本剑有效直接伤害（含削甲）参与、己方真实击败且本场胜利的具名传奇；`legendary_resolution` 是当前交谈者主手锻造剑在传奇对话和解关键动作时的见证；`mission` 仅给已经记录对应击败/和解来源的原武器，在委托正式完成后记入。领奖时临时装备的其他剑不获得事迹。
- 原见证武器若在领取任务奖励时不在队伍库存内，重拾或读档恢复后按装备Revision对已完成委托幂等补记；仍需这把剑自己保存的关键事件，日期为实际补记时刻。显示快照不推进成长。
- 传奇战斗身份按 `LegendaryEncounterTable` 对应世界队伍成员实例核对；背包旁观、同模板替身、中立/友伤、第三方收割及GM合成死亡通知不授予战斗事迹。已有剑伤后由己方后续伤害完成击杀可计，不强制末击。直接伤害在实际消耗武器耐久前保留物理实例来源，最后一次合法攻击即使恰好磨损至0仍可记功。
- 任一击败事迹或完成委托事迹允许选择一次路线：逐猎之锋对敌对具名传奇额外提高10%直接伤害；守望之锋在第一轮本人回合开始时、可用主/副手实际持有时提供2护卫。既有固定具名传奇装备独立。数值及正文唯一来源为三张配置表；基础锻造与完成愿望的倍率为 `1 + damageBonus + wishDamageBonus`，条件传奇增伤另在伤害结算应用。
- 选择路线后可从营地回应器灵。器灵使用装备实例身份，复用 Dialogue 面板、历史卡片和版本检查；`NarrativeData.DialogueId=-1`、`DialogueNpcId=0`、`EquipmentSpiritSession.WeaponId` 区分会话，不创建城镇NPC/招募角色，不进入NPC安置、商店或双人镜头。关闭清理临时会话；对话期间沿既有规则禁止存档。
- 对话包含性格、真实事迹回忆、愿望与接受选项。首项愿望要求接受后以该剑实际参与下一场获胜战斗，持有者存活并仍持该剑；开战保存愿望资格、实际伤害才记贡献。完成一次后本剑直接攻击额外提高5%，再次交谈读取完成答复，不另设可重复领取奖励。第一版性格及愿望正文按所选路线配表，尚无自由生成对白或更多愿望链。
- 营地通过熔炉/铁砧进入锻造页，使用 `CampPresentation`、`CampPanelView` 和显式 LuaReference；左侧按实例编号区分同名旧剑，右侧展示实际模型/配件、成本、事迹与成长操作。背包/工坊详情继续展示锻造收益、路线及器灵状态。与器灵交谈先关闭营地，关对白返回地图，重新打开营地继续操作；场景与界面契约见[营地](Camp.md)。
- 自角色/远征存档27/28起包含每件武器的 `legacy`，覆盖背包、已装备、地面、商队和延迟货物。旧1–26显式迁移为空成长，不补历史；新档缺失/损坏成长结构、重复事迹、未来日期、无效路线/配置在提交前拒绝。当前版本及完整生命周期见[存档](CharacterSave.md)。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/equipment_forge_core.lua`、`equipment_legacy_combat.lua`、`equipment_spirit_dialogue.lua`；真实Data使用 `pwsh -NoProfile -File Tools/Tests/equipment_legacy_data.ps1 -AssemblyPath <已编译Assembly-CSharp.dll>`。实际结果、原生UI脚本及未验证范围见[首版交付与验证](../../Docs/EquipmentForgingValidation.md)；命令不授权启动Editor、Play或再次编译。

## 关键入口

- [工艺表](../../Config/Tables/Equipment/EquipmentForgeTable.json)、[事迹表](../../Config/Tables/Equipment/EquipmentDeedTable.json)、[路线与人格表](../../Config/Tables/Equipment/EquipmentLegacyPathTable.json)：成本、条件、能力、可本地化正文。
- [EquipmentLegacyData.cs](../../Assets/GameFramework/Runtime/Data/EquipmentLegacyData.cs)、[EquipmentForgeState.cs](../../Assets/GameFramework/Runtime/Data/EquipmentForgeState.cs)、[EquipmentSpiritSession.cs](../../Assets/GameFramework/Runtime/Data/EquipmentSpiritSession.cs)：权威状态、原子锻造、临时会话。
- [EquipmentForgeRules.lua](../../Lua/Game/Equipment/EquipmentForgeRules.lua)、[EquipmentForgeModel.lua](../../Lua/Game/Equipment/EquipmentForgeModel.lua)：配置/存档验证、命令、任务归因和显示快照。
- [EquipmentLegacyCombat.lua](../../Lua/Game/Equipment/EquipmentLegacyCombat.lua)、[EquipmentSpiritDialogue.lua](../../Lua/Game/Equipment/EquipmentSpiritDialogue.lua)：真实伤害证据、收益与随身对白。
- [CampCtr.lua](../../Lua/UI/Panel/CampCtr.lua)、[DialogueCtr.lua](../../Lua/UI/Panel/DialogueCtr.lua)、[EquipmentPresentation.lua](../../Lua/Game/Equipment/EquipmentPresentation.lua)：复用原生绑定的界面。
