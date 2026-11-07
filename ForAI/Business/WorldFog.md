# 世界探索与战争迷雾

关键词：战争迷雾、雾 Shader、WorldFog、探索记录、可见、已探索灰色、大地图、小地图、地图边界、外海、海洋、水面衔接、MapBoundary、v20。

## 文档目录
正文：探索权威 / 表现 / 持久化与验证；关键入口：Data / 规则 / Shader / HUD。

## 正文

- `Adventure.fog` 缓存静态地图坐标到格索引的映射；`AdventureData.WorldExploration` 的 `WorldMapExplorationData` 唯一持有已发现与当前可见状态。索引为 1 基并对应生成地图的 cells，容量最多 100000；不能把 C# 显示纹理当成探索状态。
- Catalog `Map.WorldVisionRadius` 默认 8 格，叠加[营地队伍装备](Camp.md)宠物的有效半径收益，取小队当前大地图格的六边形范围，暂不计算山体视线遮挡。旅行换格或有效半径改变时更新；停留且半径不变时不重复改写。卸下宠物收回当前可见范围但保留已探索格；读档准备按候选存档的宠物重建视野。`Reveal` 先验证完整输入，未知、重复和越界格不能部分提交。
- `WorldFog:RevealAll()` 将当前地图全部格写入同一探索 Data，并暂停半径视野更新；`RestoreVision()` 关闭该模式，清除位置缓存并立即按当前旅行位置恢复半径视野，保留已探索记录。`Bind/Reset` 也清除会话模式。入口和使用约定见 [GM 全图视野开关](../Tools/GM.md)，不增加独立探索状态或修改小地图视野。
- 未探索地形由流动云雾遮住，已探索但离开视野的地形与静态模型保留灰色记忆，当前视野正常着色。未知地点不进入快照、导航或地点标签；移动队伍仅在当前视野中投影，据点按已发现状态显示。模拟与外交不因雾改变，地面点击仍可规划探索路线。
- [势力发现](Factions.md) 只消费当前 Visible，首次见到势力后由 NarrativeData 永久记录；地形 Known 本身不等于认识该势力。关系树未发现节点显示“？？？”，不改变本模块的探索权威或持久化格式。
- `WorldFogRenderer` 每个大地图观察器拥有一个最大 1024×1024 的线性 RGBA 遮罩和一张云雾网格。R/G/B 分别为当前视野、已发现、实际地图覆盖；预建像素到格的链表，只在探索 Revision 变化时更新状态像素并上传，不逐帧传输整张 Lua 索引表。
- `WorldFog.shader` 只对未知区域绘制多层流动云雾；完全已探索的片元在云噪声计算前返回透明，不向灰色记忆区再叠遮盖层。九点柔化后的视野/已知值按地图覆盖归一化，地图外采样不能在全图揭开后制造灰雾边圈。`WorldFogSampling.hlsl` 供地表、道路/装饰、水和自然细节共享，隐藏未知片元；记忆灰度用单调亮度曲线抬升暗部并压缩 HDR，保留夜间坡面、轮廓和材质明暗，不能以硬灰度下限压平暗部。参数绑定到观察器自己的 Material，不修改全局 Shader 状态或共享资源。水花只在当前视野内新发射。
- 大地图与 MapArea 的外海共用 `MapBoundaryRenderer` / `MapOcean.shader`，河湖、港湾与外海共用 `MapWaterSurface.hlsl` 的世界坐标、时钟、波面法线及岸线场。每个显示器持有最大 1024×1024 的静态 RGBAFloat 场（地图内为1、地图外为负出界距离/精确水位/距陆地距离/光学水深，距离和水深均除以格半径）。真实水深来自 WaterDepth；无河床数据的旧水面使用明确的岸线深度配方，外海在边界水深基础上逐渐加深，均只影响显示。外海按各段海岸局部贴合，允许不同高度：干岸取地面（含连续地表最低角点）下半格半径，河口保留精确水位。仅与连通外部空域接触的岸线像素向外传播高度，不能穿过陆地；外部高度场平滑衔接各段海岸，内部水位不变。内陆湖泊、深坑和封闭孔洞不影响外海，单处高河口或低峡谷也不能统一抬高或压低整张地图的海面。WaterDepth>0 时必须优先使用 WaterLevel，只有旧 `kind=water` 且无水深时才用 Position.y；否则会误把港湾河床当水面。桥上层不会把桥下水面变成海岸。外海仅填空背景和海面以下的地图外表面，本帧深度保留岸壁、建筑与船；不改变探索、存档、导航和拾取。队列为 Transparent+10，战争迷雾 +20 继续遮住未知大陆，深度时序见[渲染管线](../Framework/Rendering.md)。
- 外海仅提交一个四顶点/两三角形视口网格；可见陆地与内部水面提前跳过外海求交。同水位场景的空背景仅保留一次场采样；不同水位地图在实际岸线高度上下界内二分求交，避免大高度差下迭代来回跳动。岸线和水深仅构建时上传，释放纹理 CPU 副本，Draw 不建立临时集合；不新增反射相机、SSR、FFT 或逐帧模拟纹理。
- 独立地图实验室没有远征探索 Data 时仍可预览全图。切到局部地图隐藏世界雾层；换世界/销毁时释放纹理、网格、材质和对象，不保留旧世界探索状态。
- 小地图继续使用既有 Known/Visible、墙体和楼层遮挡。`MapFogColors.Remembered` 将已知不可见的地面、陈设、台阶和材质细节转换为有亮度下限的灰色；未知区域仍隐藏/黑色，当前视野保持原色，不增加视线或可交互目标。
- v20 远征保存 `expedition.worldFog={version:1,cells,known}`；Visible 不持久化，Prepare 按重建地图和当前旅行位置恢复。缺字段、未知格式、重复/越界格和地图格数不一致在提交前拒绝。v18 及更旧完整远征明确迁移为当前位置周围可见，保留原地图/人物/旅行位置，不能虚构旧档没有记录的探索历史。
- [world_fog_hud.lua](../../Tools/Tests/world_fog_hud.lua) 与 [world_fog_editmode.cs](../../Tools/Tests/world_fog_editmode.cs) 在现有空闲 Editor 的独立 PreviewScene/LuaEnv 和 OS 临时存档执行：真实路线探索、快照过滤、v20 存读与损坏拒绝、v18 迁移、实际 MainHud 按钮、云雾动画像素与小地图三态颜色。结果及实景在 [WorldFog 预览](../../Docs/Previews/WorldFog/world-fog-0.png) / [验证记录](../../Docs/Previews/WorldFog/validation.txt)。不进入 Play，不写玩家存档。
- [记忆地形定向检查](../../Tools/Tests/world_fog_memory_editmode.cs) 只启动 Config/Map，使用真实 2500 格地图和弱主光，在独立 PreviewScene 对比已探索区的云雾层开/关，并检查灰度明暗、未知云层和当前原色；保留原场景及 RenderSettings，不启动完整游戏或访问玩家存档。[三态截图](../../Docs/Previews/WorldFogMemory/after/three-states-fog-on.png) / [实际结果](../../Docs/Previews/WorldFogMemory/after/validation.json)。
- [海岸高度回归](../../Tools/Tests/map_boundary_height.cs) 在现有空闲 Editor 中只检查生产边界纹理及 Shader：不同高度海岸的局部贴合、高河口、内陆湖泊/深坑、封闭孔洞、连续地表角点和同水位快速路径；GPU 回读后释放临时资源，不进入 Play 或修改当前场景。
- [外海定向检查](../../Tools/Tests/map_boundary_ocean.cs) 使用[真实世界及港湾快照](../../Tools/Tests/map_boundary_ocean.lua)，在独立 PreviewScene 检查大/小地图外背景遮盖、水纹动画、内部地形保留、内外水域共享场、正交远景/旋转/透视，以及战争迷雾与外海同时存在；验证探索 Revision 和原场景不变，不进入 Play。`shipwreckOnly=true` 仅渲染沉船并检查旧 `kind=water` 的衔接。实际结果见[大地图与港湾](../../Docs/Previews/MapOcean/validation.txt) / [沉船](../../Docs/Previews/MapOcean/Shipwreck/validation.txt)。
- [水深着色检查](../../Tools/Tests/stylized_water_depth.cs) 用生产 Shader 检查 .25、1.5、5、12 格半径的水深着色，验证浅水偏青绿且随深度逐级变暗，并检查近景波纹的亮度对比；[结果](../../Docs/Previews/WaterStyle/depth-validation.txt)。外海检查同时报告静态纹理字节数、同水位快速路径和预热 Draw 的托管分配；这些指标不代表 Play 中 GPU 帧率。`captureMotion=true` 导出 24 帧近景，当前[波纹动图](../../Docs/Previews/WaterRipples/water-motion.webp)由真实离屏帧编码。

