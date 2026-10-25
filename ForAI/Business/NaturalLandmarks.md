# 高山、峡谷与巨树探索
关键词：高山、巍峨、峡谷、黑暗谷底、山腰云雾、参天巨树、奇观、绳索、自然地形、NaturalEntrances。

## 文档目录
正文：大地图 / 探索入口 / 小地图 / 资源与验证；关键入口：生成 / 规则 / 显示。

## 正文

- 新地图生成版本 8 的 HighMountain=12 使用实际占地组织主脊、三峰两鞍、下降支脊和排水谷；内部中心与主轴不再取裁剪前包围盒。峰高按真实占地高宽比限制，细节不超过主体尺度的2.5%。高山配置高程1～58仍是包络，实际高度随面积调整；Canyon=13仍为-42～6，普通Mountain参数保持原样。策略和水文契约见[地图](Map.md)。
- v8高山仍由完整平顶六角台子组成，不输出连续山面的 `surfaceCorners`。先用脊谷网络产生高度场，再形成有组织的六角台阶和连片同高平台；沿用原地块模型与柱体渲染，保留顶面和侧面。山体风格以六角面可读为约束，不用连续三角外壳覆盖地格。
- 峰壁、峰顶及峡谷壁/底使用 `worldTravelBlocked`，道路、设施与世界旅行均遵守。峡谷保留有实体的六角底块，颜色随 `canyonDepth` 压暗；地表与侧壁都保留这种深色，不依赖空洞或摄像机背景。`cliffTintStrength` 控制侧壁保留地貌颜色的程度。
- `MapAtmosphereTable` 从真实山体最低/最高高程确定山腰云带，独立位置噪声形成稀疏云团。云带无碰撞和导航状态，由 `MapCloudRenderer` 透明绘制并遵守世界迷雾；进小地图隐藏，释放地图时销毁材质/网格。
- `MapWonderTable` 最多生成一棵参天巨树。完整模型占半径 9 的 271 个连续格，要求完整干地、无道路/建筑且满足地面高差；无合法地点时不生成。占地保留真实地面并阻止世界旅行，树脚入口放在占地外圈。奇观独立随机流不影响区域抽取，显示为整棵树，远景不会按普通小装饰的 LOD 被省略。
- `variantAssetIds` 是巨树完整外形池：1106 保留原雕刻巨树，1109 为偏心长枝与丰茂侧冠的奇幻变体；空池使用 `assetId`。使用独立位置噪声选择，种子与配置不变时重建外形一致；两种模型共享相同占地与局部根区，外形选择不改变地格、入口身份或保存的探索状态。
- `NaturalEntrances.Build` 在营地最终确定后，以实际旅行高差和阻挡做连通搜索；只为可达的山脚/谷缘候选与巨树外圈建立入口。高山/峡谷身份为 `300000+region.instanceId`，巨树为 `400000+wonder.id`；自然地点追加在既有地点之后。
- 高山作为完整Region范围的特殊地点：`worldRegionId` 让范围内已发现格共用一个入口，点击坡面或峰顶仍沿大地图陆路走到固定可达山脚，再进入副本。发现任何一块山坡即可识别地点，未知格仍不能点击；`WorldFog` 的Region查询只是基于原生发现列表的增量索引，不新增权威探索状态。
- 峡谷首次成功进入消耗共享背包的麻绳（物品 82）一根，未进入/失败/没绳不会扣除。原生 `AdventureData.HasVisited` 是固定绳索已建立的唯一持久依据；重进及继续远征均免费，不维护第二套 Lua 状态。入口说明使用 Language/LuaTxt。当前交互复用到达地点后进入小地图，不播放攀爬动画。
- 局部地图均有独立策略：HighMountain=9/地图70，Canyon=10/地图71，GiantTree=11/地图72；主题覆盖全部13种地貌供边界混色。`NaturalTerrain` 只共享角点、步道渐变、对称通行边和入口连通域，不套地牢房间算法。
- 高山局部v2先生成登顶主路，再以主路/平台/山脊约束山体高程。入口→4级平台→最高峰净爬升48米；主路和实际最短路径都不下降，短平台可走平。只开放道路/平台，路线进度约束阻止跨折返捷径，仍可原路下山。最终每格 `corners` 均等于该格中心高度，走既有平顶六角柱渲染；相邻小步高表现攀登，不以连续坡面焊掉六角顶面。`ascentRoute/ascentStages` 是静态生成与预览数据，宽肩高度过渡防止路面被切成深沟。参数新增字段不改旧值，显式 `source.generationVersion<=7` 继续走 `HighMountainLegacyGenerator`。
- 峡谷局部仍从负高程谷底的绳降落脚台进入，保留实体岩壁、曲流禁行水道和可达高岸回路。巨树局部只显示六段粗根和一段巨大树干基部，以及普通尺度的林木，不引用完整巨树模型；模型完整投影避让中央步道。局部导航继续沿用[MapArea](MapArea.md)的格索引与真实坡面。
- 远征保存 `generationVersion`。缺字段的旧远征按旧v6地貌池重建，固定配方转换为v5；v5/v6不生成这些奇观、云带和新入口。新游戏用v8，v7继续原高山高度和原局部布局，旧游戏保存时仍写回原版本；不改变既有角色占格或探索记录。
- 模型经 Blender 制作、显式 FBX 导入；来源、尺寸和导入证据归[地图资源](MapArt.md)。巨树按本次美术要求采用连续雕塑木体与簇叶，精度高于普通低模装饰。
- 算法参考：[Hnaidi等的特征曲线地形](https://onlinelibrary.wiley.com/doi/10.1111/j.1467-8659.2010.01806.x)用高度、坡度和粗糙度约束控制地形；本项目借鉴约束先行，采用有限次Lua平滑，不是论文GPU多重网格的完整移植。[Génevaux等的水文地形](https://www.cs.purdue.edu/cgvlab/www/publications/Genevaux13ToG/)启发脊谷网络组织，当前没有执行地质时间尺度侵蚀。
- 路线参考：[Galin等的方向相关最短路](https://perso.liris.cnrs.fr/eric.galin/Articles/2010-roads.pdf)把坡度和曲率纳入代价。本副本以种子控制的平滑折返路线与逐段高程约束保证攀登顺序，没有为引用论文而改写项目通用寻路器；实际通行继续使用既有六邻接和walkMask。

## 关键入口

- [大地图地貌](../../Lua/Game/Map/MapLandforms.lua) / [奇观布局](../../Lua/Game/Map/MapWonders.lua) / [云带布局](../../Lua/Game/Map/MapAtmosphere.lua) / [自然入口](../../Lua/Game/MapArea/NaturalEntrances.lua)。
- [奇观参数](../../Config/Tables/Map/MapWonderTable.json) / [云带参数](../../Config/Tables/Map/MapAtmosphereTable.json) / [入口消耗](../../Config/Tables/MapArea/MapAreaNaturalEntranceTable.json)。
- [高山局部](../../Lua/Game/MapArea/HighMountainGenerator.lua) / [峡谷局部](../../Lua/Game/MapArea/CanyonGenerator.lua) / [巨根局部](../../Lua/Game/MapArea/GiantTreeGenerator.lua) / [共用坡面导航](../../Lua/Game/MapArea/NaturalTerrain.lua)。
- [登顶路线](../../Lua/Game/MapArea/MountainAscentPath.lua) / [路线约束高度场](../../Lua/Game/MapArea/MountainAscentTerrain.lua) / [大地图脊谷网络](../../Lua/Game/Map/MountainRidgeNetwork.lua) / [六角地形与整片悬停](../../Assets/GameFramework/Samples/Map/MapPreviewRenderer.cs)。
- [云雾渲染](../../Assets/GameFramework/Samples/Map/MapCloudRenderer.cs) / [云雾Shader](../../Assets/GameFramework/Resources/MountainCloud.shader) / [地表Shader](../../Assets/GameFramework/Resources/MapGround.shader)。
- 最小 Lua 检查：用 `python -B Tools/Tests/run_lua.py` 分别执行 [大地图高差](../../Tools/Tests/map_alpine_canyon.lua)、[三个局部地形](../../Tools/Tests/maparea_alpine_canyon.lua)、[入口和首次消耗](../../Tools/Tests/natural_entrances.lua)；[种子地图](../../Tools/Tests/map_seeded.lua)包含旧配方与协程创建回归。
- [编辑态实景预览](../../Tools/Tests/terrain_wonders_preview.cs) / [预览输入](../../Tools/Tests/terrain_wonders_preview.lua)：现有 Editor 中独立 PreviewScene 检查真实渲染与模型，输出 `Docs/Previews/TerrainWonders/`，包括关闭装饰的高山对照；不进入 Play 或写玩家存档。
- [原生状态边界检查](../../Tools/Tests/natural_entry_state.cs)：真实 C# 库存/visited 配合生产 `Enter` 规则，验证首次扣绳、重复进入、JSON恢复免扣和新旧地图版本字段；只使用独立 LuaEnv 与内存序列化，不写玩家文件。
- v8专项：[单调攀登与旧版指纹](../../Tools/Tests/high_mountain_ascent.lua)、[山体发现查询](../../Tools/Tests/mountain_site_discovery.lua)。前者验证真实寻路、六角平顶面及旧版一致性；地点完整占地、悬停/标签/遮罩回归见[world_sites_editmode.cs](../../Tools/Tests/world_sites_editmode.cs)。
