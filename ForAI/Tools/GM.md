# GM 调试系统

关键词：GM、GMSystem、调试命令、槽位、升级、获取技能、F8、NPC 搜索、查找 NPC、传送、定位、开全图、全图视野、秒杀、点选目标、投骰子、骰子组合。

## 文档目录

正文：入口与职责 / 命令 / 验证；关键入口：系统 / UI / 检查。

## 正文

- `GMSystem` 是独立 LuaSystem，注册名 `GM`，依赖 Config/Growth/Narrative；负责命令分发、参数校验和队伍槽位解析。权威数据仍归现有 C# 状态，不在 GM 系统内复制角色或 NPC 位置。
- `Execute('level_up', slot)` 将指定队员提升一级，补齐该级所需经验并调用正常 `GrowthSystem:AddExperience`；属性点、天赋点、研习机会与经历均遵循原配置，不加满血、不重置已有进度。配置等级上限时返回原因，不额外发奖。
- `Execute('grant_skill', slot, skillId)` 按 CombatSkillTable ID 永久授予技能，绕过职业、前置与属性门槛，不消费主动学习机会；重复技能或无效 ID 返回原因，不改变当前职业。骑乘、触媒与技能阶段要求仍由使用规则检查。
- `Execute('reveal_world')` / F8 面板“开全图”调用 `Adventure.fog:RevealAll()`，不依赖队员槽位或技能输入；地图未创建时拒绝。大地图持续全亮，远处敌方队伍沿正常快照可见，移动、进出小地图后继续生效；不改变局部地图视野。模式仅在当前世界会话有效，重新开局或读档恢复正常视野，全图已探索记录沿正常远征存档保留，命令不自动保存。重复点击不重复写探索状态。
- F8 面板“秒杀”发送宿主命令 `gm_begin_kill`，关闭面板后在当前战斗或小地图点选模型/占格；Esc、右键、重新打开 GM、切换阶段或执行其他业务命令取消，成功秒杀一次自动退出。三维拾取复用 `PickAreaActor`，旧二维战斗使用棋盘地格。空白或不允许的目标保持点选以便重选，当前动作播放完毕后才接受场景点击。
- `Execute('kill_target', actorId)` 的参数是当前参战者或当前区域敌群中的角色实例 ID，不能当作槽位或 NPC 配置 ID。只接受敌对单位和中立野生动物，拒绝队友、盟友、已驯服动物、场景外目标、已倒地目标及对话/非战斗非探索阶段。只扣所选单位全部生命，不消耗玩家 AP；死亡通知、效果清理和职业倒地钩子沿既有接口处理。战斗中检查胜负、交接被秒杀的行动者并正常结算；探索中生成该角色掉落，沿原标记防止重复奖励。不修改叙事 NPC 或可破坏物体。
- F8 →“投骰子”打开 GM 内的组合页，逐种增减 D4/D6/D8/D10/D12/D20/D100，允许重复，合计 1～6 颗，默认 1D6。D10 为 0～9；D100 是百分比十位骰，按 00、10…90 的面值计入总和。可清空和返回，缓存重开保留组合。
- `Execute('roll_dice', {D6=2,D20=1})` 验证整组后使用独立 GM 随机序列，返回 `true, request`；不支持的骰型、非整数、负数及空/超限组合在抽数前拒绝。面板直接将请求交给现有 `DiceRoll` Overlay，复用实体动画、快速揭晓与继续按钮；只显示逐颗点数和合计，不附加检定成败。演出期间暂时隐藏 GM 内容、保留暂停租约，继续后恢复组合页；不改角色、奖励或玩法随机序列，也不自动保存。请求与演出契约见[实体骰子](../Business/Dice.md)。
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
- [开全图按钮与语言绑定制作](../../Tools/GM/extend_world_ui.cs)：经 Unity MCP 保存到现有 Prefab；[定向检查](../../Tools/Tests/gm_world_fog_integration.lua) 覆盖远处敌人快照、移动后全亮、重复执行、重绑/新世界复位及实际按钮，使用 `run_checks.cs` 执行时将 Lua 检查路径替换为该文件。
- [秒杀规则](../../Lua/Game/GM/KillCommands.lua) / [场景点选](../../Assets/GameFramework/Samples/Adventure/AdventureGM.cs) / [按钮制作](../../Tools/GM/extend_kill_ui.cs)。[秒杀集成检查](../../Tools/Tests/gm_kill_integration.lua) 同样替换 `run_checks.cs` 的 Lua 路径执行；[原生输入状态检查](../../Tools/GM/check_kill_input.cs) 经 Unity MCP 执行，均使用独立 Edit Mode PreviewScene，不替代 Play 鼠标实点验收。
- [投骰子规则](../../Lua/Game/GM/DiceCommands.lua) / [组合页制作与语言绑定](../../Tools/GM/extend_dice_ui.cs)；`python -B Tools/Tests/run_lua.py Tools/Tests/gm_dice_core.lua` 检查组合边界、面值与随机隔离。[真实动画及按钮检查](../../Tools/Tests/gm_dice_integration.lua) 替换 `run_checks.cs` 的 Lua 路径执行，覆盖混合/重复骰型、快速揭晓、正常检定回归、缓存与暂停清理；预览：[组合页](../../Docs/Previews/GM-Dice.png)、[投掷](../../Docs/Previews/GM-Dice-Roll.png)、[结果](../../Docs/Previews/GM-Dice-Result.png)。
- [养成状态](../../Assets/GameFramework/Runtime/Data/CharacterGrowthData.cs) / [定向检查](../../Tools/Tests/gm_integration.lua) / [检查执行器](../../Tools/GM/run_checks.cs)。
