# 地图材质与环境表现

关键词：地块材质、地貌贴图、自然分布、灌木、草束、蝴蝶、虫群、石板、卵石、草地、积雪、昼夜、天气、黄昏、环境光、雾、室内暖灯、火炬、便携照明、MapEnvironmentController。

## 文档目录

正文：地表配方 / 光照生命周期 / 调参与检查；关键入口：源表 / Lua 快照 / Unity 显示。

## 正文

- 大地图由 `MapBiomeTable` 配置草地、岩地、河湖岸、林地和积雪的 Resources 贴图、纹理尺度/强度、风力及生态密度。`MapRenderSnapshot` 复制 `surfaces`、地格权重最高两项的 `surfaceA/surfaceB/surfaceBlend` 和 `groundcover`；C# 只转换格索引，地貌 ID 保持配置身份。`MapGroundPresentation` 统一加载 512×512、RGBA32、sRGB、Repeat、mipmap 纹理并创建自有 Texture2DArray，原 FBX 材质不变。
- 五类扩充生态（沼泽、黑暗森林、岩浆地、火山、蘑菇森林）使用已有纯色 Prefab 及低强度的岸地/林地/岩地纹理；资源 tintMaterial 为空时，MapPreviewRenderer 保留模型各材质色槽，有绑定时仍按地貌混合色染色。裂隙、菌群、火山等是配置装饰，本次未新增熔岩液体或伤害规则。真实十一地貌与近景见[离屏预览](../../Docs/Previews/MapEcology/contact-sheet.jpg)，由实际地图和渲染器输出。
- 专用 `MapGround.shader` 以世界坐标进行三角格点随机旋转/偏移采样，再混合地貌与低频斑块；相邻格不重复独立 UV 图案。垂直侧面改采岩土纹理，顶部边缘只做色彩过渡，不改变地块几何。地表纹理保持静止，植物地貌只有克制的风吹明暗；远景衰减细纹。水面继续使用独立[流水系统](../Tools/MapRuntimePreview.md)，局部城镇/地牢仍走下述共享地表配方。
- `MapGroundcover.Build` 在原树石/陈设后以独立位置噪声生成草束、低矮灌木、小花、蝴蝶与虫群锚点；低频斑块与簇内偏移保留空地，排除水、路、建筑、城镇占格和过陡边缘，大件物体格不叠加，树下只允许少量草并留树干净空。每格最多三株和一个生物锚点，不改通行、水位或其他随机序列；XZ 偏移已是世界单位。
- `MapNatureRenderer` 用五类各三种程序网格表现自然细节，根部固定风摆、独立拍翼和短程飞行；不逐株建立 GameObject。实例按空间桶/BVH 剔除，远景淡出，小生物最多提交 96 个实例。颜色、深度和法线通道使用相同动画，小地被不投影；隐藏、重建、销毁遵守大地图观察器生命周期。
- 大地图最小检查：`map_groundcover.lua` 验证确定性、避让、偏移、斑块与快照；`map_render_snapshot.lua` 保留显示契约回归。`import_map_ground.cs` 是原生 Editor 片段，定向导入五张贴图和两个 Shader；`preview_map_ground.cs` 在临时场景使用真实散布夹具检查材质、动画及资源释放，不进入 Play。贴图来源与提示词见[地表资产记录](../../Art/MapGround/README.md)。
- 地表材质只影响画面，不推导通行、高度、水位或玩法时间。`MapAreaTownTable.surfaceProfileId → MapAreaTownSurfaceTable` 选择道路、广场、院落、园地、桥和岩壁材质；`MapAreaTownThemeTable.outsideSurfaceId` 选择来源 Region 的城外地面。`MapAreaSurfaceTable` 提供底色、覆盖色 detailColor、米制图案尺寸、对比度、缝宽与平滑度，现有 26 种配方、9 种图案（另有 0 纯色）。
- `TownWaterRenderer` 使用 `MapWater.shader`，与河湖和[外海边界](WorldFog.md)共用水深配色、方向波法线、天空反光和断续岸浪。显式 WaterDepth>0 的港湾优先使用 WaterLevel；仅无水深的旧 `kind=water` 使用 Position.y，其已发现水柱不再重复绘制。浅水的程序化底色是风格化提示，不是屏幕折射或真实水底重渲染；数据、通行和拾取规则不变。
- 地牢新增 13 种墙地配方：旧石板、苔石、木板、泥土、湿石、霜冻岩、祭庭石板，以及粗岩墙、苔墙、木板墙、砌砖墙、渗水墙、霜冻墙。`MapAreaThemeTable.surfaceProfileId → MapAreaDungeonSurfaceTable` 提供 Region 材质池、走廊材质、覆盖功能房概率和墙面延伸宽度；样式/预设的 `floorSurfaceIds/wallSurfaceIds` 提供功能房材质池。`DungeonSurfaces.Apply` 每房选择一次，再按有限距离把墙材传播到周边实体墙，不逐格随机铺花。
- `TownTerrain/RoyalTownTerrain` 在放模型前记录 `townInside`。`TownSurfaces.Apply` 在建筑和街网完成后按用途分类，并用有限距离传播给建筑周边铺院落、城界混色；只写外观字段。王城 `pavingRole=plaza` 保留广场铺装意图，不改变道路图。`MapAreaTownInteriorTable.surfaceId` 控制室内导航地格的底面；建筑模型自身的地板网格仍可覆盖底面并使用模型材质。
- `MapAreaSystem.LayoutSnapshot` 对地牢和城镇都复制 `surfaces` 实体数组，地格持有 `surfaceId/sideSurfaceId`。`TownSurfaceRenderer` 写入 UV1 图案参数、UV2 覆盖 RGB 与平滑度；`MapAreaRenderer` 地牢地形使用独立实例材质与 `_SurfaceData/_SurfaceFinish` 数组，陈设保留源色槽，显式绑定的石、木、灰泥材质叠加模型坐标细节。共享 Shader 的模式 0 为纯色模型，1 为城镇顶点参数，2 为地牢实例参数；世界坐标生成连续图案，远景淡化细缝。未知格关闭图案，苔藓覆盖色同样遵守探索迷雾。台阶/坡面、射线与人物贴地契约不变。
- 陈设的金属度、平滑度和按可见性衰减的发光遵循[渲染契约](../Framework/Rendering.md)。`M_MapLP_InteriorGlow`（壁炉）、`M_MapLP_ForgeGlow`（锻炉）、`Mine_Lamp`（矿灯）源材质启用 HDR 自发光；固定光源由下述限量场景灯池提供，不改变探索视野。材质重导入后需保留这些源参数，只有亮色底色无法产生稳定辉光。2026-10 局部表现配置另为火盆和灯具的指定材质槽提供实例 HDR 发光，不修改共享源材质。
- 光照源表为 `MapEnvironmentTable`（生命周期和视觉时钟）、`MapLightKeyTable`（24 小时循环关键帧）、`MapWeatherTable`（晴/阴/雨光雾和云雨预设）；自动变化与区域查询见[区域天气](Weather.md)。黄昏通过时间关键帧表达；默认视觉日 600 秒、初始 10:00。`MapPresentation.Snapshot` 校验顺序、天气引用与雾距后复制给 C#，不导出只读代理数组。
- `MapEnvironmentController` 仍可独立使用视觉时间；远征 Demo 由[叙事游戏时钟](Narrative.md)驱动 Hour，使昼夜与 NPC 日程一致并随叙事状态存档。方向光兼作夜间月光，插值天空/水平/地面环境光、雾色和阴影；按领队真实占格混合建筑室内外环境；地下环境由 `MapAreaPresentation.undergroundAreaTypes` 独立选择，不借用建筑剖切标记。
- 局部灯在 `SetArea` 按 `MapAreaPresentation` 的资源 ID 和模型局部坐标缓存光源；默认最多 4 盏附近场景灯，场景灯与旅行火炬合计最多 2 盏实时阴影。位置随模型旋转和缩放转换，灯具补件只在进入地图时建立，Tick 不新建对象。控制器要求显式绑定方向光、相机与宿主，`AdventureRuntimeDemo.environmentSun` 通过原生 Editor API 保存。销毁时释放灯并恢复原场景 RenderSettings、方向光、相机背景和受影响的 QualitySettings。雾距相对观察焦点计算，避免远处正交相机把整张大地图淹没。
- 旅行火炬为 `EquipmentItemTable` 94 的 `material` 堆叠，占背包 1×2，不占武器槽；`TorchTable` 配用途说明、暖色、强度、高度和 9 米照明半径。背包或[队伍火把槽](Camp.md)持有时可用于局部地图与原地战斗，探索中按 `T` 或“时间 / 天气”窗口开关。队伍槽另提供大地图夜间照明，按插值后的 `displayedTravel` 跟随；背包中的火炬单独不点亮大地图。`SetTorch` 和 `SetWorldTorch` 复用同一真实点光并按地图切换关闭。火炬不消耗数量、不揭开迷雾；全部转移到仓库或队外后关闭。灯与室内灯共用环境控制器生命周期，不逐帧创建。
- 火炬开关由 C# `NarrativeData` 的 `flag:torch_extinguished` 保存（0 点亮意图、1 熄灭；旧档缺键为 0），`Torch` 模块只生成显示快照与执行开关；存档准备阶段拒绝其他值。所有权复用现有背包/搜刮/营地/存档协议。当前图标和展示资源复用船舱提灯，未新增手持挂点或燃料规则。局部共享 Shader 使用 URP PBR 额外点光；两套世界管线每物体最多 8 盏灯，默认最多 4 盏场景灯加 1 盏火炬。火炬启用软阴影，并占用一个局部阴影名额。
- 新增物品 94 / 资源 403 后，须在 Edit Mode 执行 `Project Y/装备/同步旅行火炬资源`（`EquipmentAssets.SyncTorch`），通过原生 AssetDatabase 将现有提灯 Prefab 和 Sprite 写入 `EquipmentAssetCatalog`；不重建武器或 UI。源路径存在不代表 Catalog 已绑定，未同步时背包图标与补给桌物品展示会明确报错。2026-10-16 已通过 Unity MCP 执行该同步，物品图标与资源绑定经独立 PreviewScene 检查通过。
- `Tick` 按所选[渲染风格](../Framework/Rendering.md)对昼夜光强应用表现倍率，不改源表或叙事时间。奇幻模式使用独立的天空材质克隆，随真实主光更新太阳/晨昏；只在模式变化或太阳明显移动时请求环境反射更新。像素模式回到原始光照；销毁恢复 skybox、reflectionIntensity 和 camera.clearFlags。
- 远征“时间 / 天气”窗口显示游戏时间、自动天气与手动表现预览；时间参数通过配置调整，避免视觉时刻与 NPC 日程分离。区域天气、雨粒子和星空遵循[天气模块](Weather.md)。渲染使用 [URP 与奇幻风格](../Framework/Rendering.md)，无烘焙光照依赖；仍非天文太阳模型，不包含街灯日程。
- 最小检查：`town_interiors.lua` 验证源表快照、地表引用与广场/院落/园地，以及真实配方的门洞和四人进出；`preview_expansion.cs/.lua` 在 Edit Mode 用真实远征命令检查全部室内、屋顶恢复、时间跨日、天气光强并截图。脚本属于原生 MCP 片段，不放入 Assets 编译；完整检查结果在扩展资源目录下。

