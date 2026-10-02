# URP、奇幻光影与像素风格

关键词：URP、渲染管线、后处理、WarmFantasy、MedievalFantasy、光束、体积光、薄雾、F9、风格切换、像素风、PixelArt、色阶、抖色、SSAO、Bloom、阴影、材质迁移、离屏相机。

## 文档目录

正文：资源与生命周期 / 材质契约 / 最小检查；关键入口：管线 / 风格 / 安装工具。

## 正文

- Unity 2022.3 使用 URP 14.0.11。工程基础 Graphics/Quality 引用 `WarmFantasyURP`，世界会话按 `Resources/Rendering/WorldVisualStyles` 选择自己的管线克隆。两套 Renderer 0 均为 Forward，Renderer 1 共用无世界后处理的离屏预览。
- 两套独立预设：`PixelInk → WarmFantasyURP / WarmFantasy` 保留像素墨线、4× MSAA、2048 主光阴影与半分辨率 SSAO；`MedievalFantasy → MedievalFantasyURP / MedievalFantasy` 使用原生分辨率、4× MSAA + SMAA、4096 四级联软阴影、全分辨率 SSAO、暖日光/冷暗部调色和柔和 Bloom。默认选择奇幻光影。HUD Overlay 保持清晰，不启用景深、运动模糊或色差。
- Unity 菜单 `Project Y/渲染/风格/奇幻光影`、`像素墨线` 或 F9 切换；运行中的 `FantasyPresentation` 立即更新管线/Profile/AA，选择保存到 WorldVisualStyles，下一次世界会话继续使用。`打开当前风格参数` 定位对应 Profile；F9 属于 Editor 菜单快捷键，不是 Player 的游戏按键。
- `FantasyPresentation` 由远征环境控制器或地图 Demo 创建，显式接收相机和宿主；创建全局 Volume，克隆所选 URP 资产，避免修改源预设。像素模式关闭相机后处理 AA/Dithering，奇幻模式开启 SMAA/Dithering；切换保留已计算的阴影距离。销毁时注销活动会话、释放 Volume/克隆并恢复相机及 Quality 管线。昼夜、天气、室内灯和原有环境雾仍归[地图环境](../Business/MapPresentation.md)。
- `FantasyAtmosphereRendererFeature` 在调色/Bloom 前以半分辨率计算高度薄雾和主光阴影遮挡的散射，再按深度引导合成。支持正交/透视，最多从可见表面向镜头积分 `maximumDistance` 米，避免远距地图相机把全图淹没。透视镜头另加按场景深度遮挡的径向丁达尔光束，太阳屏幕位置与 URP 深度重建坐标一致；固定空间抖动减轻离散采样条带。天空跳过世界雾积分，但可接收径向光束。
- 当前大气 Profile：`strength=0.82 / density=0.0035 / samples=20 / maximumDistance=110 / sunlight=2.2 / anisotropy=0.68`；雾中阴影使用更强的遮光对比，减轻整屏灰黄蒙层。strength=0 关闭整个效果，sunlight=0 可单独比较光束贡献；径向采样次数为 max(32, samples×3)，增加 samples 会提高 GPU 开销。
- 奇幻模式的实际环境光由 `WorldVisualStyles.fantasyLighting` 控制，`MapEnvironmentController` 应用到原有昼夜关键帧：当前白天主光倍率 3.2、环境光倍率 0.78、冷色天空补光、环境反射强度 0.75；夜间主光倍率退回 1，像素模式使用原始光照。`打开日照与天空参数` 可编辑这些值。`FantasySky` 提供 HDR 太阳、晨昏渐变与缓慢云层，材质按会话克隆并跟随真实主光；切换/销毁恢复原天空和相机清屏方式。
- 当前奇幻调色曝光 0.1、对比 18、饱和度 22，Bloom 强度 0.34/阈值 1.1，AO 强度 0.35；提高色彩分离同时限制泛白。天空反射不等于场景 SSR/镜面水体，当前没有新增水面反射渲染器。
- 世界 Renderer 的 `PixelArtRendererFeature` 在调色/Bloom 后执行：点采样到低分辨率 RT，按整数方形像素放大，显示色空间内做可调色阶和固定 4×4 有序抖色。只处理开启后处理的 Game Base 相机；HUD Overlay、Scene View 和 Renderer 1 的背包/头像预览保持原清晰度。像素网格固定在屏幕，运动时仍会发生采样跳变；不是 Dead Cells 的离线精灵烘焙，也不是逐材质 cel shading。
- 在 `WarmFantasy` 的 `Project Y/Pixel Art` 中调整：`enableEffect` 开关；`referenceHeight` 当前 540（细腻），360 更明显；实际像素边长为 `ceil(画面高度/referenceHeight)`，非整除尺寸保留末端部分像素，不拉伸画面；当前共享 Profile 为 `colorLevels=32 / colorStrength=0.45 / ditherStrength=0.06`，后两者设 0 可分别关闭色阶化/抖色。保持会话管线 renderScale=1、相机后处理 AA=None，避免最终缩放/FXAA 再次软化网格。
- 墨线使用同一虚拟像素网格的深度突变与强法线折角，不以颜色差勾满纹理。`outlineStrength=0.8 / outlineWidth=1 / outlineDepthThreshold=0.012 / creaseStrength=0.22`；外轮廓较强、折面线较弱，设 outlineStrength=0 关闭并停止额外请求深度/法线输入。支持透视与正交深度；普通透明材质未写入深度/法线时不产生自身轮廓。
- 常规模型使用 URP Lit；人物定制的 PropertyBlock 使用 `_BaseColor`，平滑度使用 `_Smoothness`。共享地图 Shader 保留 `_Color` 实例数组、UV1/UV2 图案和 `_SurfaceData/_SurfaceFinish` 契约，提供 ForwardLit、ShadowCaster、DepthOnly、DepthNormals 通道；探索格使用独立 URP 透明 Shader。
- `UrpCameraRendering.Render` 使用 SingleCameraRequest 替代内置管线的 `Camera.Render()`。背包和工坊相机复用请求对象，经 `ConfigurePreview` 选择 Renderer 1、关闭世界后处理和阴影；图标与 Editor 捕获同样使用渲染请求。新增手动截图脚本也应使用此入口。
- `InventoryCharacterView` 的背包与 HUD 头像通过 `SkinnedPreviewSnapshot` 同步烘焙当前姿态，再提交离屏请求，避免同帧换发型/装备后读取旧 GPU 蒙皮缓冲。代理和 Mesh 由预览持有并复用，换装后刷新源列表，关闭时释放；请求期间临时隐藏源 Renderer，结束或异常时恢复，不修改共享网格。场景角色仍使用正常蒙皮。
- 菜单 `Project Y/渲染/安装 URP 奇幻风格资源` 用于首次接入或恢复缺失资产：创建缺失资源、不重置已有风格参数；调用 Unity 材质升级器保留材质 GUID、颜色、纹理与透明模式，FBX 内嵌 Standard 材质抽出后显式 remap。安装要求 Edit Mode，不保存打开的场景。
- `Project Y/渲染/安装像素风后处理` 只安装/修复世界 Renderer Feature 和缺失的 Volume 组件，不转换材质、不重设已有参数，不保存场景；完整 URP 安装也会调用它。Feature 序列化 Shader 引用，避免 Player 构建裁剪；RT 与 Material 由 Feature 释放。
- `Project Y/渲染/安装奇幻光影与对比预设` 创建缺失的第二套 Renderer/管线/Profile 与选择资源，不重设已有调参、不改变原像素资产；完整 URP 安装也会调用它。奇幻 Renderer 的像素 Feature 关闭，头像 Renderer 不包含大气效果。
- 最小检查：`preview_urp.cs` 是 MCP 片段，使用真实王城布局在临时 PreviewScene 渲染白天/黄昏，检查粉色/黑屏、单相机渲染请求和状态恢复；不进入 Play，不写存档。启动异常需单独确认时，只检查一次远征启动和退出；完整游戏回归与 Player 构建另行授权。

