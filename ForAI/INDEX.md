# ForAI · 入口

关键词：框架、业务、Lua、UI、配表、编辑器、文档维护。

## 文档目录

| 任务关键词 | 按需读取 |
| --- | --- |
| Lua 风格、需求澄清、过度防御、Unity MCP、最小测试、编译、SubAgent | [开发约束 Skill](../.agents/skills/lua-code-style/SKILL.md) |
| LuaConsole、Python、运行时注入、执行片段、调试控制台 | [LuaConsole](Tools/LuaConsole.md) |
| Blender、MCP、建模、FBX、贴图、材质、模型导入、Prefab | [Blender 资源管线](Tools/Blender.md) |
| 大地图美术、low-poly、低多边形、模型风格、地块模型、民居模型、中世纪城堡、森林树、雪松、地牢模型、七格平台、MapLowPoly | [地图模型资源](Business/MapArt.md) |
| 启动、LuaSystem、注册、Tick、require、Lua 文件、构建、xLua 桥接、退出 | [运行时](Framework/Runtime.md) |
| Panel、Widget、MVC、LuaReference、UIRoot、WorldUIRoot、WorldUI、暂停、场景切换 | [UI](Framework/UI.md) |
| JSON 表、导表、二进制、读表、公式、枚举、常量、Catalog、C# 查表、_Gen、生成目录、产物迁移 | [配置管线](Framework/Config.md) |
| text、本地化、Language.lua、LuaTxt、UITxt、PrefabTxt、i18n、TMP | [本地化](Framework/Localization.md) |
| Player、金币、等级、奖励、示例流程、Data、ModelSystem | [玩家示例](Business/Player.md) |
| Battle、战斗、原地战斗、敌群、回合、行动点、技能、效果、属性、特质、敌方 AI | [六边形战斗](Business/Battle.md) |
| 战斗 UI、BattleHUD、技能栏、物品槽、行动顺序、AP、Sprite、图标配置、自适应 | [战斗 HUD](Business/BattleHUD.md) |
| 装备、法杖、符文、步枪、弹匣、换弹、搜刮、宝箱、共享背包、3D 改装、持握动作、EquipmentWorkbench | [装备与改装 Demo](Business/Equipment.md) |
| Adventure、探索事件、选择、条件、营地、远征 Demo、战斗结算 | [探索事件与远征](Business/Adventure.md) |
| 主角小队、战棋棋子、人物模型、圆形底座、模块化装备、武器挂点、PawnLowPoly | [小队棋子资源](Business/PawnArt.md) |
| 城镇小地图、第三人称、逛街、居民、工匠、巡游、酒馆、铁匠铺、商店、公会、广场、露天摊位、山城、联排、台地、台阶、坡道、上下层道路、街桥、连续室内、真实比例、米制、屋顶隐藏、面包房、药草铺、礼拜堂、仓库、马厩、瞭望塔、TownExpansionLowPoly、TownInteriorLowPoly、TownLowPoly | [城镇街区与漫游](Business/TownArea.md) |
| 地块材质、铺装、城内外地面、昼夜、天气、黄昏、环境光、雾、室内暖灯、MapEnvironmentController | [地图材质与环境表现](Business/MapPresentation.md) |
| 王城、最高档城镇、宫殿、御苑、非对称城市、分区生长、临街选址、等高线、街网、RoyalTown | [王城 MapArea](Business/RoyalTown.md) |
| MapArea、小地图、局部探索、地牢内部、三层混合生成、功能分区、组团、预设房间、变宽通道、多格设施、陈设、墙壁、迷雾、视线、原地战斗、96×96 | [MapArea 局部地图](Business/MapArea.md) |
| Map、MapGenerator、Region、Border、种子地图、六边形、噪声、山脊、森林、冰雪、湖泊、跨区河流、支流、瀑布、水位、MapAssetTable、MapBiomeTable、边界混合、城镇、建筑占地、道路、地图查询、地牢、隐居群落、与世隔绝、矮屋、地图大小、目标格数、十万格 | [地图](Business/Map.md) |
| 地图预览、地图实验室、Editor 菜单、启动器、Web、Map Lab、柱体、算法调试、4175 | [地图预览工具](Tools/MapPreview.md) |
| 地图测试场景、Unity 地图、Play、运行时地图、MapRuntimePreview、MapRuntimeDemo、配置模型、瀑布预览 | [Unity 地图运行测试](Tools/MapRuntimePreview.md) |
| Web 服务、注册表、一键启动、停止全部、服务管理、4173、4175 | [Web 服务管理](Tools/WebServices.md) |
| PanelGenerator、生成 Prefab、PanelConfig 编辑、模块目录、EmmyLua | [UI 生成器](Tools/PanelGenerator.md) |
| 配表网页、增列、表头、目录、模块根节点、总览、保存、409、前端 | [配置编辑器](Tools/ConfigEditor.md) |
| 新增文档、更新文档、索引、阅读规则、skill | [维护约定](MAINTENANCE.md) |

## 正文

- 起步只读本索引和最相关的一篇；跨模块才追加对应文档。实现或排错时按“关键入口”定位符号，再读取必要代码。
- `Framework/` 记录通用契约，`Business/` 记录实际玩法，`Tools/` 记录开发工具；尚未实现的模块不建空文档。
- 模块文档只记录当前实现及修改约束。代码与文档不符时核对代码并修正文档；不把规划视为现有能力。

## 关键入口

- [README](../README.md)：运行步骤；[完整架构](../Docs/Architecture.md)：需要详细示例或协议说明时读取。
- [验证记录](../Docs/Validation.md)：历史验证范围，不代表本次修改已测试。
- [AGENTS.md](../AGENTS.md)：自动阅读入口；[维护约定](MAINTENANCE.md)：写文档时才展开。
