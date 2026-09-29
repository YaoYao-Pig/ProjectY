# URP 与奇幻风格

关键词：URP、渲染管线、后处理、WarmFantasy、SSAO、Bloom、阴影、材质迁移、离屏相机。

## 文档目录

正文：资源与生命周期 / 材质契约 / 最小检查；关键入口：管线 / 风格 / 安装工具。

## 正文

- Unity 2022.3 使用 URP 14.0.11。Graphics 和全部 Quality 档位引用 `WarmFantasyURP`；Renderer 0 为世界 Forward（四级联软阴影、4× MSAA、半分辨率 SSAO），Renderer 1 为无 SSAO 的离屏预览。项目资源已提交，正常运行无需再执行安装菜单。
- `Resources/Rendering/WarmFantasy` 是可调的共享 VolumeProfile：ACES、轻微暖色白平衡、冷影暖亮、低强度 Bloom 和暗角。HUD Overlay 不经过世界相机后处理。不启用景深、运动模糊或色差。
- `FantasyPresentation` 由远征环境控制器或地图 Demo 创建，显式接收相机和宿主；创建全局 Volume、开启 SMAA，并克隆 URP 资产作为会话配置，避免修改原始资产。销毁时释放 Volume/克隆并恢复相机及 Quality 管线。地图阴影距离从观察焦点向后计算。昼夜、天气、室内灯和雾仍归[地图环境](../Business/MapPresentation.md)。
- 常规模型使用 URP Lit；人物定制的 PropertyBlock 使用 `_BaseColor`，平滑度使用 `_Smoothness`。共享地图 Shader 保留 `_Color` 实例数组、UV1/UV2 图案和 `_SurfaceData/_SurfaceFinish` 契约，提供 ForwardLit、ShadowCaster、DepthOnly、DepthNormals 通道；探索格使用独立 URP 透明 Shader。
- `UrpCameraRendering.Render` 使用 SingleCameraRequest 替代内置管线的 `Camera.Render()`。背包和工坊相机复用请求对象，经 `ConfigurePreview` 选择 Renderer 1、关闭世界后处理和阴影；图标与 Editor 捕获同样使用渲染请求。新增手动截图脚本也应使用此入口。
- 菜单 `Project Y/渲染/安装 URP 奇幻风格资源` 用于首次接入或恢复缺失资产：创建缺失资源、不重置已有风格参数；调用 Unity 材质升级器保留材质 GUID、颜色、纹理与透明模式，FBX 内嵌 Standard 材质抽出后显式 remap。安装要求 Edit Mode，不保存打开的场景。
- 最小检查：`preview_urp.cs` 是 MCP 片段，使用真实王城布局在临时 PreviewScene 渲染白天/黄昏，检查粉色/黑屏、单相机渲染请求和状态恢复；不进入 Play，不写存档。启动异常需单独确认时，只检查一次远征启动和退出；完整游戏回归与 Player 构建另行授权。

## 关键入口

- [管线资产](../../Assets/GameFramework/Rendering/WarmFantasyURP.asset) / [世界 Renderer](../../Assets/GameFramework/Rendering/WarmFantasyRenderer.asset) / [预览 Renderer](../../Assets/GameFramework/Rendering/PreviewRenderer.asset) / [风格参数](../../Assets/GameFramework/Resources/Rendering/WarmFantasy.asset)。
- [会话生命周期](../../Assets/GameFramework/Runtime/Rendering/FantasyPresentation.cs) / [离屏渲染](../../Assets/GameFramework/Runtime/Rendering/UrpCameraRendering.cs) / [安装与材质转换](../../Assets/GameFramework/Editor/FantasyRenderingAssets.cs)。
- [预览入口](../../Tools/Rendering/preview_urp.cs) / [真实布局](../../Tools/Rendering/preview_urp.lua) / [检查结果](../../Docs/Previews/Rendering/validation.json) / [运行截图](../../Docs/Previews/Rendering/urp-runtime-map.png)。
