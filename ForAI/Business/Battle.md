# 六边形战斗

关键词：Battle、回合、行动点、技能、效果、属性、特质、AI、战斗事件。

## 文档目录

正文：状态与规则 / 配置与扩展 / 验证；关键入口：系统 / 数据 / 配置。

## 正文

- 来源：[战斗总览](https://my.feishu.cn/wiki/XvPvw2sk2ih7BTkAonGcjmR7nlg)、[技能](https://my.feishu.cn/wiki/Gyb1wnuCJisBbfkc7o1crZmmn4e)。文档未定义的数值与顺序是用户授权的 demo 规则。
- `BattleSystem` 依赖 Config，引用 `services.Adventure.Battle`。C# `BattleData/CombatActorData` 保存唯一可变状态；Lua 只持有配置、战场静态布局、规则与临时查询结果。队伍进入战斗时共享角色实例，生命与特质跨遭遇保留。
- 注册器在 OnInit 失败后也调用 OnShutdown；Battle/Adventure 的回收只释放已取得的资源并解除引用，不掩盖原始启动错误。缺少 `services.Adventure` 时须检查 C# 编译及 xLua 绑定生成，不能靠跳过 Battle 初始化继续运行。
- `Start(encounterId, livingParty, seed)` 使用独立随机流生成半径 3–7 的尖顶六边形小战场，保持地面连通、双方出生格畅通。障碍为静态阻挡；BFS 禁止穿越存活单位，尸体可通行。与大地图共用 HexGrid 坐标工具，但不复用其生成期道路通行规则。
- `BattleBoard.FromArea(area, q, r, radius)` 可从 [MapArea](MapArea.md) 取得同坐标的局部窗口，复用原格子的墙体与身份；当前 `BattleSystem:Start` 尚未接入此接口，不能把它当成已实现的原地遭遇战。
- 每轮按速度降序、实例 ID 升序决定次序，轮中跳过死亡角色。每个角色回合重置 AP、一次移动和一次主要行动额度；次要行动仅受 AP 限制。移动范围/消耗及角色 AP 来自模板；技能消耗、射程和目标来自配表。防御不叠加，持续至自己下回合开始；普通治疗不复活。
- `TryMove/TrySkill/EndTurn` 对正常不可操作输入返回 `false, reason`，不消费资源；配置/生命周期契约错误直接报错。技能完整求值校验后再扣 AP。`StepAI` 每次推进一名敌人，调用相同的命令入口，没有另一套数值或行动权限。
- `CombatUnitTable` 定义六个一级属性、按名称/值配对的二级属性、最大生命公式和技能列表；未训练的二级属性为 0。`CombatTraitTable` 加算属性修正，重复获得同一特质不叠加；生命上限更新保留已受伤害。敌我使用相同模板体系。
- `CombatSkillTable` 定义 main/secondary、AP、六边形距离和 enemy/ally/self 目标，顺序引用 `CombatEffectTable` 的 damage/heal/guard 效果。数值沿用现有受限 RPN 公式；这是技能效果基础框架，未实现新的通用脚本语言、持续 Buff、视线、命中率或反应攻击。扩展效果需同步效果类型、执行器与配置检查。
- `Changed` 发出 battle_started/turn_started/turn_ended/moved/damage/heal/guard/defeated/battle_ended 通知。通知不是可修改或取消结算的拦截器；监听方按自身生命周期退订。战斗日志保留最近 80 条。
- 存活敌人清零获胜，队伍清零失败，轮数耗尽为 draw；胜负状态只写一次。奖励由[远征流程](Adventure.md)消费，不在 BattleSystem 中发放。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/adventure_core.lua`；真实 C# 桥接、资源消费和结算使用 Unity 菜单 `Project Y/远征/验证战斗与事件`，在 Edit Mode 创建独立测试数据与 LuaEnv，不切场景或进入 Play。它不是全项目集成检查。
- 启动回滚改动运行 `python -B Tools/Tests/run_lua.py Tools/Tests/adventure_lifecycle.lua`，覆盖桥接缺失、配置失败、部分初始化和重复关闭，不触发 Unity 编译。

## 关键入口

- [BattleSystem.lua](../../Lua/Game/Battle/BattleSystem.lua)：回合、命令、技能效果、AI 与通知；[BattleBoard.lua](../../Lua/Game/Battle/BattleBoard.lua)：小战场与 BFS；[CombatStats.lua](../../Lua/Game/Battle/CombatStats.lua)：同源属性/公式。
- [BattleData.cs](../../Assets/GameFramework/Runtime/Data/BattleData.cs) / [CombatActorData.cs](../../Assets/GameFramework/Runtime/Data/CombatActorData.cs)：权威状态。
- [配置目录](../../Config/Tables/Adventure/)：Unit / Skill / Effect / Trait / Encounter 表；[数据检查](../../Tools/Tests/adventure_core.lua) / [桥接检查](../../Tools/Tests/adventure_integration.lua)。
