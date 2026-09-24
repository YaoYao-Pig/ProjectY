# 王城 MapArea

关键词：王城、宫殿、最高档城镇、RoyalTown、御苑、分区生长、非对称街网、临街选址、等高线、门楼、桥廊。

## 文档目录

正文：入口与配置 / 地形与街区规划 / 资源与验证；关键入口：源表、策略、研究资料、模型、预览。

## 正文

- 王城是 Town 类型的独立配方：`MapTownTable.id=6 → MapAreaEntranceTable → MapAreaTable.id=6/profileId=5`。大地图仍复用配置里的城堡、集会厅和民居；内部使用新宫殿资源。全图王城上限 1，大城市上限从 3 调为 2，所有聚落的总预算仍为 16；选址沿用城市的地形/水体评分，有限候选不足时不强行放置。
- 默认采样范围 128×128、半径 1.5，已检查种子的公共可走部分约 2900 格；不是把整个采样矩形都铺成城市。菜单 `Project Y/地图/打开王城漫游测试` 打开 AdventureDemo，用户自行 Play，选择地点“王城”；操控和功能边界沿用[城镇漫游](TownArea.md)。静态布局按地点缓存，修改算法后应重新开始一次远征，离开再进入同一地点不会重生成。
- `MapAreaTownTable.royalLayoutIds` 为空时保留原山城策略；非空选择 `MapAreaRoyalTable`。该表控制不对称城界、弯曲台地、各层错位阶梯、偏置低径/桥、道路代价与地块评分。`MapAreaRoyalDistrictTable` 定义独立的宫苑、城门、市集、工坊、东坡住宅、御苑及坡心旧街七个中心及偏移。`MapAreaRoyalPlacementTable.localQ/localR` 是相对于片区中心的意图位置，配合搜索半径、朝向候选、生成阶段和必需标记选址；`MapAreaTownLotTable → MapAssetTable` 决定完整占地与模型。
- `RoyalTownPlanner` 先安置必需地标/设施，再按目的地连接主街并补回路，随后逐组生长临街住宅，最后布置可选景观。道路复用 Dijkstra，但邻接来自真实分层地形图；代价考虑爬升、低频空间变化和已有道路。地块评分考虑片区目标、临街距离、住宅聚集与种子变化，门前保留至少三个通行邻格；整块必须平坦且不侵占街道/台阶，每次占地后校验公共空间连通。必需地块无解明确报错，可选景观在 `planningDiagnostics.skipped` 记录原因。`districts/roadPaths/planningDiagnostics` 只属于冻结后的生成布局，不新增运行时权威状态。
- 宫殿为一栋完整建筑，显示拆为结构和可隐藏上盖；占地扣除 U 形中庭及可走门厅，门楼只占双塔地面，中央门洞可走。连续室内、服务点、米制尺寸与剖切规则见[城镇街区](TownArea.md)。喷泉、花坛、凉亭和雕像占地阻挡，台地石栏与挡墙共享边缘占地，不能从栏杆处直接跨崖。
- 四层高度为 0/4.5/9/13.5 米，乘来源 Region 的 `reliefScale`；阶梯、坡道、石桥继续用 `TownTerrain.Connect` 生成唯一邻接图。桥面为独立 layer=1，桥下保留 layer=0，基础净空为 4.2 米。主街铺装通常三格宽、支巷一格宽；铺装之外的合法公共地面也可行走，扩宽仅沿通行图，不跨崖或串层；坡道与变化后的外边界保留配置净距，避免产生不可达碎片。四人移动、NPC、拾取与交互均按同一图处理。
- 默认含王宫接见厅、王家喷泉广场、酒馆、铁匠铺、商店、公会及面包房、药草铺、小礼拜堂、仓库、马厩、瞭望塔，共 12 项设施、42 栋住宅、28 名居民/工匠；模型实例数随合法地块和挡墙长度变化。宫殿自身保留双翼对称，中庭外的街区不再镜像复制；来源 Region 继续影响地色与高差。10 类设施首层（瞭望塔为底层值守室）和王宫门厅可直接步行进入；介绍点位于室内，未实现交易或宫廷玩法。论文与真实城市参考、适配边界见[规划说明](../../Art/RoyalTownLowPoly/Integration/organic-planning-notes.md)。
- `MapAreaRenderer` 的城镇相机障碍由模型包围盒与阻挡占地相交得到，开放中庭/门洞不会再被整栋 AABB 封死。此处是显示避障近似；地形/桥面另外使用真实三角面射线，不改变玩法通行。
- 王城资产 ID 54–63：宫殿、门楼、凉亭、喷泉、雕像、花坛、柏树、桥栏、台地栏杆、拱券挡墙。旧宫殿保留；当前使用新米制空心宫殿（ID 72/73），约 43.23×25.21×34 米，结构与上盖共 36628 三角面，高度不再随半径放大。沿用纯色哑光硬边，王城使用暖石、象牙轮廓、暗莓色屋顶与少量旧金色。四类米制设施、上盖和三种紧凑联排为 ID 64–76，位于 `TownInteriorLowPoly`。
- 源和暂存位于 `Art/RoyalTownLowPoly/`，Unity 模型与独立材质位于 `Assets/DynamicAsset/RoyalTownLowPoly/`。源 .blend 不放入 Assets；FBX 导出与轴向沿用[地图资源约定](MapArt.md)。新资源须定向导入、同步受影响的配置 TextAsset，再同步场景引用，不能以文件已复制代替导入完成。
- **当前检查（2026-09-25）**：普通四配方、王城多种子/Region 与四人路线通过；扩展原生预览读取 12 项设施、28 名 NPC、113 个模型实例，完成 11 处室内进出、交互、上盖/镜头障碍恢复与重进。见[扩展检查报告](../../Art/TownExpansionLowPoly/Integration/preview.json)。材质和环境框架见[地图表现](MapPresentation.md)；旧图保留对照，当前日间全景见[扩展全景](../../Art/TownExpansionLowPoly/Previews/city-12.png)。

