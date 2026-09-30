# GM 调试系统

关键词：GM、GMSystem、调试命令、槽位、升级、获取技能、F8、NPC 搜索、查找 NPC、传送、定位。

## 文档目录

正文：入口与职责 / 命令 / 验证；关键入口：系统 / UI / 检查。

## 正文

- `GMSystem` 是独立 LuaSystem，注册名 `GM`，依赖 Config/Growth/Narrative；负责命令分发、参数校验和队伍槽位解析。权威数据仍归现有 C# 状态，不在 GM 系统内复制角色或 NPC 位置。
- `Execute('level_up', slot)` 将指定队员提升一级，补齐该级所需经验并调用正常 `GrowthSystem:AddExperience`；属性点、天赋点、研习机会与经历均遵循原配置，不加满血、不重置已有进度。配置等级上限时返回原因，不额外发奖。
- `Execute('grant_skill', slot, skillId)` 按 CombatSkillTable ID 永久授予主动技能，绕过研习候选与属性门槛，不消费升级研习机会；重复技能或无效 ID 返回原因。若技能正位于当前候选中，只移除相同候选，保留学习机会，必要时沿正常流程补充候选。骑兵技能的骑乘要求仍由战斗规则检查。
- 角色命令的槽位为当前队伍顺序的 1..PartyCount，内部才转换为零基索引；不能把槽位当作角色实例 ID。命令描述区分角色目标与 NPC 目标，`goto_npc` 的第一个参数是稳定 NPC 配置 ID，不经过槽位解析。未知命令、非整数、越界和空队伍均在修改前拒绝。
- HUD 的 `GM F8` 按钮或 F8 打开独立 `GM` Panel；窗口为 Popup、模态、暂停世界、可缓存，Esc/关闭按钮/F8 关闭。左侧仍提供槽位升级与技能 ID 授予；技能 ID 默认 201（驯服），打开面板不自动执行命令。
- 右侧“查找 NPC”按名称或 ID 子串过滤 [NpcTable](../Business/Narrative.md)，留空列出全部叙事 NPC；不把通用巡游居民的临时编号当作叙事身份。条目显示所属城镇、当前日程；当前区域中的目标另显示实际 q/r/层，其他城镇的实时占格在进入后读取。已招募显示队伍槽位，未生成出生城镇明确显示不可用，不创建替身。
- 点击条目走 `DemoBridge → GMSystem.Execute('goto_npc', npcId)`：在 map/area 阶段进入目标城镇，寻找 NPC 真实占格的道路相邻格作为领队落点，并为全部存活队员（含坐骑完整 footprint）规划互不重叠的位置。禁止中断战斗/事件/对话；全队倒地不可传送。探索记录保留，绕过普通入城探索事件，不修改任务事实、奖励或 NPC 日程；跨城后附近空间不足时保留进入的目标城镇并在结果中明确说明。
- 成功传送后停止路线并刷新视野，桥接的 `gmTeleport` 提示显示宿主清理旧区域渲染并按新快照重建，避免跨城套用旧布局或播放长距离移动动画；镜头切到近距离俯视并聚焦玩家和 NPC。关闭 GM 后按 E 使用正常距离校验交谈；不会自动接任务或做对话选择。
- `CharacterGrowthData.GrantSkill` 是直接授予状态接口，保证已学技能不重复、与候选集合互斥；保存沿用现有[角色存档](../Business/CharacterSave.md)。GM 本身不自动落盘，仍由“保存队伍”保存。
- 初次制作依次通过 Unity MCP 执行 `Tools/GM/create_gm_ui.cs` 与 `extend_npc_ui.cs`，在同一 GM Prefab 上保存 LuaReference 绑定；重复执行不重复创建控件。`run_checks.cs` 在独立 PreviewScene 运行 `gm_integration.lua`，覆盖原命令回归、NPC 搜索、同城/跨城传送、不可用状态及实际列表按钮/暂停释放，并输出 `Docs/Previews/GM.png`；不进入 Play。`python -B Tools/Tests/run_lua.py Tools/Tests/gm_npc_core.lua` 另查阶段限制、完整占地回溯、居民/敌人占格拒绝。

## 关键入口

- [GMSystem.lua](../../Lua/Game/GM/GMSystem.lua) / [系统注册](../../Lua/Game/Systems.lua) / [命令桥接](../../Lua/Game/Adventure/DemoBridge.lua)。
- [NpcCommands.lua](../../Lua/Game/GM/NpcCommands.lua)：搜索、目标解析与传送规划；[原生检查](../../Tools/Tests/gm_npc_core.lua)。
- [GMCtr.lua](../../Lua/UI/Panel/GMCtr.lua) / [GMPanel.prefab](../../Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab) / [制作脚本](../../Tools/GM/create_gm_ui.cs)。
- [NPC 控件与绑定制作](../../Tools/GM/extend_npc_ui.cs) / [GM 预览](../../Docs/Previews/GM.png)。
- [养成状态](../../Assets/GameFramework/Runtime/Data/CharacterGrowthData.cs) / [定向检查](../../Tools/Tests/gm_integration.lua) / [检查执行器](../../Tools/GM/run_checks.cs)。
