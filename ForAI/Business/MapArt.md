# 大地图模型资源

关键词：大地图美术、low-poly、低多边形、六边形地块、民居、工坊、集会厅、中世纪城堡、七格平台、森林树、雪松、高山、峡谷、参天巨树、雕塑树、地牢陈设、柱厅、石棺、配置模型、模型风格、MapLowPoly。

## 文档目录

正文：资源边界 / 几何契约 / 修改与验收；关键入口：源文件 / Unity 资源 / 风格技能。

## 正文

- [码头与河船](WaterTravel.md)资源为1200–1202：完整码头、破损码头、基础河船。源位于 [DocksLowPoly.blend](../../Art/DocksLowPoly/Source/DocksLowPoly.blend)，Unity FBX 与独立 URP 材质在 `Assets/DynamicAsset/DocksLowPoly`；两款码头同原点同包络，岸端 Z=0、甲板 Y=.5，前3米共用完整部分；河船以水线为原点、船首 +Z。[导入记录](../../Art/DocksLowPoly/Integration/unity-import.json)与[实际预览](../../Art/DocksLowPoly/Previews/Unity.png)已核对。

- 本套资源延续地图实验室的低多边形与纯色风格，用于 Unity 地形和城镇表现。[Unity 运行测试](../Tools/MapRuntimePreview.md) 已使用本套模型显示真实生成布局；地图算法、配表和 Web Canvas 渲染仍由 [地图](Map.md) 与 [地图预览](../Tools/MapPreview.md) 维护。
- 源文件、制作脚本、FBX 暂存与图片在 `Art/MapLowPoly/`；最终 Unity 资源在 `Assets/DynamicAsset/MapLowPoly/`。源 `.blend` 不进入 Assets，避免 Unity 调用本机 Blender 自动转换；已有 FBX 更新保留 `.meta`。
- `Hex_Grass/Hex_Rock/Hex_Shore/Hex_Riverbed/Hex_City/Hex_Forest/Hex_Snow` 共用半径 1 的尖顶六边形外形，顶面 Y=0，底面 Y=-1。中心沿项目轴坐标放置；地形高度由实例位置和纵向缩放控制，模型本身不运行地形算法。
- `Hex_Water` 是独立不透明薄水面；放置高度来自 `cell.waterLevel`，并只在实际水格显示。运行时[动态流水、分层波纹和水花](../Tools/MapRuntimePreview.md)由观察器的专用 Shader/粒子系统实现，原模型与共用材质不变。`Mountain_Cluster` 是可选山石装饰，不属于拼接边界或碰撞/通行规则。
- `CityPlot7` 按中心与六邻格合并外轮廓制作，平坦连续顶面，不以放大单六边形代替。单格建筑地块用 `Hex_City`；平台放到 `building.baseHeight`，厚度根据实际地面落差配置，避免悬空或穿底。
- `House/Workshop/TownHall` 分别对应当前 `MapBuildingTable` 的 ID 2/3/4；建筑模型是一栋完整建筑，集会厅使用七格占地。资源路径与基准高度统一由 MapAssetTable 配置，建筑表通过 assetId/platformAssetId 引用；Editor 同步真实场景引用。
- `Building_Castle` 为四角塔、垛口城墙、拱门和中央主堡，建筑 ID 5 参与城堡领地生成。当前细化版加入后塔尖顶、吊桥与沿七格平台边界的水渠，Unity 尺寸 X=5.144、Y=3.7、Z=4.95，仍在原七格占地内；当前来源见[城镇建筑美术](TownArt.md)。模型没有室内；聚落通过 [MapArea](MapArea.md) 进入城镇，宫殿与御苑另见[王城](RoyalTown.md)。
- `Tree_Broadleaf/Tree_Conifer/Tree_SnowPine` 分别高 2/2.5/2.5，68/130/202 三角形；旧 `Building_Dungeon` 高 1.6、260 三角形，石塔遗址保留但不再绑定地牢资源 ID 18。森林、雪地底块各 20 三角形。生态源场景独立保存在 Ecosystem.blend；分布与模型关联由地貌表配置，模型不自行撒树。
- `Building_DungeonEntrance` 为独立石拱地牢入口，高 1.6、264 三角形，资源 ID 18 → 建筑 ID 1；`Building_SecludedCottage` 为低墙木顶矮屋，高 1.05、116 三角形，资源 ID 19 → 建筑 ID 6 → 隐居群落样式 5。两者均单格、共享原有材质，源为 RemoteSites.blend；原民居高 1.75。暗洞背板有厚度，避免单面剔除；生成规则归 [地图](Map.md)。
- 建筑与地形均采用米制；Unity +Y 上，建筑 +Z 为正面，落地原点位于建筑底部中心。未来接入入口方向时需按 `building.entrance` 旋转，不能直接照搬 Web 占位建筑的局部正面轴。
- 本套静态导出对副本网格烘焙 Blender Z 轴 180°，启用 FBX `bake_space_transform`，Unity importer 同时保持 `bakeAxisConversion=true`、Scale Factor 1、Convert Units 开启。这组参数经过实际模型验证；混用默认导出或默认 importer 会改变正面或留下 X=90° 根旋转，造成地块缩放轴错误。源对象保持原样，具体参数以清单和本套导出脚本为准。
- 原模型使用 [URP Lit](../Framework/Rendering.md) 纯色哑光材质；大地图运行显示通过独立[地貌贴图与动态自然细节](MapPresentation.md)覆盖地表，原 FBX 与共用模型材质不变。视觉规则与配色由 [map-lowpoly-style](../../.agents/skills/map-lowpoly-style/SKILL.md) 维护，操作流程由 [Blender 资源管线](../Tools/Blender.md) 路由。
- 地牢内部新增 `Dungeon_Pillar/BrokenPillar/Altar/Sarcophagus/CrateStack/Brazier/RuinedArch/Bench`，资源 ID 20–27，源为 DungeonInteriors.blend，复用原材质。柱、断柱、木箱和火盆为单格占地，其余为七格占地；由 `MapAreaPropTable` 决定移动/视线和模型关系。废拱作为阻挡陈设使用，不能把其小门洞当作可通行入口。预设房间的墙地格罩与摆放归 [MapArea](MapArea.md) 配置，模型不生成房间。
- 地牢成组设施 `Dungeon_RubbleMound/SupplyCache/RitualDais/TombCluster/RootThicket/BookArchive/DiningSet/BrokenColonnade` 为资源 ID 28–35，源为 DungeonGroups.blend。货垛和连柱廊占 13 格，其余占 19 格，每个模型作为完整设施使用；足迹通过 MapAreaPropTable 的局部坐标与模型同步旋转。复用原 29 种材质，不新增纹理或渲染特性。
- 当前交付 36 个 FBX（其中旧地牢石塔未绑定，资源表使用 35 个）、29 个共用模型材质与独立展示场景（另有 1 个展示背景材质）。小陈设各 48–180 三角形，多格设施各 156–768 三角形；建筑三角形：民居 272、工坊 248、集会厅 460、城堡细化版 2596。工坊含烟囱总高 2.124，高于墙体加屋顶的 1.9；后续相机包围盒用模型实测高度，勿只用配表墙高与屋顶高裁剪。
- 最小验收已覆盖源网格六方向接缝、七格平台面积，以及 Unity 中全部模型尺寸/边界、零根旋转、单位缩放、材质映射和调色板；实际截图见下方入口。展示场景是独立附加场景，不加入 Build Settings，也不接入游戏生命周期。
- 修改后只检查实际受影响模型：FBX 尺寸/朝向、材质映射、硬边、地块接缝、大建筑连续地基和模型预览。不要为美术验收进入 Play、编译工程或运行地图回归；算法变化才选对应测试。
- `TerrainWonders` 新增资源 ID 1100–1108：裸岩/雪岩尖峰、层理岩块、绳桩、垂绳、黑色实体谷底、完整巨树、局部巨根与树干弧壁。巨大高差、峡谷深度、多格奇观占地及入口归[自然地貌与巨树奇观](NaturalLandmarks.md)；山岩模型只强化少量剪影，不负责逐格山峰或通行。
- 完整 `WorldTree_Colossal`（1106）为 Unity XYZ=28×42×28 米、半径 9 的连续 271 格奇观；仅大地图使用。`WorldTree_RootSection`（1107）为 4×4×12 米、长轴 +Z，粗根隆起、两端渐细弯入地面；`WorldTree_BaseArc`（1108）为 30×35×8 米，仅树干一角与板根，无树冠。小地图只用后两者及普通树对照；导航净空由地图布局决定。
- 巨树按用户参考改用精细有机雕塑：木体体积联合、接合平滑和连续纵向树皮，源几何中每件木体均为单个连通分量；叶冠为分层折叶实体，不是球体组合。完整树/巨根/弧壁分别为 185720/28000/64998 三角形，仍采用纯色哑光、无贴图与动画；这一唯一奇观的雕塑要求优先于普通低多边形树规则。
- `WorldTree_FantasyBough`（1109）作为第二款随机巨树外形保留，原 1106 的模型不被替换。新变体 Unity XYZ 实测为 24.1948×42×19.7036 米，主导长枝向 +X 曲折延伸，三股粗木脊与主干融合，长枝叶台与上冠连片丰茂；24830 片实体折叶、共 270640 三角形。原点固定在干脚，包围盒偏心，禁止按包围盒重新居中；最远水平顶点距原点 14.71445 米，沿用半径 9 的 271 格占地。两款外形的随机选择归自然地貌模块；局部地图仍复用 1107/1108。
- 绳桩（1103）为 1×0.85×0.85 米；垂绳（1104）顶端原点 Y=0，向下到 Y=-8，可按实际谷深缩放 Y。黑底（1105）使用精确半径 1 六边形实体，顶面 Y=0、底面 Y=-1，独立 `M_MapTW_Depth` 为 URP Unlit 近黑材质，避免把谷底当作缺失网格。
- 本批已执行 Blender 实际建模/渲染及九个 FBX 的 Unity 定向导入检查：尺寸、零根旋转、单位缩放、轴转换与独立 URP 材质有效；三件雕塑更新保留原 GUID。源几何检查与导入证据不等于 Play 交互验收，实际地图接入验证见自然地貌模块。

