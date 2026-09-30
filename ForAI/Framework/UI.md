# UI

关键词：MVC、PanelConfig、LuaPanel、UIPanelCtrl、UIWidgetCtrl、LuaReference、self.view、UIRoot、WorldUIRoot、WorldUI、暂停、场景切换。

## 文档目录

正文：配置与职责 / 生命周期与策略 / 验证；关键入口：运行时 / 生成与绑定。

## 正文

- PanelConfig 是 Unity 配置资产，位置为 Assets/DynamicAsset/UI/Resources/PanelConfig.asset。条目包含模块、Panel/Widget 类型、窗口策略及 Prefab 直接引用；Resources 只加载注册表，引用的 DynamicAsset Prefab 随构建收集。
- 配置名全局唯一且大小写不冲突。模块只管理 Prefab 目录；路径与控制器名称由 PanelDefinition 计算，生成步骤见 [PanelGenerator](../Tools/PanelGenerator.md)。原 Game.PanelDefinitions 已移除。
- View 是 C# LuaReference 的 Key + Component 数组。UIWidgetCtrl 创建 UIView 只读代理，使用 self.view.Key 获取组件并缓存；self.reference 保留原始 LuaReference。Key 需是非关键字的 Lua 标识符。
- Panel 继承 UIPanelCtrl，Widget 继承 UIWidgetCtrl。可变业务状态仍归 C# Data；Lua ModelSystem 只转发。self.panel 是 C# LuaPanel，负责 Canvas、交互与实际显示状态。
- UISystem 每个配置名同时一个 Panel。Bind 每实例一次；Show(args) 每次打开执行，重复打开先 Hide。缓存关闭仅 Hide；非缓存/强制关闭会 Dispose 和销毁。`IsOpen(name)` 查询当前可见状态，已关闭的缓存返回 false。
- Widget 不进窗口栈。AddWidget('Stats', self.view.StatsWidget) 使用已有子引用；CreateWidget('Stats', parentTransform) 按配置实例化独立 Prefab。两者都随父 Show/Hide/Dispose；动态创建的 View 由父 Ctrl 释放。
- 多模板、可变尺寸的虚拟滚动列表使用 [UIScrollList](UIScrollList.md)，通过 AddWidget 接入父控制器生命周期。
- Listen(button, fn) 的解绑归 lifetime；显示订阅归 visibleScope。Hide 逆序隐藏子项、释放 visibleScope，再 OnHide；不要在 OnHide 依赖仍存活的显示订阅。
- UIHost.Initialize 在常驻宿主下创建两个独立根节点：UIRoot（ScreenSpaceOverlay Canvas，CanvasScaler 1280×720 / match 0.5）与 WorldUIRoot（WorldSpace Canvas，单位缩放）。Shutdown 释放根节点、实例及自建 EventSystem；场景切换保留根节点。
- 非 WorldUI Panel 挂 UIRoot 并全屏拉伸、归零偏移与旋转、设为单位缩放，由根 CanvasScaler 统一适配；Panel Prefab 的 Canvas 保留为子 Canvas 负责排序，子 CanvasScaler 不参与屏幕适配。Widget 随所属 Panel/父节点。
- Background < Main < Popup < Overlay，同层按打开顺序。最高模态窗口屏蔽下层输入，Back 遇到不可返回的模态窗口停止。操作窗口使用 UISystem，勿直接销毁其 View。
- PanelDefinition.ModalDimAlpha 配置模态遮罩透明度，默认 .65；[对话面板](../Business/Narrative.md) 使用 0 保留世界镜头画面，仍阻断下层输入。
- IsWorldUI Panel 挂 WorldUIRoot，保留 Prefab 局部尺寸、位置、旋转及缩放，不套用全屏拉伸。使用 WorldSpace Canvas，初始相机为 Camera.main，可调用 self.panel:SetWorldCamera(camera)；持久世界 UI 在更换相机时由业务重新绑定。
- PauseWorldOnOpen 按可见 Panel 计数，首次暂停保存 Time.timeScale，最后一个释放时恢复。UI 仍 Tick，可使用 unscaledDt；业务若需跳过逻辑可读 services.UI.IsWorldPaused。其他时间控制系统接入时需统一暂停所有权。
- UIHost 监听 activeSceneChanged 与 Single sceneLoaded，UISystem 下一次 Tick 强制释放 CloseOnSceneChange 条目（含已隐藏缓存）；未勾选的随常驻宿主保留。SupportsHotSwitch 当前仅保存标记。
- `UISystem.Open` 也会先同步 SceneVersion：若 sceneLoaded 已发生而首次 UI Tick 尚未执行，先清旧场景窗口，再打开新场景窗口，避免刚开的 MainHud 在下一 Tick 被清掉。定向回归为 `Tools/Tests/ui_scene_lifecycle.lua`。
- UITxt 及文本查询见 [本地化](Localization.md)；它同样通过 self.view.Key 获取。绑定变更后重新导出 EmmyLua，提示只供编辑器使用。
- `AnimationWrap` 提供 `inClip` / `outClip` 和额外 `clips[]`：固定名称 `in`、`out`，其他 Clip 按资源名称查找，区分大小写；空默认槽可保留，额外槽空引用、重复名及保留名报错。通过 LuaReference 的 `Animation` 绑定调用 `self:PlayAnimation('in')`、`self:PlayAnimation('pulse')`，或 `self.view.Animation:PlayOut()`；自定义绑定用 `PlayAnimation(name,key)`。没有自动接管 Panel 开关时序。
- AnimationWrap 自动要求同物体 Animator，普通 Clip 用 Playables 播放，无需 AnimatorController；Legacy Clip 使用同物体 Animation（按需添加）。默认使用未缩放时间，可在 Inspector 改为缩放时间。新播放替换前一个，非循环片段停留末帧，`Stop`/禁用/销毁释放播放资源；不要让其他动画播放器同时控制同一批 UI 属性。
- 新 UI 动效组件带 `LuaCallCSharp` 标记及独立 `Runtime/UI/link.xml` 保留声明，未生成专用 xLua Wrapper 时可使用反射桥接；定向 Edit Mode 检查覆盖真实 Lua 调用。战斗双层血条接入见 [MainHud](../Business/MainHud.md)。

