# 死门与永久死亡
关键词：死门、死亡之门、濒死、0血行动、致死攻击、永久死亡、D20、死亡检定、衰弱、DeathDoor、ActorLife。

## 文档目录
正文：生命状态 / 伤害与概率 / 惩罚与恢复 / 演出与保存 / 验证；关键入口：数据 / 规则 / UI / 检查。

## 正文

- 仅正式加入玩家小队的角色启用死门；普通敌人、盟军NPC、宠物及坐骑沿用原生命规则。`CombatActorData.HP` 仍是六部位当前HP的真实总和，不用1血代理0血。`DeathDoorState` 持有是否启用、死门、当场保护已用、永久死亡、幸存次数和Revision；`ActorLife.Alive` 是战斗、探索、占格、技能、回合与投影共用的存活判断。
- 每场首次从正HP承受致死伤害，HP归零并进入死门，不投骰、不发出 defeated、不清除死亡型状态，也不触发击杀奖励。死门角色仍能行动、占格、作为攻击/治疗目标，并计入存活与胜负判断。已在死门中开始下一场战斗者仍需检定，不能重新获得一次无条件保护。
- 已在0HP时再次承受正的结算伤害，或本场治疗后再次归零，进行一次D20检定。伤害指护甲/减伤后、生命截断前的数值；未命中、全额抵挡和0伤害不检定。连击及持续伤害按各次真实伤害结算。一次通过可能接着遇到同一技能的后续伤害，检定风险读取当时已变化的士气。
- `DeathDoorRuleTable`：满士气死亡率10%，零士气90%，中间线性变化，再向上取整到5%档位。`deathFaces=ceil((10+80*(1-current/max))/5)`；D20掷值不大于致死面数则死亡，其余幸存。满士气1–2死亡；75%士气1–6死亡；零士气1–18死亡。使用原战斗RNG的0–99映射到1–20，每次死亡检定只取一次随机数。
- 幸存仍为0HP；幸存次数+1，智力、力量、速度、防御及各武器熟练额外削减10%，最多50%，按现有伤势与士气修正后的值取整。体力、耐力与勇气不参与这项削减，避免上限反向改变死亡率或形成最大HP循环；具体属性集合配表。士气减少上限的40%，向上取整、最低0，可能立即进入原士气系统的逃跑状态。
- 治疗将HP恢复到正数后离开死门，但不会刷新本场首次保护或清除衰弱。现有营地/休整的 `Restore` 为幸存者恢复可恢复部位并清除死门衰弱；永久死亡者 `Heal/Restore` 均不能复活。永久死亡身份留在角色记录中，装备、经历等继续沿现有角色/编组系统管理；本模块不新增复活或遗产分配流程。
- 最终死亡才发出 defeated、结束相关效果和参与胜负结算；零血继续行动与死亡后的回合交接使用同一存活判断。原始部位伤势计算、伤害量和HP比例查询仍用HP，不能机械替换成布尔存活。3D动画与场景选择读取真实存活标志；最终死亡时即使HP仍为0，也会播放死亡动作。角色手记、队伍卡和血环显示“死门／已死亡”。
- `death_door_check` 携带已结算的骰值、致死面数、检定前士气和成败；`DiceChecks.FromBattleEvent` 转成单颗D20请求，`MainHudCtr` 在战斗中同样打开既有 `DiceRoll`。真实物理轨迹只负责展示，快速揭晓和排队不重抽。窗口显示“挺过死门／已死亡”；模态窗口期间停止战斗输入、自动AI和世界角色演出，UI使用未缩放时间继续播放。
- `ActorSave.deathDoor` 自v39/40引入，保存format=1、entered、used、dead、survived；后续保存版本继续携带，当前版本由[存档模块](CharacterSave.md)维护。旧1–38档的0血队员迁移为可救回的死门状态，不能凭空变为永久死亡；新版拒绝正HP但死亡、同时死门与死亡等矛盾组合。读取、再次保存和营地恢复均保留真正死亡标志。
- 已执行：规则边界单测、原骰子生命周期回归、本地化检查、真实C#系统/致死伤害/AI选目标/0血逃跑/治疗再入/DOT/营地/永久死亡/当前存档回读/v38迁移、真实D20物理轨迹与面值/连续队列/快速揭晓/暂停释放。主动触发一次集中C#编译并通过；未进入Play，未运行全量测试。实际游玩中的节奏与长期平衡仍待验收。

## 关键入口

- [DeathDoorState.cs](../../Assets/GameFramework/Runtime/Data/DeathDoorState.cs) / [ActorLife.lua](../../Lua/Game/Battle/ActorLife.lua)：唯一生命状态与跨模块查询。
- [DeathDoor.lua](../../Lua/Game/Battle/DeathDoor.lua) / [DeathDoorRuleTable](../../Config/Tables/Adventure/DeathDoorRuleTable.json)：概率、幸存惩罚与配置。
- [GameEffects.lua](../../Lua/Game/Battle/GameEffects.lua) / [CombatStats.lua](../../Lua/Game/Battle/CombatStats.lua) / [BattleSystem.lua](../../Lua/Game/Battle/BattleSystem.lua)：护甲后伤害、属性与行动结算。
- [DiceChecks.lua](../../Lua/Game/Presentation/DiceChecks.lua) / [DiceRollCtr.lua](../../Lua/UI/Panel/DiceRollCtr.lua) / [MainHudCtr.lua](../../Lua/UI/Panel/MainHudCtr.lua)：D20事实投影与窗口；物理演出见[骰子模块](Dice.md)。
- [核心检查](../../Tools/Tests/death_door_core.lua)：`python -B Tools/Tests/run_lua.py Tools/Tests/death_door_core.lua`；[系统检查宿主](../../Tools/Tests/death_door_integration_editmode.cs) / [系统检查](../../Tools/Tests/death_door_integration.lua)：独立Services与唯一临时存档；[D20窗口检查](../../Tools/Tests/death_door_dice_editmode.cs)：PreviewScene，不进入Play。
- [真实D20动画预览](../../Docs/Previews/DeathDoor/death-door.gif) / [幸存结果](../../Docs/Previews/DeathDoor/survived.png) / [死亡结果](../../Docs/Previews/DeathDoor/dead.png)：固定测试骰值的原生窗口截图，非玩家存档。
