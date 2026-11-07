# 游戏内暂停菜单
关键词：ESC、Escape、PauseMenu、左侧半屏、继续游戏、保存游戏、加载游戏、游戏设置、退出游戏。

## 文档目录
正文：输入与生命周期 / 操作 / 资源与验证；关键入口：控制器 / Prefab / 检查。

## 正文

- 游戏 HUD 的 `OnBack` 打开 `PauseMenu`；已有窗口先按 [UI 返回规则](../Framework/UI.md) 处理 ESC，不穿透不可返回的模态窗口。菜单再次收到 ESC 时关闭；退出确认中 ESC 只取消确认。
- `Page` 横向锚点 0–0.5、纵向全屏，保持左侧半屏；按未缩放时间用 0.2 秒滑入。菜单是 Popup 模态窗口，使用 UIHost 的暂停计数，关闭或切换场景释放暂停；保留世界相机画面。战斗 HUD 在世界暂停期间不处理键盘快捷键。
- `BlurBackground` 是全屏 Image + [Blur](../Framework/UI.md)，打开时截取包含原 HUD 的背景，`captureGroup` 绑定菜单根 CanvasGroup，排除菜单及其模态遮罩。背景模糊并调暗，左侧面板半透明，标题和按钮保持清晰；关闭时组件自动释放截图。
- 按钮从上到下为继续游戏、保存游戏、加载游戏、游戏设置、退出游戏。继续关闭菜单；设置保留无操作按钮；退出复用现有退出桥及确认文案，不自动保存。
- 保存先走 `CampaignPreparation.Check`，再用 `CharacterSave.Write` 更新当前槽，菜单内显示成功或失败原因。加载复用 StartMenu 的 load 页，先打开选档页再关闭 PauseMenu，避免释放两个窗口间的暂停。区域中先停止行走。存档限制、数据范围和真实加载事务见[远征存档](CharacterSave.md)与[开始菜单](StartMenu.md)。
- 固定标签保存为 LuaReference 本地化绑定；反馈走 Language/LuaTxt。首次安装脚本只创建缺失菜单，不覆盖现存 Prefab。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/pause_menu.lua`、`node Tools/Tests/ui_localization_sources.mjs`；原生布局和暂停所有权通过 Unity MCP 执行下方 Edit Mode 脚本。原生检查使用隔离 PreviewScene、替身存档/退出操作，不进入 Play、不写玩家存档；不能替代真实 Player 的键盘和磁盘存取验收。

## 关键入口

- [PauseMenuCtr.lua](../../Lua/UI/Panel/PauseMenuCtr.lua)：菜单操作、滑入与退出确认；[MainHudCtr.lua](../../Lua/UI/Panel/MainHudCtr.lua)：`OnBack` 入口。
- [PauseMenuPanel.prefab](../../Assets/DynamicAsset/UI/Prefabs/Adventure/PauseMenuPanel.prefab) / [PanelConfig.asset](../../Assets/DynamicAsset/UI/Resources/PanelConfig.asset)：布局、绑定和暂停策略。
- [首次安装](../../Tools/UI/build_pause_menu.cs) / [交互检查](../../Tools/Tests/pause_menu.lua) / [原生布局检查](../../Tools/Tests/pause_menu_editmode.cs) / [预览](../../Docs/Previews/PauseMenu/menu.png)。
- [接入 Blur](../../Tools/UI/apply_pause_menu_blur.cs) / [模糊检查](../../Tools/Tests/ui_blur_editmode.cs) / [模糊背景预览](../../Docs/Previews/PauseMenu/blur.png)：预览图源为已有地图截图，不能作为真实帧末截图时序已通过的证据。