验证：python Tools/Tests/run_lua.py；Unity Project Y → Tests → Run Integration Checks / Run Panel Checks。加载与构建变更还需真实 Player 验证。

## 关键入口

- [PanelConfig.cs](../../Assets/GameFramework/Runtime/UI/PanelConfig.cs)：PanelDefinition 路径/策略；[UISystem.lua](../../Lua/UI/UISystem.lua)：Open / Close / OnSceneChanged。
- [UIWidgetCtrl.lua](../../Lua/UI/UIWidgetCtrl.lua) / [UIPanelCtrl.lua](../../Lua/UI/UIPanelCtrl.lua)：控制器基类；[UIView.lua](../../Lua/UI/UIView.lua)：点式引用代理。
- [LuaReference.cs](../../Assets/GameFramework/Runtime/UI/LuaReference.cs)：绑定校验；[LuaPanel.cs](../../Assets/GameFramework/Runtime/UI/LuaPanel.cs) / [UIHost.cs](../../Assets/GameFramework/Runtime/UI/UIHost.cs)：Unity 实例和暂停所有权。
- [AnimationWrap.cs](../../Assets/GameFramework/Runtime/UI/AnimationWrap.cs)：具名 UI Clip 播放；[BattleFeedbackValidation.cs](../../Assets/GameFramework/Editor/BattleFeedbackValidation.cs)：`Project Y/UI/验证战斗受击与双层血条`，含 Animator / Legacy 与真实 xLua 桥接检查。
- [DemoCtr.lua](../../Lua/UI/Panel/DemoCtr.lua) / [Stats.lua](../../Lua/UI/Widget/Stats.lua)：示例；[Prefab 目录](../../Assets/DynamicAsset/UI/Prefabs/)：模块资产。
