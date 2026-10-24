# 六边形战斗

关键词：Battle、回合、部署、准备技能、消耗品、行动点、借机攻击、贴身移动、opportunityAttack、高地、命中、射程、直射、抛射、弹道、trajectory、追踪、散射多选、拦截、友伤、ProjectileCombat、缴械、紧握武器、BattleLog、实际掷值。

## 文档目录

正文：状态与规则 / 配置与扩展 / 验证；关键入口：系统 / 数据 / 配置。

## 正文

- 六职业共享状态、每轮被动、技能材料／减费、二阶段位移、承誓与绊索的契约见 [职业战斗与兼职联动](ProfessionCombat.md)。`ProfessionCombatTable`、`ProfessionBeastTable`、`ProfessionExplorationTable` 中有独立执行器的技能允许空 `effectIds`；不可把空效果误当成已实现技能。

- 直接攻击造成的部位创伤、永久致残、移动/属性惩罚与治疗见[身体健康与创伤](BodyInjuries.md)；移动预算统一通过 `CombatStats.MoveRange` 查询，避免绕开腿伤。

- `CombatUnitTable.traitIds` 声明创建时固有特质；`CombatTraitTable.onHitEffectIds` 为伤害攻击增加命中效果，敌我共享，防御与治疗不触发。配置、初始化及专属传奇机制见[传奇生物与具名人物](Legends.md)。

- `CombatSkillTable.minRange`（默认 0）约束双方完整占地的最近距离；`fixedRange`（默认 false）禁止装备与高地延长射程。角色、自动追加目标及容器共用下限判定，失败不消耗 AP/随机流；具有近身禁区的 AI 通过 `ApproachCells` 寻找可攻击落点，可后退到有效距离。长枪配置见[装备](Equipment.md)，定向检查为 [spear_range.lua](../../Tools/Tests/spear_range.lua)。
- 原地 3D 战斗的每次实际攻击触发短特写：参与者来自已结算的 `VisualEffects` hit/miss 记录，包含多目标和实际拦截者，不揭露未显示单位。慢动作、聚焦镜头、抬升与共享轮廓灰罩的生命周期见[主 HUD](MainHud.md)。二维旧棋盘不播放此 3D 特写。

- 技能的方块粒子、实际拦截/逐发命中与失败表现通过只读结算事件接入，配置扩展和清理见[技能与物品方块特效](VisualEffects.md)。

- [森林动物与骑乘](Animals.md)扩展中立动物、驯服、完整多格占位、坐骑受伤及骑兵地格技能；`CanUseSkillAt/TrySkillAt/SkillCells` 处理地格目标，角色目标仍使用 `CanUseSkill/TrySkill`。
- [巧匠营造](Construction.md)复用地格技能入口；动态工事/坑沟投影影响移动代价、通行和射线，单格高台影响站位与远程射程。施工、501 缴械、503 拾取武器走独立事务，允许空 `effectIds`；职业独立执行器的例外见上文。静态棋盘与普通格移动规则保持原契约。
- [容器攻击](Loot.md)通过 `skill_container` 接入普通攻击/适用伤害技能，共用预算和公式；容器不加入角色列表，原角色目标入口仍用 `TrySkill`。技能栏可用性同时检查容器目标，范围攻击在原目标限额内波及容器。

