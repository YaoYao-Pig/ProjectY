# MainHud 与屏幕跟随 UI

关键词：MainHud、UIFollower、Overlay、屏幕血条、相机跟随、常驻 HUD、地点、资金、队伍、交互、日志。

## 文档目录

正文：所有权与接入 / 跟随与布局 / 修改和验证；关键入口：资源 / 控制器 / 数据投影。

## 正文

- `MainHud` 是 Main 层、非模态、缓存的唯一常驻 HUD。`AdventureUIBridge.sync` 打开它并管理故事面板；旧 `AdventureJournal` 与独立 `BattleHUD` 不再在远征流程中同时显示。
- `MainHudModel` 仅读真实远征／区域／战斗状态：地点、资金、可进入地点、可见搜刮点、设施、附近交互、队伍、可见敌人和经历。按钮沿用 `AdventureRuntimeDemo` 和业务命令；不在 UI 复制背包、血量或事件消费状态。
- 导航增加[任务与同行者](Narrative.md)入口；大地图提供独立三人叙事示例，NPC 好感/阵营/日程及任务进度由 MissionJournal 展示。近距离同优先级时具名 NPC 交谈优先于设施；招募队员显示其 NPC 名称。
- 点击 `HudParty` 队员卡选择角色，`CharacterSkill` Widget 显示其实际拥有且带 `life` 标签的技能；空技能、不可用原因、双用途标签和当前目标选择都有独立投影。点击技能后点击场景目标使用，Esc 或取消按钮退出选择；自己为目标的技能可直接释放。生活技能每页四格，上一页/下一页切换；换角色重置页码。选择状态保存在 Demo，切换角色或阶段清除目标选择。
- `CombatSkillTable.contexts` 是独立使用场景数组，允许 `{life,battle}`；驯服同时出现在生活栏与战斗栏。`CharacterSkills` 负责所有权、场景、目标、可用性与命令分派，生活效果通过 `Register` 接入处理器，战斗效果复用原 BattleCommand。栏位布局不写死驯服 ID，为以后展示其他技能保留同一查询/执行接口。
- 技能栏制作脚本为 `Art/ForestAnimals/Scripts/create_skill_hud.cs`，经 Unity MCP 创建 Prefab、登记 Widget、绑定 LuaReference 并导出提示；不调用会全局 Refresh 的 PanelAssets.Generate。`MainHudView.SetCharacterSkillBar` 接收显式绑定的容器统一布局。
- 场景中的单位目标优先用 `PawnView.Raycast` 和队伍/动物显示器的实际模型包围盒拾取，未命中模型才按完整占地回退；不把模型头部下方投射到的另一块地格当作目标。拾取只遍历已显示且存活的棋子，外观变化时重建 Renderer 缓存，移动时读取当前世界包围盒。探索的自动 `snapshot` 只刷新状态，保留上一次命令提示；明确的新命令或阶段切换会更新提示。最小检查为 Unity MCP 执行 [animal_targeting.cs](../../Tools/Tests/animal_targeting.cs)，复现并覆盖三种动物的多角度模型点击、隐藏目标和提示保留。
- 探索组包含导航、左侧队伍头像/生命/AP、底部技能、交互和日志；右侧公共入口栏与时钟在战斗中保留，菜单收纳养成、存读档、区域操作与调试入口。背包和任务在战斗中禁用；导航含“定位小队并跟随”显示命令，日志显示最近两条摘要，完整文本留在经历。战斗组复用嵌套的原 BattleHUD Prefab 与 `BattleHUDContent` Widget 控制器。原 `BattleHUDCtr` 仅保留独立检查入口。主 HUD 将父 CanvasGroup 的输入状态传给战斗内容，模态窗口仍可阻断快捷键。
- `MainHudView` 负责布局、字体和屏幕血条注册，不将血条堆叠到离角色更远的位置。可收起导航；C# 世界相机按导航实际像素宽度留出视口。小窗口隐藏常驻日志，完整经历仍可在角色手记查看。队伍头像复用 InventoryCharacterView 的按需肖像模式，基于头部挂点取景，仅外观变化时渲染；隐藏释放预览，重开重新生成。
- 头顶 `HudHealth` 在战斗和森林探索中生成投影，阵营侧边标记区分友方/敌方/中立（中立为黄色），生命条统一红色、AP 条蓝色；其他探索区域保留左侧竖排队伍卡。其身份列表与 Demo 已应用的显示快照交叉匹配，避免探索视野先推进、棋子尚未生成时绑定不存在的目标。血条位于 MainHud 的 Screen Space Canvas 下，不创建 World Space 血条。`AdventureRuntimeDemo.HealthTarget` 返回棋子的显式 head 挂点，血条底部跟随该挂点上方 .32 米及 4 UI 单位；动画时随头骨移动。`UIFollower` 在相机更新后投影，直接写父节点局部位置，支持非中心锚点。摄像机背后、裁面外和视口外隐藏，屏幕朝向保持水平，缩放默认限制 .75–1，不在近景额外放大。
- `HudHealthWidget` 的 UIFollower 可配置 `orthographicFade` 和 `perspectiveFade`（X 开始淡出、Y 完全隐藏）。正交默认尺寸 12→20；透视默认等效深度 18→30，深度按 FOV 折算到 60 度。通过 CanvasGroup.alpha 平滑过渡，远景 alpha=0，拉近自动恢复。正交不能用相机世界位置距离判断缩放；旧二维屏幕点模式不受此渐隐影响。interactiveChildren 只给包含可交互子图标的跟随 UI 开启，完全渐隐/离屏后停止拦截射线。
- 血条 Widget 默认 160×50，显示姓名、各自的 HP/AP；GameEffect 图标置于条下，每行六个、每行增加 24 高度，骑乘时也汇总坐骑效果。血条和文字不拦截鼠标，只有可见状态图标参与悬停；详情由 MainHud 的独立提示框显示。目标从小队／可见敌人渲染器取得，不做运行时层级搜索；雾外敌人不创建血条。靠近时允许重叠，不能通过抬高位置破坏目标对应关系。`Project Y/UI/同步头顶 HP AP 与状态` 定向迁移 HudHealth/HudStatusEffect 与提示框，同时删除独立战斗状态区；旧“同步紧凑血条与跟随参数”菜单委托此入口。
- 旧二维事件棋盘仍由 IMGUI 绘制棋盘与角色标记；其血条也使用 MainHud Widget，通过 UIFollower 的显式屏幕点模式跟随。大地图地点标记和可选画面调试窗仍留在 Demo；旧侧栏、头顶 IMGUI 血条及重复探索信息已移除。
- `BattleFeedbackSystem` 由 MainHud Prefab 持有，Lua `BattleFeedback.Changed` 只消费结算通知；Demo 在角色快照 Capture 后用同一命中延时提交反馈。每次实际攻击伤害独立排入震屏，下一次命中立即中断并重启当前震屏（包括普通命中打断强震屏），不会合并多次伤害或叠加振幅。镜头先计算基础位置再叠加偏移；二维棋盘叠加同源屏幕偏移。
- 连射仍同步结算，反馈使用原始 `impact.shot` 序号，在首次命中延时后按 `burstHitInterval`（默认 .2 秒）排开；此项序列化于 MainHud Prefab 的 BattleFeedbackSystem，可在 Inspector 调整。漏掉或未命中的子弹保留原时间空档，不补震屏；低帧率按发生时间顺序处理，以最新一次震屏的剩余进度显示。血条目标值仍合并为本次结算后的值。
- `impact.critical` 与 `impact.defeated` 分别采用默认 1.7 / 2.5 倍幅度，两者同时出现取较强值；致死伤害（含坐骑及持续伤害致死）只排一次强震屏，后续死亡通知不重复播放。普通持续伤害、未命中、零伤害与治疗不震屏。当前没有暴击判定，未来判定层可传 `GameEffects:ApplyPrepared(plan,{shot=n,critical=true})`；`QueueImpact(shotIndex,critical,defeated)` 是组件表现接口，不修改数值。
- `HudHealth` / `HudParty` 绑定 `HealthAnimation` 和 `HealthTrail`，淡色底层位于原生命条下方。`HealthBarAnimation` 协程先按曲线掉前景（默认 .22 秒），再掉底层（.38 秒）；等待命中与动画均使用缩放时间。连续伤害从当前显示值继续，重复投影不重启；治疗直接同步两层，更换角色/坐骑血量身份、隐藏及重开清除旧动效。时长、曲线、震屏像素幅度/频率/时长均可在组件 Inspector 调整。
- 头顶 Widget 按角色身份复用；已显示角色死亡时在现存目标上保留血条到两层归零，再隐藏，不把尸体加入可交互目标或业务存活列表。离场与清空 HUD 取消反馈，空格跳过局部战斗动作时也结束震屏和血条动画。
- 定向资源迁移 `Project Y/UI/同步战斗受击与双层血条` 仅保存 MainHud、HudHealth、HudParty 与 LuaReference/View 提示，保留现有布局和已调参数。检查入口 `Project Y/UI/验证战斗受击与双层血条` 在 PreviewScene 测试双层血条、逐发中断、漏发空档、暴击/死亡幅度、低帧率、暂停/跳过与具名 UI 动画，不进入 Play；`python -B Tools/Tests/run_lua.py Tools/Tests/battle_feedback.lua` 覆盖事件分类和实际 TrySkill 连射循环。
- 资源菜单 `Project Y/UI/创建 MainHud 与跟随血条` 创建 Prefab 和 LuaReference 绑定，重复执行保留手工布局。嵌套 BattleHUD 保持 Prefab 关联，但根节点必须显式设为单位缩放和零旋转：它作为 Widget 嵌入，不执行独立 LuaPanel.Initialize 的归一化。图标和基础布局继续由原资源同步工具维护。
- 最小检查：`Project Y/UI/验证 MainHud 与 UIFollower` 在独立 PreviewScene 验证导航、生命更新、战斗命令、缓存重开、战斗内容非零缩放、相机旋转/任意锚点的精确投影，以及重叠目标不会被移位，并输出 map/area/battle 三组截图。必须检查实际可见性，不能仅用 Lua visible 标记代替。此检查不进入 Play。基础战斗规则仍用 `battle_hud_core.lua`。

