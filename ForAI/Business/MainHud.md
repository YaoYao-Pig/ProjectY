# MainHud 与屏幕跟随 UI

关键词：MainHud、UIFollower、Overlay、屏幕血条、相机跟随、常驻 HUD、地点、资金、队伍、交互、日志。

## 文档目录

正文：所有权与接入 / 跟随与布局 / 修改和验证；关键入口：资源 / 控制器 / 数据投影。

## 正文

- `MainHud` 是 Main 层、非模态、缓存的唯一常驻 HUD。`AdventureUIBridge.sync` 打开它并管理故事面板；旧 `AdventureJournal` 与独立 `BattleHUD` 不再在远征流程中同时显示。
- `MainHudModel` 仅读真实远征／区域／战斗状态：地点、资金、可进入地点、可见搜刮点、设施、附近交互、队伍、可见敌人和经历。按钮沿用 `AdventureRuntimeDemo` 和业务命令；不在 UI 复制背包、血量或事件消费状态。
- 点击 `HudParty` 队员卡选择角色，`CharacterSkill` Widget 显示其实际拥有且带 `life` 标签的技能；空技能、不可用原因、双用途标签和当前目标选择都有独立投影。点击技能后点击场景目标使用，Esc 或取消按钮退出选择；自己为目标的技能可直接释放。技能多时横向滚动。选择状态保存在 Demo，切换角色或阶段清除目标选择。
- `CombatSkillTable.contexts` 是独立使用场景数组，允许 `{life,battle}`；驯服同时出现在生活栏与战斗栏。`CharacterSkills` 负责所有权、场景、目标、可用性与命令分派，生活效果通过 `Register` 接入处理器，战斗效果复用原 BattleCommand。栏位布局不写死驯服 ID，为以后展示其他技能保留同一查询/执行接口。
- 技能栏制作脚本为 `Art/ForestAnimals/Scripts/create_skill_hud.cs`，经 Unity MCP 创建 Prefab、登记 Widget、绑定 LuaReference 并导出提示；不调用会全局 Refresh 的 PanelAssets.Generate。`MainHudView.SetCharacterSkillBar` 接收显式绑定的容器统一布局。
- 场景中的单位目标优先用 `PawnView.Raycast` 和队伍/动物显示器的实际模型包围盒拾取，未命中模型才按完整占地回退；不把模型头部下方投射到的另一块地格当作目标。拾取只遍历已显示且存活的棋子，外观变化时重建 Renderer 缓存，移动时读取当前世界包围盒。探索的自动 `snapshot` 只刷新状态，保留上一次命令提示；明确的新命令或阶段切换会更新提示。最小检查为 Unity MCP 执行 [animal_targeting.cs](../../Tools/Tests/animal_targeting.cs)，复现并覆盖三种动物的多角度模型点击、隐藏目标和提示保留。
- 探索组包含导航、背包／养成入口、区域操作、队伍状态、交互和日志；导航含“定位小队并跟随”显示命令，日志显示最近两条摘要，完整文本留在经历。战斗组复用嵌套的原 BattleHUD Prefab 与 `BattleHUDContent` Widget 控制器。原 `BattleHUDCtr` 仅保留独立检查入口。主 HUD 将父 CanvasGroup 的输入状态传给战斗内容，模态窗口仍可阻断快捷键。
- `MainHudView` 负责布局、字体和屏幕血条注册，不将血条堆叠到离角色更远的位置。可收起导航；C# 世界相机按导航实际像素宽度留出视口。小窗口隐藏常驻日志，完整经历仍可在角色手记查看。
- 头顶 `HudHealth` 在战斗和森林探索中生成投影，森林中立动物以黄色显示；其他探索区域保留底部队伍生命卡。其身份列表与 Demo 已应用的显示快照交叉匹配，避免探索视野先推进、棋子尚未生成时绑定不存在的目标。血条位于 MainHud 的 Screen Space Canvas 下，不创建 World Space 血条。`AdventureRuntimeDemo.HealthTarget` 返回棋子的显式 head 挂点，血条底部跟随该挂点上方 .32 米及 4 UI 单位；动画时随头骨移动。`UIFollower` 在相机更新后投影，直接写父节点局部位置，支持非中心锚点。摄像机背后、裁面外和视口外隐藏，屏幕朝向保持水平，缩放默认限制 .75–1，不在近景额外放大。
- `HudHealthWidget` 的 UIFollower 可配置 `orthographicFade` 和 `perspectiveFade`（X 开始淡出、Y 完全隐藏）。正交默认尺寸 12→20；透视默认等效深度 18→30，深度按 FOV 折算到 60 度。通过 CanvasGroup.alpha 平滑过渡，远景 alpha=0，拉近自动恢复。正交不能用相机世界位置距离判断缩放；旧二维屏幕点模式不受此渐隐影响。
- 血条 Widget 默认 128×36，血槽高 11，显示姓名和 HP 数字；不拦截鼠标。目标从小队／可见敌人渲染器取得，不做运行时层级搜索；雾外敌人不创建血条。靠近时允许重叠，不能通过抬高位置破坏目标对应关系。`Project Y/UI/同步紧凑血条与跟随参数` 定向更新现有血条 Prefab。
- 旧二维事件棋盘仍由 IMGUI 绘制棋盘与角色标记；其血条也使用 MainHud Widget，通过 UIFollower 的显式屏幕点模式跟随。大地图地点标记和可选画面调试窗仍留在 Demo；旧侧栏、头顶 IMGUI 血条及重复探索信息已移除。
- 资源菜单 `Project Y/UI/创建 MainHud 与跟随血条` 创建 Prefab 和 LuaReference 绑定，重复执行保留手工布局。嵌套 BattleHUD 保持 Prefab 关联，但根节点必须显式设为单位缩放和零旋转：它作为 Widget 嵌入，不执行独立 LuaPanel.Initialize 的归一化。图标和基础布局继续由原资源同步工具维护。
- 最小检查：`Project Y/UI/验证 MainHud 与 UIFollower` 在独立 PreviewScene 验证导航、生命更新、战斗命令、缓存重开、战斗内容非零缩放、相机旋转/任意锚点的精确投影，以及重叠目标不会被移位，并输出 map/area/battle 三组截图。必须检查实际可见性，不能仅用 Lua visible 标记代替。此检查不进入 Play。基础战斗规则仍用 `battle_hud_core.lua`。

## 关键入口

- [MainHudModel.lua](../../Lua/Game/Adventure/MainHudModel.lua) / [MainHudCtr.lua](../../Lua/UI/Panel/MainHudCtr.lua)：投影与 UI 生命周期。
- [CharacterSkills.lua](../../Lua/Game/Adventure/CharacterSkills.lua) / [CharacterSkill.lua](../../Lua/UI/Widget/CharacterSkill.lua) / [技能栏检查](../../Tools/Tests/character_skills_core.lua)：技能上下文、所有权、效果适配与角色技能栏。
- [MainHudView.cs](../../Assets/GameFramework/Runtime/UI/MainHudView.cs) / [UIFollower.cs](../../Assets/GameFramework/Runtime/UI/UIFollower.cs)：布局、相机投影、缩放与隐藏。
- [MainHudAssets.cs](../../Assets/GameFramework/Editor/MainHudAssets.cs) / [MainHudValidation.cs](../../Assets/GameFramework/Editor/MainHudValidation.cs)：资源和最小验证。
- [main_hud_integration.lua](../../Tools/Tests/main_hud_integration.lua) / [动作设计](../../Docs/CharacterAnimationPlan.md)。
