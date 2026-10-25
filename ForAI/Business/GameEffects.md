# GameEffect
关键词：GameEffect、GAS、BuffTable、Buff、Debuff、再生、流血、中毒、火花点燃、燃烧、潮湿、眩晕、追踪、manualEnemyTargets、ignoreProjectileBlockers、互斥、分钟计时、周期伤害、治疗、叠层、状态飘字、概率日志、report。

## 文档目录
正文：配置与入口 / 生命周期 / 存档与 UI / 验证；关键入口：数据 / 规则 / 配置。

## 正文

- [伤口感染](BodyInjuries.md)使用persistent/infinite Buff，沿用属性组件和Effects存档；概率由DiseaseRules在新创伤后判定，疾病治疗在健康界面消费药物并删除实际Buff实例。普通回血只恢复部位HP，不清除创伤/疾病。

- `CombatEffectTable` 定义可复用的伤害、治疗、属性修改等动作，新增 `apply_buff/buffId/chance` 施加状态；`BuffTable` 定义名称、色号、图标、生命周期、叠层、标签关系、控制效果及引用的动作。`CombatSkillTable.effectIds`、[武器/配件命中效果](Equipment.md)、[事件选项效果](Adventure.md)和 `BattleSystem:ApplyEffect(effectId,source,target)` 复用同一执行器；独立调用不消耗技能 AP。换弹、驯服和位移保留各自的事务/目标上下文。
- `CombatEffect.recipient=target/source` 决定实际接收者，`requiredTags/forbiddenTags` 按原始选中目标的当前 Buff 标签匹配；`sourceRequiredTags/sourceForbiddenTags` 明确匹配施法者，不能用 recipient 代替源条件。`remove_buffs` 按 removeTags/removeCategories 清除实际接收者，并区分实际移除的减益数量；旧正向属性／治疗效果归 buff，负向属性／周期伤害归 debuff。执行顺序由 effectIds 决定；[职业一次性联动](ProfessionCombat.md)使用命中前快照，不受致死清除破坏。
- 每发的目标命中或沿途拦截由 [ProjectileCombat](Battle.md)统一决定；被角色拦截时为实际接收者重新准备完整效果程序，标签条件也查询该角色，因此友伤不是仅显示日志。所有命中收益共用这一发的结果；未命中不自疗/护卫/净化。致死命中的同一发仍可执行无条件source收益，后续发不能对尸体刷收益，使用者倒地后终止余下角色效果。死亡清理先移除标签，依赖目标状态且需随致死命中触发的收益应配置在伤害之前。
- 即时效果在Prepare做数值预检，实际执行时重新按当前属性/生命求值；4个新增公式变量sourceMissingHealth/targetMissingHealth及sourceHealthPercent/targetHealthPercent（0–100）按需读取，即时效果的target仍指原始选中目标；Buff组件的target指实际Buff接收者。Buff组件在成功施加时重新捕获快照，周期沿用快照；周期和属性组件必须无标签条件并作用于Buff接收者。
- 容器只接受 `affectsContainers=true`、无标签条件、recipient=target的即时伤害；不执行自疗、护卫、状态或状态条件收益，也不把耐久伪作角色HP。容器波及角色时仍走统一的角色效果程序。新增武器专属技能只在战斗使用，原基础技能保留生活破拆。
- 新 Buff ID 与效果动作 ID 必须互不重复；持久实例的 `EffectId` 对新状态保存规范 Buff ID，旧效果仍保存原 Effect ID。不同概率的施加动作引用同一 Buff 时，按同一状态刷新/叠层。附加效果统一将0–99随机样本映射为1–100掷值，以 `roll > 100-chance` 成功；`chance` 仍表示成功率，0/100不耗随机数，报告附带 `rollConvention/rollComparison/threshold`，日志和探索骰子按同一门槛展示。施加概率在本发已命中或被角色拦截后独立判定；未命中、概率未触发、被标签阻止或目标倒地都不生成“获得状态”通知。普通攻击与容器攻击波及角色共用效果程序，不为每个附加动作重新判命中。
- `GameEffects.New` 的可选 `report` 回调观察既有判定，记录触发概率与实际掷值；`BuffEffects` 报告阻止施加的状态，角色效果程序报告致死伤害后略过的附加Buff。报告不另掷骰、不改伤害/概率/状态，只补充未生效原因；日志展示契约归[战斗](Battle.md)。
- `scope=battle/persistent` 决定是否战斗结束移除；`clock=turns/minutes/infinite` 决定剩余回合、游戏分钟或无倒计时。周期动作可以按回合或分钟触发，无倒计时也可带周期；只能选择一种周期轴。分钟计时用于跨战斗状态，战斗中游戏时钟冻结，局内倒计时按目标回合推进。
- `periodicEffectIds` 引用瞬时伤害/治疗，`modifierEffectIds` 引用属性动作，`onApplyEffectIds` 引用成功施加时的瞬时动作；组件不允许递归施加 Buff。组件数值在施加时求值并由 C# 保存快照，叠层使用最新来源和数值；复合状态的时长由 Buff 表决定，不重复运行属性组件自身的独立计时。
- `tags/blockedByTags/removeTags` 配置状态关系，不按状态名称写分支。当前潮湿删除 burning 标签，并以 wet 标签阻止燃烧；`skipTurn` 使目标跳过整个正式行动回合，在回合前记录控制状态，按原开始/结束时机推进效果，避免最后一回合提前恢复行动。
- `manualEnemyTargets/ignoreProjectileBlockers/skillGroups` 显式配置 Buff 对技能选择/弹道的能力，不按 Buff ID 或标签名写特判。`BuffRules:ApplySkillModifiers` 只修改已复制的有效技能：对敌、射程大于1且技能组匹配时，多目标可获得 `manualTargets`，direct/lobbed 弹体可获得 `guided`；两能力独立，sight 状态法术可手选散射但仍按自身视线规则。状态到期后下次技能查询立即恢复；具体目标/概率契约归 [战斗](Battle.md)。
- 追踪 Buff10105 由效果1361施加，属于battle/turns/refresh，按持有者自身3次turn_end计时；在自己回合施加时，当前回合结束也计一次。追踪术1624为1AP次要行动、无CD，保留同回合主要攻击额度。转施给队友或敌人后仍由接收者计时，施法者回合不推进对方状态。施加动作使用recipient=target；转施资格、资源与获得路径见 [装备](Equipment.md)。
- 分钟状态保存绝对到期与下次周期时刻；批量时间推进按时间顺序交错执行各状态，避免先算完全部治疗再算全部伤害。旅行/探索通过 `NarrativeSystem:AdvanceMinutes` 同步结算，营地等待在成功推进 C# 时钟后调用 `TickBuffs`；即使等待窗口暂停自动时钟，已推进的时间也会结算。真实移除/伤亡才触发队伍与掉落刷新。
- 首批包含再生、流血、中毒、燃烧、潮湿、眩晕、长效复苏和战场祝福。法杖授予毒雾术、润泽术、长效复苏、战场祈愿和火球术；精确刺击/穿叶箭可流血，黑曜重型巨剑命中可眩晕。火花3、群星之火104、火球509均通过804以60%概率施加燃烧10004；显示掷值大于40成功（41–100），1–40失败。真实程序定向检查覆盖1/40/41/100及89成功，wet阻止燃烧，目标先被直接伤害打死则不再施加；燃烧在目标turn_end触发3次，周期动作904基础伤害4，按施加技能倍率捕获快照。现在通过report解释未触发、潮湿阻止和致死略过，不能将未见状态直接视为配置缺失。参数均在源表，技能图鉴登记同一技能 ID。
- 旧效果的 `duration` 为 instant/duration/infinite；有限效果使用 durationTurns，无限实例 Remaining=-1。旧持续效果支持 damage/heal/modifier，继续兼容原存档和调用；modifier 的 attribute 指定属性、amount 可为负，periodTurns 必须为 0；周期伤害/治疗的 periodTurns 必须大于 0。
- magnitude 在施加时用现有受限公式求值并保存快照；技能伤害缩放仍沿用原接口，独立施加时 proficiency 为 0。属性增减参与 `CombatStats:Get`，生命上限变化按原 SetMaxHP 契约保留已受伤害。
- 回合效果的 `tickPhase` 配置 turn_start 或 turn_end，在目标回合的对应阶段推进一次计时。先触发到期周期，再移除耗尽的实例；首次周期不会在施加瞬间执行。回合开始死亡会跳过行动，结束阶段死亡仍检查胜负；区域战斗先进入 battle 阶段，再结算首个回合效果，允许保留的效果在开场直接结束遭遇。
- `stacking` 按“目标 + 效果 ID”聚合：refresh 使用最新施加者/数值并重置时长与周期；independent 产生独立实例；stack 增层至 maxStacks，并使用最新数值、重置时长与周期。界面状态仅投影实例，不维护计时副本。
- 旧效果的 `removeOnBattleEnd`（新 Buff 的 scope）决定战斗结束是否移除；保留的效果进入探索后，随现有探索世界回合推进开始/结束阶段，暂停/对话和没有执行路线时不累计新世界回合。`removeOnDeath` 决定倒地是否清除；普通治疗仍不复活。
- 角色及坐骑的 `Effects` 仍是 C# `GameEffectCollectionData`，新状态增加组件数值数组与分钟时刻，`GameBuffState` 提供反射桥接；[角色存档](CharacterSave.md) v8 保存新增字段，旧档显式迁移为空组件快照。读档核对状态定义、组件身份/顺序、生命周期、层数和周期，未知配置不静默降级。
- 探索周期结算后移除倒地队员的移动编队；全员倒地返回大地图。敌人死亡继续发送 defeated 事件并使用原掉落标记防止重复掉落。挂在坐骑上的效果同样推进，坐骑死亡释放骑乘关系。
- [MainHud](MainHud.md) 的各角色头顶 HudHealth 使用 HudStatusEffect Widget 显示实际实例的图标、层数和剩余回合，按六列换行并悬停查看来源与说明；状态正文、来源、层数、剩余时间使用完整本地化模板分行，MainHud 按正文高度收紧说明卡；不使用独立屏幕状态区。iconId 复用 BattleIconTable，空 Sprite 使用名称首字作为可读徽记。
- 伤害通知的 `impact.damageColor` 保存结算后的颜色：Buff 周期伤害继承 `BuffTable.color`；独立伤害动作使用 `CombatEffectTable.damageColor`，空值保留普通/暴击默认色，旧持续效果未指定时使用自身 `color`。颜色仅影响表现；当前流血鲜红、中毒绿色、燃烧橙色，复用动作不会覆盖 Buff 的颜色。
- `effect_added` 只在成功施加/刷新/叠层后发布，携带状态名、色号、层数和命中序号；头顶复用伤害数字池排队显示彩色状态文字。图标倒计时区分回合、分钟（m）和无限（∞），配色共用 `Config.Color` 的 3/4/6/8 位十六进制解析。
- 最小原生 Lua 检查：`python -B Tools/Tests/run_lua.py Tools/Tests/game_effects_core.lua`。真实桥接检查为 `Tools/Tests/game_effects_integration.lua`，需要独立 UIHost、FrameworkServices 与临时存档路径，在现有 Edit Mode LuaEnv 中运行；不读写玩家存档。

