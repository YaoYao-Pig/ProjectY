# GM 调试系统

关键词：GM、GMSystem、调试命令、槽位、升级、获取技能、F8。

## 文档目录

正文：入口与职责 / 命令 / 验证；关键入口：系统 / UI / 检查。

## 正文

- `GMSystem` 是独立 LuaSystem，注册名 `GM`，依赖 Config/Growth；负责命令分发、参数校验和队伍槽位解析。权威数据仍归现有 C# 角色与养成状态，不在 GM 系统内复制角色数据。
- `Execute('level_up', slot)` 将指定队员提升一级，补齐该级所需经验并调用正常 `GrowthSystem:AddExperience`；属性点、天赋点、研习机会与经历均遵循原配置，不加满血、不重置已有进度。配置等级上限时返回原因，不额外发奖。
- `Execute('grant_skill', slot, skillId)` 按 CombatSkillTable ID 永久授予主动技能，绕过研习候选与属性门槛，不消费升级研习机会；重复技能或无效 ID 返回原因。若技能正位于当前候选中，只移除相同候选，保留学习机会，必要时沿正常流程补充候选。骑兵技能的骑乘要求仍由战斗规则检查。
- 槽位为当前队伍顺序的 1..PartyCount，内部才转换为零基索引；不能把槽位当作角色实例 ID。未知命令、非整数、越界和空队伍均在修改前拒绝。
- HUD 的 `GM F8` 按钮或 F8 打开独立 `GM` Panel；窗口为 Popup、模态、暂停世界、可缓存，Esc/关闭按钮/F8 关闭。面板只输入槽位与技能 ID，调用 DemoBridge 的 `gm_level_up/gm_grant_skill`；桥接转交 `GMSystem` 并刷新正常游戏快照。技能 ID 默认 201（驯服），不会在打开面板时自动授予。
- `CharacterGrowthData.GrantSkill` 是直接授予状态接口，保证已学技能不重复、与候选集合互斥；保存沿用现有[角色存档](../Business/CharacterSave.md)。GM 本身不自动落盘，仍由“保存队伍”保存。
- `Tools/GM/create_gm_ui.cs` 经 Unity MCP 创建和绑定 Prefab，不手改 YAML。`Tools/GM/run_checks.cs` 经 Unity MCP 在 Edit Mode 的独立 PreviewScene 中运行 `gm_integration.lua`，验证槽位隔离、正常升级奖励、直接授予、候选互斥、满级、重复与非法输入，以及面板按钮/暂停释放，并输出 `Docs/Previews/GM.png`；不进入 Play。

## 关键入口

- [GMSystem.lua](../../Lua/Game/GM/GMSystem.lua) / [系统注册](../../Lua/Game/Systems.lua) / [命令桥接](../../Lua/Game/Adventure/DemoBridge.lua)。
- [GMCtr.lua](../../Lua/UI/Panel/GMCtr.lua) / [GMPanel.prefab](../../Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab) / [制作脚本](../../Tools/GM/create_gm_ui.cs)。
- [养成状态](../../Assets/GameFramework/Runtime/Data/CharacterGrowthData.cs) / [定向检查](../../Tools/Tests/gm_integration.lua) / [检查执行器](../../Tools/GM/run_checks.cs)。
