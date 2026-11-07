# 区域天气与云雨表现
关键词：天气、晴天、阴天、下雨、雨滴、雨粒子、水花、云团、云影、星星、星空、WorldWeatherField、MapWeatherRenderer。

## 文档目录
正文：逻辑查询 / 显示与预算 / 生命周期与验证；关键入口：数据、配置、宿主、Shader、检查。

## 正文

- `WorldWeatherField` 是无状态的权威天气场：相同世界种子、世界 XZ、绝对游戏分钟和配置得到相同结果；不依赖相机、帧率、查询次序或全局 RNG。固定成本连续噪声输出 `WeatherId`（1晴、2阴、3雨）、`Cloud/Rain`（0–1）、`WindX/WindZ`。云雨强度连续，天气身份按阈值分类；风单位为世界单位/游戏分钟，静风仍随时间演化。无需遍历全图或为不可见区域建立特效。
- `Game.Adventure.Weather.Bind` 在新世界与读档时用已保存的种子重新建立同一配置的场；不新增存档字段。`Query(adventure,x,z,minutes?)` 默认使用已保存的 `NarrativeData.Minutes`；`QueryCell` 将世界六角格转换成 XZ。`DemoBridge.weather_field` 将同一场实例交给显示层；`weather_at(x,z,minutes?)` 返回采样结果。当前不改变移动、战斗、视野或水位，也没有剧情天气覆盖的持久状态。
- 大地图直接按世界 XZ 采样；局部 MapArea 快照携带活动地点的 `weatherX/weatherZ`，整个局部图继承该地点天气。局部米制坐标不直接当作大地图坐标，进出地点不重新随机；地下只关闭表现，不修改世界天气。
- 配置源为 `MapWeatherSystemTable`（区域尺度、演变周期、风、表现预算）和 `MapWeatherTable`（晴/阴/雨的云雨及光雾预设）。区域尺度以大地图地格半径为单位。`MapPresentation.Snapshot` 复制实体配置给 C#，所有天气名称使用 `text` 字段。修改配置仍须走[配置导出](../Framework/Config.md)。
- 显示仅缓存相机附近的 32×32 云量/雨强纹理，默认最短 0.25 秒重采样；不变的镜头和游戏时间不重建，传送、大幅缩放或时间跳跃立即更新。雨滴和水花各复用一个 ParticleSystem 与预分配数组，解析式更新位置、不启用逐滴碰撞/物理射线。默认硬上限为 96 云团、1800 雨滴、128 水花，远景关闭水花，缩放不突破预算。雨滴空间位置不随相机平移。
- 云形体使用独立连续显示时钟，每帧更新有固定世界格身份的实例槽；风向来自权威场，显示风速按地格半径缩放并限幅，不由离散游戏分钟直接计算位置。游戏时钟暂停时云继续飘动，显示 delta 为零才停止；长帧限制动画追赶量。密度、颜色和高度目标默认每 0.25 秒采样后逐帧渐变，静止镜头下的云运动不上传天气纹理。平移复用原身份，边缘槽淡出回收；明显缩放先淡出旧间距再换网格，切图和隐藏后重新显示从透明淡入。时间大跳立即更新权威天气与纹理，但云位置不瞬移。槽、矩阵与颜色数组均预分配，不做全图逐帧扫描。
- 世界主光在地图地表、共享模型、植被及水面 Shader 按天气纹理局部衰减，避免一处下雨使全图变暗；环境光、额外点光和发光保持原契约。局部地图天气统一，由环境控制器混合方向光/雾，关闭重复的空间衰减。自定义 PBR 组合基于 URP 14，升级管线必须复核。
- `MapWeatherSurface` 绑定地图时缓存六角列的最高地面、水面和遮雨标记，查询为坐标取整、字典查找和固定六扇形高度插值。室内/上盖列即使剖切仍遮雨；施工版本变化才重建列索引。当前按列保守遮雨，同列室内上方的露天平台也会被遮雨；未做模型级屋檐、树冠或地图边界外海碰撞。
- `FantasySky` 的稳定星点随昼夜淡出，被实际云层遮挡；雨云更暗。俯视画面用地图上方云团表现局部天气，天空在镜头能看见时显示。时间/天气窗口默认自动演变，手动天气只作画面预览，不改变逻辑查询或存档；“自动天气”恢复现场采样。
- `MapEnvironmentController` 持有天气显示会话；普通与异步创建/读档均显式绑定天气场。进入/退出 MapArea 更新地形缓存，载入期间隐藏特效。粒子仅在目标相机渲染时启用，天气 Shader 全局参数在相机回调中设置并恢复；销毁释放材质、网格、纹理、粒子对象及回调，不修改源资源。
- 最小验证：`world_weather_config.lua` 检查真实导出、语言键、复制所有权、查询坐标/时钟与实例复用；`world_weather_core.cs` 检查真实 C# 确定性、连续性、三种天气、非法参数、完整 uint 种子及 10 万查询耗时/分配；`world_weather_render_editmode.cs` 使用真实 2500 格世界和城镇在独立 PreviewScene 检查区域差异、预算、遮雨、地下关闭、星点贡献及资源/环境恢复；`world_weather_motion_editmode.cs` 独立平地夹具检查 60fps 连续位移、采样边界、时钟暂停/跳跃、相机平移/传送/缩放、淡入淡出及托管分配。上述是定向入口，不授权额外启动 Editor、Play 或全面测试；实际离屏结果写 `Docs/Previews/Weather/validation.json`，不代表 Player GPU 性能基准。

## 关键入口

- [权威天气场](../../Assets/GameFramework/Runtime/Data/WorldWeatherField.cs) / [Lua 查询入口](../../Lua/Game/Adventure/Weather.lua) / [DemoBridge](../../Lua/Game/Adventure/DemoBridge.lua)。
- [天气系统配置](../../Config/Tables/Rendering/MapWeatherSystemTable.json) / [天气表现配方](../../Config/Tables/Rendering/MapWeatherTable.json) / [配置快照](../../Lua/Game/Rendering/MapPresentation.lua)。
- [显示会话](../../Assets/GameFramework/Samples/Adventure/MapWeatherRenderer.cs) / [地面与遮雨缓存](../../Assets/GameFramework/Samples/Adventure/MapWeatherSurface.cs) / [环境控制器](../../Assets/GameFramework/Samples/Adventure/MapEnvironmentController.cs)。
- [天气采样 Shader](../../Assets/GameFramework/Resources/MapWeather.hlsl) / [主光组合](../../Assets/GameFramework/Resources/MapWeatherLighting.hlsl) / [云团](../../Assets/GameFramework/Resources/MapWeatherCloud.shader) / [雨滴与水花](../../Assets/GameFramework/Resources/MapWeatherParticle.shader) / [天空](../../Assets/GameFramework/Rendering/FantasySky.shader)。
- [配置检查](../../Tools/Tests/world_weather_config.lua) / [数据检查](../../Tools/Tests/world_weather_core.cs) / [真实地图离屏检查](../../Tools/Tests/world_weather_render_editmode.cs) / [云运动检查](../../Tools/Tests/world_weather_motion_editmode.cs)。
