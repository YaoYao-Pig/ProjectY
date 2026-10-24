# 世界探索与战争迷雾

关键词：战争迷雾、雾 Shader、WorldFog、探索记录、可见、已探索灰色、大地图、小地图、v20。

## 文档目录
正文：探索权威 / 表现 / 持久化与验证；关键入口：Data / 规则 / Shader / HUD。

## 正文

- `Adventure.fog` 缓存静态地图坐标到格索引的映射；`AdventureData.WorldExploration` 的 `WorldMapExplorationData` 唯一持有已发现与当前可见状态。索引为 1 基并对应生成地图的 cells，容量最多 100000；不能把 C# 显示纹理当成探索状态。
- Catalog `Map.WorldVisionRadius` 默认 8 格，取小队当前大地图格的六边形半径范围，暂不计算山体视线遮挡。新开局只揭开当前位置周围；实际旅行完成一步后更新，停留/暂停不重复改写。`Reveal` 先验证完整输入，未知、重复和越界格不能部分提交。
- 未探索地形由流动云雾遮住，已探索但离开视野的地形与静态模型保留灰色记忆，当前视野正常着色。未知地点不进入快照、导航或地点标签；移动队伍仅在当前视野中投影，据点按已发现状态显示。模拟与外交不因雾改变，地面点击仍可规划探索路线。
- `WorldFogRenderer` 每个大地图观察器拥有一个最大 1024×1024 的线性 RGBA 遮罩和一张云雾网格。R/G/B 分别为当前视野、已发现、实际地图覆盖；预建像素到格的链表，只在探索 Revision 变化时更新状态像素并上传，不逐帧传输整张 Lua 索引表。
- `WorldFog.shader` 使用多层位置噪声、两向流动、轻微高度浮动及九点遮罩柔化。`WorldFogSampling.hlsl` 供地表、道路/装饰、水和自然细节共享，隐藏未知片元并灰化记忆区域；参数绑定到观察器自己的 Material，不修改全局 Shader 状态或共享资源。水花只在当前视野内新发射。
- 独立地图实验室没有远征探索 Data 时仍可预览全图。切到局部地图隐藏世界雾层；换世界/销毁时释放纹理、网格、材质和对象，不保留旧世界探索状态。
- 小地图继续使用既有 Known/Visible、墙体和楼层遮挡。`MapFogColors.Remembered` 将已知不可见的地面、陈设、台阶和材质细节转换为有亮度下限的灰色；未知区域仍隐藏/黑色，当前视野保持原色，不增加视线或可交互目标。
- v20 远征保存 `expedition.worldFog={version:1,cells,known}`；Visible 不持久化，Prepare 按重建地图和当前旅行位置恢复。缺字段、未知格式、重复/越界格和地图格数不一致在提交前拒绝。v18 及更旧完整远征明确迁移为当前位置周围可见，保留原地图/人物/旅行位置，不能虚构旧档没有记录的探索历史。
- [world_fog_hud.lua](../../Tools/Tests/world_fog_hud.lua) 与 [world_fog_editmode.cs](../../Tools/Tests/world_fog_editmode.cs) 在现有空闲 Editor 的独立 PreviewScene/LuaEnv 和 OS 临时存档执行：真实路线探索、快照过滤、v20 存读与损坏拒绝、v18 迁移、实际 MainHud 按钮、云雾动画像素与小地图三态颜色。结果及实景在 [WorldFog 预览](../../Docs/Previews/WorldFog/world-fog-0.png) / [验证记录](../../Docs/Previews/WorldFog/validation.txt)。不进入 Play，不写玩家存档。

## 关键入口

- [探索 Data](../../Assets/GameFramework/Runtime/Data/WorldMapExplorationData.cs) / [规则与静态索引](../../Lua/Game/Adventure/WorldFog.lua) / [旅行接入](../../Lua/Game/Adventure/WorldTravel.lua)。
- [云雾显示](../../Assets/GameFramework/Samples/Map/WorldFogRenderer.cs) / [雾 Shader](../../Assets/GameFramework/Resources/WorldFog.shader) / [共享采样](../../Assets/GameFramework/Resources/WorldFogSampling.hlsl)。
- [小地图记忆颜色](../../Assets/GameFramework/Samples/Map/MapFogColors.cs) / [地形和陈设](../../Assets/GameFramework/Samples/Adventure/MapAreaRenderer.cs) / [坡阶与楼板](../../Assets/GameFramework/Samples/Adventure/TownSurfaceRenderer.cs)。
- [持久化](CharacterSave.md) / [MainHud 时间与定位按钮](MainHud.md)。