## 关键入口

- [奇观源场景](../../Art/MapLowPoly/Source/TerrainWonders.blend) / [奇观资产清单](../../Art/MapLowPoly/terrain_wonders_manifest.json) / [Unity 定向导入证据](../../Art/MapLowPoly/Integration/terrain-wonders-unity.json) / [雕塑木体连通检查](../../Art/MapLowPoly/Integration/terrain-wonders-sculpt-topology.json)：九个模型的尺寸、材质、原点和三个有机木体的连通性。
- [奇观概览](../../Art/MapLowPoly/Previews/terrain-wonders-world.png) / [完整巨树](../../Art/MapLowPoly/Previews/world-tree-sculpted.png) / [树干与板根接合](../../Art/MapLowPoly/Previews/world-tree-trunk-detail.png) / [局部巨根与普通树对照](../../Art/MapLowPoly/Previews/world-tree-local-roots.png)：均为真实 Blender 源渲染，展示源资产形体与尺度。
- [初始建模](../../Art/MapLowPoly/Scripts/build_terrain_wonders.py) / [巨树雕塑修订](../../Art/MapLowPoly/Scripts/sculpt_world_tree.py) / [导出](../../Art/MapLowPoly/Scripts/export_terrain_wonders.py) / [最终源预览](../../Art/MapLowPoly/Scripts/render_terrain_wonders_review.py)：初建后分别调用雕塑脚本 `build_colossal/build_root/build_arc/save_manifest`，再导出；已有作品优先打开源文件定向修改，不能仅重跑初始低模脚本覆盖最终雕塑。
- [奇幻长枝变体建模](../../Art/MapLowPoly/Scripts/build_fantasy_bough.py) / [单件导出](../../Art/MapLowPoly/Scripts/export_fantasy_bough.py) / [变体源检查](../../Art/MapLowPoly/Integration/world-tree-fantasy-bough-source.json)：只新增/重做 1109，不修改原树或局部根模型；原源备份保存在 `Source/TerrainWonders_20261025_before_asymmetric.blend`，两款最终源共同保存在 TerrainWonders.blend。源检查包含原 FBX 的 SHA256、木体连通性、偏心包围盒与半径。
- [两款巨树同框](../../Art/MapLowPoly/Previews/world-tree-variants.png) / [奇幻长枝树单体](../../Art/MapLowPoly/Previews/world-tree-fantasy-bough.png) / [长枝与交缠木体近景](../../Art/MapLowPoly/Previews/world-tree-fantasy-bough-detail.png) / [变体预览脚本](../../Art/MapLowPoly/Scripts/render_fantasy_bough_review.py)：正视机位保留长枝横向轮廓，左侧原款、右侧奇幻长枝款。
- [变体Unity核验](../../Art/MapLowPoly/Integration/world-tree-fantasy-bough-unity.json) / [实际模型同框](../../Docs/Previews/TerrainWonders/giant-tree-variants-unity.png) / [定向核验入口](../../Tools/Tests/giant_tree_variants_preview.cs)：新模型全部顶点落在271格占地内，原模型FBX哈希不变；两场景均已保存233项资源引用。检查没有进入Play或触发项目编译。

