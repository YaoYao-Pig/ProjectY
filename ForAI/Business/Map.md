# 地图生成与查询

关键词：Map、MapGenerator、MapRegion、Region、Border、种子、六边形、噪声、湖泊、河流、边界混合、森林、冰雪、主河、支流、瀑布、城镇、建筑占地、资源配置、道路、地图查询。

## 文档目录

正文：职责与生成 / 查询与边界 / 调用与验证；关键入口：生成 / 配置 / 测试。

## 正文

- 需求来源：[大地图](https://my.feishu.cn/wiki/VYw9wbMINiJ9B8k0SgqcAS34n1b)、[视角](https://my.feishu.cn/wiki/N3QGwWdw2iTym9kQBSScIsghn4g)。当前实现只读布局数据；未创建 Mesh、材质、相机、建筑/敌人实体或寻路规则。可变玩法状态仍归 C# Data，不把快照中的候选配置当成实体状态。
- `MapSystem` 依赖 Config，启动只创建生成器；调用 `Generate(seed, regionIds)` 才生成。seed 为 uint32，regionIds 为非空、连续的配置 ID 数组；重复 ID 生成独立实例。同种子、配表、配方顺序与 generationVersion 才保证相同结果，调用不改变全局 `math.random` 状态；系统不持有“当前地图”。
- generationVersion 当前为 4：先生成噪声扰动的不规则轮廓，保留中心连通块；从全图真实外沿最多尝试 64 次贴合，裁掉已占用格，保留不少于原轮廓 60% 的中心连通部分，优先更长的共享边。失败时从最东格向东继续，保证终止与连通；区域从不重复占格。`MapRegionConvertBase:Generate` 累积 draft，全部完成后统一过渡、旧水体整理、全图水系、城镇/道路、配置装饰、建立 Border，再冻结。
- `E_MapRegion` → converter/instance 类由 `MapSystem` 注册：Grassland=1（缓坡）、Mountain=2（多尺度山脊）、Lake=3（扰动盆地）、River=4（噪声曲流河谷）、Forest=5（林地丘陵）、Snow=6（冰雪高地）。新增类型需同时补 Catalog、MapRegionTable、MapBiomeTable 与注册。转换器 `GetHeight(config,q,r,random,noiseScale,region)` 返回地面高度、可选水位、lake/river 类型；会在邻区边界采样，所以必须能处理轮廓外坐标，不能修改随机流或布局。`ValidateConfig` 负责策略特有校验。
- minX/maxX、minY/maxY 保留 float，从 ceil(min) 到 floor(max) 抽整数作为 q/r **采样包围盒尺寸**，不再代表完整矩形或实际格子数。`Contains` 查询实际归属索引；中心必须保留。MaxCells 按最终格子数检查，采样包围盒面积另限制为 MaxCells 的两倍，避免在容量检查前分配极端轮廓。
- `SeededRandom` 的独立 uint32 随机流负责布局；Fractal/迭代振幅、Warp/坐标扰动、Ridged/折叠山脊均为带通道的纯位置采样，不推进布局随机流。区域表控制 shapeIrregularity、noiseScale（相对 Catalog 基础跨度）、roughness、warpStrength；水体策略另读 waterLevel、lakeSize/riverWidth。当前六行配置是可调整的技术样例。
- `TerrainBlend` 按六邻接距离混合附近策略在同一点的采样，Catalog `BorderBlendWidth` 控制宽度（0–12，0 关闭）；区域主体不做整图模糊。`baseHeight` 是所属策略原始高度，受其 minHeight/maxHeight 约束；混合后的高度在过渡带允许超出所属区范围，但处于参与采样包络内；随后水系可按开挖预算进一步降低最终 `height`，避免截断后重新形成台阶。`blendAmount` 表示邻区权重，`biomeWeights` 提供归一化地貌类型权重。格子所有权和候选配置不变。
- 水体仍是静态地形预览：`height` 为河床/湖床，`waterLevel` 为水面，`waterDepth` 为深度，`waterKind` 为 lake/river。`MapWater.Build` 先整理策略候选水域；水系生成后仅 `Reindex`，按连通且等高的水格分组 `GetWaterBodies()`，不再把不同高度河段压平。地图外缘允许出口；不模拟流量、侵蚀、游泳、桥梁或队伍通行。
- `MapHydrology` 读取 `MapWaterNetworkTable`（空表关闭、最多一行）：从低洼外沿出口构建无环下游树，高处选源，主河可跨多个 Region，支流汇入既有河段。每条候选先验证水位沿下游不升高、干岸高度与最大开挖预算，成立才写入。`GetRivers()` 包含有序 cells、source/mouth、rootId/parentRiverId 与 regionIds；格子以 riverId/flowTo 记录河段与直接下游。
- 跨 Region 的直接水流边达到 waterfallMinDrop 后按 waterfallChance 判定；下游须能在配置半径及开挖预算内形成至少三格连通落水潭，且不造成倒流，才生成 `GetWaterfalls()`。记录 from/to、最终 drop、riverId、poolCells；概率 0 关闭瀑布而保留河网。有限选址不保证每个种子都有瀑布。
- 六边形采用尖顶轴坐标 `(q,r)`，Unity 平面为 XZ，顶面高度为 Y。`FindCellAtWorld(x,z)` 忽略 Y，将点取整到最近格子中心；不等同于柱体射线检测。`FindCell`/`FindCellAtWorld` 越界返回 nil，`GetCell`/`GetRegion` 缺失报错；已声明但未生成的类型查询返回空集合，未知类型报错。
- Border 按相邻的**实例**聚合，每条共享六边形边仅记录一次，保存两侧 cell 与 B-A 高差；同类型实例仍有 Border，地图外缘不计为 Border。Region 提供 cells、neighborIds、borders 查询。
- `MapEnemyTable`/`MapBuildingTable` 的 regions 为 enum[]，候选查询与生成实体分开；敌人表仍为空。地牢、民居、工坊、集会厅、城堡为建筑 ID 1–5，分别由对应聚落样式引用后参与静态布局。
- `MapInfrastructure` 读取 `MapTownTable` 的小村庄、大城市、城堡领地、地牢遗址样式、地貌、数量、间距、搜索半径、试排次数和平整度，使用独立种子随机流选择平缓陆地。建筑表提供占地半径、墙高和屋顶高；占地完整、无重叠、干燥、位于本 Region，并保留到中心的入口街道。按 priority 降序选址；少于 minBuildings 或缺少 requiredBuildingIds 指定地标的试排整批放弃；不整平原地面，地基取占地最高点。maxCount 是上限而非保证数量，所有样式上限之和最多 16；空城镇表关闭生成。
- 城镇样式的 `groundColor` 使用 `#RRGGBB`，随 town 一起输出，负责大地图实际建筑占地的统一底色；城镇搜索半径内的空闲地面不因着色而变成建筑占地。城市等级与队伍进入城市尚未实现，现有 town.id/configId 分别保留实例与样式身份。
- `MapPathfinder` 提供生成期 Dijkstra；道路按近邻优先连接可达城镇并复用已铺路段。Catalog `RoadMaxStep` 限制邻格高差、`RoadSlopeCost` 控制坡度代价；禁止经过水格和建筑占地，不生成桥梁。路径不可达时保留多个 `roadNetworks`，不假造连接。这些规则只服务布局预览，不接入运行时寻路或玩法通行。
- Map 的 `GetTowns/GetBuildings/GetRoads/GetRoadNetworks` 返回只读布局；Region 的 `GetTowns/GetBuildings` 返回本区实际生成布局，与候选查询分开。建筑保存中心 cell、占地 cells、entrance、baseHeight 与尺寸；道路保存有序 cells、street/road 类型及端点城镇 ID；格子以 townId/buildingId/roadIds 反查。城镇范围仅包含本区半径内的干地；查询引用共享原格子身份。
- `MapAssetTable` 是资源 ID、Unity 路径、基准高度、适配占地及 Web 轮廓的唯一配置；`MapBuildingTable.assetId/platformAssetId` 绑定完整建筑与平台，半径须匹配。`MapBiomeTable` 按地貌枚举配置底块、水面、混合底色与装饰资源、密度/坡度/缩放。`MapVisuals` 用独立位置噪声撒装饰，避开水域、建筑与道路；边界按 biomeWeights 混色并降低外来地貌装饰密度。格子输出 terrainAssetId/waterAssetId/groundColor，`GetDecorations()` 输出 cell/assetId/scale/yaw；渲染器不重新抽样。
- Map 及嵌套布局、索引、Region/Border 为只读代理，查询返回的格子保持对象身份；`GetNeighbors` 生成调用方自己的列表。快照可由调用方持有，MapSystem 退出不改写已返回的快照。

已启动的 Lua 运行时可调用（无需新增 UI）：

```lua
local map = require('Main'):Get('Map'):Generate(20260921, {1, 1, 1, 1})
local cell = map:GetCell(0, 0)
local x, y, z = map:GetCellWorldPosition(cell.q, cell.r)
local region = map:GetRegion(cell.regionId)
local buildings = region:GetBuildingConfigs()
```

最小验证：改表后 `node Tools/ConfigEditor/exporter.mjs`；按改动选用 `python -B Tools/Tests/run_lua.py Tools/Tests/<文件>.lua`：map 检查拓扑/查询/只读/生命周期，map_terrain 检查噪声/水体/不相交高度范围过渡，map_pathfinder 检查最短路，map_infrastructure 检查占地/街道/水域与陡坡阻隔，map_ecosystem 检查六地貌、四样式、资源、河网与瀑布概率。使用项目 xLua，不启动 Editor/Play。

算法效果可用 [地图预览工具](../Tools/MapPreview.md) 查看：直接复用工程读表与 Lua 算法，不依赖 3D 美术模型；[Unity 运行测试](../Tools/MapRuntimePreview.md) 在 Play 中复用当前 MapSystem，并使用已导入模型显示真实生成结果。

## 关键入口

- [MapGenerator.lua](../../Lua/Game/Map/MapGenerator.lua)：参数校验、轮廓拼接、生成/冻结；[MapSystem.lua](../../Lua/Game/Map/MapSystem.lua)：生命周期与策略注册。
- [MapRegionConvertBase.lua](../../Lua/Game/Map/MapRegionConvertBase.lua) / [MapRegionInstanceBase.lua](../../Lua/Game/Map/MapRegionInstanceBase.lua)：策略契约与区域查询；[RegionFootprint.lua](../../Lua/Game/Map/RegionFootprint.lua)：不规则连通轮廓。
- [GrasslandRegion.lua](../../Lua/Game/Map/GrasslandRegion.lua)、[MountainRegion.lua](../../Lua/Game/Map/MountainRegion.lua)、[LakeRegion.lua](../../Lua/Game/Map/LakeRegion.lua)、[RiverRegion.lua](../../Lua/Game/Map/RiverRegion.lua)、[ForestRegion.lua](../../Lua/Game/Map/ForestRegion.lua)、[SnowRegion.lua](../../Lua/Game/Map/SnowRegion.lua)：六种策略；[TerrainNoise.lua](../../Lua/Game/Map/TerrainNoise.lua)：共用采样工具。
- [TerrainBlend.lua](../../Lua/Game/Map/TerrainBlend.lua)：边界混合；[MapWater.lua](../../Lua/Game/Map/MapWater.lua)：水位与最终水体连通分组。
- [MapInfrastructure.lua](../../Lua/Game/Map/MapInfrastructure.lua)：城镇选址、占地与道路；[MapPathfinder.lua](../../Lua/Game/Map/MapPathfinder.lua)：生成期路径搜索；[MapTownTable.json](../../Config/Tables/Map/MapTownTable.json)：城镇样式参数。
- [Map.lua](../../Lua/Game/Map/Map.lua) / [HexGrid.lua](../../Lua/Game/Map/HexGrid.lua) / [SeededRandom.lua](../../Lua/Game/Map/SeededRandom.lua)：查询、坐标与随机算法。
- [MapRegionTable.json](../../Config/Tables/Map/MapRegionTable.json) / [MapEnemyTable.json](../../Config/Tables/Map/MapEnemyTable.json) / [MapBuildingTable.json](../../Config/Tables/Map/MapBuildingTable.json)：表源；[Catalog.json](../../Config/Catalog.json)：枚举与参数。
- [map.lua](../../Tools/Tests/map.lua) / [map_terrain.lua](../../Tools/Tests/map_terrain.lua)：基础与自然地貌检查。
- [map_infrastructure.lua](../../Tools/Tests/map_infrastructure.lua) / [map_pathfinder.lua](../../Tools/Tests/map_pathfinder.lua)：城镇、占地、道路及搜索检查。

算法设计参考：[Factorio 噪声组合](https://www.factorio.com/blog/post/fff-390)与 [Red Blob Games 多层噪声地形](https://www.redblobgames.com/maps/terrain-from-noise/)。这里只借鉴多尺度、山脊和可视化调参思路，实际实现与参数以上述工程 Lua 为准。

- [MapHydrology.lua](../../Lua/Game/Map/MapHydrology.lua) / [水系配置](../../Config/Tables/Map/MapWaterNetworkTable.json)：跨区河流、支流与瀑布。
- [MapVisuals.lua](../../Lua/Game/Map/MapVisuals.lua) / [地貌表现](../../Config/Tables/Map/MapBiomeTable.json) / [资源配置](../../Config/Tables/Map/MapAssetTable.json)：配置资源与装饰。
- [map_ecosystem.lua](../../Tools/Tests/map_ecosystem.lua)：水系、聚落地标、装饰约束与确定性。

水系参考 [Priority-Flood 论文](https://rbarnes.org/sci/2014_barnes_depressions_published.pdf)的优先扩展与排水树思路；当前工程为有限开挖的美术预览算法，不是物理水文仿真。