- 来源：[战斗总览](https://my.feishu.cn/wiki/XvPvw2sk2ih7BTkAonGcjmR7nlg)、[技能](https://my.feishu.cn/wiki/Gyb1wnuCJisBbfkc7o1crZmmn4e)。文档未定义的数值与顺序是用户授权的 demo 规则。
- `BattleSystem` 依赖 Config，引用 `services.Adventure.Battle`。C# `BattleData/CombatActorData` 保存唯一可变状态；Lua 只持有配置、战场静态布局、规则与临时查询结果。队伍进入战斗时共享角色实例，生命与特质跨遭遇保留。
- 注册器在 OnInit 失败后也调用 OnShutdown；Battle/Adventure 的回收只释放已取得的资源并解除引用，不掩盖原始启动错误。缺少 `services.Adventure` 时须检查 C# 编译及 xLua 绑定生成，不能靠跳过 Battle 初始化继续运行。
- `Start(encounterId, livingParty, seed)` 使用独立随机流生成半径 3–7 的尖顶六边形小战场，保持地面连通、双方出生格畅通。障碍为静态阻挡；BFS 禁止穿越存活单位，尸体可通行。与大地图共用 HexGrid 坐标工具，但不复用其生成期道路通行规则。
- `BattleBoard.FromArea(area, q, r, radius, layer)` 从 [MapArea](MapArea.md) 裁取共享地格身份与导航边的窗口。`BattleSystem:StartArea` 已接入单层地牢与森林，保留双方真实位置及角色实例；`Start` 继续服务旧事件的独立棋盘。多层战斗明确拒绝，不能把支持多层裁窗当作已实现的多层战斗。
- 多方战场在 `board.sideRelations[a][b]` 声明 `hostile/allied/neutral`；未声明对按中立、同侧按盟友，关系不传递。`IsHostile/IsAllied` 接受角色或 side 数字，攻击、治疗、范围目标、弹道友伤提示及 AI 共用查询；未提供关系表时兼容原双边敌我规则，side 0 动物始终非敌对。`StartArea` 在有关系表时保留参战者的 side 2–64，最多 16 名非玩家角色；side 1 始终只属于最多 4 名玩家队员，盟军 AI 不参与玩家部署。`PresentationTeam` 只做显示投影（玩家1、主敌2、独立方3、盟军4、动物0），不可回写 `CombatActorData.Team`。
- `HeightAdvantageTable` 按双方最终站立面计算高打低：默认每 1 米提升命中 5 个百分点，最多 15；敌方目标的远程技能（range>1）另获每级 1 格、最多 3 格射程。近战也获得命中收益，平地/仰攻不受罚，不增加伤害；不同 layer 不计算。天然台地、工事高台与容器攻击共用规则，已有营造射程与高差射程取较大值，避免重复相加。多目标逐目标计算，命中上限 100%；HUD 区分基础命中/射程与按目标高差结算的收益。
- 原地战场以首名非玩家存活者为中心，覆盖所有参战角色并追加配置边距；普通遭遇只加入触发敌群，势力冲突加入现场各参战群并设置关系表。未参战敌群保持占格、本场不行动。玩家移动限定已发现地格，移动后按存活队员更新视野；技能遮挡由 `trajectory` 决定，探索视野仍使用完整地形视线。
- `CombatSkillTable.trajectory` 为 `sight`（默认，仍按完整视线拒绝遮挡）、`direct`（忽略攻击者相邻一格，后续路径可能拦截）、`lobbed`（只由攻击者相邻一格内的遮挡拦截）。只查中间格，起点/目标自身不拦截自己。枪械及奥术飞矢、火球、引潮/炉火与其终结术使用 direct；弓箭使用 lobbed；治疗、非弹体状态和其他技能保留各自配置，不按武器种类全局改写。
- `SkillTrajectory.Trace` 返回几何可达性与从近到远排列、按物理身份去重的遮挡描述。地形、陈设、工事、容器、工具障碍及存活角色完整占位均可参与；角色包含友军、敌军、动物与 NPC，倒地角色及已附着坐骑不另占位。有中途遮挡仍可开火；射程、目标合法性、同层和起终点楼板等几何条件仍须成立。`CanReach`、角色/容器目标、散射、AI 与预览使用同一查询，探索 `CanSee` 不改变。
- `ProjectileCombat` 统一每发结算：沿途逐个按 [ProjectileCoverTable](../../Config/Tables/Adventure/ProjectileCoverTable.json) 判拦截，当前角色35%、物体50%；第一个成功拦截者接收整发，原目标不再受击。全数通过后才判原目标命中，因此目标实际命中率为本次命中率（含装备/高地修正）乘各段通过概率。角色拦截执行真实伤害与效果，可误伤友军；可破坏容器/工事按结构规则受伤，无生命地形、不可破坏或锁定容器只吸收，不绕过其破坏限制。拦截是已施放的一发，正常消耗 AP、弹药、CD 与使用磨损；命中源收益及死亡边界见 [GameEffect](GameEffects.md)。
- [追踪状态](GameEffects.md)仅为匹配的远程 direct/lobbed 技能启用 `guided`，绕过中途拦截而不保证命中、不扩展射程；非弹体 sight 继续检查视线。独立的 `manualTargets` 使玩家从射程内选择1至 `maxTargets` 个不同合法敌人，取消主目标周边 `splashRadius` 限制；`TrySkillTargets` 在扣费前校验整组，重复/过量/失效目标整组拒绝，确认后只执行所选目标，不自动补满或波及容器。敌方 AI 沿用自动选取合法目标；操作与风险提示见 [BattleHUD](BattleHUD.md)。
- 地图 `CanTrace(origin,target,query,includeCell)` 提供中间格筛选与真实楼层几何，Trace 复用它枚举弹道；`CanSee` 不传筛选。追踪仍保留起终点楼板检查，不因此开放多层战斗；视线与弹道查询均不掷随机数或消费资源。
- `BattleData.Phase` 为 idle → deployment → combat → ended；`Start/StartArea` 先进入独立部署回合，`Round=0`。仅己方按速度/ID行动，每人获得模板AP、一份可分段移动预算及主要行动额度；敌人保留已布置位置且不行动。移动仍遵守地形、完整占格、已发现区域，另外受 `BattlePreparationTable.deploymentRadius` 限制（默认距本人入战格2格）。全员结束后按当前速度重排正式第一轮并重置预算，部署不推进持续效果或区域世界回合。
- `CombatSkillTable.skillKind` 区分 active/preparation/item，`contexts` 分别控制 life/battle/preparation 的使用权限；准备技能来自职业学习，不在正式战斗施放。401–404 提供战意/警戒/奥术凝聚/临时加固，效果按 turn_end 计时，部署结束不消耗寿命，保留至自身首个正式回合结束；奥术凝聚需要有效触媒。
- `ConsumableTable` 将共享背包物品映射到 self 目标的 item 技能。`CanUseItem/TryItem` 先校验阶段、AP、库存、治疗收益及全部效果，再消费真实堆叠和AP；消耗品不授予永久技能。急救包91恢复12生命，备战药剂92提供2防御并持续至自己的两个正式回合结束；均可在部署/正式战斗中使用，当前不支持对他人使用。
- 每轮按速度降序、实例 ID 升序决定次序，轮中跳过死亡角色。每个角色回合重置 AP、移动距离预算和一次主要行动额度；次要行动仅受 AP 限制。可不移动直接行动；成功的 `SpendAction(main/secondary)`（含准备技、道具和容器攻击）将未用移动标记为已跳过，不额外扣移动 AP、不改坐标或 `MovementSequence`。失败或仅选择技能不消耗移动；`BeginTurn/BeginDeploymentTurn` 重置。常规移动可在首个成功行动前分段提交；第一次移动扣模板moveCost，之后不重复扣移动AP，实际最短路代价累计消耗同一moveRange（含工事/坑沟附加距离）。C# `CombatActorData` 保存已用距离，`BattleMovement` 只提供反射桥，Lua不保存另一份计数；额度耗尽或技能实际提交后关闭移动，回合/部署初始化时重置。技能自带位移仍遵守该技能契约。移动范围/消耗及角色 AP 来自模板；技能消耗、射程和目标来自配表。防御不叠加，持续至自己下回合开始；普通治疗不复活。
- 正式战斗中，`TryMove` 先验证完整移动是否合法，再让起点处每名存活、可行动且能近战的相邻敌人各借机攻击一次，按角色 ID 升序结算；敌我共用 `IsHostile`，相邻按双方完整占地最近距离 1 格判断。绕行及分段再次提交同样触发，不限每轮次数；部署、无效移动、从未贴敌的起点走近敌人和技能自带位移不触发。本规则只检查移动起点，不沿路径逐格检测。
- `CombatSkillTable.opportunityAttack` 显式标记普通近战动作；当前包含斩击、单手／大剑／巨刃、副手斩击、扑咬、徒手。每个反应者优先主手、其次副手，同类按技能 ID 选择一招；远程武器、近身盲区长枪、破损武器不提供对应武器反应，徒手沿原可用技能规则。借机不消费或检查 AP、主要行动、移动额度、技能冷却，仍沿用命中、伤害、特质／符文效果、武器磨损、动画记录、VFX 与倒地通知；仅攻击移动者，不扩散或连击。`OpportunityAttackers(actor)` 是不消费随机数的只读候选查询。
- 每击前重查反应者资格；移动者倒地、眩晕或战斗结束即停止剩余攻击与移动。已发生借机结算的移动中断返回 `true, reason`，让上层处理真实伤亡和胜负；不扣移动 AP 或距离、不改位置。倒地正常交接回合，眩晕结束当前行动；存活且可行动时，按坐骑等最新状态重查可达性后再提交移动。`StepAI` 在两处移动后检查回合归属，不能继续操作新角色。
- `TryMove/TrySkill/EndTurn` 对正常不可操作输入返回 `false, reason`，不消费资源；配置/生命周期契约错误直接报错。技能完整求值校验后再扣 AP。`StepAI` 每次推进一名非玩家角色（含盟军与第三方），调用相同命令入口；只选择与自身敌对的目标，按距离、生命和 ID 排序，没有敌对目标时结束回合。
- 场景可在 `board.aiProfiles[actorId]` 提供只读 `{selfPreservation=true, retreatHealthRatio=比例}`；仅玩家盟军在生命比例不高于阈值时启用[自保策略](../../Lua/Game/Battle/AllySelfPreservation.lua)。优先向存活盟友靠近，完整占地的最近敌人距离不得缩短，存在借机攻击者时原地防御；移动保留防御所需 AP，防御使用角色已拥有的 `guard` 效果技能并结束回合。健康、未配置或敌对角色沿用原 AI，profile 不改变侧关系或控制权，也不保存第二份可变战斗状态。
- [缴械与耐久](Equipment.md)接入同一 `TrySkill`：缴械501为近身主行动2 AP、30%基础成功率、CD2，额外加上 `2×（自身速度−目标速度）` 个百分点，速度取 `CombatStats:Get` 的当前最终属性。`DisarmChance` 在有效装备技能命中上叠加速度差与高地收益，最终限制在0%～100%；`ShotPreview` 与实际判定共用，施放前求值，不受本次使用磨损影响。同速、平地、无装备命中修正时0/29成功、30/99失败。成功后真实武器落地，拾取为次行动2 AP。目标具有[紧握武器免疫](Progression.md)时，`CanUseSkill`拒绝并返回原因；实际尝试由`TrySkill`记录免疫说明，不消耗AP、CD、磨损或随机流，预览查询不刷日志。
- 精确刺击和火焰/重击的装备磨损通过效果配置区分，命中且实际扣血才损伤装备，持续伤害也走 `GameEffects.Execute`。`Battle.Changed` 的伤害/治疗事件提供真实 `hpBefore/hpAfter/periodic` 顶层字段，周期治疗标记为 true，不能用请求 amount 倒推治疗前血量。
- `CombatUnitTable` 定义一级/二级属性、最大生命公式和固有技能；未训练二级属性为 0。`CombatStats` 还叠加特质、[养成](Progression.md)投入/被动与装备；重复特质不叠加，生命上限变化保留已受伤害。`EquipmentRules:SkillIds` 合并角色已研习主动技能，敌我共用查询，敌人默认无养成投入。
- `CombatSkillTable` 定义 main/secondary、AP、距离、目标、命中、CD、耗弹与动作模板，组合 `CombatEffectTable` 的即时和[持续 GameEffect](GameEffects.md)。`SkillIds/Skill/SkillBudget` 是装备后技能查询入口；`ActionBudget` 统一阶段、AP、触媒及弹药门槛，主动技能与物品均不能绕过；散射、冷却、枪械规则见[装备 Demo](Equipment.md)。数值沿用受限 RPN 公式；反应入口当前仅支持上述移动前借机攻击，没有通用脚本语言或通用反应触发器。
- `Changed` 发出 battle_started/turn_started/turn_ended/moved/opportunity_attack/intercepted/damage/heal/guard/check/immune/effect_blocked/defeated/battle_ended 等通知。通知不是可修改或取消结算的拦截器；监听方按自身生命周期退订。战斗日志保留最近80条。
- `BattleLog.Format`只格式化已结算事实：按角色、动作、目标、伤害/治疗值区分颜色字号，生命显示实际`hpAfter/maxHP`及原血量，伤害可显示本次防御/护卫；坐骑承伤使用实际承伤者的生命快照。命中、拦截、缴械和状态触发日志显示最终概率阈值、实际掷值与结果，未掷骰的确定分支不伪造掷值。日志不解析旧文案推测数值，也不为展示额外消耗随机数；附加状态失败原因来自[GameEffect report](GameEffects.md)。
- `damage` 通知的 `attackHit` 标记区分即时技能伤害与持续伤害；`impact` 携带原始 `shot` 序号、可选 `critical` 标记及实际 `defeated` 结果（含坐骑死亡）。`CombatSkillTable.criticalChance/criticalMultiplier`定义命中后的逐发暴击概率与倍率（默认0%/2倍）；每发、每个实际受击角色只判定一次，包括角色拦截，附加伤害共享该次暴击。即时对他人伤害在实时公式/防御计算后乘倍率并向下取整，治疗、护卫、状态、持续伤害及容器/建筑不放大。未命中不判定暴击/附加效果；0%及100%暴击不额外消耗随机数。附加效果仍逐发独立判断，不修改复用的技能/效果计划；连射顺序不变。定向验证为[枪械核心](../../Tools/Tests/firearms_core.lua)与[原生库存/战斗](../../Tools/Tests/firearms_integration.lua)。表现层检查 `amount>0`，震屏、连射间隔与血条契约见 [MainHud](MainHud.md)。
- 战斗 UI 复用 Panel/Widget；技能图标由 `CombatSkillTable.iconId` 引用配置。显示投影、图标同步、操作与验证见[战斗 HUD](BattleHUD.md)。
- 局部场景的[动作表现](PawnAnimation.md)读取 C# 角色有限动作记录，不改变结算；Demo 等待移动/动画结束再推进自动 AI。技能 actionTemplate 也覆盖基础技能和养成技能，敌人共用。MapArea 快照单独给出倒地敌人以播放死亡，不混入存活占格或头顶 HUD。
- 对玩家敌对的所有侧存活单位清零获胜，玩家队伍清零失败（存活盟军不能代替玩家），中立与盟军无需击杀；轮数耗尽为 draw，胜负状态只写一次。奖励由[远征流程](Adventure.md)消费，不在 BattleSystem 中发放。
- [尸体掉落](Loot.md)与[叙事击杀](Narrative.md)分别消费真实死亡：掉落不按友敌过滤非玩家尸体；任务击杀要求玩家来源及实际敌对关系，不能用显示颜色推断奖励归属。
- 多方关系最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/battle_sides.lua`，覆盖非传递关系、控制权、攻疗目标、独立 AI、胜负、超过四人的原地部署及跨侧友伤提示；纯 Lua 检查不替代 C# 桥接与 Play 视觉验收。
- 盟军自保定向检查：`python -B Tools/Tests/run_lua.py Tools/Tests/ally_self_preservation.lua`，覆盖安全靠拢、借机威胁、防御 AP、死亡盟友、原策略与控制权、移动后的回合交接；使用真实 Lua 战斗/技能规则及隔离角色状态，不替代 Play 表现验收。
- 部署与道具定向检查：`python -B Tools/Tests/run_lua.py Tools/Tests/battle_preparation_core.lua`；真实 C# 状态使用 [battle_preparation_integration.lua](../../Tools/Tests/battle_preparation_integration.lua) 在独立 Edit Mode LuaEnv 中执行，核对库存消费、预算、计时、效果和清理，不操作玩家存档。2026-10-16 新增并通过真实 C# 的原地行动／副行动后禁移、失败保留移动、回合恢复，以及无额外移动 AP／动画的检查。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/adventure_core.lua`；真实 C# 桥接、资源消费和结算使用 Unity 菜单 `Project Y/远征/验证战斗与事件`，在 Edit Mode 创建独立测试数据与 LuaEnv，不切场景或进入 Play。它不是全项目集成检查。
- 启动回滚改动运行 `python -B Tools/Tests/run_lua.py Tools/Tests/adventure_lifecycle.lua`，覆盖桥接缺失、配置失败、部分初始化和重复关闭，不触发 Unity 编译。
- 原地战斗最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/area_battle_core.lua`；真实 C#、入战位置、命令战斗、结算和敌群持久性用 Edit Mode 菜单 `Project Y/远征/验证地牢原地战斗`，不进入 Play。
- 弹道最小检查：[projectile_trace_core.lua](../../Tools/Tests/projectile_trace_core.lua)覆盖几何、身份去重、占位和楼板；[skill_trajectory_core.lua](../../Tools/Tests/skill_trajectory_core.lua)覆盖实际拦截/友伤、消耗、AI 与探索容器；[projectile_interception_core.lua](../../Tools/Tests/projectile_interception_core.lua)覆盖35/50逐个判定、锁定/无耐久吸收、连射摧毁遮挡后重查及大体型射线起点，均通过 `python -B Tools/Tests/run_lua.py <文件>` 独立执行。真实 C# 状态与手选整组事务见 [tracking_projectiles_integration.lua](../../Tools/Tests/tracking_projectiles_integration.lua)，仅在现有 Edit Mode 宿主的隔离 LuaEnv 运行；这些定向检查已通过，完整 Play 尚未验收。
- 高地最小检查：[battlefield_elevation_core.lua](../../Tools/Tests/battlefield_elevation_core.lua)覆盖 12 个真实随机战场的二/三级台地、所有出生位置到全部可行走格的实际 `BattleBoard.Search`、最高峰路径、相邻一级高差，以及真实角色/容器的射程与命中结算；本轮纯 Lua 检查通过，不等于已完成 Play 视觉验收。
- 概率与日志定向检查：[disarm_immunity.lua](../../Tools/Tests/disarm_immunity.lua)覆盖免疫零消费、30%边界、双方最终速度差、0%/100%限制、高地收益、预览与实际判定一致及其他技能不受速度差影响；[battle_log_core.lua](../../Tools/Tests/battle_log_core.lua)覆盖角色/动作/实际HP分数、概率掷值及火花触发/受阻/致死说明。均通过 `python -B Tools/Tests/run_lua.py <文件>` 独立执行，日志仅观察原判定。

- 非人形两格／四格单位通过 `CombatBodyTable` 与 `BodyFootprints` 接入通用占位，独立于驯服/骑乘身份；当前来源与验证见[大地图队伍](WorldParties.md)。

## 关键入口

- [BattleSystem.lua](../../Lua/Game/Battle/BattleSystem.lua)：回合、命令、技能效果、AI 与通知；[BattleBoard.lua](../../Lua/Game/Battle/BattleBoard.lua)：小战场与 BFS；[CombatStats.lua](../../Lua/Game/Battle/CombatStats.lua)：同源属性/公式。
- [OpportunityAttacks.lua](../../Lua/Game/Battle/OpportunityAttacks.lua)：只读候选、逐次近战反应及共享效果结算；[opportunity_attacks.lua](../../Tools/Tests/opportunity_attacks.lua) 通过 `python -B Tools/Tests/run_lua.py Tools/Tests/opportunity_attacks.lua` 做离线定向检查，不替代真实 C# 桥接与 Play 表现验收。
- [SkillTrajectory.lua](../../Lua/Game/Battle/SkillTrajectory.lua)：只读 Trace；[ProjectileCombat.lua](../../Lua/Game/Battle/ProjectileCombat.lua)：共享概率、拦截与实际命中；[ContainerCombat.lua](../../Lua/Game/Loot/ContainerCombat.lua)：容器目标/拦截结算。
- [BattleLog.lua](../../Lua/Game/Battle/BattleLog.lua)：结构化结算信息的富文本格式化；`BattleSystem:ChanceLog`接收已产生的阈值和掷值，不负责判定。
- [HeightAdvantage.lua](../../Lua/Game/Battle/HeightAdvantage.lua) / [高地规则表](../../Config/Tables/Adventure/HeightAdvantageTable.json)：只读高度收益；地形生成见[旅行](WorldTravel.md)。
- [部署规则](../../Config/Tables/Adventure/BattlePreparationTable.json) / [消耗品映射](../../Config/Tables/Equipment/ConsumableTable.json) / [库存消费](../../Assets/GameFramework/Runtime/Data/EquipmentConsumables.cs)：配置预算边界与堆叠事务。
- [BattleData.cs](../../Assets/GameFramework/Runtime/Data/BattleData.cs) / [CombatActorData.cs](../../Assets/GameFramework/Runtime/Data/CombatActorData.cs)：权威状态。
- [配置目录](../../Config/Tables/Adventure/)：Unit / Skill / Effect / Trait / Encounter 表；[数据检查](../../Tools/Tests/adventure_core.lua) / [桥接检查](../../Tools/Tests/adventure_integration.lua)。
- [CombatSnapshot.lua](../../Lua/Game/Battle/CombatSnapshot.lua)：探索/战斗共用角色显示契约；[原地战斗算法检查](../../Tools/Tests/area_battle_core.lua) / [原地战斗桥接检查](../../Tools/Tests/area_battle_integration.lua)。

- [分段移动权威桥接](../../Assets/GameFramework/Runtime/Data/BattleMovement.cs)：`Reachable`同时返回加权距离供`TryMove`提交，AI使用剩余额度，部署继续限制在原始入战格半径内。`battle_segmented_movement.lua`覆盖定向路径规则；`inventory_stacks_data.ps1`同时检查真实C#距离/AP/行动关闭与新回合重置。