- [势力据点资源](../../Art/FactionLowPoly/README.md)：兽人木寨、哥布林营地、树精灵高树林居的单格模型；保留 Blender 源，FBX 与 14 个共享 URP 材质已导入，AdventureDemo.worldPartyBindings 保留原 7 项并追加 3 项。[实际同框预览](../../Art/FactionLowPoly/Previews/faction-sites-unity.png)已核对，未进入 Play。生态归属与玩法见[势力系统](Factions.md)。

- [矿井地牢](Mine.md)：三层矿道及坍塌表现；[矿井资源清单](../../Art/AssetExpansion202610/Mine/README.md)记录入口、木支架、矿轨、矿车、矿簇与工作棚的来源和实测尺寸。资源 ID 900–905 已接入地图资源表。

- [2026 年 10 月补充资产库](../../Art/AssetExpansion202610/README.md) / [可浏览档案](../../Art/AssetExpansion202610/gallery.html)：独立新增五生态 15 个六边地块、21 个生态装饰及 20 个地牢陈设；源、参考图、三视图和逐项审核均位于同目录。Unity 产物在 `Assets/DynamicAsset/AssetExpansion202610/`。其中 Terrain 的 15 款底块、21 款装饰已登记 MapAssetTable 1000–1035 并接入十一地貌随机开局，使用现有 Prefab；多材质地块保留原色槽，见[地图材质](MapPresentation.md)。其余该批地牢陈设与纹理仍按各自接入说明处理。
- [地图环境装饰](MapDressing.md)：新增 24 类自然、街区、地牢物件的独立源目录、资源 ID、真实米制占地与配置生成入口。
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
- [Unity 生态地图实景](../../Art/MapLowPoly/Previews/ecosystem-unity-final.png) / [本次增量验收](../../Art/MapLowPoly/Integration/ecosystem-verification.json)：真实配表、地图布局、资源绑定与水幕修正检查。
- [偏远地点源场景](../../Art/MapLowPoly/Source/RemoteSites.blend) / [Blender 对照](../../Art/MapLowPoly/Previews/remote-sites-kit.png) / [Unity 对照](../../Art/MapLowPoly/Previews/remote-sites-unity.png) / [导入检查](../../Art/MapLowPoly/Integration/remote-sites-unity-verification.json)：新地牢、矮屋与普通民居的尺度和材质检查，未进入 Play；地图测试与远征 Demo 已同步资源绑定。
- [地牢内部源场景](../../Art/MapLowPoly/Source/DungeonInteriors.blend) / [八件模型对照](../../Art/MapLowPoly/Previews/dungeon-interiors-kit.png) / [Unity 导入检查](../../Art/MapLowPoly/Integration/dungeon-interiors-unity.json)：尺寸、单位根变换、轴转换和共享材质；地图测试与远征 Demo 均已同步 27 项资源引用。
- [地牢建模脚本](../../Art/MapLowPoly/Scripts/build_dungeon_interiors.py) / [导出脚本](../../Art/MapLowPoly/Scripts/export_dungeon_interiors.py) / [实际布局预览入口](../../Art/MapLowPoly/Scripts/preview_dungeon_layout.lua) / [房间整体预览](../../Art/MapLowPoly/Previews/dungeon-mixed-unity-overview.png)：真实生产算法与配置生成的布局，在 Unity Edit Mode 临时场景静态渲染；不代表已验证 Play 中的交互。
- [多格设施源场景](../../Art/MapLowPoly/Source/DungeonGroups.blend) / [八件设施概览](../../Art/MapLowPoly/Previews/dungeon-groups-kit.png) / [Unity 占地与导入检查](../../Art/MapLowPoly/Integration/dungeon-groups-unity.json) / [第三版布局](../../Art/MapLowPoly/Previews/dungeon-v3-unity-overview.png)：新模型尺寸、材质、水平包围盒采样与配置占地一致，AdventureDemo 已保存 35 项引用；大地图快照不要求绑定未使用的内部设施。
- [成组设施建模](../../Art/MapLowPoly/Scripts/build_dungeon_groups.py) / [成组设施导出](../../Art/MapLowPoly/Scripts/export_dungeon_groups.py)：初次制作脚本拒绝覆盖；后续定向编辑 Blender 源作品、复用导出函数并保留 Unity .meta。
