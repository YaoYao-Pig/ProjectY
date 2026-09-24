# 地图材质与环境表现

关键词：地块材质、石板、卵石、草地、积雪、昼夜、天气、黄昏、环境光、雾、室内暖灯、MapEnvironmentController。

## 文档目录

正文：地表配方 / 光照生命周期 / 调参与检查；关键入口：源表 / Lua 快照 / Unity 显示。

## 正文

- 城镇地表只影响画面，不推导通行、高度、水位或玩法时间。`MapAreaTownTable.surfaceProfileId → MapAreaTownSurfaceTable` 选择道路、广场、院落、园地、桥和岩壁材质；`MapAreaTownThemeTable.outsideSurfaceId` 选择来源 Region 的城外地面。`MapAreaSurfaceTable` 提供颜色、米制图案尺寸、对比度、缝宽与平滑度，现有 13 种配方、7 种图案。
- `TownTerrain/RoyalTownTerrain` 在放模型前记录 `townInside`。`TownSurfaces.Apply` 在建筑和街网完成后按用途分类，并用有限距离传播给建筑周边铺院落、城界混色；只写外观字段。王城 `pavingRole=plaza` 保留广场铺装意图，不改变道路图。`MapAreaTownInteriorTable.surfaceId` 控制室内导航地格的底面；建筑模型自身的地板网格仍可覆盖底面并使用模型材质。
- `MapAreaSystem.LayoutSnapshot` 复制 `surfaces` 实体数组，地格持有 `surfaceId/sideSurfaceId`。`TownSurfaceRenderer` 将材质参数写入网格 UV1/UV2，仍使用单网格与单材质；射线和人物贴地继续采样原来的台阶/坡面。共享地图 Shader 使用 Built-in Standard 哑光光照；只有城镇地表开启世界空间程序图案，远景淡化细缝，旧实例模型仍使用原有颜色。
- 光照源表为 `MapEnvironmentTable`（生命周期和视觉时钟）、`MapLightKeyTable`（24 小时循环关键帧）、`MapWeatherTable`（晴/阴倍率和雾距）。黄昏通过时间关键帧表达；默认视觉日 600 秒、初始 10:00。`MapPresentation.Snapshot` 校验顺序、天气引用与雾距后复制给 C#，不导出只读代理数组。
- `MapEnvironmentController` 持有视觉时间，支持暂停、手动小时和天气选择。时间在大地图/小地图之间延续，但不存档、不影响 NPC 日程或战斗时间。方向光兼作夜间月光，插值天空/水平/地面环境光、雾色和阴影；按领队真实占格混合室内外环境，按进入室内的队员开启限量点光，默认最多 4 盏。
- 局部灯在 `SetArea` 缓存建筑中心，Tick 不扫描全图、不新建灯。控制器要求显式绑定方向光、相机与宿主，`AdventureRuntimeDemo.environmentSun` 通过原生 Editor API 保存。销毁时释放灯并恢复原场景 RenderSettings、方向光、相机背景和受影响的 QualitySettings。雾距相对观察焦点计算，避免远处正交相机把整张大地图淹没。
- 第三人称右上角“时间 / 天气”及俯视侧栏可调视觉时间与天气；拖动时间或选小时会暂停自动循环，可重新勾选。无 URP 迁移、烘焙光照或后处理包依赖。本版不是天文太阳模型，也不包含自动天气随机、街灯日程或楼上室内。
- 最小检查：`town_interiors.lua` 验证源表快照、地表引用与广场/院落/园地，以及真实配方的门洞和四人进出；`preview_expansion.cs/.lua` 在 Edit Mode 用真实远征命令检查全部室内、屋顶恢复、时间跨日、天气光强并截图。脚本属于原生 MCP 片段，不放入 Assets 编译；完整检查结果在扩展资源目录下。

## 关键入口

- [地表定义](../../Config/Tables/MapArea/MapAreaSurfaceTable.json) / [城镇地表组合](../../Config/Tables/MapArea/MapAreaTownSurfaceTable.json) / [地表选择](../../Lua/Game/MapArea/TownSurfaces.lua)。
- [环境配方](../../Config/Tables/Rendering/MapEnvironmentTable.json) / [时间关键帧](../../Config/Tables/Rendering/MapLightKeyTable.json) / [天气](../../Config/Tables/Rendering/MapWeatherTable.json) / [配置快照](../../Lua/Game/Rendering/MapPresentation.lua)。
- [显示数据](../../Assets/GameFramework/Samples/Adventure/MapEnvironmentData.cs) / [环境控制器](../../Assets/GameFramework/Samples/Adventure/MapEnvironmentController.cs) / [地表网格](../../Assets/GameFramework/Samples/Adventure/TownSurfaceRenderer.cs) / [共享 Shader](../../Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader)。
- [当前检查](../../Art/TownExpansionLowPoly/Integration/preview.json) / [Unity 预览片段](../../Art/TownExpansionLowPoly/Scripts/preview_expansion.cs) / [真实路线](../../Art/TownExpansionLowPoly/Scripts/preview_expansion.lua)。
- [城镇建筑与操控](TownArea.md) / [王城生成](RoyalTown.md)。
