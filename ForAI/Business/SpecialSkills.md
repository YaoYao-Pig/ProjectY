# 特殊技能与传授
关键词：特殊技能、NPC绝技、观摩、战后领悟、传授、师徒、转授、SpecialSkill。

## 文档目录
正文：配置与持有 / 传授与领悟 / 生命周期与验证；关键入口：规则 / 数据 / 界面。

## 正文

- 特殊技能继续使用 `CombatSkillTable` 的技能身份和战斗效果；`SpecialSkillTable` 定义获得规则，不能同时加入职业课程。首版支持战斗主动技，描述和名称来自配置 `text`；示例为2701断誓斩、2702穿林连矢、2703回生急救。
- `SpecialSkillHolderTable` 每行按单位模板或剧情NPC二选一配置初始技能；NPC沿既有 `10000+npcId` 身份且核对模板。原始持有由配置决定，身份/模板不变的招募保留能力；`EquipmentRules.SkillIds` 合并原始技能与永久已学技能，战斗、探测及手记使用同一集合。
- 传授要求探索阶段、两名不同的存活队员、教师持有技能、双方关系达到配置门槛、学生符合共享属性要求且未掌握。`teachable` 控制能否传授，`reteachable=false` 时只有原始持有者可教。达标后直接学会，不消费职业学习机会，也不消耗或降低关系。
- 入口为角色手记→总览→选择队友关系→请教技能→确认。当前查看角色是学生，所选队友是教师；资格不足可查看原因。图鉴和技能详情显示特殊技能来源、学习门槛及领悟规则。
- 观摩只计真实参战的己方队员；释放者可以是敌人或队友，不能观察自己。成功施放包括未命中，失败命令、预览、部署及场外旁观不算。施放前保存视线和属性快照，成功后提交，防止位移或末击清理场地改变观察结果。
- 共享属性要求和观摩属性均通过 `CombatStats.Get(...,true)` 排除装备；保留当时职业、特质、状态等既有属性修正。达到观摩门槛后按 `min(上限,基础概率+(属性-门槛)*每点增量)` 计算；同人同技能每场取最高观察概率，战后只抽一次。
- 普通战斗及礼式决斗结算时，无论胜负，仅仍存活且属于队伍的观察者有机会学会。随机数来自角色已有养成随机流；已掌握者不再抽取，重复结算不再奖励。
- `SpecialSkillBattleState` 是按 `AdventureData` 隔离的C#临时权威状态，保存参战者、去重观察和结算标记；Lua仅持有配置与单次命令快照。`Start/Dispose` 注册和释放观察入口，新游戏/读档重置；战斗不能存档，因此不新增战斗保存字段。
- 学会后用 `Growth.GrantSkill` 进入既有技能存档；传授经历准确记录师徒两人，观摩经历记录学生及释放者当时的名字，避免把敌方临时ID写进队伍经历参与者。个人成长同步统计本次新学技能。
- 示例关系门槛60，学习属性8、观摩属性12，概率5%起、每点增加2个百分点、上限25%。均来自源表；改表后按[配置管线](../Framework/Config.md)导出，UI文案按[本地化](../Framework/Localization.md)处理。
- 定向检查：`special_skill_rules.lua` 校验配置/归属/概率，`special_skills.lua` 校验传授/观摩/结算，`special_skill_ui.lua` 校验师徒方向及确认交互。用 `python -B Tools/Tests/run_lua.py Tools/Tests/<文件>` 执行；这些入口不授权启动Editor或Play。
- 原生最小检查使用[隔离宿主](../../Tools/Tests/special_skill_integration_editmode.cs)执行[真实数据用例](../../Tools/Tests/special_skill_integration.lua)，仅初始化Config/Battle/Growth和临时数据，不生成世界或修改场景；通过反射桥访问新状态，`Data/link.xml`保留两个类型。2026-11-02已通过7组原生用例及已学技能、职业学习机会、随机状态的JSON往返；Lua规则/观摩/交互、技能详情、特效目录、本地化检查通过。主动集中编译一次，后补配置仅定向导入，无Play验收；既有`opportunity_attacks.lua`受测试替身缺`TitleState`阻断，新观摩检查已直接覆盖其真实Execute入口。

## 关键入口

- [SpecialSkillRules.lua](../../Lua/Game/Progression/SpecialSkillRules.lua) / [规则表](../../Config/Tables/Progression/SpecialSkillTable.json) / [持有者表](../../Config/Tables/Progression/SpecialSkillHolderTable.json)：初始化、门槛、概率、说明。
- [SpecialSkills.lua](../../Lua/Game/Progression/SpecialSkills.lua) / [SpecialSkillBattleState.cs](../../Assets/GameFramework/Runtime/Data/SpecialSkillBattleState.cs)：传授、观察事务和结算去重。
- [BattleSystem.lua](../../Lua/Game/Battle/BattleSystem.lua) 的 `ObserveSkillUse` / [OpportunityAttacks.lua](../../Lua/Game/Battle/OpportunityAttacks.lua)：实际施放与反应攻击接入。
- [AdventureSystem.lua](../../Lua/Game/Adventure/AdventureSystem.lua) / [DemoBridge.lua](../../Lua/Game/Adventure/DemoBridge.lua)：生命周期、结算与 `special_skill_teach` 命令。
- [CharacterGrowthCtr.lua](../../Lua/UI/Panel/CharacterGrowthCtr.lua) / [GrowthSkillDetailModel.lua](../../Lua/UI/GrowthSkillDetailModel.lua) / [SkillAtlas.lua](../../Lua/Game/Progression/SkillAtlas.lua)：关系页请教、详情和图鉴。
- [规则检查](../../Tools/Tests/special_skill_rules.lua) / [玩法检查](../../Tools/Tests/special_skills.lua) / [交互检查](../../Tools/Tests/special_skill_ui.lua)。
