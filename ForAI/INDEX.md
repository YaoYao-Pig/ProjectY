# ForAI · 入口

关键词：框架、业务、Lua、UI、配表、编辑器、文档维护。

## 文档目录

| 任务关键词 | 按需读取 |
| --- | --- |
| Lua 风格、需求澄清、过度防御、Unity MCP、最小测试、编译、SubAgent | [开发约束 Skill](../.agents/skills/lua-code-style/SKILL.md) |
| 设计盘点、玩法差距、未实现、待办、职业划分、自由转职、跨职业学习、主动选学、触媒、专精、战前部署、准备技能、部署道具、直射、抛射、开发顺序 | [玩法设计与实现差距清单](../Docs/GameplayGapAudit.md)（2026-10-11 盘点，2026-10-13 补充职业、触媒与战前部署设计；含未来方案，不替代模块当前契约） |
| 码头、破损码头、码头修复、临水城市、城市水域、码头工人、付费坐船、快速旅行、购船、自由航行、野外停靠 | [码头与水上旅行](Business/WaterTravel.md)、[设计依据](../Docs/DocksAndWaterTravelDesign.md) |
| 优势判定、优势检定、两次取最高、高点射击、沟通后驯服、CheckRoll | [共享判定与骰子](Business/Dice.md)、[高地命中](Business/Battle.md)、[沟通驯服](Business/Animals.md)；[设计与验证边界](../Docs/AdvantageCheckDesign.md)（首版已接入，实机未验收） |
| 职业触媒部署验收、联合存档、基础玩法迭代、Play 验收、准备道具 | [基础玩法迭代验收](../Docs/GameplayFoundationIteration.md)（已执行范围与复验入口） |
| 新职业、技能扩展、兼职联动、炼金师、吟游诗人、神官、咒术师、决斗家、驯兽师 | [职业战斗契约](Business/ProfessionCombat.md)、[职业探索与单挑](Business/ProfessionExploration.md)、[设计依据](../Docs/ProfessionExpansionDesign.md)；动物指令见动物模块 |
| 内容接入复盘、启动报错、缺交易价格、独立特效重复、挂点数量不一致、共享Prefab、防回归 | [内容接入报错复盘](../Docs/ContentIntegrationErrorsPostmortem.md)（2026-10-25三项错误的原因、修复证据与验证缺口） |
| 营地关系战利品验收、技能图标异常、入口整理、v6验收、待同步资源 | [营地／关系／战利品迭代](../Docs/GameplayExpansionIteration.md)（源码与数据层结果，原生资源及本轮实机验收尚未完成） |
| LuaConsole、Python、运行时注入、执行片段、调试控制台 | [LuaConsole](Tools/LuaConsole.md) |
| 3C、相机、镜头、拖拽、平移、旋转、缩放、角色跟随、StrategyCameraRig | [俯视镜头与操控](Business/CameraControls.md) |
| GM、GMSystem、GM 面板、F8、指定槽位升级、按技能 ID 获取技能、查找 NPC、NPC 搜索、传送定位、开全图、全图视野、秒杀、点选目标、投骰子、骰子组合、免随机遇敌、遇敌开关 | [GM 调试系统](Tools/GM.md) |
| Blender、MCP、建模、FBX、贴图、材质、模型导入、Prefab | [Blender 资源管线](Tools/Blender.md) |
| 大地图美术、low-poly、低多边形、模型风格、地块模型、民居模型、中世纪城堡、森林树、雪松、地牢模型、七格平台、MapLowPoly | [地图模型资源](Business/MapArt.md) |
| 事件插图、剧情配图、冒险者插画、平涂、细线、漫画、去脏纹理、插画风格 | [事件插画风格 Skill](../.agents/skills/event-illustration-style/SKILL.md) |
| 骰子、检定、投掷、D4、D6、D8、D10、D12、D20、百分比、DiceRoll | [实体检定骰子](Business/Dice.md) |
| 启动、LuaSystem、注册、Tick、require、Lua 文件、构建、xLua 桥接、退出 | [运行时](Framework/Runtime.md) |
| Audio、BGM、音乐、音效、击中、受击、淡入淡出、音量、CC0、Wwise | [音乐与战斗音效](Framework/Audio.md) |
| URP、渲染管线、后处理、像素风、PixelArt、色阶、抖色、奇幻光影、MedievalFantasy、WarmFantasy、丁达尔、光束、天空、薄雾、体积光、HDR、F9、风格切换、SSAO、Bloom、阴影、材质迁移、离屏相机 | [渲染管线](Framework/Rendering.md) |
| Panel、Widget、MVC、LuaReference、UIRoot、WorldUIRoot、WorldUI、AnimationWrap、UI 动效、按名称播放、暂停、场景切换 | [UI](Framework/UI.md) |
| UI 换皮、底图、切图、九宫格、ArtSkin、GuildMatte、CollageMatte、皮革、拼贴、哑光、奖励图标、3D 预览保护 | [UI 美术换皮](Tools/UIArtSkins.md) |
| 字体、Typography、思源宋体、霞鹜文楷、Noto Sans、中文字体、英文字体、字重、数字字体、字体授权 | [UI 字体规则](Tools/UITypography.md) |
| Loading、Loding、加载界面、进度条、创建世界加载、加载世界、读档进度、建议、骚话、随机文案 | [Loading](Framework/Loading.md) |
| UIScrollList、无限滚动、虚拟列表、ScrollRect、CellTemplate、多模板、可变尺寸、列表复用 | [UIScrollList](Framework/UIScrollList.md) |
| JSON 表、导表、二进制、读表、公式、枚举、常量、Catalog、C# 查表、_Gen、生成目录、产物迁移 | [配置管线](Framework/Config.md) |
| Condition、条件组合、all、any、not、前置、后置、条件类型扩展 | [共享条件](Framework/Condition.md) |
| Mission、Quest、网状叙事、任务、领取界面、任务结算、EXP+、奖励卡片、对话、队员插话、自动发言、点名、特质条件、经历条件、NPC、招募、好感、阵营、声望、日程、Cinemachine | [任务对话与 NPC](Business/Narrative.md) |
| 随机任务、城镇委托、护送商队、附身、清剿、材料交付、NPC 感叹号、TownMission | [城镇随机委托](Business/TownMissions.md) |
| Mission 编辑器、Web 任务、叙事关系图、Agent 工具、CLI、批量变更、影响分析、4179 | [叙事工坊与 Agent 工具](Tools/Narrative.md) |
| text、本地化、i18n、禁止硬编码、中文字符串、玩家提示、UI 文案、格式模板、Language.lua、LuaLanguage、LuaTxt、UITxt、PrefabTxt、TMP | [玩家可见文本与本地化约束](Framework/Localization.md) |
| Player、金币、等级、奖励、示例流程、Data、ModelSystem | [玩家示例](Business/Player.md) |
| Battle、战斗、借机攻击、贴身移动、opportunityAttack、分段移动、剩余移动距离、原地战斗、回合、行动点、高地、命中、射程、直射、抛射、弹道、trajectory、拦截概率、35/50、友伤、ProjectileCombat、追踪散射、手选目标、敌方 AI | [六边形战斗](Business/Battle.md) |
| 战斗 UI、BattleHUD、技能栏、悬停、选中反馈、目标确认、取消多选、命中预览、友伤风险、物品槽、行动顺序、AP、Sprite、图标配置、自适应 | [战斗 HUD](Business/BattleHUD.md) |
| 技能图标生成、低细节、像素图标、生成配方、图标版本、SkillIconRecipeTable、SkillIconStyleTable | [技能图标生成管线](Tools/SkillIcons.md) |
| 技能图标风格、简洁像素、大色块、单主体、图标美术验收、pixel-simple-v1 | [技能图标美术风格](Business/SkillIconArt.md) |
| 技能说明、装备描述、触发收益限制、技能Tips、Tooltip、彩色标签、术语、TMP link、下划线、协同效应、问号遮罩、bitset、符文发现 | [技能说明与协同发现](Business/SkillTips.md) |
| 巧匠、营造、栅栏、木墙、高台、铲子挖掘、坑洞、壕沟、施工材料、Construction | [巧匠营造与战斗地形](Business/Construction.md) |
| BuffTable、Buff、Debuff、追踪、manualEnemyTargets、ignoreProjectileBlockers、再生、流血、中毒、燃烧、潮湿、眩晕、互斥、分钟 Buff、GameEffect、GAS、持续效果、周期伤害、治疗、叠层、状态图标、战后保留 | [GameEffect](Business/GameEffects.md) |
| 战斗特写、慢动作、运镜、SceneFocusMask、物体交互 HUD、E 提示、交互按键、状态飘字、MainHud、常驻 HUD、Overlay、UIFollower、屏幕血条、脚下圆环、世界空间血条、圆环遮挡、HP AP 同心圆、弧形文字、双层血条、伤害数字、飘字、暴击、震屏、BattleFeedbackSystem、相机跟随、地点、地点标签、Tag、远近景、悬停抬升、SceneFocusMask、逆遮罩、队伍、交互提示 | [主 HUD 与跟随 UI](Business/MainHud.md) |
| 破甲弹、肉弹、综合弹、穿甲率、弹种、装备、长枪、捕潮长枪、最小射程、品质、词缀、附魔、熟练、传奇、破损、武器分类、等级、属性要求、单手剑、大剑、双手巨剑、扩充槽位、四槽工坊、握柄、柄尾配重、弓臂、弓弦、枪口、枪托、grip、pommel、bowlimb、bowstring、muzzle、stock、槽位引线、法杖、符文、转施、allowTransfer、transferSelf、步枪、突击步枪、狙击枪、霰弹枪、暴击、弹匣、换弹、搜刮、3D 改装、EquipmentWorkbench | [装备与改装 Demo](Business/Equipment.md) |
| 具名传奇武器、传奇盾牌、比武骑枪、传奇外框、折光、残样、返场、共债、冲势、活榫迁筑 | [具名传奇装备](Business/LegendaryEquipment.md)；通用武器辉光、Shader与点光见[特效](Business/VisualEffects.md) |
| 创伤、伤势、部位血量、总生命、身体健康、四肢、躯干、永久致残、医疗、疾病、感染、抗感染药、创伤打击、急救包、BodyHealth、InjuryRules | [身体健康与创伤](Business/BodyInjuries.md) |
| 网格背包、Inventory、独立堆、分堆、同类合并、占格、拖拽、旋转、收纳、满包、头部、身体甲、左右戒指、裤子、鞋子、副手、双持、盾牌、角色预览、模型图标、图标导出 | [网格背包与角色装备](Business/Inventory.md) |
| 商店、商人、商品模板、随机商品、库存、售价、购买、补货、刷新天数 | [NPC 商店](Business/Shop.md) |
| Camp、配方合成、装备制作、独立营地入口、建设、生产订单、仓库、物资存取、等待生产 | [营地建设与生产](Business/Camp.md) |
| 队员关系、真实救援、共战、关系阶段、日期纪事、傲慢消除、守望者 | [队员关系与持久经历](Business/PartyStory.md) |
| 宝箱生成、容器、陶罐、板条箱、武器架、耐久、破坏、掉落、战利品、概率、掉落池、敌人掉落、战后拾取、旧事件战场 | [宝箱与敌人掉落](Business/Loot.md) |
| 工具性武器、武器标签、斧子、镐子、铲子、撬棍、清障、石堆、木箱、土堆、开锁 | [工具武器与临时障碍](Business/ToolWeapons.md) |
| 商队、游荡敌人、追击、强盗、巨狼、岩石巨兽、队伍棋子、旗帜、双向交易、WorldParties | [大地图可见队伍](Business/WorldParties.md) |
| 传奇生物、传奇人类、传奇特性、固定具名、友好生物、战前交流、和解、传奇委托、LegendaryEncounter | [传奇生物与具名人物](Business/Legends.md) |
| 势力、组织关系、关系树、势力 UI、势力发现、首次目击、未知势力、外交、实力、兽人劫掠、树精灵、据点攻陷、解放、恢复、三方混战、黄色第三方 | [势力关系与大地图冲突](Business/Factions.md) |
| 关系LOD、模拟LOD、渲染LOD、三级分级、100ms、相机外实例、视锥、模型池、摘要行程、远方结算 | [世界模拟与渲染 LOD](Business/WorldLOD.md) |
| 战争迷雾、雾 Shader、流动雾、WorldFog、大地图探索、已探索灰色、探索存档 | [世界探索与战争迷雾](Business/WorldFog.md) |
| 大地图旅行、行军、路线、改路、旅行暂停、倍速、沿途事件、随机遇敌、随机战场、WorldTravel | [大地图旅行与随机遭遇](Business/WorldTravel.md) |
| Adventure、探索事件、触发路径、设施交易、配件获取、选择、条件、营地、远征 Demo、战斗结算 | [探索事件与远征](Business/Adventure.md) |
| 特殊事件、骑士审判、神秘逃兵、比武审判、城镇周边、专属事件地图、支援盟军、受伤入队、定时恢复 | [特殊事件与招募](Business/SpecialEvents.md) |
| Growth、养成、升级、经验、属性加点、被动、网状天赋、技能池、潜力、经历、特质标签、CharacterGrowth、职业徽记、兼职网格、技艺图谱、技能浏览、两级分类、SkillAtlas、技能前置、技能 Tips | [角色养成与经历](Business/Progression.md) |
| 动物、动物交谈术、沟通投骰、动物亲和、魅力、驯服、中立、黄色框、坐骑、亲密度、骑兵、冲击、飞扑、跳跃、森林小地图、哥布林刷新 | [森林动物与骑乘](Business/Animals.md) |
| 主角小队、战棋棋子、人物模型、圆形底座、模块化装备、武器挂点、PawnLowPoly | [小队棋子资源](Business/PawnArt.md) |
| 动画、动作、骨骼、Humanoid、Avatar、蒙皮、Quaternius、UAL、双手握点、倒地 | [棋子动画](Business/PawnAnimation.md) |
| 粒子、特效、VFX、方块、立方体、技能表现、物品拾取、装备发光、VisualEffectTable、特效预览 | [技能与物品方块特效](Business/VisualEffects.md) |
| 捏人、脸型、体型、男女、精灵、哥布林、龙人、兽人、模块化角色、随机外观 | [角色定制](Business/PawnCustomization.md) |
| 角色样貌、二次元、杏仁眼、发束、头脸、网格破面、拓扑更新 | [角色定制](Business/PawnCustomization.md) |
| 建筑优化、木筋房、风车、磨坊、谷仓、麦田、稻草人、TownStylized | [城镇建筑美术](Business/TownArt.md) |
| 所有建筑可进入、装饰建筑、住宅室内、多门、门楼塔房、TownOpenBuildings | [城镇街区与漫游](Business/TownArea.md) |
| 开始菜单、StartMenu、世界命名、世界名称、开场身世、12种开场、CampaignStart、基础武器、开局物资、种子输入、世界大小、多存档、选择存档、继续游戏、保存远征、随机开局、探索存档、角色存档、保存队伍、读取队伍、背包存档、磁盘保存 | [远征与角色存档](Business/CharacterSave.md) |
| 攻击模组、剑盾、共持、双持、枪型、offset、Vector3、武器握点、武器朝向、旋转修正、持握组合 | [持武模组与握点](Business/EquipmentMotion.md) |
| 角色工坊、角色网页、Character Lab、真实 Unity 资源、随机预览、握点编辑、offset 可视化、自动保存、4177 | [角色网页预览](Tools/CharacterPreview.md) |
| 城镇小地图、走格子、点击移动、高位跟随、二楼、楼梯、楼板剖切、逛街、居民、工匠、巡游、酒馆、铁匠铺、商店、公会、广场、露天摊位、山城、联排、台地、台阶、坡道、上下层道路、街桥、连续室内、真实比例、米制、屋顶隐藏、面包房、药草铺、礼拜堂、仓库、马厩、瞭望塔、TownExpansionLowPoly、TownInteriorLowPoly、TownLowPoly | [城镇街区与漫游](Business/TownArea.md) |
| 地块材质、地貌贴图、自然分布、灌木、草束、蝴蝶、虫群、铺装、城内外地面、地牢墙地、苔藓、木板、昼夜、天气、黄昏、环境光、雾、室内暖灯、火炬、便携照明、MapEnvironmentController | [地图材质与环境表现](Business/MapPresentation.md) |
| 装饰物、倒木、芦苇、石井、货车、晾晒架、矿道木架、遗骨、晶簇、MapDressingLowPoly | [地图环境装饰](Business/MapDressing.md) |
| 王城、最高档城镇、宫殿、御苑、非对称城市、分区生长、临街选址、等高线、街网、RoyalTown | [王城 MapArea](Business/RoyalTown.md) |
| 高山、巍峨、峡谷、黑暗谷底、山腰云雾、参天巨树、奇观、绳索、巨根、NaturalEntrances | [自然地标](Business/NaturalLandmarks.md) |
| MapArea、小地图、局部探索、地牢内部、三层混合生成、功能分区、组团、预设房间、变宽通道、多格设施、陈设、墙壁、迷雾、视线、探索格子高亮、距离渐隐、原地战斗、96×96 | [MapArea 局部地图](Business/MapArea.md) |
| 沉船、废弃船只、Shipwreck、开阔水域、水上遗址、科克船、中型副本、下舱、主甲板、船艏高台、三层船形、桌面小物 | [沉船遗址](Business/Shipwreck.md) |
| 矿井、矿洞、废弃矿道、Mine、三层矿井、分层探索、坍塌、破损楼板、透视下层、木支架、矿车、矿轨 | [矿井地牢](Business/Mine.md) |
| Map、MapGenerator、Region、Border、种子地图、六边形、噪声、山脊、森林、冰雪、湖泊、跨区河流、支流、瀑布、水位、MapAssetTable、MapBiomeTable、边界混合、城镇、建筑占地、道路、地图查询、地牢、隐居群落、与世隔绝、矮屋、地图大小、目标格数、十万格 | [地图](Business/Map.md) |
| 地图预览、地图实验室、Editor 菜单、启动器、Web、Map Lab、柱体、算法调试、4175 | [地图预览工具](Tools/MapPreview.md) |
| 地图测试场景、Unity 地图、Play、运行时地图、MapRuntimePreview、MapRuntimeDemo、配置模型、瀑布预览、流水效果、湖面、分层波纹、水花粒子 | [Unity 地图运行测试](Tools/MapRuntimePreview.md) |
| Web 服务、注册表、一键启动、停止全部、服务管理、4173、4175 | [Web 服务管理](Tools/WebServices.md) |
| PanelGenerator、生成 Prefab、PanelConfig 编辑、模块目录、EmmyLua | [UI 生成器](Tools/PanelGenerator.md) |
| 配表网页、增列、表头、目录、模块根节点、总览、保存、409、前端 | [配置编辑器](Tools/ConfigEditor.md) |
| 一站式、内容中心、可视化配表、物品编辑、武器编辑、特殊角色、模型选择、初始装备、MCP、4181 | [内容编辑中心](Tools/ContentCenter.md) |
| 新增文档、更新文档、索引、阅读规则、skill | [维护约定](MAINTENANCE.md) |

## 正文

- 起步只读本索引和最相关的一篇；跨模块才追加对应文档。实现或排错时按“关键入口”定位符号，再读取必要代码。
- `Framework/` 记录通用契约，`Business/` 记录实际玩法，`Tools/` 记录开发工具；尚未实现的模块不建空文档。
- 模块文档只记录当前实现及修改约束。代码与文档不符时核对代码并修正文档；不把规划视为现有能力。

## 关键入口

- [README](../README.md)：运行步骤；[完整架构](../Docs/Architecture.md)：需要详细示例或协议说明时读取。
- [验证记录](../Docs/Validation.md)：历史验证范围，不代表本次修改已测试。
- [AGENTS.md](../AGENTS.md)：自动阅读入口；[维护约定](MAINTENANCE.md)：写文档时才展开。
