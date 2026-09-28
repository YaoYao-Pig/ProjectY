# 森林动物与骑乘

关键词：动物、动物亲和、魅力、驯服、中立、黄色框、坐骑、亲密度、骑兵技能、冲击、飞扑、跳跃、森林、哥布林。

## 文档目录

正文：状态与配置 / 森林与显示 / 验证；关键入口：规则 / 状态 / 资源。

## 正文

- `AnimalRules` 解释物种、驯服概率、占格与骑兵技能；`CombatActorData` 保存动物生命、归属、亲密度、随机状态及角色的 `MountedAnimal` 引用。驯服复用原动物实例，保留已有伤势，不复制一份坐骑生命。坐骑先承担每次攻击，归零后死亡并解除骑乘；该次溢出不传给角色，后续攻击正常伤害角色。
- `GrowthAttributeTable.animalAffinity/charisma` 均为可投入的生活属性，动物亲和可参与主动技能研习；是否参与由 `skillDirection` 决定，不按生活分类排除。`ActiveSkillPoolTable` 配置驯服门槛与权重。成功率由 `AnimalRuleTable` 的 `affinity/charisma/missingHealth/hostile/difficulty` 公式和概率上下限决定；仅敌对动物有伤势加成。
- `AnimalSpeciesTable.tameRetryTurns` 配失败后的动物重试间隔（首版马/鸡/兔为 3/2/3 回合）；剩余回合保存在动物实例，所有角色共享限制，重新部署和出入战斗不清零。`Config/Catalog.json` 的全局常量 `Global.ExplorationRoundSeconds` 定义探索回合时长（首版 3 秒）：只累计小队执行移动路线的游戏时间，停止、改道、离开区域保留不足一回合的余量，静止和暂停不累计。战斗完成整轮时推进一次区域回合，进入战斗的第一轮不额外推进。
- `AnimalSpeciesTable` 配战斗模板、可乘骑性、固定轴向占地、骑手髋部位置、骑乘移动格数、初始亲密度与共同战斗收益。首批马、鸡、兔均一格；连续多格占地要求包含原点且不重复，部署、移动、落点和占位检查均检查完整格罩。
- `AnimalSkillTable` 根据当前坐骑的物种与亲密度自动开放技能；坐骑死亡后不再提供该物种的技能。马冲击沿六向直线抵达目标前一格，路径不能穿过阻挡，伤害公式可读取实际冲刺 `distance`；鸡飞扑向目标前方跃进一格并攻击；兔跳跃为地格目标，最多三格，落点不能阻挡或被占据。高大视线阻挡限制原地形中的跃迁。
- 森林是独立 `E_MapAreaType.Forest` 生成策略。`MapAreaForestTable/ThemeTable` 定义林间空地、连通小径、树木密度和地面材质；`MapAreaForestEntranceTable` 在大地图真实森林 Region 创建入口；`MapAreaForestSpawnTable` 独立抽取物种组数、刷新概率与中立比例，哥布林使用限定哥布林的外观池。进入同一地点复用敌群和动物状态，新远征重建。
- 野生动物沿用区域遭遇实体；中立 Team=0 不主动触发战斗，黄色占地框与血条区别于敌对红色。已驯服动物从独立占格、野外显示和行动顺序中移除，由骑手占地与模型组合展示。驯服是同一个 `CombatSkillTable` 技能，`contexts={life,battle}`；探索中从 [MainHud 角色技能栏](MainHud.md) 选择角色、点击驯服，再点击中立动物；战斗中从技能栏对敌对动物使用。
- `PawnView/PawnAnimationView` 组合动物网格与 Humanoid 骑手坐姿；`PawnMotion` 仅表现冲刺/抛物线跳跃，不参与规则结算。坐骑存档嵌入现有角色存档，包含生命、物种、亲密度和随机状态；旧存档没有坐骑记录时仍可读取。
- 源模型位于 `Art/ForestAnimals/Source/ForestAnimals.blend`，FBX、独立纯色材质位于 `Assets/DynamicAsset/ForestAnimals/`。三只动物和阔叶树、针叶树、蕨类、六边形地面共七个模型；沿用项目已验证的轴向烘焙导出预设，Unity 根旋转为零、缩放为一，地面半径一米、顶面 Y=0。
- 最小纯 Lua 检查：`python -B Tools/Tests/run_lua.py Tools/Tests/forest_animals_core.lua`；涉及真实状态/技能命令时，编译及生成 xLua 绑定后用 Edit Mode 菜单 `Project Y/远征/验证森林动物与骑乘`。资源预览脚本经 Unity MCP 执行，创建并释放独立 PreviewScene，不进入 Play。

## 关键入口

- [动物规则](../../Lua/Game/Animals/AnimalRules.lua) / [权威状态](../../Assets/GameFramework/Runtime/Data/CombatActorAnimals.cs) / [配置源](../../Config/Tables/Animals/)。
- [森林生成](../../Lua/Game/MapArea/ForestGenerator.lua) / [刷新计划](../../Lua/Game/MapArea/ForestEncounters.lua) / [区域命令](../../Lua/Game/MapArea/MapAreaSystem.lua)。
- [规则检查](../../Tools/Tests/forest_animals_core.lua) / [真实状态检查](../../Tools/Tests/forest_animals_integration.lua) / [Edit Mode 入口](../../Assets/GameFramework/Editor/ForestAnimalValidation.cs)。
- [制作脚本](../../Art/ForestAnimals/Scripts/build_assets.py) / [Unity 资源导入](../../Art/ForestAnimals/Scripts/import_assets.cs) / [森林实际显示预览](../../Art/ForestAnimals/Scripts/preview_forest.cs)。
