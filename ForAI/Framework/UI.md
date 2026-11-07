# UI

关键词：MVC、PanelConfig、LuaPanel、UIPanelCtrl、UIWidgetCtrl、LuaReference、self.view、UIRoot、WorldUIRoot、WorldUI、暂停、场景切换。

## 文档目录

正文：配置与职责 / 生命周期与策略 / 验证；关键入口：运行时 / 生成与绑定。

## 正文

- PanelConfig 是 Unity 配置资产，位置为 Assets/DynamicAsset/UI/Resources/PanelConfig.asset。条目包含模块、Panel/Widget 类型、窗口策略及 Prefab 直接引用；Resources 只加载注册表，引用的 DynamicAsset Prefab 随构建收集。
- 配置名全局唯一且大小写不冲突。模块只管理 Prefab 目录；路径与控制器名称由 PanelDefinition 计算，生成步骤见 [PanelGenerator](../Tools/PanelGenerator.md)。原 Game.PanelDefinitions 已移除。
- View 是 C# LuaReference 的 Key + Component 数组。UIWidgetCtrl 创建 UIView 只读代理，使用 self.view.Key 获取组件并缓存；self.reference 保留原始 LuaReference。Key 需是非关键字的 Lua 标识符。
- LuaReference 的 `localizedTexts` 另存初始文案目标与 LuaTxt ID；UIHost 创建 View/Widget 后、Lua Bind 和动态 SetData 前应用。既有 Text/TMP 引用不替换，固定文案与语言表的维护入口见[本地化](Localization.md)。
- Panel 继承 UIPanelCtrl，Widget 继承 UIWidgetCtrl。可变业务状态仍归 C# Data；Lua ModelSystem 只转发。self.panel 是 C# LuaPanel，负责 Canvas、交互与实际显示状态。
- UISystem 每个配置名同时一个 Panel。Bind 每实例一次；Show(args) 每次打开执行，重复打开先 Hide。缓存关闭仅 Hide；非缓存/强制关闭会 Dispose 和销毁。`IsOpen(name)` 查询当前可见状态，已关闭的缓存返回 false。
- Widget 不进窗口栈。AddWidget('Stats', self.view.StatsWidget) 使用已有子引用；CreateWidget('Stats', parentTransform) 按配置实例化独立 Prefab。两者都随父 Show/Hide/Dispose；动态创建的 View 由父 Ctrl 释放。
- 多模板、可变尺寸的虚拟滚动列表使用 [UIScrollList](UIScrollList.md)，通过 AddWidget 接入父控制器生命周期。
- Listen(button, fn) 的解绑归 lifetime；显示订阅归 visibleScope。Hide 逆序隐藏子项、释放 visibleScope，再 OnHide；不要在 OnHide 依赖仍存活的显示订阅。
- UIHost.Initialize 在常驻宿主下创建两个独立根节点：UIRoot（ScreenSpaceOverlay Canvas，CanvasScaler 1280×720 / match 0.5）与 WorldUIRoot（WorldSpace Canvas，单位缩放）。Shutdown 释放根节点、实例及自建 EventSystem；场景切换保留根节点。
- 非 WorldUI Panel 挂 UIRoot 并全屏拉伸、归零偏移与旋转、设为单位缩放，由根 CanvasScaler 统一适配；Panel Prefab 的 Canvas 保留为子 Canvas 负责排序，子 CanvasScaler 不参与屏幕适配。普通 Widget 随所属 Panel/父节点；IsWorldUI Widget 挂 WorldUIRoot，仍由原控制器及 UIHost 的 Widget 集合管理 Show/Hide/Dispose，不依赖父 Panel 的 Transform 隐藏。
- Background < Main < Popup < Overlay，同层按打开顺序。最高模态窗口屏蔽下层输入，Back 遇到不可返回的模态窗口停止。操作窗口使用 UISystem，勿直接销毁其 View。
- `LuaPanel.SetOrder` 在窗口激活后一起设置 `Canvas.overrideSorting=true` 和 sortingOrder。Unity 会忽略未激活子 Canvas 的 overrideSorting，首次激活还会重置排序号，不能仅在 Initialize 中设置。`UISystem.Open` 保持先 SetVisible、后 RefreshInput 的顺序；[原生叠层检查](../../Tools/Tests/ui_panel_sorting.cs) 覆盖 Loading 先创建、HUD 后创建及缓存重开，并逐像素确认 HUD 不穿透 Loading。
- `UISystem.Back` 按栈顶向下先询问可选 `Ctrl:OnBack()`；返回 true 表示已消费，未消费时再执行 CloseOnBack / Modal 策略。游戏 HUD 通过此入口打开 [ESC 菜单](../Business/PauseMenu.md)，通用 UI 层不识别具体业务窗口。
- PanelDefinition.ModalDimAlpha 配置模态遮罩透明度，默认 .65；[对话面板](../Business/Narrative.md) 使用 0 保留世界镜头画面，仍阻断下层输入。
- IsWorldUI Panel 挂 WorldUIRoot，保留 Prefab 局部尺寸、位置、旋转及缩放，不套用全屏拉伸。使用 WorldSpace Canvas，初始相机为 Camera.main，可调用 self.panel:SetWorldCamera(camera)；持久世界 UI 在更换相机时由业务重新绑定。
- PauseWorldOnOpen 按可见 Panel 计数，首次暂停保存 Time.timeScale，最后一个释放时恢复。UI 仍 Tick，可使用 unscaledDt；业务若需跳过逻辑可读 services.UI.IsWorldPaused。其他时间控制系统接入时需统一暂停所有权。
- UIHost 监听 activeSceneChanged 与 Single sceneLoaded，UISystem 下一次 Tick 强制释放 CloseOnSceneChange 条目（含已隐藏缓存）；未勾选的随常驻宿主保留。SupportsHotSwitch 当前仅保存标记。
- `UISystem.Open` 也会先同步 SceneVersion：若 sceneLoaded 已发生而首次 UI Tick 尚未执行，先清旧场景窗口，再打开新场景窗口，避免刚开的 MainHud 在下一 Tick 被清掉。定向回归为 `Tools/Tests/ui_scene_lifecycle.lua`。
- UITxt 及文本查询见 [本地化](Localization.md)；它同样通过 self.view.Key 获取。绑定变更后重新导出 EmmyLua，提示只供编辑器使用。
- `AnimationWrap` 提供 `inClip` / `outClip` 和额外 `clips[]`：固定名称 `in`、`out`，其他 Clip 按资源名称查找，区分大小写；空默认槽可保留，额外槽空引用、重复名及保留名报错。通过 LuaReference 的 `Animation` 绑定调用 `self:PlayAnimation('in')`、`self:PlayAnimation('pulse')`，或 `self.view.Animation:PlayOut()`；自定义绑定用 `PlayAnimation(name,key)`。没有自动接管 Panel 开关时序。
- AnimationWrap 自动要求同物体 Animator，普通 Clip 用 Playables 播放，无需 AnimatorController；Legacy Clip 使用同物体 Animation（按需添加）。默认使用未缩放时间，可在 Inspector 改为缩放时间。新播放替换前一个，非循环片段停留末帧，`Stop`/禁用/销毁释放播放资源；不要让其他动画播放器同时控制同一批 UI 属性。
- `Blur` 直接挂在 UGUI `Image` 同一节点（Add Component → UI/Project Y/Blur）。运行时每次 OnEnable 等待帧末，通过 `ScreenCapture.CaptureScreenshotIntoRenderTexture` 截取当前 Game View，再以 GPU Dual Kawase 下采样/上采样生成静态半分辨率 RT；打开期间不重复截图。`iterations`（默认4）、`radius`（默认1）和 `downsample`（默认2）控制质量/范围/成本，下次捕获时应用。
- Blur 的可选 `captureGroup` 指向要排除的窗口 CanvasGroup；截图期间临时隐藏整组，完成或取消恢复原 alpha。未配置时只隐藏自身 Image。一个窗口使用一个截图背景组件；菜单文字置于背景 Image 上层。Shader 按屏幕坐标采样，保留 Image 顶点色/透明度、Sprite alpha、RectMask2D 与 stencil Mask；不替换为 RawImage、不创建 CPU 截图或 Sprite。关闭/禁用/销毁释放 RT 与实例材质并恢复原 Image 材质，重新打开重新捕获。
- `Blur.Capture()` 显式重拍 Game View；`CaptureFrom(Texture)` 供已有离屏图源和 Edit Mode 预览，调用方继续持有输入；`Clear()` 主动释放。Shader 位于 Resources，随构建保留，组件无需 Lua 调用或新增 xLua 桥接。Edit Mode 不自动截 Game View；真实帧末截图需 Play/Player 验收。算法来自 [ARM SIGGRAPH 2015 的 Dual filtering](https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_marius_2D00_notes.pdf)，截图时机依照 [Unity ScreenCapture 文档](https://docs.unity3d.com/2022.3/Documentation/ScriptReference/ScreenCapture.CaptureScreenshotIntoRenderTexture.html)。
- `AnimationWrap.SampleNormalized(name,progress)` 供 C# 表现组件按共享进度采样现有 Clip；同名连续采样复用播放器并停用自动计时，可连续反向。地图 `HudModeTransition` 使用它同步相机/HUD，且在 UIHost 未激活或已隐藏根节点时跳过采样，首次活动 Tick 再应用；不要在未激活的 Bind 阶段直接 `Play`。
- 新 UI 动效组件带 `LuaCallCSharp` 标记及独立 `Runtime/UI/link.xml` 保留声明，未生成专用 xLua Wrapper 时可使用反射桥接；定向 Edit Mode 检查覆盖真实 Lua 调用。战斗双层血条接入见 [MainHud](../Business/MainHud.md)。
- `SceneFocusMask` 是 C# 显示资源：`Create(RectTransform)` 从已保存的 `Resources/UI/SceneFocusMask` 实例化不接收射线的 RawImage；`Begin(camera)` 返回离屏 CommandBuffer，`DrawRenderers` 支持真实 Renderer（包含蒙皮），实例地图可直接用 `SilhouetteMaterial` 和 `_SiteMask` 逐实例标记绘制，`End(opacity)` 将逆轮廓灰罩显示在相机视口。相机定位后提交；调用方负责目标抬升/颜色与所有权，并在隐藏、换场景时调用 `Hide`/`Dispose`。目标 RT、材质、命令缓冲由组件释放，分辨率随相机变化；业务 UI 维持在灰罩上方。
- `SceneFocusMask.Begin` 将原始 `camera.projectionMatrix` 交给 `CommandBuffer.SetViewProjectionMatrices`，由 Unity 完成平台转换；不能再次调用 `GL.GetGPUProjectionMatrix`，否则 Direct3D 的深度次序会错误。UI 按常规 UV 采样，无额外翻转。不能只用 RT 内部采样断言屏幕对齐：[最终合成检查](../../Tools/Tests/scene_focus_mask_editmode.cs) 在不对称场景里对比罩前/罩后像素，分别覆盖 Renderer 与实例批次，确认选中物体保留、非选中物体压灰，并检查后景不会覆盖前景、前景能遮挡后景。

验证：python Tools/Tests/run_lua.py；Unity Project Y → Tests → Run Integration Checks / Run Panel Checks。加载与构建变更还需真实 Player 验证。

## 关键入口

- [SceneFocusMask.cs](../../Assets/GameFramework/Runtime/UI/SceneFocusMask.cs) / [轮廓 Shader](../../Assets/GameFramework/Resources/WorldSiteSilhouette.shader) / [逆遮罩 Shader](../../Assets/GameFramework/Resources/WorldSiteDim.shader)；资源同步与大地图接入见 [MainHud](../Business/MainHud.md)。

- [PanelConfig.cs](../../Assets/GameFramework/Runtime/UI/PanelConfig.cs)：PanelDefinition 路径/策略；[UISystem.lua](../../Lua/UI/UISystem.lua)：Open / Close / OnSceneChanged。
- [UIWidgetCtrl.lua](../../Lua/UI/UIWidgetCtrl.lua) / [UIPanelCtrl.lua](../../Lua/UI/UIPanelCtrl.lua)：控制器基类；[UIView.lua](../../Lua/UI/UIView.lua)：点式引用代理。
- [LuaReference.cs](../../Assets/GameFramework/Runtime/UI/LuaReference.cs)：绑定校验；[LuaPanel.cs](../../Assets/GameFramework/Runtime/UI/LuaPanel.cs) / [UIHost.cs](../../Assets/GameFramework/Runtime/UI/UIHost.cs)：Unity 实例和暂停所有权。
- [AnimationWrap.cs](../../Assets/GameFramework/Runtime/UI/AnimationWrap.cs)：具名 UI Clip 播放；[BattleFeedbackValidation.cs](../../Assets/GameFramework/Editor/BattleFeedbackValidation.cs)：`Project Y/UI/验证战斗受击与双层血条`，含 Animator / Legacy 与真实 xLua 桥接检查。
- [Blur.cs](../../Assets/GameFramework/Runtime/UI/Blur.cs) / [滤波 Shader](../../Assets/GameFramework/Resources/UI/BlurFilter.shader) / [Image 合成 Shader](../../Assets/GameFramework/Resources/UI/BlurImage.shader)：静态截图模糊；[原生 GPU 与生命周期检查](../../Tools/Tests/ui_blur_editmode.cs) 在隔离 PreviewScene 检查颜色/方向、奇数尺寸/1×1、局部 Image、两种遮罩、重拍与释放，不进入 Play。
- [DemoCtr.lua](../../Lua/UI/Panel/DemoCtr.lua) / [Stats.lua](../../Lua/UI/Widget/Stats.lua)：示例；[Prefab 目录](../../Assets/DynamicAsset/UI/Prefabs/)：模块资产。
