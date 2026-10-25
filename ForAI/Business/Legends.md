# 传奇生物与具名人物
关键词：传奇生物、传奇人类、传奇特性、友好、敌对、战前交流、和解、传奇委托、LegendaryEncounter。

## 文档目录
正文：身份与遭遇 / 战斗特性 / 对话与任务 / 修改与验证；关键入口：配置 / 运行时 / 检查。

## 正文

- `LegendaryEncounterTable.id` 绑定 `WorldPartyTable`，`npcId` 绑定稳定叙事身份。每种固定一位、一个独立角色模板和一个独立势力；态度由 `WorldFactionTable.playerRelation` 加已保存声望决定。独立势力避免与一位传奇和解影响整个种族。传奇使用无据点的游荡策略，不随驻军补员复活；未配置合法地貌时不生成替身。
- 新世界与旧存档初始化共用 `WorldParties:Spawn`；旧档仅补入缺失的传奇定义，已有编制、伤势和死亡不改变。地貌、数量、行军速度、感知与游荡范围仍由队伍和势力配置负责；模型复用已绑定巨狼、岩石巨兽与人类资源，战斗占位分别为二格、四格、一格。
- 四只传奇动物的物种由 `AnimalSpeciesTable` 显式绑定 701–704，均可驯服骑乘；友好时通过接触对话和平收服，敌对时在战斗中驯服。已经完成势力迁移的旧档也会原地补齐动物初始化，保留同一实例与原有生命/特性。收服后原队伍保留唯一动物记录但退出活动、战力和战争结算，不复制或重生。骑乘展示、沟通规则及重试时钟见[动物模块](Animals.md)。
- `CombatUnitTable.traitIds` 在创建敌人或准备队员时授予固有特质，实例 `AddTrait` 保证同 ID 不重复。`CombatTraitTable` 的 `rarity` 标记传奇，`onHitEffectIds` 将已有 GameEffect 指令附加到伤害攻击；防御、治疗不触发，未命中沿原攻击流程不结算。效果顺序为原技能、特质、武器与配件；实际承伤者、源方收益、潮湿阻止燃烧、死亡边界沿用 [GameEffect](GameEffects.md)。
- 首批单位 701–706、特质 101–106、队伍/独立势力 11–16、叙事身份 101–106：

| 个体 | 初始态度 | 专属特性 |
| --- | --- | --- |
| 血月巨狼 · 裂喉 | 敌对 | 血月獠牙：命中流血 |
| 寒潮巨狼 · 听雪 | 友好 | 霜息：命中迟缓 |
| 磐脊巨兽 · 守誓 | 友好 | 磐心回响：命中后自身护卫 |
| 熔脉巨兽 · 余烬 | 敌对 | 熔脉火种：命中燃烧 |
| 叛誓剑士 · 维兰 | 敌对 | 断誓锋刃：命中驱散增益 |
| 引路游侠 · 洛恩 | 友好 | 归途之息：命中后自身治疗 |

- `NpcTable.locationKind=world_party` 不使用城镇安置、日程或招募；`townTemplateId` 在此类型不参与显示。接触未交战传奇时先打开现有 Dialogue Panel；动物须施放交谈术后才能读取原对白、接取/提交委托，人类沿原流程。地图与伙伴对话不查找城镇 NPC/商品，也不调用城镇双人镜头。友好个体需主动接近，敌对个体沿既有追击/接触规则自动接触。
- `DialogueChoiceTable.worldAction=attack` 仅允许无奖励动作的终止选项；提交时重查附近、存活和未交战，再关闭对话并进入已有战场流程。普通关闭/离开使用 `contactGraceMinutes` 写入已有脱战保护（首批60游戏分钟），世界继续暂停；主动再接近仍可交谈。对话版本拒绝旧点击；对话期间沿既有规则禁止保存。
- 三条委托 701–703 由听雪、守誓、洛恩提供，各有“解决目标 / 返回回报”两个阶段。击败、和解或成功收服对应传奇均可解决目标；收服写入同一 `defeatedFlag` 解决事实，但不计击杀或发放援助奖励。听雪/守誓成为伙伴后仍用原 NPC 对话提交任务。友军击杀、友伤、中立及已驯服动物死亡不写任务结果；和平补偿分支不能反复扣费。
- 接取、回报、领取和经历奖励复用 [叙事系统](Narrative.md)，事实与声望使用现有 Narrative 存档，队伍生命使用现有 WorldParties 存档。没有另建 Lua 持久状态或新的存档版本。
- 新内容通过叙事 CLI `review → patch → export` 校验保存；配置中心“投放与流程”收录传奇绑定、队伍、势力与编制。校验拒绝重复身份/专属特质、批量生成同名传奇、城镇安置混用、城镇对话开战及攻击选项同时发奖；图中能追踪任务条件对击败事实的依赖。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/legendary_traits.lua`、`legendary_story.lua`、`legendary_spawn.lua`；`node --test Tools/Narrative/tests/legendary.test.mjs`。本轮已通过上述离线检查及相关叙事、配置中心、战斗效果与势力归因回归；未验证 Unity 真实 UI/镜头、桥接存档与 Play 游玩表现。

## 关键入口

- [传奇绑定](../../Config/Tables/Travel/LegendaryEncounterTable.json) / [固有特质](../../Config/Tables/Adventure/CombatUnitTable.json) / [特质效果](../../Config/Tables/Adventure/CombatTraitTable.json)。
- [LegendaryEncounters.lua](../../Lua/Game/Adventure/LegendaryEncounters.lua)：接触合法性、结束交流、击败事实；[WorldParties.lua](../../Lua/Game/Adventure/WorldParties.lua)：生成与接触分流。
- [Dialogue.lua](../../Lua/Game/Narrative/Dialogue.lua)：地图会话及开战出口；[规则与引用图](../../Tools/Narrative/rules.mjs)：编辑期契约。
- [特性执行检查](../../Tools/Tests/legendary_traits.lua) / [叙事路线检查](../../Tools/Tests/legendary_story.lua) / [生成检查](../../Tools/Tests/legendary_spawn.lua) / [工具校验](../../Tools/Narrative/tests/legendary.test.mjs)。
