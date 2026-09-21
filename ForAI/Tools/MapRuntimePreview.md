# Unity 地图运行测试

关键词：地图测试场景、Play、运行时地图、MapRuntimePreview、MapRuntimeDemo、GPU 实例、配置模型、森林、冰雪、瀑布。

## 文档目录

正文：打开与操作 / 数据与渲染边界 / 验证；关键入口：场景 / Lua 适配 / C# 渲染。

## 正文

- 菜单 `Project Y/地图/打开运行测试场景` 创建缺失场景并打开；`Project Y/地图/运行地图测试` 进一步进入 Play。保存的 `MapRuntimePreview.unity` 也可直接打开后按 Play。切换前由 Unity 提示保存已修改的场景；菜单保留既有场景，并同步资源表指定的模型引用。
- 场景自带 `GameBootstrap`（关闭原 Demo 面板）、相机、光源和已绑定模型。`MapRuntimeDemo.Start` 通过同一常驻 LuaEnv 中的 `Main → MapSystem → MapGenerator` 生成地图，没有第二套读表或算法，也不依赖 Web 服务。
- 默认种子 20260921、配方 `1,2,3,4,5,6,1,4,5,6`。面板可重生成、递增种子、开关水面/建筑/道路/地貌装饰、定位城镇与瀑布；滚轮缩放，中键/WASD 平移，右键旋转，Q/E 转向，F 全图，R 按当前输入重生成。
- 与普通游戏运行相同，读取 `Resources/Config` 已导出的二进制与 `Lua/Generated`。改表后先退出 Play，执行 `Project Y/Config/Export Tables` ；若新增或改了资源路径，再执行 `Project Y/地图/同步配置资源引用`（打开场景菜单也会同步），然后运行；Lua 文件变化也在下一次 Play 重新加载。生成按钮不隐式重导表或热重载系统。
- `GenerateRenderMap` 仅解析配方文本并调用已启动的 Map；`MapRenderSnapshot` 将查询结果复制为无循环的显示输入。C# 读取完立即释放所有 LuaTable，长期持有普通 C# 数据，不持有 Lua 对象或游戏实体状态。
- 资源表通过 Editor 解析 MapAssetTable.json 并序列化为 ID/路径/GameObject 数组；Play 中仍由工程 ConfigSystem 读取导表资产参数，若 ID/路径不一致或缺模型明确报错。地面/水面使用每格 terrainAssetId/waterAssetId，颜色使用 groundColor；顶面色槽由 tintMaterial 指定，侧面保持较暗。城市平台仅覆盖真实建筑占地，模型与材质见 [地图资源](../Business/MapArt.md)。
- 建筑使用 assetId/platformAssetId，按 entrance 朝向及配置总高/referenceHeight 缩放；单格/七格平台保持完整，不随建筑旋转。地牢、民居、工坊、集会厅与城堡都来自真实布局。装饰使用 Lua 给出的 assetId/scale/yaw，显示实际树木和山石模型。
- 地块、平台、建筑与装饰使用最多 1023 实例一批的 GPU Instancing，复用导入网格，无需开启 FBX Read/Write。预览 Shader 负责纯色、硬边和光照；每格不会创建独立 GameObject。地貌颜色和资源不以枚举分支硬编码；当前完整平台支持单格/七格。
- 道路沿原始路径各格顶面绘制，并在高差处补立面；不生成桥梁、碰撞、寻路组件或队伍交互。水面按真实高度渲染，共边落差补双面水幕，瀑布下方增加静态白沫。正反面拆开顶点避免法线抵消，水幕稍离崖壁以避免重叠闪烁。渲染数据、道路/水幕 Mesh 和预览材质随观察器销毁释放，不修改原 FBX 材质。此场景用于算法与美术联调，尚未加入 Build Settings。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/map_render_snapshot.lua` 验证真实生成结果的坐标、水位、引用索引、独立副本和非法输入。C# 与 Shader 变化集中编译一次，再按用户授权在此场景检查生成、重生成、全图/城镇镜头和退出；不运行地图全量回归或完整构建。

## 关键入口

- [测试场景](../../Assets/GameFramework/Samples/Map/MapRuntimePreview.unity) / [菜单](../../Assets/GameFramework/Editor/MapRuntimePreviewMenu.cs)：场景创建、模型绑定、打开和运行。
- [MapRuntimeDemo.cs](../../Assets/GameFramework/Samples/Map/MapRuntimeDemo.cs)：输入面板、相机和生成生命周期；[MapPreviewData.cs](../../Assets/GameFramework/Samples/Map/MapPreviewData.cs)：LuaTable 转换与释放。
- [MapPreviewRenderer.cs](../../Assets/GameFramework/Samples/Map/MapPreviewRenderer.cs) / [实例 Shader](../../Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader)：模型批次、连续平台、道路和显示资源回收。
- [GenerateRenderMap.lua](../../Lua/Game/Map/GenerateRenderMap.lua) / [MapRenderSnapshot.lua](../../Lua/Game/Map/MapRenderSnapshot.lua) / [适配检查](../../Tools/Tests/map_render_snapshot.lua)：复用运行中生成器、显示快照与测试。