## 关键入口

- [王城配方](../../Config/Tables/MapArea/MapAreaRoyalTable.json) / [功能片区](../../Config/Tables/MapArea/MapAreaRoyalDistrictTable.json) / [地块意图](../../Config/Tables/MapArea/MapAreaRoyalPlacementTable.json) / [城镇配方](../../Config/Tables/MapArea/MapAreaTownTable.json)。
- [生成策略](../../Lua/Game/MapArea/RoyalTownGenerator.lua) / [台地与桥](../../Lua/Game/MapArea/RoyalTownTerrain.lua) / [街网与选址](../../Lua/Game/MapArea/RoyalTownPlanner.lua) / [通行检查](../../Tools/Tests/royal_town.lua) / [规划检查](../../Tools/Tests/royal_planning.lua)。
- [Blender 源](../../Art/RoyalTownLowPoly/Source/RoyalTown.blend) / [建模](../../Art/RoyalTownLowPoly/Scripts/build_royal.py) / [导出](../../Art/RoyalTownLowPoly/Scripts/export_royal.py) / [导入](../../Art/RoyalTownLowPoly/Scripts/import_royal.cs)。
- [初始配置迁移](../../Art/RoyalTownLowPoly/Scripts/configure_royal.py) / [分区规划迁移](../../Art/RoyalTownLowPoly/Scripts/configure_organic.py)：仅保留初次配置记录；后续调表直接编辑源 JSON，不重放脚本覆盖用户调整。
- [模型清单](../../Art/RoyalTownLowPoly/Integration/models.json) / [Unity 尺寸、材质、GUID](../../Art/RoyalTownLowPoly/Integration/unity-import.json) / [原生预览检查](../../Art/RoyalTownLowPoly/Integration/royal-preview.json)。
- [全景](../../Art/RoyalTownLowPoly/Previews/royal-overview.png) / [宫殿](../../Art/RoyalTownLowPoly/Previews/royal-palace.png) / [街景](../../Art/RoyalTownLowPoly/Previews/royal-street.png) / [桥上](../../Art/RoyalTownLowPoly/Previews/royal-bridge.png) / [桥下](../../Art/RoyalTownLowPoly/Previews/royal-underpass.png)。
- [预览 C#](../../Art/RoyalTownLowPoly/Scripts/preview_royal.cs) / [真实远征命令脚本](../../Art/RoyalTownLowPoly/Scripts/preview_royal.lua)：由 Unity MCP 在 Edit Mode 执行，临时预览场景在 finally 关闭，不生成项目验证程序集。
- [新布局全景](../../Art/RoyalTownLowPoly/Previews/royal-organic-overview.png) / [俯视街网](../../Art/RoyalTownLowPoly/Previews/royal-organic-plan.png) / [市集](../../Art/RoyalTownLowPoly/Previews/royal-organic-market.png) / [布局预览报告](../../Art/RoyalTownLowPoly/Integration/royal-organic-preview.json)：对应独立规划快照预览，不含远征状态验收。

- [新版城镇全景](../../Art/TownInteriorLowPoly/Previews/city-overview.png) / [连续进入宫殿](../../Art/TownInteriorLowPoly/Previews/palace-interior-plan.png) / [新版预览入口](../../Art/TownInteriorLowPoly/Scripts/preview_interiors.cs)：当前米制室内版本。上面的旧王城与 organic 图片保留为历史对照。
