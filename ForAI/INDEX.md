# ForAI · 入口

关键词：框架、业务、Lua、UI、配表、编辑器、文档维护。

## 文档目录

| 任务关键词 | 按需读取 |
| --- | --- |
| Lua 风格、需求澄清、过度防御、Unity MCP、最小测试、编译、SubAgent | [开发约束 Skill](../.agents/skills/lua-code-style/SKILL.md) |
| LuaConsole、Python、运行时注入、执行片段、调试控制台 | [LuaConsole](Tools/LuaConsole.md) |
| GM、GMSystem、GM 面板、F8、指定槽位升级、按技能 ID 获取技能、查找 NPC、NPC 搜索、传送定位 | [GM 调试系统](Tools/GM.md) |
| Blender、MCP、建模、FBX、贴图、材质、模型导入、Prefab | [Blender 资源管线](Tools/Blender.md) |
| 大地图美术、low-poly、低多边形、模型风格、地块模型、民居模型、中世纪城堡、森林树、雪松、地牢模型、七格平台、MapLowPoly | [地图模型资源](Business/MapArt.md) |
| 启动、LuaSystem、注册、Tick、require、Lua 文件、构建、xLua 桥接、退出 | [运行时](Framework/Runtime.md) |
| URP、渲染管线、后处理、像素风、PixelArt、色阶、抖色、奇幻光影、MedievalFantasy、WarmFantasy、丁达尔、光束、天空、薄雾、体积光、HDR、F9、风格切换、SSAO、Bloom、阴影、材质迁移、离屏相机 | [渲染管线](Framework/Rendering.md) |
| Panel、Widget、MVC、LuaReference、UIRoot、WorldUIRoot、WorldUI、AnimationWrap、UI 动效、按名称播放、暂停、场景切换 | [UI](Framework/UI.md) |
| UIScrollList、无限滚动、虚拟列表、ScrollRect、CellTemplate、多模板、可变尺寸、列表复用 | [UIScrollList](Framework/UIScrollList.md) |
| JSON 表、导表、二进制、读表、公式、枚举、常量、Catalog、C# 查表、_Gen、生成目录、产物迁移 | [配置管线](Framework/Config.md) |
| Condition、条件组合、all、any、not、前置、后置、条件类型扩展 | [共享条件](Framework/Condition.md) |
| Mission、Quest、网状叙事、任务、对话、NPC、招募、好感、阵营、声望、日程、Cinemachine | [任务对话与 NPC](Business/Narrative.md) |
| Mission 编辑器、Web 任务、叙事关系图、Agent 工具、CLI、批量变更、影响分析、4179 | [叙事工坊与 Agent 工具](Tools/Narrative.md) |
| text、本地化、Language.lua、LuaTxt、UITxt、PrefabTxt、i18n、TMP | [本地化](Framework/Localization.md) |
| Player、金币、等级、奖励、示例流程、Data、ModelSystem | [玩家示例](Business/Player.md) |
| Battle、战斗、原地战斗、敌群、回合、行动点、技能、效果、属性、特质、敌方 AI | [六边形战斗](Business/Battle.md) |
| 战斗 UI、BattleHUD、技能栏、物品槽、行动顺序、AP、Sprite、图标配置、自适应 | [战斗 HUD](Business/BattleHUD.md) |
| 巧匠、营造、栅栏、木墙、高台、铲子挖掘、坑洞、壕沟、施工材料、Construction | [巧匠营造与战斗地形](Business/Construction.md) |
| GameEffect、GAS、持续效果、周期伤害、治疗、Buff、叠层、状态图标、战后保留 | [GameEffect](Business/GameEffects.md) |
| MainHud、常驻 HUD、Overlay、UIFollower、屏幕血条、双层血条、震屏、BattleFeedbackSystem、相机跟随、地点、队伍、交互提示 | [主 HUD 与跟随 UI](Business/MainHud.md) |
| 装备、武器分类、等级、属性要求、单手剑、大剑、双手巨剑、推进器、槽位引线、法杖、符文、步枪、弹匣、换弹、搜刮、共享背包、3D 改装、持握动作、EquipmentWorkbench | [装备与改装 Demo](Business/Equipment.md) |
| 网格背包、Inventory、占格、拖拽、旋转、收纳、满包、头部、身体甲、左右戒指、裤子、鞋子、副手、双持、盾牌、角色预览、模型图标、图标导出 | [网格背包与角色装备](Business/Inventory.md) |
| 商店、商人、商品模板、随机商品、库存、售价、购买、补货、刷新天数 | [NPC 商店](Business/Shop.md) |
| 宝箱生成、容器、陶罐、板条箱、武器架、耐久、破坏、掉落、战利品、概率、掉落池、敌人掉落、战后拾取、旧事件战场 | [宝箱与敌人掉落](Business/Loot.md) |
| 工具性武器、武器标签、斧子、镐子、铲子、撬棍、清障、石堆、木箱、土堆、开锁 | [工具武器与临时障碍](Business/ToolWeapons.md) |
| Adventure、探索事件、触发路径、设施交易、配件获取、选择、条件、营地、远征 Demo、战斗结算 | [探索事件与远征](Business/Adventure.md) |
| Growth、养成、升级、经验、属性加点、被动、网状天赋、技能池、潜力、经历、特质标签、CharacterGrowth、技艺图谱、技能浏览、两级分类、SkillAtlas、技能前置、技能 Tips | [角色养成与经历](Business/Progression.md) |
| 动物、动物亲和、魅力、驯服、中立、黄色框、坐骑、亲密度、骑兵、冲击、飞扑、跳跃、森林小地图、哥布林刷新 | [森林动物与骑乘](Business/Animals.md) |
| 主角小队、战棋棋子、人物模型、圆形底座、模块化装备、武器挂点、PawnLowPoly | [小队棋子资源](Business/PawnArt.md) |
| 动画、动作、骨骼、Humanoid、Avatar、蒙皮、Quaternius、UAL、双手握点、倒地 | [棋子动画](Business/PawnAnimation.md) |
| 捏人、脸型、体型、男女、精灵、哥布林、龙人、兽人、模块化角色、随机外观 | [角色定制](Business/PawnCustomization.md) |
| 角色样貌、二次元、杏仁眼、发束、头脸、网格破面、拓扑更新 | [角色定制](Business/PawnCustomization.md) |
| 建筑优化、木筋房、风车、磨坊、谷仓、麦田、稻草人、TownStylized | [城镇建筑美术](Business/TownArt.md) |
| 所有建筑可进入、装饰建筑、住宅室内、多门、门楼塔房、TownOpenBuildings | [城镇街区与漫游](Business/TownArea.md) |
| 角色存档、保存队伍、读取队伍、背包存档、磁盘保存 | [角色与背包存档](Business/CharacterSave.md) |
| 攻击模组、剑盾、共持、双持、枪型、offset、Vector3、武器握点、武器朝向、旋转修正、持握组合 | [持武模组与握点](Business/EquipmentMotion.md) |
| 角色工坊、角色网页、Character Lab、真实 Unity 资源、随机预览、握点编辑、offset 可视化、自动保存、4177 | [角色网页预览](Tools/CharacterPreview.md) |
| 城镇小地图、第三人称、高位跟随、二楼、楼梯、楼板剖切、逛街、居民、工匠、巡游、酒馆、铁匠铺、商店、公会、广场、露天摊位、山城、联排、台地、台阶、坡道、上下层道路、街桥、连续室内、真实比例、米制、屋顶隐藏、面包房、药草铺、礼拜堂、仓库、马厩、瞭望塔、TownExpansionLowPoly、TownInteriorLowPoly、TownLowPoly | [城镇街区与漫游](Business/TownArea.md) |
| 地块材质、铺装、城内外地面、地牢墙地、苔藓、木板、昼夜、天气、黄昏、环境光、雾、室内暖灯、MapEnvironmentController | [地图材质与环境表现](Business/MapPresentation.md) |
| 装饰物、倒木、芦苇、石井、货车、晾晒架、矿道木架、遗骨、晶簇、MapDressingLowPoly | [地图环境装饰](Business/MapDressing.md) |
| 王城、最高档城镇、宫殿、御苑、非对称城市、分区生长、临街选址、等高线、街网、RoyalTown | [王城 MapArea](Business/RoyalTown.md) |
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
