# 俯视镜头与操控

关键词：3C、相机、镜头、阻尼、45度、90度、地图HUD、俯瞰、任务标记、拖拽、平移、旋转、缩放、角色跟随、StrategyCameraRig。

## 文档目录

正文：近景操控 / 俯瞰与地图HUD / 跟随与接管 / 验证；关键入口：显示宿主 / 镜头模型 / 标记投影 / 原生资源。

## 正文

- 大地图、地点探索和三维战斗共用正交俯视镜头；左键仍按各阶段发送旅行、走格子或战斗命令。WASD/方向键平移、中键拖拽、右键旋转、滚轮缩放、F 全景、HUD 定位按钮恢复跟随。角色导航规则归原有 Lua 系统，镜头只有表现状态。
- 近景默认俯角 45°，右键俯角限制为 30°–60°。中键按实际视口、正交尺寸与视角换算屏幕位移，增加 .065 秒指数阻尼；键盘归一化斜向速度，只有持续键盘输入乘帧时长。`AdventureRuntimeDemo.cameraSettings` 可调默认角度、限制及各类阻尼；角色导航不改变。
- 滚轮按比例缩放，在过渡的每一帧固定鼠标射线与焦点水平面的交点；焦点平面不是地形碰撞拾取。缩放下限为正交尺寸 3，上限按当前地图包围盒、视角和视口计算。平移或滚轮解除自动跟随，定位按钮可恢复；右键旋转保留跟随。
- 仅 `phase=map` 可进入地图俯瞰。`worldMapCameraSettings` 默认进入/退出正交尺寸为格半径的 60/48 倍；小地图按正俯视全景尺寸缩小阈值，避免无法进入。默认过渡 .55 秒，快速反向滚轮从当前进度反向播放。概览为严格 90°、北朝上，禁止右键改变视角；拉近或返回按钮恢复近景，回到小队同时恢复持续跟随。新建/加载远征默认近景跟随；F 可取全图并进入概览。
- 俯瞰期间只隐藏地图 NPC、势力队伍与玩家棋子/航船模型和拾取，保留静态地形、建筑及码头。后台旅行、势力模拟和存档状态不暂停；玩家位置与路线由独立地图开关控制。进入地点/战斗立即清除概览状态，不将 90° 写入近景角度。
- 地图 HUD 是 MainHud 根下的嵌套 Widget，保留根控制器及地点跟随层。11 个普通 HUD 分组先向边缘错峰离场，地图四个分组再从各自边缘进入；独立全屏 Motion wrapper 的位置动画不覆盖 MainHudView 的响应布局。过渡期间两套按钮不接收点击，完成后只有当前一套接收输入；根 Group 仍由对话/UISystem 管理。
- 地图开关为地点名称、可接任务、进行中委托、可回城交付、小队位置与旅行路线，状态归缓存 HUD，不写存档。近景原有地点标签开关独立保留。地图标签关闭后连悬停文字也隐藏，仍可点选已知地点；概览不使用地点抬升与灰罩。任务标记不拦截世界点击。
- 地图使用 `MapParchment` 无文字透明图集：四种纸面、十种功能/任务图标，以 Unity 原生 SpriteMultiple 切片和九宫格保存。布局为左上标题签、左侧过滤卡、右侧小图例、右上返回、底部两个分离工具组；`MapHudLayout` 保存美术与六组地图/八组普通HUD遮挡引用，并按视口等比缩放。标题保持宋体，短标签/状态使用黑体；重建基础HUD后需重新执行下方羊皮纸同步脚本。
- 地点 Tag 为 24 高的小纸签，默认仅显示 `Site.ShortName`（原始地点配置名称），悬停可显示完整状态名称；按真实字体宽度截短并使用本地化省略模板，宽度上限普通180/悬停300。任务同地点合并为一条图标组及数量，不重复地点名称；三类筛选分别控制图标与合计数，过滤隐藏保留实例复用，已移除地点才释放。
- `MapLabelCoordinator` 在 MainHud 的全部 UIFollower 投影结束后统一排布地点名、任务图标和玩家标记。优先级为悬停地点、小队、可交付/进行中/可接任务、城镇及其他地点；稳定ID与上一帧槽位减少闪动。最多偏移36屏幕像素，标签及HUD间保留4像素；无可用位置时隐藏低优先级名称，地图地格拾取仍有效。两套HUD过渡中的实际可见卡片均参与避让；显隐/位置变化更新地点拾取缓存。
- `WorldMapMarkers.Build(adventure,snapshot.sites)` 只读当前已探索地点、现有 NPC 接/交任务分支和已生成城镇委托，按地点和 available/active/ready 聚合。数量是联系人/委托数，不是 Quest 数。进行中护送只标已知目的地；未生成的每日委托、已完成/失败任务、未知地点和移动实体不显示。不调用生成/刷新/领取命令；交付检查不要求玩家已站在发布人旁。
- 普通 Mission/Quest 没有统一目标坐标；首版图标表示任务联络或委托地点，不推测材料采集点或具体敌人位置。新增标记类别应扩展同一投影契约和过滤入口，禁止从原始未过滤地点数组补出位置。
- 拖拽只在世界视口内、UI 未拦截的按下帧开始，开始后经过 HUD 继续本次拖拽。释放、移出窗口、失焦、模态界面或特写接管会清理手势；镜头按键按住期间屏蔽场景点击和目标悬停。非模态 HUD 悬停不阻止键盘平移，文本输入框聚焦时阻止镜头键盘输入。
- 地点跟随在 `SquadPawnRenderer.Tick` 后读取领队的实际显示位置，不提前追逐权威目标格。全队阵亡且等待表现结束时保留最后显示位置并停止跟随。大地图跟随使用棋子同源的 `displayedTravel`。
- `LateUpdate` 应用基础镜头，再叠加战斗特写和反馈震屏。对话、特写及模态接管清除普通镜头残留运动；切换大地图/地点时同步目标与显示状态，不跨地图插值。战斗取景和 F 全景使用包围盒的屏幕投影及实际视口宽高比。
- 定向验证在已打开且空闲的 Editor Edit Mode 执行下方片段；相机检查含投影、30/60/144 FPS、阻尼、阈值滞回、反向过渡、90°锁定与切图。HUD 检查真实已保存 Prefab/Clip、输入状态、过滤、隐藏队伍与缓存重开，预览输出 `Docs/Previews/WorldMapOverview/`。主观手感仍须人工试玩。