- 本次 UX 的增量迁移入口为 `Project Y/UI/应用 UX 布局`，通过 Unity MCP 调用 [UXLayoutAssets](../../Assets/GameFramework/Editor/UXLayoutAssets.cs)，保存现有 Prefab、LuaReference 和 View 提示，不进入 Play。

## 关键入口

- [MainHudModel.lua](../../Lua/Game/Adventure/MainHudModel.lua) / [MainHudCtr.lua](../../Lua/UI/Panel/MainHudCtr.lua)：投影与 UI 生命周期。
- [CharacterSkills.lua](../../Lua/Game/Adventure/CharacterSkills.lua) / [CharacterSkill.lua](../../Lua/UI/Widget/CharacterSkill.lua) / [技能栏检查](../../Tools/Tests/character_skills_core.lua)：技能上下文、所有权、效果适配与角色技能栏。
- [MainHudView.cs](../../Assets/GameFramework/Runtime/UI/MainHudView.cs) / [UIFollower.cs](../../Assets/GameFramework/Runtime/UI/UIFollower.cs)：布局、相机投影、缩放与隐藏。
- [MainHudAssets.cs](../../Assets/GameFramework/Editor/MainHudAssets.cs) / [MainHudValidation.cs](../../Assets/GameFramework/Editor/MainHudValidation.cs)：资源和最小验证。
- [BattleFeedbackSystem.cs](../../Assets/GameFramework/Runtime/UI/BattleFeedbackSystem.cs) / [BattleFeedback.lua](../../Lua/Game/Battle/BattleFeedback.lua)：战斗反馈调度；[HealthBarAnimation.cs](../../Assets/GameFramework/Runtime/UI/HealthBarAnimation.cs)：双层协程；[BattleFeedbackAssets.cs](../../Assets/GameFramework/Editor/BattleFeedbackAssets.cs)：资源绑定。
- [main_hud_integration.lua](../../Tools/Tests/main_hud_integration.lua) / [动作设计](../../Docs/CharacterAnimationPlan.md)。