- `MapAreaPresentation` 为局部材质和固定光源的独立资源配置：37 个源材质引用选择石板、砖石、木纹或粗岩配方，8 类模型配置光源锚点、发光槽和可选可见提灯。未绑定材质保留源表现；不按材质名字在运行时猜测用途。`MapSurfaceDetail.hlsl` 由连续高度生成表面梯度法线，并在 Forward/DepthNormals 使用相同规则；砖石水平面用石板、立面用砖缝，细节按屏幕导数淡出。它不位移网格、不修改六边形轮廓，也不让砖缝产生几何投影。
- 建筑墙使用独立 `M_MapLP_WallMasonry/WallBoards` 材质引用：铁匠铺、商店、公会与 RowA/B 为砖石，酒馆和 RowC 为木板。14 个结构/上盖模型通过原生 ModelImporter 重映射 21 个墙面槽，保留网格和 GUID；结构内器皿等共用的原 Plaster 槽不改。重新导出模型应保留这些 importer 映射，显示细节仍由 `MapAreaPresentation` 提供。
- `MapAreaSceneLighting` 只为可见且未被楼层剖切隐藏的光源提供照明，按队员距离选择限量灯池；位置不随队员移动。矿井木架/工作台与酒馆台面的附加提灯由环境会话持有，退出时释放灯具及克隆发光材质。记忆区域/未知区域均不点灯。地牢和矿井使用固定冷色补光，关闭室外雾与日光散射；建筑室内减弱散射，后处理只修改会话克隆。
- 最小表现检查：`preview_local_surfaces.cs/.lua` 在现有 Editor 的独立 PreviewScene 使用实际地牢、矿井、铁匠铺和酒馆布局，检查阴影/凹凸的实际像素贡献、隐藏灯熄灭、地下昼夜独立及场景状态还原；火炬继续使用 `torch_editmode.cs`。输出与实际检查范围见 `Docs/Previews/Rendering/local-surfaces-validation.json`；没有自动进入 Play 或做 GPU 性能基准。