## 关键入口

- [探索 Data](../../Assets/GameFramework/Runtime/Data/WorldMapExplorationData.cs) / [规则与静态索引](../../Lua/Game/Adventure/WorldFog.lua) / [旅行接入](../../Lua/Game/Adventure/WorldTravel.lua)。
- [云雾显示](../../Assets/GameFramework/Samples/Map/WorldFogRenderer.cs) / [雾 Shader](../../Assets/GameFramework/Resources/WorldFog.shader) / [共享采样](../../Assets/GameFramework/Resources/WorldFogSampling.hlsl)。
- [地图边界显示](../../Assets/GameFramework/Samples/Map/MapBoundaryRenderer.cs) / [外海 Shader](../../Assets/GameFramework/Resources/MapOcean.shader) / [共享水面](../../Assets/GameFramework/Resources/MapWaterSurface.hlsl)。
- [小地图记忆颜色](../../Assets/GameFramework/Samples/Map/MapFogColors.cs) / [地形和陈设](../../Assets/GameFramework/Samples/Adventure/MapAreaRenderer.cs) / [坡阶与楼板](../../Assets/GameFramework/Samples/Adventure/TownSurfaceRenderer.cs)。
- [持久化](CharacterSave.md) / [MainHud 时间与定位按钮](MainHud.md)。
