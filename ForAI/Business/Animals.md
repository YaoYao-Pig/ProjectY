# 森林动物与骑乘

关键词：动物、动物交谈术、沟通、投骰、动物亲和、魅力、驯服、中立、黄色框、坐骑、亲密度、骑兵技能、冲击、飞扑、跳跃、森林、哥布林。

## 文档目录

正文：状态与配置 / 森林与显示 / 验证；关键入口：规则 / 状态 / 资源。

## 正文

- 动物交谈术 `206` 由法师、游侠、驯兽师课程及动物亲和研习提供，需要奥术触媒；战斗为 1AP 次要行动、3格距离。普通动物通过生活技能点选，传奇世界接触先显示无法理解的观察/示好/攻击入口，施法后开放剧情与委托。理解仅维持当前会话，关闭后需要重新施法。已绑定伙伴在区域可点击主人/动物，在大地图由任意会施法的队员打开全队动物选择，仍使用原传奇 NPC 身份交接任务。
- `AnimalSpeechRuleTable/AnimalSpeechApproachTable` 配置沟通方式、成功率与失败惩罚；沟通自身仍由动物随机序列一次结算。成功的正值持久结果赋予下一次驯服 `animal_speech` 优势，不再叠加概率；失败负值仍加到基础概率后钳制。`AnimalSpeechState` 将结果保存在目标实例，全队共享；换人、换方式、关闭重开不能重投。实际驯服无论成败消费一次，预览与非法操作不消费；失败冷却也阻止沟通。关闭会话只清除理解状态；未消费结果沿用原存档字段，旧正值结果按优势解释。
- `AnimalRules:TameChance` 首返回值为实际成功率，`values.baseChance/advantageSources` 保留单次概率与来源；`Tame` 保留前四项并以第五项返回优势结算。世界对话、探索与战斗共用同一动物随机流抽两次，按百分之一精度转高值并取最高；仅结算一次归属／冷却。展示与共享结算契约见[骰子与优势](Dice.md)；战斗目标预览显示优势后的驯服率。
- `AnimalRules` 解释物种、驯服概率、占格与骑兵技能；`CombatActorData` 保留同一个绑定动物实例。`AnimalCompanionState.Bound/Partner/Independent` 区分绑定、独立随行与骑乘。生活技能“伙伴随行”在拥有动物时出现，切换不刷新生命、亲密度、创伤或状态。只有 `MountedAnimal` 承担骑手伤害；独立同伴有自己的占格和生命，死亡不能通过切换复活。
- 驯兽指令由 `ProfessionBeastTable/ProfessionBeasts` 解释。独立动物加入战场实体及敌方目标，但不进入行动顺序、不获得队员升级经验；主人的 AP／主要行动支付指令，动物的回合状态随主人开始／结束推进。驱赶每轮一次，保留真实借机风险；夹击用动物扑咬；救援需玩家选择目标与合法落点，执行后本轮禁止攻击指令；气味仅部署阶段可用，首次真实命中消费。
- 战宠采用同一角色存档中的动物记录，保存模式、身体创伤、探索楼层、特质、出生/职业属性与沟通结果；旧记录缺字段按旧语义恢复。完整远征读档将该引用重新连接到原世界队伍或区域中的同一动物，并校验身份与状态一致；没有复制第二只宠物。探索跟随、投影和占格使用实际楼层，战斗仍遵守现有单层限制。
- `GrowthAttributeTable.animalAffinity/charisma` 均为可投入的生活属性，动物亲和可参与主动技能研习；是否参与由 `skillDirection` 决定，不按生活分类排除。`ActiveSkillPoolTable` 配置驯服门槛与权重。成功率由 `AnimalRuleTable` 的 `affinity/charisma/missingHealth/hostile/difficulty` 公式和概率上下限决定；仅敌对动物有伤势加成。
- `AnimalSpeciesTable.tameRetryTurns` 配失败后的动物重试间隔（首版马/鸡/兔为 3/2/3 回合）；剩余回合保存在动物实例，所有角色共享限制，重新部署和出入战斗不清零。`Config/Catalog.json` 的全局常量 `Global.ExplorationRoundSeconds` 定义探索回合时长（首版 3 秒）：只累计小队执行移动路线的游戏时间，停止、改道、离开区域保留不足一回合的余量，静止和暂停不累计。战斗完成整轮时推进一次区域回合，进入战斗的第一轮不额外推进。
- `AnimalSpeciesTable` 配战斗模板、可乘骑性、固定轴向占地、骑手髋部位置、骑乘移动格数、初始亲密度与共同战斗收益。首批马、鸡、兔均一格；连续多格占地要求包含原点且不重复，部署、移动、落点和占位检查均检查完整格罩。
- 传奇动物的新编制与旧档原对象均由 `WorldFactions:PrepareRoster` 按 `AnimalRules.byUnit` 补一次物种/随机种子；不改生命、特性、归属和势力态度。已收服动物不再贡献原势力战力，也不接受据点恢复。大地图重试间隔在玩家实际行军时按 `WorldPartiesData.ElapsedTicks` 的整游戏分钟边界递减，沿用持久时钟余量；静止、暂停和已进入区域战场的动物不推进这条时钟。
- `AnimalRules:Cells(actor,board,q,r,layer)` 可显式传楼层；探索占地、招募及物件避让从成员锚点透传 `layer`。多格坐骑缺少同层格时拒绝占地，不借用脚下楼层；省略时保持 MapArea 地面层或 BattleBoard 的窗口默认层。
- `AnimalSkillTable` 根据当前坐骑的物种与亲密度自动开放技能；坐骑死亡后不再提供该物种的技能。马冲击沿六向直线抵达目标前一格，路径不能穿过阻挡，伤害公式可读取实际冲刺 `distance`；鸡飞扑向目标前方跃进一格并攻击；兔跳跃为地格目标，最多三格，落点不能阻挡或被占据。高大视线阻挡限制原地形中的跃迁。
- 森林是独立 `E_MapAreaType.Forest` 生成策略。`MapAreaForestTable/ThemeTable` 定义林间空地、连通小径、树木密度和地面材质；`MapAreaForestEntranceTable` 在大地图真实森林 Region 创建入口；`MapAreaForestSpawnTable` 独立抽取物种组数、刷新概率与中立比例，哥布林使用限定哥布林的外观池。进入同一地点复用敌群和动物状态，新远征重建。
- 野生动物沿用区域遭遇实体；中立 Team=0 不主动触发战斗。骑乘模式从独立占格和显示中移除，由骑手组合展示；独立随行模式单独显示且参与弹道拦截。两种绑定模式均不再作为未驯服野生目标。驯服仍是同时支持 life/battle 的同一技能，探索从 [MainHud 角色技能栏](MainHud.md) 点击动物，战斗中可对敌对动物使用。
- `PawnView/PawnAnimationView` 组合动物网格与 Humanoid 骑手坐姿；`CombatSnapshot` 从坐骑身体确定固定占格显示，`PawnMotion.SetFootprint` 让巨狼/巨兽在完整占格中心显示并保持方向。小队投影使用当前区域成员锚点与实际楼层，骑手动作不旋转固定多格身体。`PawnMotion` 仅表现移动，不参与规则结算。座位首版依据模型源尺寸配置，尚待 Unity 实际画面验收。坐骑存档嵌入现有角色存档，包含生命、物种、亲密度和随机状态；旧存档没有坐骑记录时仍可读取。
- 源模型位于 `Art/ForestAnimals/Source/ForestAnimals.blend`，FBX、独立纯色材质位于 `Assets/DynamicAsset/ForestAnimals/`。三只动物和阔叶树、针叶树、蕨类、六边形地面共七个模型；沿用项目已验证的轴向烘焙导出预设，Unity 根旋转为零、缩放为一，地面半径一米、顶面 Y=0。
- 最小纯 Lua 检查：`python -B Tools/Tests/run_lua.py Tools/Tests/forest_animals_core.lua`；涉及真实状态/技能命令时，编译及生成 xLua 绑定后用 Edit Mode 菜单 `Project Y/远征/验证森林动物与骑乘`。资源预览脚本经 Unity MCP 执行，创建并释放独立 PreviewScene，不进入 Play。

