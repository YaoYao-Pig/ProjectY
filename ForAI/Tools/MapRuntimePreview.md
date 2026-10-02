# Unity 地图运行测试

关键词：地图测试场景、Play、运行时地图、MapRuntimePreview、MapRuntimeDemo、GPU 实例、配置模型、森林、冰雪、瀑布、流水、湖面、分层波纹、水花粒子。

## 文档目录

正文：打开与操作 / 数据与渲染边界 / 验证；关键入口：场景 / Lua 适配 / C# 渲染。

## 正文

- 菜单 `Project Y/地图/打开运行测试场景` 创建缺失场景并打开；`Project Y/地图/运行地图测试` 进一步进入 Play。保存的 `MapRuntimePreview.unity` 也可直接打开后按 Play。切换前由 Unity 提示保存已修改的场景；菜单保留既有场景，并同步资源表指定的模型引用。
- 场景自带 `GameBootstrap`（关闭原 Demo 面板）、相机、光源和已绑定模型。`MapRuntimeDemo.Start` 通过同一常驻 LuaEnv 中的 `Main → MapSystem → MapGenerator` 生成地图，没有第二套读表或算法，也不依赖 Web 服务。
- 默认种子 20260921、配方 `1,2,3,4,5,6,1,4,5,6`。面板可重生成、递增种子、开关水面/建筑/道路/地貌装饰、定位城镇与瀑布；滚轮缩放，中键/WASD 平移，右键旋转，Q/E 转向，F 全图，R 按当前输入重生成。
- 目标格数通过 `MapPreviewSettings` 从已启动 Config 读取默认值与上限（当前一万/十万），面板提供 1 万、5 万、10 万快捷填入，也可手填或留空按原配方。`MapPreviewData.Generate` 的可选 targetCells 传入 `GenerateRenderMap → MapSystem`；未传参数的其他调用保持兼容。十万格仍同步生成与读取，期间主线程会等待，不表示运行时分帧生成或流式加载已实现。
- 与普通游戏运行相同，读取 `Resources/_Gen/Config` 已导出的二进制与 `Lua/_Gen`。改表后先退出 Play，执行 `Project Y/Config/Export Tables` ；若新增或改了资源路径，再执行 `Project Y/地图/同步配置资源引用`（打开场景菜单也会同步），然后运行；Lua 文件变化也在下一次 Play 重新加载。生成按钮不隐式重导表或热重载系统。
- `GenerateRenderMap` 仅解析配方文本并调用已启动的 Map；`MapRenderSnapshot` 将查询结果复制为无循环的显示输入。水格复制 `isRiver/riverId/waterDepth/flowTo`，下游对象转为索引（Lua 0、C# -1 表示无下游）；湖泊可保留河网引用，视觉类型仍以最终 waterKind 为准。快照 assets 只包含当前地面、实际水格、建筑及平台、地貌装饰引用的资源，保留资源表顺序；新增小地图模型不会要求大地图绑定未使用资源。C# 读取完立即释放所有 LuaTable，长期持有普通 C# 数据，不持有 Lua 对象或游戏实体状态。
- 资源表通过 Editor 解析 MapAssetTable.json 并序列化为 ID/路径/GameObject 数组；Play 中仍由工程 ConfigSystem 读取导表资产参数，若 ID/路径不一致或缺模型明确报错。地面/水面使用每格 terrainAssetId/waterAssetId，颜色使用 groundColor；顶面色槽由 tintMaterial 指定，侧面保持较暗。城市平台仅覆盖真实建筑占地，模型与材质见 [地图资源](../Business/MapArt.md)。
- 建筑使用 assetId/platformAssetId，按 entrance 朝向及配置总高/referenceHeight 缩放；单格/七格平台保持完整，不随建筑旋转。地牢、民居、工坊、集会厅与城堡都来自真实布局。装饰使用 Lua 给出的 assetId/scale/yaw，显示实际树木和山石模型。
- 地块、平台、建筑与装饰使用最多 1023 实例一批的 GPU Instancing，复用导入网格，无需开启 FBX Read/Write。预览 Shader 负责纯色、硬边和光照；每格不会创建独立 GameObject。地貌颜色和资源不以枚举分支硬编码；当前完整平台支持单格/七格。
- 道路沿原始路径各格顶面绘制，并在高差处补立面；不生成桥梁、碰撞、寻路组件或队伍交互。水面按真实高度渲染，共边落差补双面水幕，正反面拆开顶点避免法线抵消，水幕稍离崖壁以避免重叠闪烁。渲染数据、道路/水幕 Mesh 和预览材质随观察器销毁释放，不修改原 FBX 材质。此场景用于算法与美术联调，尚未加入 Build Settings。
- `MapWaterEffects` 为地图测试与远征大地图共用，生成无缝 RGBA 噪声输入与流向；同 riverId 的扩宽河格继承最近中心线方向。`MapWater.shader` 以两尺度势函数的解析梯度构造时变旋涡流场，双相位有限平流分别采样后按 sin² 权重混合；重置时零权重，纹理梯度计入流场拉伸而排除相位跳变。四邻有限支撑波包具有独立寿命、方向和波长，消散后换代，波高与近似斜率驱动波峰明暗和法线。真实河流方向增量在格边渐变回连续全局流场，平面水格不位移，避免六边形拼缝；远景同时衰减波高着色和法线细节。
- 明显落差用平滑法线弧形水幕覆盖顶底硬折角，并在上下沿覆盖噪声渐隐白沫和破碎扩散弧，不改地形、水位或碰撞。效果按真实相邻水位落差创建，不依赖瀑布标签。水面不透明并写深度/法线，透明泡沫和水花不写深度；无需反射或相机深度纹理。上述流场用于视觉表现，不是物理流体仿真。
- 水花只使用一个共享 ParticleSystem；构建时按空间桶缓存河湖、水岸和落差发射源，定期筛选可见源，最多 32 个发射点、768 个活粒子。落差源混合快速下冲长水滴、向外反弹水花和少量雾滴，按落差增强并随机脉动；按整段落差判可见，发射预算轮换源避免饥饿。远景停止细小水滴发射，纹理动画继续；水面关闭、进入 MapArea、重生成和销毁均清空水花。Shader 由 Resources 显式加载，贴图、材质及粒子对象由观察器创建与释放。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/map_render_snapshot.lua` 验证真实生成结果的坐标、水位、引用索引、独立副本和非法输入。C# 变化集中编译一次；纯 Shader 调整只定向导入该资产，不主动触发 C# 编译。再按改动与用户授权检查生成、重生成、镜头和退出；不运行地图全量回归或完整构建。

## 关键入口

- [测试场景](../../Assets/GameFramework/Samples/Map/MapRuntimePreview.unity) / [菜单](../../Assets/GameFramework/Editor/MapRuntimePreviewMenu.cs)：场景创建、模型绑定、打开和运行。
- [MapRuntimeDemo.cs](../../Assets/GameFramework/Samples/Map/MapRuntimeDemo.cs)：输入面板、相机和生成生命周期；[MapPreviewData.cs](../../Assets/GameFramework/Samples/Map/MapPreviewData.cs)：LuaTable 转换与释放。
- [MapPreviewRenderer.cs](../../Assets/GameFramework/Samples/Map/MapPreviewRenderer.cs) / [实例 Shader](../../Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader)：模型批次、连续平台、道路和显示资源回收。
- [MapWaterEffects.cs](../../Assets/GameFramework/Samples/Map/MapWaterEffects.cs) / [水体 Shader](../../Assets/GameFramework/Resources/MapWater.shader)：河流方向、分层纹理、水幕泡沫与限量水花。
- [水体定向预览](../../Tools/Tests/map_water_render.cs)：Edit Mode MCP 片段，以真实 FBX 和渲染批次构建 20 格临时布局，检查流向、无标签落差白沫、水幕法线、下冲/上溅及生命周期。`captureMotion=true` 导出 60 帧；只覆盖临时材质的 `_WaterPreviewTime`，运行默认 -1 使用游戏时间。通过原 Mesh 的逐材质槽代理捕获，不代替 Play 中 GPU 实例渲染验收。[动态近景](../../Docs/Previews/Rendering/map-water-flow-close.gif) / [落差近景](../../Docs/Previews/Rendering/map-water-impact-close.png) / [检查记录](../../Docs/Previews/Rendering/map-water-validation.json)。
- [GenerateRenderMap.lua](../../Lua/Game/Map/GenerateRenderMap.lua) / [MapRenderSnapshot.lua](../../Lua/Game/Map/MapRenderSnapshot.lua) / [适配检查](../../Tools/Tests/map_render_snapshot.lua)：复用运行中生成器、显示快照与测试。