## 关键入口

- [StrategyCameraRig.cs](../../Assets/GameFramework/Samples/Adventure/StrategyCameraRig.cs)：目标与显示状态、阻尼、投影换算、缩放锚点和包围盒取景。
- [AdventureCameraControls.cs](../../Assets/GameFramework/Samples/Adventure/AdventureCameraControls.cs)：输入归属、拖拽生命周期、UI 门控与解除跟随。
- [WorldMapCameraMode.cs](../../Assets/GameFramework/Samples/Adventure/WorldMapCameraMode.cs) / [AdventureWorldMapOverview.cs](../../Assets/GameFramework/Samples/Adventure/AdventureWorldMapOverview.cs)：阈值、共享时间轴、模式生命周期与反射桥接。
- [WorldMapMarkers.lua](../../Lua/Game/Adventure/WorldMapMarkers.lua) / [WorldMapMarkerView.cs](../../Assets/GameFramework/Samples/Adventure/WorldMapMarkerView.cs)：只读任务联络投影与真实位置显示。
- [WorldMapHud.lua](../../Lua/UI/Widget/WorldMapHud.lua) / [HudModeTransition.cs](../../Assets/GameFramework/Runtime/UI/HudModeTransition.cs)：地图操作及两套 HUD 动画输入控制。
- [MapHudLayout.cs](../../Assets/GameFramework/Samples/Adventure/MapHudLayout.cs) / [MapLabelCoordinator.cs](../../Assets/GameFramework/Samples/Adventure/MapLabelCoordinator.cs) / [MapLabelLayout.cs](../../Assets/GameFramework/Samples/Adventure/MapLabelLayout.cs)：纸面分区、统一投影后排布、独立屏幕几何算法。
- [apply_map_parchment.cs](../../Tools/UI/apply_map_parchment.cs) / [sprites.json](../../Art/UI/MapParchment/sprites.json)：原生切片、MainHud/WorldSiteOverlay显式绑定和字体/本地化同步；先导入并编译新增组件，再执行脚本，保留已有Motion动画及玩法绑定。
- [build_world_map_hud.cs](../../Tools/UI/build_world_map_hud.cs)：经 Unity MCP 定向保存 MainHud、map-overview.anim、LuaReference、本地化清单及 View 提示；先导出 Language，再导入并编译新增组件，然后执行。可重复执行，已有资源编辑器须通过绑定复用 Motion 下的布局节点。
- [AdventureRuntimeDemo.cs](../../Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs)：跟随采样、地图切换和最终镜头应用；[战斗特写](MainHud.md)、[城镇导航](TownArea.md)保持各自职责。
- [strategy_camera_editmode.cs](../../Tools/Tests/strategy_camera_editmode.cs)：Unity MCP `execute_code` 定向检查正文。
- [world_map_overview_editmode.cs](../../Tools/Tests/world_map_overview_editmode.cs) / [world_map_markers.lua](../../Tools/Tests/world_map_markers.lua)：原生 HUD/动画与只读任务标记定向检查。
- [map_label_layout_editmode.cs](../../Tools/Tests/map_label_layout_editmode.cs) / [map_parchment_editmode.cs](../../Tools/Tests/map_parchment_editmode.cs)：密集100项几何检查与真实纸面Prefab/字体/标签避让预览；图中地图与任务为测试夹具，非玩家存档。
- 参考：[0 A.D. CameraController](https://github.com/0ad/0ad/blob/master/source/graphics/CameraController.cpp)、[Spring RTS SpringController](https://github.com/spring/spring/blob/develop/rts/Game/Camera/SpringController.cpp)、[Cinemachine Damper](https://github.com/Unity-Technologies/com.unity.cinemachine/blob/main/com.unity.cinemachine/Runtime/Core/Predictor.cs)。借鉴输入分离、投影尺度、缩放锚点和指数阻尼，未引入新的相机包。