## 关键入口

- [交谈流程](../../Lua/Game/Animals/AnimalSpeech.lua) / [检定规则](../../Lua/Game/Animals/AnimalSpeechRules.lua) / [结果状态](../../Assets/GameFramework/Runtime/Data/AnimalSpeechState.cs) / [会话状态](../../Assets/GameFramework/Runtime/Data/AnimalSpeechSession.cs)。最小离线检查：[animal_speech_core.lua](../../Tools/Tests/animal_speech_core.lua)、[势力结算检查](../../Tools/Tests/animal_speech_conflicts.lua)；[原生状态检查](../../Tools/Tests/animal_speech_state.cs) 是已有空闲 Editor 的内存检查片段，不启动 Play、不读写玩家存档。
- [动物指令](../../Lua/Game/Battle/ProfessionBeasts.lua) / [权威模式桥](../../Assets/GameFramework/Runtime/Data/AnimalCompanionState.cs) / [源配置](../../Config/Tables/Progression/ProfessionBeastTable.json)。定向离线检查：[profession_beasts_core.lua](../../Tools/Tests/profession_beasts_core.lua)，隔离 C# 边界，不替代原生数据／存档检查。

- [动物规则](../../Lua/Game/Animals/AnimalRules.lua) / [权威状态](../../Assets/GameFramework/Runtime/Data/CombatActorAnimals.cs) / [配置源](../../Config/Tables/Animals/)。
- [优势驯服检查](../../Tools/Tests/advantage_animals.lua) / [战斗与探索入口检查](../../Tools/Tests/advantage_routes.lua)：概率、消费、旧正值兼容、两轮展示和单次行动；通过 `run_lua.py` 离线执行，不替代真实存档／Play 验收。
- [森林生成](../../Lua/Game/MapArea/ForestGenerator.lua) / [刷新计划](../../Lua/Game/MapArea/ForestEncounters.lua) / [区域命令](../../Lua/Game/MapArea/MapAreaSystem.lua)。
- [规则检查](../../Tools/Tests/forest_animals_core.lua) / [真实状态检查](../../Tools/Tests/forest_animals_integration.lua) / [Edit Mode 入口](../../Assets/GameFramework/Editor/ForestAnimalValidation.cs)。
- [制作脚本](../../Art/ForestAnimals/Scripts/build_assets.py) / [Unity 资源导入](../../Art/ForestAnimals/Scripts/import_assets.cs) / [森林实际显示预览](../../Art/ForestAnimals/Scripts/preview_forest.cs)。
