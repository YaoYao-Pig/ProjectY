# 俯视镜头与操控

关键词：3C、相机、镜头、拖拽、平移、旋转、缩放、角色跟随、StrategyCameraRig。

## 文档目录

正文：输入 / 跟随与接管 / 验证；关键入口：显示宿主 / 镜头模型 / 定向检查。

## 正文

- 大地图、地点探索和三维战斗共用正交俯视镜头；左键仍按各阶段发送旅行、走格子或战斗命令。WASD/方向键平移、中键拖拽、右键旋转、滚轮缩放、F 全景、HUD 定位按钮恢复跟随。角色导航规则归原有 Lua 系统，镜头只有表现状态。
- 中键按实际视口高度、正交尺寸、俯角与方位角换算屏幕像素，拖动直接响应且释放后没有惯性。键盘按视口尺度与帧时长积分，并归一化斜向速度；鼠标位移不再次乘帧时长。旋转、定位和缩放分别使用时间稳定的短阻尼。
- 滚轮按比例缩放，在过渡的每一帧固定鼠标射线与焦点水平面的交点；焦点平面不是地形碰撞拾取。缩放下限为正交尺寸 3，上限按当前地图包围盒、视角和视口计算。平移或滚轮解除自动跟随，定位按钮可恢复；右键旋转保留跟随。
- 拖拽只在世界视口内、UI 未拦截的按下帧开始，开始后经过 HUD 继续本次拖拽。释放、移出窗口、失焦、模态界面或特写接管会清理手势；镜头按键按住期间屏蔽场景点击和目标悬停。非模态 HUD 悬停不阻止键盘平移，文本输入框聚焦时阻止镜头键盘输入。
- 地点跟随在 `SquadPawnRenderer.Tick` 后读取领队的实际显示位置，不提前追逐权威目标格。全队阵亡且等待表现结束时保留最后显示位置并停止跟随。大地图跟随使用棋子同源的 `displayedTravel`。
- `LateUpdate` 应用基础镜头，再叠加战斗特写和反馈震屏。对话、特写及模态接管清除普通镜头残留运动；切换大地图/地点时同步目标与显示状态，不跨地图插值。战斗取景和 F 全景使用包围盒的屏幕投影及实际视口宽高比。
- 定向验证在已打开且空闲的 Editor Edit Mode 执行下方片段：临时预览场景中的真实 Camera 检查拖拽/缩放投影、裁切和竖屏视口、30/60/144 FPS、斜向速度、上下限、接管、切图和取景，不进入 Play 或改活动场景。主观手感仍须人工试玩。

## 关键入口

- [StrategyCameraRig.cs](../../Assets/GameFramework/Samples/Adventure/StrategyCameraRig.cs)：目标与显示状态、阻尼、投影换算、缩放锚点和包围盒取景。
- [AdventureCameraControls.cs](../../Assets/GameFramework/Samples/Adventure/AdventureCameraControls.cs)：输入归属、拖拽生命周期、UI 门控与解除跟随。
- [AdventureRuntimeDemo.cs](../../Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs)：跟随采样、地图切换和最终镜头应用；[战斗特写](MainHud.md)、[城镇导航](TownArea.md)保持各自职责。
- [strategy_camera_editmode.cs](../../Tools/Tests/strategy_camera_editmode.cs)：Unity MCP `execute_code` 定向检查正文。
- 参考：[0 A.D. CameraController](https://github.com/0ad/0ad/blob/master/source/graphics/CameraController.cpp)、[Spring RTS SpringController](https://github.com/spring/spring/blob/develop/rts/Game/Camera/SpringController.cpp)、[Cinemachine Damper](https://github.com/Unity-Technologies/com.unity.cinemachine/blob/main/com.unity.cinemachine/Runtime/Core/Predictor.cs)。借鉴输入分离、投影尺度、缩放锚点和指数阻尼，未引入新的相机包。