## 关键入口

- [Buff 表](../../Config/Tables/Adventure/BuffTable.json) / [Buff 配置规则](../../Lua/Game/Battle/BuffRules.lua) / [复合状态执行](../../Lua/Game/Battle/BuffEffects.lua) / [C# 快照与分钟时钟](../../Assets/GameFramework/Runtime/Data/GameBuffState.cs)。定向规则检查 [buffs_core.lua](../../Tools/Tests/buffs_core.lua) 与 [battle_feedback.lua](../../Tools/Tests/battle_feedback.lua)；[真实状态往返](../../Tools/Tests/buff_state_data.ps1)接收 `-AssemblyPath`，不编译、不读写用户存档。以上已通过；原生 Edit Mode“验证伤害数字”已覆盖彩色状态顺序和真实 xLua 桥接，完整 Play 与磁盘旧档迁移仍未复测。

- [GameEffectData.cs](../../Assets/GameFramework/Runtime/Data/GameEffectData.cs)：唯一实例状态与存档结构。
- [GameEffects.lua](../../Lua/Game/Battle/GameEffects.lua)：Prepare / ApplyPrepared / TickActor / Clear / Rows / ValidateSaved。
- [battle_log_core.lua](../../Tools/Tests/battle_log_core.lua)：已通过的真实火花概率边界、受阻/致死说明、承伤生命值与观察日志随机流检查；未进入Play。
- [BattleSystem.lua](../../Lua/Game/Battle/BattleSystem.lua) / [CombatStats.lua](../../Lua/Game/Battle/CombatStats.lua)：技能组合、回合与属性。
- [CombatEffectTable](../../Config/Tables/Adventure/CombatEffectTable.json) / [MapAreaSystem.lua](../../Lua/Game/MapArea/MapAreaSystem.lua)：配置与探索时钟接入。

- [原子指令路由/条件/清除](../../Lua/Game/Battle/EffectInstructions.lua)；新增机制定向检查入口为 [arsenal_effects.lua](../../Tools/Tests/arsenal_effects.lua)（真实配置与真实Lua规则，隔离C#数据适配器），不需要启动Editor或Play。
- [追踪/转施配置检查](../../Tools/Tests/tracking_config_core.lua)：真实规则验证能力范围、三回合刷新/到期、接收者计时、1AP后主要攻击、转施白名单/固定射程及获取引用；命令为 `python -B Tools/Tests/run_lua.py Tools/Tests/tracking_config_core.lua`。