## 关键入口

- [地貌配方](../../Config/Tables/Map/MapBiomeTable.json) / [自然分布](../../Lua/Game/Map/MapGroundcover.lua) / [地表材质](../../Assets/GameFramework/Samples/Map/MapGroundPresentation.cs) / [自然细节显示](../../Assets/GameFramework/Samples/Map/MapNatureRenderer.cs)。
- [地表 Shader](../../Assets/GameFramework/Resources/MapGround.shader) / [地被 Shader](../../Assets/GameFramework/Resources/MapNature.shader) / [贴图导入](../../Tools/Rendering/import_map_ground.cs) / [原生预览](../../Tools/Rendering/preview_map_ground.cs) / [展示布局导出](../../Tools/Rendering/export_map_ground_preview.lua)。
- [独立地牢纹理库](../../Art/AssetExpansion202610/Dungeon/texture_manifest.json)：3 墙面与 3 地面 Base Color，Unity 目录 `Assets/DynamicAsset/AssetExpansion202610/Dungeon/Textures`，对应 URP/Lit 材质使用 sRGB、Repeat、mipmap。当前共享 Shader 已支持陈设源材质的 `_BaseMap`、启用的法线图和金属/平滑度图；地牢墙地使用配方生成的高度凹凸，本批独立墙地颜色贴图尚未自动套入随机地形。平铺视觉检查及边缘残差见[审核档案](../../Art/AssetExpansion202610/Dungeon/review.json)。
- [地牢材质配方](../../Config/Tables/MapArea/MapAreaDungeonSurfaceTable.json) / [房间与墙面选择](../../Lua/Game/MapArea/DungeonSurfaces.lua) / [装饰与定向检查](MapDressing.md)。
- [局部表现参数](../../Assets/GameFramework/Resources/Rendering/MapAreaPresentation.asset) / [参数类型](../../Assets/GameFramework/Samples/Adventure/MapAreaPresentationSettings.cs) / [场景灯池](../../Assets/GameFramework/Samples/Adventure/MapAreaSceneLighting.cs) / [凹凸函数](../../Assets/GameFramework/Samples/Map/MapSurfaceDetail.hlsl)。
- [建筑墙材质安装](../../Tools/Rendering/install_local_wall_materials.cs)：创建缺失的两种墙材质并定向重映射；可在基础表现资源安装后运行，保留已有调参。[建筑墙面近景](../../Tools/Rendering/preview_local_walls.cs) / [地牢墙面近景](../../Tools/Rendering/preview_dungeon_wall.cs) / [本次检查](../../Docs/Previews/Rendering/local-walls-validation.json)。
- [缺失参数资源安装](../../Tools/Rendering/install_local_surfaces.cs)：原生 MCP 方法体，仅创建缺失资源，已有参数不会重置；[实际布局与视觉回归](../../Tools/Rendering/preview_local_surfaces.cs)。
- [地表定义](../../Config/Tables/MapArea/MapAreaSurfaceTable.json) / [城镇地表组合](../../Config/Tables/MapArea/MapAreaTownSurfaceTable.json) / [地表选择](../../Lua/Game/MapArea/TownSurfaces.lua)。
- [环境配方](../../Config/Tables/Rendering/MapEnvironmentTable.json) / [时间关键帧](../../Config/Tables/Rendering/MapLightKeyTable.json) / [天气](../../Config/Tables/Rendering/MapWeatherTable.json) / [配置快照](../../Lua/Game/Rendering/MapPresentation.lua)。
- [火炬配方](../../Config/Tables/Equipment/TorchTable.json) / [所有权与开关](../../Lua/Game/Adventure/Torch.lua) / [最小离线检查](../../Tools/Tests/torch_core.lua)：`python Tools/Tests/run_lua.py Tools/Tests/torch_core.lua` 检查真实导表配置、资源路径、所有权、恢复开关、转移与战斗门禁；真实光照的定向检查见下项；完整 Play 体验不在本次自动检查范围。
- [火炬 Edit Mode 检查](../../Tools/Tests/torch_editmode.cs)：原生目录同步后由 MCP 执行的方法体；独立 PreviewScene 检查真实配置/Catalog/点光参数、跟随、开关、离区与销毁，使用共享地图 Shader 比较开关火炬的离屏像素亮度。所有环境状态和临时资源在 finally 还原，不进入 Play；2026-10-16 实际通过：测试区域平均亮度由 0.0323 增至 0.1344（约 4.17 倍），跟随、开关、释放与原场景状态恢复全部通过。
- [显示数据](../../Assets/GameFramework/Samples/Adventure/MapEnvironmentData.cs) / [环境控制器](../../Assets/GameFramework/Samples/Adventure/MapEnvironmentController.cs) / [地表网格](../../Assets/GameFramework/Samples/Adventure/TownSurfaceRenderer.cs) / [共享 Shader](../../Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader)。
- [当前检查](../../Art/TownExpansionLowPoly/Integration/preview.json) / [Unity 预览片段](../../Art/TownExpansionLowPoly/Scripts/preview_expansion.cs) / [真实路线](../../Art/TownExpansionLowPoly/Scripts/preview_expansion.lua)。
- [城镇建筑与操控](TownArea.md) / [王城生成](RoyalTown.md)。
