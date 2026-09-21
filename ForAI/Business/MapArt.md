# 大地图模型资源

关键词：大地图美术、low-poly、低多边形、六边形地块、民居、工坊、集会厅、中世纪城堡、七格平台、森林树、雪松、地牢、配置模型、模型风格、MapLowPoly。

## 文档目录

正文：资源边界 / 几何契约 / 修改与验收；关键入口：源文件 / Unity 资源 / 风格技能。

## 正文

- 本套资源延续地图实验室的低多边形与纯色风格，用于 Unity 地形和城镇表现。[Unity 运行测试](../Tools/MapRuntimePreview.md) 已使用本套模型显示真实生成布局；地图算法、配表和 Web Canvas 渲染仍由 [地图](Map.md) 与 [地图预览](../Tools/MapPreview.md) 维护。
- 源文件、制作脚本、FBX 暂存与图片在 `Art/MapLowPoly/`；最终 Unity 资源在 `Assets/DynamicAsset/MapLowPoly/`。源 `.blend` 不进入 Assets，避免 Unity 调用本机 Blender 自动转换；已有 FBX 更新保留 `.meta`。
- `Hex_Grass/Hex_Rock/Hex_Shore/Hex_Riverbed/Hex_City/Hex_Forest/Hex_Snow` 共用半径 1 的尖顶六边形外形，顶面 Y=0，底面 Y=-1。中心沿项目轴坐标放置；地形高度由实例位置和纵向缩放控制，模型本身不运行地形算法。
- `Hex_Water` 是独立不透明薄水面；放置高度来自 `cell.waterLevel`，并只在实际水格显示。`Mountain_Cluster` 是可选山石装饰，不属于拼接边界或碰撞/通行规则。
- `CityPlot7` 按中心与六邻格合并外轮廓制作，平坦连续顶面，不以放大单六边形代替。单格建筑地块用 `Hex_City`；平台放到 `building.baseHeight`，厚度根据实际地面落差配置，避免悬空或穿底。
- `House/Workshop/TownHall` 分别对应当前 `MapBuildingTable` 的 ID 2/3/4；建筑模型是一栋完整建筑，集会厅使用七格占地。资源路径与基准高度统一由 MapAssetTable 配置，建筑表通过 assetId/platformAssetId 引用；Editor 同步真实场景引用。
- `Building_Castle` 是额外的中世纪城堡模型：四座角塔、垛口城墙、拱门和中央主堡共用完整基座，位于七格城市平台内。Unity 实测尺寸为 X=3.35、Y=3.7、Z=3.415；已作为建筑 ID 5 参与城堡领地生成；尚未实现城市等级或进入城市的玩法。
- 新增 `Tree_Broadleaf/Tree_Conifer/Tree_SnowPine` 分别高 2/2.5/2.5，68/130/202 三角形；`Building_Dungeon` 高 1.6、260 三角形，石塔与暗门用于地牢遗址。森林、雪地底块各 20 三角形。新增源场景独立保存在 Ecosystem.blend；分布与模型关联由地貌表配置，模型不自行撒树。
- 建筑与地形均采用米制；Unity +Y 上，建筑 +Z 为正面，落地原点位于建筑底部中心。未来接入入口方向时需按 `building.entrance` 旋转，不能直接照搬 Web 占位建筑的局部正面轴。
- 本套静态导出对副本网格烘焙 Blender Z 轴 180°，启用 FBX `bake_space_transform`，Unity importer 同时保持 `bakeAxisConversion=true`、Scale Factor 1、Convert Units 开启。这组参数经过实际模型验证；混用默认导出或默认 importer 会改变正面或留下 X=90° 根旋转，造成地块缩放轴错误。源对象保持原样，具体参数以清单和本套导出脚本为准。
- 当前使用 Built-in `Standard` 纯色哑光材质，无外部贴图。视觉规则与配色由 [map-lowpoly-style](../../.agents/skills/map-lowpoly-style/SKILL.md) 维护，操作流程由 [Blender 资源管线](../Tools/Blender.md) 路由。
- 当前交付 18 个 FBX、29 个共用模型材质与独立展示场景（另有 1 个展示背景材质）。建筑三角形：民居 272、工坊 248、集会厅 460、城堡 1712。工坊含烟囱总高 2.124，高于墙体加屋顶的 1.9；后续相机包围盒用模型实测高度，勿只用配表墙高与屋顶高裁剪。
- 最小验收已覆盖源网格六方向接缝、七格平台面积，以及 Unity 中全部模型尺寸/边界、零根旋转、单位缩放、材质映射和调色板；实际截图见下方入口。展示场景是独立附加场景，不加入 Build Settings，也不接入游戏生命周期。
- 修改后只检查实际受影响模型：FBX 尺寸/朝向、材质映射、硬边、地块接缝、大建筑连续地基和模型预览。不要为美术验收进入 Play、编译工程或运行地图回归；算法变化才选对应测试。

## 关键入口

- [制作目录](../../Art/MapLowPoly/)：可编辑来源、暂存导出与预览。
- [源场景](../../Art/MapLowPoly/Source/MapLowPoly.blend) / [资源清单](../../Art/MapLowPoly/asset_manifest.json)：模型尺寸、三角形、材质与导出设置。
- [城堡源场景](../../Art/MapLowPoly/Source/Castle.blend) / [城堡 FBX](../../Assets/DynamicAsset/MapLowPoly/Models/Building_Castle.fbx)：城堡独立保存源场景，复用现有调色板。
- [Unity 展示场景](../../Assets/DynamicAsset/MapLowPoly/MapLowPolyPreview.unity)：在 Editor 中查看全套模型；[Blender 概览](../../Art/MapLowPoly/Previews/MapLowPoly_Overview.png) 用于风格对照。
- [静态导出](../../Art/MapLowPoly/Scripts/export_map_static_fbx.py)：本套经过 Unity 实测的 `export_map_static_fbx`；按需在 MCP 中传源对象名、绝对路径和明确覆盖选项，不直接重复执行初始建模脚本。
- [Unity 实际预览](../../Art/MapLowPoly/Previews/MapLowPoly_Unity.png) / [Unity 验收记录](../../Art/MapLowPoly/Integration/unity-verification.json) / [源几何检查](../../Art/MapLowPoly/verification.json)：区分导出、导入和视觉检查层级。
- [城堡 Unity 预览](../../Art/MapLowPoly/Previews/Castle_Unity.png) / [含城堡的全套预览](../../Art/MapLowPoly/Previews/MapLowPoly_Unity_WithCastle.png) / [城堡验收记录](../../Art/MapLowPoly/Integration/castle-unity-verification.json)：仅增量检查城堡的尺寸、朝向和 11 个共享材质；展示场景提供关闭状态的 `Castle_PreviewCamera` 单体机位。
- [模型风格 Skill](../../.agents/skills/map-lowpoly-style/SKILL.md)：轮廓、配色与远景可读性。
- [建筑配置](../../Config/Tables/Map/MapBuildingTable.json)：建筑 ID、占地和高度；[城镇配置](../../Config/Tables/Map/MapTownTable.json)：城市底色。

- [生态源场景](../../Art/MapLowPoly/Source/Ecosystem.blend) / [模型对照](../../Art/MapLowPoly/Previews/ecosystem-kit.png) / [增量 Unity 导入记录](../../Art/MapLowPoly/Integration/ecosystem-unity-import.json)：新增六个模型的尺寸、根变换、材质映射。
- [资源表](../../Config/Tables/Map/MapAssetTable.json) / [地貌表](../../Config/Tables/Map/MapBiomeTable.json)：模型路径、颜色、缩放及装饰分布。
