# PanelGenerator

关键词：PanelGenerator、编辑器弹窗、PanelConfig、生成 Prefab、模块目录、Ctr、Widget、EmmyLua、组件提示。

## 文档目录

正文：操作与命名 / 生成约束 / 扩展与验证；关键入口：窗口 / 生成器 / 引用适配。

## 正文

- Unity 菜单 Project Y → UI → Panel Generator 打开独立窗口。搜索/选择已有配置，或新建 Panel/Widget；编辑模块和窗口策略，保存并生成。
- 名称 Inventory、模块 Bag：Prefab 为 Assets/DynamicAsset/UI/Prefabs/Bag/InventoryPanel.prefab；控制器为 Lua/UI/Panel/InventoryCtr.lua。Widget 名称 Item 则生成同模块 ItemWidget.prefab 和 Lua/UI/Widget/Item.lua。Lua 控制器目录均平铺。
- 配置名和模块使用英文字母开头的标识符，拒绝路径穿越、Windows 保留名和大小写冲突。已有配置名/类型固定；改模块会移动 Prefab 并保留 GUID。
- Panel 自动附加 LuaReference、LuaPanel、Canvas、CanvasGroup、CanvasScaler、GraphicRaycaster；Widget 附加 RectTransform、LuaReference、CanvasGroup。初始绑定提供 Root，Panel 另有 Canvas / Panel。
- 生成保留已有控制器源码、组件绑定及内容，仅补齐组件并同步 Canvas 模式。运行时按 IsWorldUI 挂到 UIRoot / WorldUIRoot，屏幕缩放由 UIRoot 统一处理，既有 Prefab 无需重新生成。控制器基类、根节点与窗口策略见 [UI](../Framework/UI.md)。
- 仅保存可保留尚未生成的配置；运行时打开它会报缺资源，构建校验拒绝缺 Prefab/控制器或路径不一致的条目。Prefab 引用由生成器维护，不手工移出约定目录。
- LuaReference Inspector 支持自定义 Key、Component 和同物体组件类型选择。导出按钮或 Project Y → UI → Export All View Hints 更新 Lua/UI/Types/<配置名>PanelView.lua 或 WidgetView.lua。
- 生成控制器通过 @field view 关联提示。Types/UnityUI.lua 提供常见 UGUI/TMP 成员提示；Types 目录不进入 Player，也不被 require。子引用可单独导出 <物体名>View，名字必须合法且应唯一。
- 增加组件适配：LuaViewHints 注册具体类型 → XLuaBindings 补桥接 → UnityUI.lua 补成员提示 → XLua Generate Code。未适配的组件绑定仍可保存，提示回退 Component 并警告。

验证：Unity Project Y → Tests → Run Panel Checks 覆盖生成保留、模块移动、提示输出、WorldUI、暂停计数和 Widget 实例化；运行时改动补 [UI 验证](../Framework/UI.md)。

## 关键入口

- [PanelGenerator.cs](../../Assets/GameFramework/Editor/PanelGenerator.cs)：窗口和配置 Inspector；[PanelAssets.cs](../../Assets/GameFramework/Editor/PanelAssets.cs)：Save / Generate / ValidateForBuild。
- [LuaReferenceEditor.cs](../../Assets/GameFramework/Editor/LuaReferenceEditor.cs)：绑定列表和组件选择；[LuaViewHints.cs](../../Assets/GameFramework/Editor/LuaViewHints.cs)：类型映射与导出。
- [UnityUI.lua](../../Lua/UI/Types/UnityUI.lua)：基础提示；[XLuaBindings.cs](../../Assets/GameFramework/Editor/XLuaBindings.cs)：UGUI 桥接。
- [PanelValidation.cs](../../Assets/GameFramework/Editor/PanelValidation.cs)：Unity 生成与生命周期检查；[LuaBuildFiles.cs](../../Assets/GameFramework/Editor/LuaBuildFiles.cs)：排除提示文件。
