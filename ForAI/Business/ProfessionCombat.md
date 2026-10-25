# 职业战斗与兼职联动

关键词：炼金师、吟游诗人、神官、咒术师、决斗家、破绽、咒印、余音、附刃、安可、转祸、绊索、护卫换位、承誓。

## 文档目录

正文：配置入口 / 消费和命中 / 移动和期限 / 验证；关键入口：规则 / 状态 / 测试。

## 正文

- 职业战斗使用 `ProfessionCombatTable` 的技能身份、机制、材料、技能族、装备条件与变体父技能，`ProfessionStatusTable` 把实际 Buff 连接到一次性状态语义。职业名不参与使用许可；已学父技能自动开放对应水／毒涂层、燃烧／中毒爆破、转祸状态与火／水附刃变体。学习和天赋入口见 [养成](Progression.md)，动物指令见 [动物](Animals.md)。
- `ProfessionCombat` 仅持规则和查询临时结果；每轮／每场被动计数在角色的 C# `ProfessionMarks`，机关在 C# `BattleData.ProfessionTraps`。计数和机关随本次战斗清理；可显示、计时和转移的状态仍使用 [GameEffect](GameEffects.md) 的 C# 实例，不另建 Lua 状态镜像。
- [具名传奇装备](LegendaryEquipment.md)复用同一命中快照、条件附伤预算、承誓和角色计数；共债不能再生成一份独立的 50% 附伤预算，传奇资源不改变原职业材料或行动额度。
- `Battle:Skill` 返回实际装备与状态修正后的复制技能。`Budget/CanUse/CanUseAt` 完整校验动作、材料、免疫和落点后，`Commit` 扣对应材料并消费减费状态，之后提交 AP／冷却；合法施放未命中仍付费。安可最低 1 AP，不能恢复主要行动额度，同一接收者每轮仅受益一次；减费不作用于道具。
- 每发命中或角色拦截由 `ProjectileCombat.ApplyActor` 建立实际接收者的伤前快照。破绽仅由直接武器命中消费，咒印仅由直接伤害消费；致死清状态仍保留这一发的原始收益。固定条件附伤扣防御／护卫，新条件增益总和上限为基础直接伤害的 50%；破绽和咒印不会复制到同次连射的后续发。
- 留手只免除本人对命中前已有破绽目标的本次护甲磨损，自身武器仍磨损。附刃替换当前近战命中的伤害类型并附加选中状态，不新增第二次基础伤害；水／毒涂层和火／水附刃各自互斥、各只使用一次。状态免疫继续按 `immunityTags` 检查，伤害类型免疫使用 `damage_<type>` 标签。
- 接句要求敌人在本发新效果之前已有减益，每轮一次且借机反应不触发；残液回收只在本人爆破消费敌方状态后每场一次；余恩只计本人的技能实际清除自身减益，自然到期、移除正面状态与队友净化不计；苦难研习在回合开始检查中毒／流血／虚弱，智力收益只维持该回合。
- 转祸的毒／流血／虚弱变体在提交前检查已有状态和已知免疫。实际命中后先成功转移再移除来源，C# 保留原来源、组件快照、剩余时长、周期进度，合并目标层数不超过上限。新状态在角色现有 Effects 存档中往返。
- 起拍和准备涂层／审势／描印在接收者首个正式回合结束失效。净身祷文的护卫在正式 `BeginTurn` 清零后恢复至至少 3，首个正式回合末移除；守命护符仅减免下一次直接伤害，周期伤害不消费。承誓仅重定向一次单目标直接命中给仍相邻且存活的护卫者，重新以其防御／坐骑结算，不递归转交；护卫者下回合开始撤销。
- 牵步刺和退身射击使用 `NeedsSkillLanding/SkillLandingCells/TrySkillWithLanding` 两阶段目标／落点入口，落点必须使完整占位更远离目标，技能位移不重开普通移动。退步与护卫换位属于技能内位移，**不触发借机攻击**；驯兽师驱赶口令另有明确的动物借机风险。换位校验双方完整占位。推拉只移动不大于施术者占地的目标，检查真实邻接与落点，无法推动时保留原攻击伤害。
- 绊索消耗真实麻绳物品 82，放置公开的一次性机关。普通移动在路径上首个接触机关处截断，技能推拉／换位／动物位移调用同一 `OnMoved`；触发中止剩余移动并施加迟缓，敌我均可触发。机关公开只读投影供二维、三维战场显示。拆料的实际投入与退款边界见 [营造](Construction.md)。

## 关键入口

- [ProfessionCombat.lua](../../Lua/Game/Battle/ProfessionCombat.lua)：配置查询、事务、一次命中快照、被动、位移和机关。
- [ProfessionCombatState.cs](../../Assets/GameFramework/Runtime/Data/ProfessionCombatState.cs)：权威计数、机关、精确状态转移与技能位移桥；不依赖修改已生成的角色包装。
- [ProfessionCombatTable](../../Config/Tables/Progression/ProfessionCombatTable.json) / [ProfessionStatusTable](../../Config/Tables/Progression/ProfessionStatusTable.json)：源配置。
- [profession_combat_core.lua](../../Tools/Tests/profession_combat_core.lua)：真实配置与 Lua 程序的定向检查，隔离 C# 边界；命令 `python -B Tools/Tests/run_lua.py Tools/Tests/profession_combat_core.lua`。
- [profession_combat_state.ps1](../../Tools/Tests/profession_combat_state.ps1)：对已编译程序集检查计数、位移、状态转移存档往返和机关生命周期；参数 `-AssemblyPath`，脚本本身不编译、不启动 Editor／Play。
