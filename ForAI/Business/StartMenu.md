# 场景式开始菜单
关键词：开始菜单、StartMenu、3D 路牌、沙盘、世界预览、最近创建、相机转场、减少镜头运动、设置、About Me、删除存档。

## 文档目录
正文：表现与生命周期 / 预览快照 / 存档操作 / 资源与验证；关键入口：控制器 / 资源 / 检查。

## 正文

- `StartMenuCtr` 保留世界名称、uint 种子、四档规模、12 种身世和真实物资预览，创建及加载仍走[原加载事务](../Framework/Loading.md)。`CampaignSaveEntry` 只负责存档条目的选中和删除入口；选中后通过独立“继续远征”按钮提交加载。
- `StartMenuView` 持有离屏 3D 舞台、RenderTexture、木牌投影按钮和未缩放时间转场；`StartMenuStage` 只消费显示快照，不创建玩法世界。路牌靠左前景、局部伸出画面，沙盘后退；相机位置、目标与 FOV 保存在舞台 Prefab，木牌按钮位置、角度和高度按真实投影更新。开始/加载向右转，返回反向；完整转场 1.1 秒，减少运动使用 0.3 秒淡入淡出。`ProjectY.Menu.ReducedMotion` 保存选择，未设置时启用减少运动。
- 舞台用 Prefab 直接引用进入构建，运行时创建独立附加场景，Edit Mode 使用 PreviewScene；不改用户活动场景。关闭释放场景、地形网格、材质和 RT，并恢复外部灯光的 layer 30 掩码。背景 RT 上限 1600×900，存档缩略图 640×360，缩略图暂时隐藏舞台中沙盘以外的 Renderer；静止界面只在内容或尺寸改变时重绘。菜单打开期间保留显示相机启用，但将世界 cullingMask 设为 0、仅清色，避免 Editor 的“No cameras rendering”提示；天气与世界 Update 不继续推进，关闭恢复相机的 enabled、cullingMask 和 clearFlags。
- 首页按持久化 `createdAt` 选择最近创建的世界，独立于存档列表的保存时间排序。旧档没有该字段时使用文件创建时间；后续成功载入再保存会将该时间写回。该可选元数据不改变角色/远征存档版本。
- 主菜单只读取每档前 32,768 个字符中的头部元数据，不解析演员、装备和世界正文。成功创建或载入后，由已提交的 `MapPreviewData` 提取 `<存档路径>.preview`；不在首页运行地图生成器。快照为 64×48 地形高度/颜色、最多 128 个树木/城镇标记，二进制读取上限 64 KiB；大世界不会增大渲染预算。
- 无世界时展示固定沙盘；旧档缺快照时明确显示“此世界尚无预览”，使用同一示意沙盘，首次加载后补齐。损坏缓存和目录读取错误有独立提示，不伪装为真实世界预览，不阻止加载页检查完整存档。
- 每个存档 Cell 有删除按钮，损坏档也可删除；当前正在游玩的槽位禁删，桥接层再次校验。确认后只按规范 GUID/`legacy` 槽位删除该存档、`.bak`、`.tmp` 和预览派生文件，禁止输入任意路径。失败保留明确提示；成功刷新列表及首页最近世界。可选派生文件先删，主存档最后删，派生文件失败时保留主存档。
- 设置只通过现有音频服务提交总音量、音乐、音效，并保存减少运动选项；关闭不应用。About Me 显示 `Application.productName/version`，不虚构作者。所有新文案走 Language/LuaTxt，保存 Prefab 的固定文字带 `LuaReference.localizedTexts`。
- 2026-10-27 已保存原生资源并通过菜单交互、两种转场、投影方向、相机状态恢复、快照/排序/删除检查；实际 2,500 格创建、跨槽恢复、创建时间保留与快照持久化检查通过。使用隔离 PreviewScene 和临时存档，不读写玩家档案、不进入 Play；不代表 Player 构建或长时间游玩验收。

## 关键入口

- [控制器](../../Lua/UI/Panel/StartMenuCtr.lua) / [存档 Cell](../../Lua/UI/Widget/CampaignSaveEntry.lua) / [主菜单桥](../../Assets/GameFramework/Samples/Adventure/CampaignMenu.cs)。
- [舞台与转场](../../Assets/GameFramework/Runtime/UI/StartMenuView.cs) / [舞台渲染](../../Assets/GameFramework/Runtime/UI/StartMenuStage.cs) / [快照提取](../../Assets/GameFramework/Samples/Adventure/CampaignPreviewCapture.cs) / [快照和头部读写](../../Assets/GameFramework/Runtime/Data/WorldMenuPreview.cs)。
- [资源安装](../../Assets/GameFramework/Editor/StartMenuSceneAssets.cs)：`Project Y/远征/安装场景式开始菜单`，首次迁移保留原 Prefab 备份，安装后直接维护保存的资源，不反复重建。路牌源见 [MainMenu.blend](../../Art/MainMenu/Source/MainMenu.blend)、[制作脚本](../../Art/MainMenu/Scripts/build_main_menu.py) 与 [清单](../../Art/MainMenu/manifest.json)。
- [舞台 Prefab](../../Assets/DynamicAsset/MainMenu/MainMenuStage.prefab) / [原生前景构图调整](../../Tools/UI/align_main_menu_stage.cs)：首次安装后的近景路牌与远景沙盘布置，以及标题避让；由 Unity MCP 执行并保存。不要用旧安装默认布局覆盖已调整资源。
- [原生界面检查](../../Tools/Tests/start_menu_scene_editmode.cs) / [菜单交互](../../Tools/Tests/start_menu_scene_integration.lua) / [快照、排序与删除](../../Tools/Tests/start_menu_preview_editmode.cs)。实际截图输出 `Docs/Previews/MainMenu`；源码文案检查沿用 [本地化](../Framework/Localization.md)。
- [相机所有权检查](../../Tools/Tests/start_menu_camera_editmode.cs) / [真实创建与恢复](../../Tools/Tests/loading_editmode.cs)：仅隔离 Edit Mode 验收，不触碰玩家存档。