## 关键入口

- [管线资产](../../Assets/GameFramework/Rendering/WarmFantasyURP.asset) / [世界 Renderer](../../Assets/GameFramework/Rendering/WarmFantasyRenderer.asset) / [预览 Renderer](../../Assets/GameFramework/Rendering/PreviewRenderer.asset) / [风格参数](../../Assets/GameFramework/Resources/Rendering/WarmFantasy.asset)。
- [风格选择](../../Assets/GameFramework/Resources/Rendering/WorldVisualStyles.asset) / [奇幻管线](../../Assets/GameFramework/Rendering/MedievalFantasyURP.asset) / [奇幻参数](../../Assets/GameFramework/Resources/Rendering/MedievalFantasy.asset) / [安装与切换菜单](../../Assets/GameFramework/Editor/WorldVisualStyleAssets.cs)。
- [大气参数](../../Assets/GameFramework/Runtime/Rendering/FantasyAtmosphere.cs) / [半分辨率渲染与合成](../../Assets/GameFramework/Runtime/Rendering/FantasyAtmosphereRendererFeature.cs) / [光束 Shader](../../Assets/GameFramework/Rendering/FantasyAtmosphere.shader)。
- [天空 Shader](../../Assets/GameFramework/Rendering/FantasySky.shader) / [天空材质](../../Assets/GameFramework/Rendering/FantasySky.mat) / [光照参数](../../Assets/GameFramework/Runtime/Rendering/WorldVisualStyles.cs)。
- [同机位风格比较](../../Tools/Rendering/preview_visual_styles.cs) / [渲染与切换检查](../../Docs/Previews/Rendering/visual-styles-validation.json) / [阴影散射验证](../../Tools/Rendering/validate_fantasy_atmosphere.cs)：Edit Mode 临时场景，正交/透视、奇数尺寸、主光阴影对半分辨率雾缓冲的实际影响、状态恢复；不进入 Play。
- [会话生命周期](../../Assets/GameFramework/Runtime/Rendering/FantasyPresentation.cs) / [离屏渲染](../../Assets/GameFramework/Runtime/Rendering/UrpCameraRendering.cs) / [安装与材质转换](../../Assets/GameFramework/Editor/FantasyRenderingAssets.cs)。
- [像素参数](../../Assets/GameFramework/Runtime/Rendering/PixelArt.cs) / [渲染通道](../../Assets/GameFramework/Runtime/Rendering/PixelArtRendererFeature.cs) / [Shader](../../Assets/GameFramework/Rendering/PixelArt.shader) / [定向安装](../../Assets/GameFramework/Editor/PixelArtRenderingAssets.cs)。
- [像素风最小预览](../../Tools/Rendering/preview_pixel_art.cs)：MCP Edit Mode 片段，现有人物、效果开关、720p/1080p/非整除尺寸、像素网格一致性、离屏预览不受影响、状态恢复；输出在 `Docs/Previews/Rendering/pixel-art-*`，不进入 Play。
- URP 14 的 `SingleCameraRequest` 不自动刷新 Volume。世界后处理截图应像上述预览一样使用独立 VolumeStack，渲染前 Update，结束恢复并释放；不能用旧 stack 截图证明效果已启用。头像/背包仍使用禁用后处理的独立 Renderer。
- 光照预览必须使用 ARGBHalf 线性相机目标，最后把已调色的线性读回转换成 sRGB PNG。URP 会沿用显式目标格式，直接使用 ARGB32 会在 Bloom 前截断 HDR 高光。优先用[真实昼夜预览](../../Tools/Rendering/preview_daylight.cs)及其 [Lua 数据入口](../../Tools/Rendering/preview_daylight.lua)，不要以手工灯光截图代替游戏环境。
- [森林丁达尔开关比较](../../Tools/Rendering/preview_tyndall_forest.cs)：已有树木资源的临时测试布局，保留真实日照与材质，仅比较大气 sunlight 开关；[开启](../../Docs/Previews/Rendering/forest-tyndall-on.png) / [关闭](../../Docs/Previews/Rendering/forest-tyndall-off.png)。美术方向参考 [Complementary 官方图](https://www.complementary.dev/assets/img/newScreenshots/reim1_oldGrowth.jpg)，未引入该光影包代码。
- [角色预览快照](../../Assets/GameFramework/Runtime/Rendering/SkinnedPreviewSnapshot.cs) / [换装渲染定向检查](../../Tools/Tests/skinned_preview_render.cs)：MCP Edit Mode 片段，在独立 PreviewScene 检查同帧换发型、身体、头盔穿脱、缩放、材质、缓存复用、异常恢复及源资产不变，不进入 Play。
- [预览入口](../../Tools/Rendering/preview_urp.cs) / [真实布局](../../Tools/Rendering/preview_urp.lua) / [检查结果](../../Docs/Previews/Rendering/validation.json) / [运行截图](../../Docs/Previews/Rendering/urp-runtime-map.png)。
