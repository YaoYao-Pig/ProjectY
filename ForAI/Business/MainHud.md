# MainHud 与屏幕跟随 UI

关键词：MainHud、UIFollower、Overlay、屏幕血条、伤害数字、飘字、暴击、相机跟随、常驻 HUD、地点、资金、队伍、交互、日志。

## 文档目录

正文：所有权与接入 / 跟随与布局 / 修改和验证；关键入口：资源 / 控制器 / 数据投影。

## 正文

- 剧情对话期间由 MainHud 自身按 Narrative.DialogueOpen 隐藏整组 HUD 表现，结束后恢复；只调整已绑定 CanvasGroup 的透明度，不关闭常驻控制器。输入仍由 UISystem 的模态规则管理，避免时钟、技能栏及队员卡穿透对白。

- MainHud 常驻“开始／暂停／速度 1×・2×・4×／回到小队”按钮，全部由 LuaReference 显式绑定。开始/暂停为幂等命令 `travel_resume/travel_suspend`，速度按钮循环三档且不改变暂停状态；时间按钮只在大地图显示并控制旅行和世界时钟。“回到小队”复用 `hud_follow`，大地图与局部探索均可用。资源增量迁移为 `Project Y/UI/同步大地图时间与小队定位按钮`（[WorldFogHudAssets](../../Assets/GameFramework/Editor/WorldFogHudAssets.cs)），保留原布局，实际按钮与存读验证见[战争迷雾](WorldFog.md)。

- [BattleCinematic](../../Assets/GameFramework/Samples/Adventure/BattleCinematic.cs) 与 [AdventureBattleCinematic](../../Assets/GameFramework/Samples/Adventure/AdventureBattleCinematic.cs) 只消费结算后的攻击事件。`AdventureRuntimeDemo.battleCinematicSettings` 调整开关、默认 .35 倍动作速度、过渡、运镜、抬升和灰罩强度；镜头按全部参与模型 bounds 取景。复用 `SceneFocusMask.Create(mainHud.PresentationRoot)` 的实际轮廓遮罩，不修改全局 Time.timeScale 或任何玩法位置。
- 特写只收集当前启用且处于活动层级的 Renderer；未启用的换装/头发模块允许保留空材质槽，不进入提亮、遮罩或取景集合。[空材质占位回归](../../Tools/Tests/battle_cinematic_optional_renderers.cs) 使用真实 PawnRig 的禁用模块，检查开始特写、隐藏部件不被修改和退出恢复。
- 特写期间角色、粒子、震屏、血条等待与伤害数字共用表现速度；面板暂停不推进特写。恢复基础镜头后再接收下一条战斗命令，空格跳过、换 HUD、离场、销毁均清理抬升、材质 PropertyBlock 和遮罩。死亡模型销毁允许保留最后取景边界；只临时调整显示根 Transform，下一帧导航更新前还原，不累计偏移。定向原生检查为 [spear_cinematic_editmode.cs](../../Tools/Tests/spear_cinematic_editmode.cs)。

- 正式远征复用动态菜单行提供四档地图规模的新游戏、继续和保存（F5），无额外 prefab 绑定；火炬开关复用相同命令通道（T）。队员卡显示实际等级。流程及存档范围见[远征](Adventure.md)与[存档](CharacterSave.md)。

- `MainHud` 是 Main 层、非模态、缓存的唯一常驻 HUD。`AdventureUIBridge.sync` 打开它并管理故事面板；旧 `AdventureJournal` 与独立 `BattleHUD` 不再在远征流程中同时显示。
- `MainHudModel` 仅读真实远征／区域／战斗状态：地点、资金、可进入地点、可见搜刮点、设施、附近交互、队伍、可见敌人和经历。按钮沿用 `AdventureRuntimeDemo` 和业务命令；不在 UI 复制背包、血量或事件消费状态。
- `InteractionPrompt.Find` 是附近交互的共同查询，按道路可达距离和稳定优先级选择 NPC、设施、容器或障碍；物体头顶 `HudInteraction` 与 `area_interact_nearest`（E 键）使用同一结果。附近目标只显示头顶提示，不再同时投影为底部交互卡片；已打开的设施等交互仍可显示详情与关闭入口。头顶提示在已交互或战斗中隐藏。`InteractionPromptBridge.Track → MainHudView.TrackPoint` 将只读场景位置交给 UIFollower，在相机更新后投影、缩放和淡出；不查找运行时子节点。
- `Project Y/UI/同步物体交互按键提示` 已生成并保存 HudInteraction Prefab、PanelConfig 及 Root/Key/Label/Follower 绑定。Widget 归 MainHud 生命周期，提示不拦截鼠标；城镇取消第三人称切换按钮，与其他小地图共用格子移动。
- 状态获得通知通过 `StatusFeedback.Queue` 进入现有头顶弹字池，沿用命中时序，以每角色独立队列显示名称、层数和配置颜色，不触发伤害数字或震屏。`DamageNumberAnimation.statusInterval/statusFontSize` 控制间隔/字号；状态文字位于伤害数字上方，暂停/跳过/角色复用时与原动画共同处理。状态规则见 [GameEffect](GameEffects.md)。
- 大地图导航复用现有行按钮显示[旅行](WorldTravel.md)目的地、地形、预计分钟、暂停/继续及 1/2/4 倍速；`hud_follow` 在大地图定位旅行小队，在局部地图仍按原规则跟随。地点命令先旅行，到达后进入；无需新增 Prefab 绑定。
- 大地图底部的独立“营地”按钮调用 `camp_open`，复用已序列化的 `Restart/RestartText` 绑定。菜单通过既有动态行提供四档规模的新游戏、继续游戏、保存远征和火炬开关，分别走明确命令；流程与存档范围见[远征](Adventure.md)和[存档](CharacterSave.md)。顶部“角色养成”负责学习与加点，队员卡显示当前等级；“技能图鉴 · 浏览”只查询技能。营地面板资源接入见[营地](Camp.md)。
- 导航增加[任务与同行者](Narrative.md)入口；正式远征采用三人开局，NPC 好感/阵营/日程及任务进度由 MissionJournal 展示。近距离同优先级时具名 NPC 交谈优先于设施；招募队员显示其 NPC 名称。
- 点击 `HudParty` 队员卡选择角色，`CharacterSkill` Widget 显示其实际拥有且带 `life` 标签的技能；空技能、不可用原因、双用途标签和当前目标选择都有独立投影。点击技能后点击场景目标使用，Esc 或取消按钮退出选择；自己为目标的技能可直接释放。生活技能每页四格，上一页/下一页切换；换角色重置页码。选择状态保存在 Demo，切换角色或阶段清除目标选择。
- `CombatSkillTable.contexts` 是独立使用场景数组，允许 `{life,battle}`；驯服同时出现在生活栏与战斗栏。`CharacterSkills` 负责所有权、场景、目标、可用性与命令分派，生活效果通过 `Register` 接入处理器，战斗效果复用原 BattleCommand。栏位布局不写死驯服 ID，为以后展示其他技能保留同一查询/执行接口。
- 技能栏制作脚本为 `Art/ForestAnimals/Scripts/create_skill_hud.cs`，经 Unity MCP 创建 Prefab、登记 Widget、绑定 LuaReference 并导出提示；不调用会全局 Refresh 的 PanelAssets.Generate。`MainHudView.SetCharacterSkillBar` 接收显式绑定的容器统一布局。
- 场景中的单位目标优先用 `PawnView.Raycast` 和队伍/动物显示器的实际模型包围盒拾取，未命中模型才按完整占地回退；不把模型头部下方投射到的另一块地格当作目标。拾取只遍历已显示且存活的棋子，外观变化时重建 Renderer 缓存，移动时读取当前世界包围盒。探索的自动 `snapshot` 只刷新状态，保留上一次命令提示；明确的新命令或阶段切换会更新提示。最小检查为 Unity MCP 执行 [animal_targeting.cs](../../Tools/Tests/animal_targeting.cs)，复现并覆盖三种动物的多角度模型点击、隐藏目标和提示保留。
- 探索组包含导航、左侧队伍头像/生命/AP、底部技能、交互和日志；右侧公共入口栏与时钟在战斗中保留，菜单收纳养成、存读档、区域操作与调试入口。背包和任务在战斗中禁用；导航含“定位小队并跟随”显示命令，日志显示最近两条摘要，完整文本留在经历。战斗组复用嵌套的原 BattleHUD Prefab 与 `BattleHUDContent` Widget 控制器。原 `BattleHUDCtr` 仅保留独立检查入口。主 HUD 将父 CanvasGroup 的输入状态传给战斗内容，模态窗口仍可阻断快捷键。
- `MainHudView` 负责布局、字体和屏幕血条注册，不将血条堆叠到离角色更远的位置。`Prepare` 通过既有 `BattleContent` / `HUD` 引用取得嵌套战斗视图；按右侧时钟、入口栏和菜单的占用给 [BattleHUD](BattleHUD.md) 预留宽度，菜单显隐及窗口变化都会重新布局。公共栏随较小窗口等比缩放，金币文字与首个菜单按钮保留间距。可收起导航；C# 世界相机按导航实际像素宽度留出视口。小窗口隐藏常驻日志，完整经历仍可在角色手记查看。队伍头像复用 InventoryCharacterView 的按需肖像模式，基于头部挂点取景，仅外观变化时渲染；隐藏释放预览，重开重新生成。
- `HudHealth` 在战斗和森林探索中显示脚下同心圆：外圈红色 HP、内圈蓝色 AP，取消头顶姓名栏和矩形底板；阵营保留小标记，其他探索区域沿用队伍卡。身份列表仍与 Demo 已应用的显示快照交叉匹配，雾外敌人不创建 UI。`HealthFootTarget` 从已有棋子渲染器返回根 Transform，`HealthRingRadius` 按实际占地计算半径；多格单位按占地中心与外缘扩大。`HudHealth.IsWorldUI` 使 Widget 由 UIHost 放入独立 WorldUIRoot；Prefab 自带 World Space Canvas，使用 UI/Default 的世界深度测试，角色和不透明场景物体能遮挡圆环。`UIFollower.groundPlane` 将圆环按实际世界半径平放在脚下 .035 米处，支持透视/正交、相机旋转、背面/裁面/视口隐藏，不改变角色位置。
- `HealthRingMesh` 为普通 Image 生成中空圆环，Filled Image 的 `fillAmount` 作为 HP/AP 比例。`HealthBarAnimation` 与 `MainHudView.SetHealth` 同时支持 Filled 圆环和既有矩形队伍条。`ArcText.worldBillboard` 将字形中心放在地面圆弧上，并抬高半个字高；完整字形朝向相机，保留黑色 Outline，不随地面俯角压扁。世界模式根节点为 128×128，世界缩放由半径决定；状态格子浮于前侧并朝向相机，增减效果不改变圆环中心。
- 伤害/状态飘字通过已绑定的 `DamageFollower` 跟随原 `HealthTarget` 的 head 挂点，位置独立于脚下圈；飘字在同一世界 Canvas 中朝向相机，UIFollower 补偿父节点缩放并维持屏幕字号。Lua 同时注册/注销两处跟随，Retire 保留头部和脚下的最后位置，隐藏/复用清理原反馈。
- `HudHealthWidget` 的 UIFollower 可配置 `orthographicFade` 和 `perspectiveFade`（X 开始淡出、Y 完全隐藏）。正交默认尺寸 12→20；透视默认等效深度 18→30，深度按 FOV 折算到 60 度。通过 CanvasGroup.alpha 平滑过渡，远景 alpha=0，拉近自动恢复。正交不能用相机世界位置距离判断缩放；旧二维屏幕点模式不受此渐隐影响。interactiveChildren 只给包含可交互子图标的跟随 UI 开启，完全渐隐/离屏后停止拦截射线。
- GameEffect 图标由 [ArcLayoutGroup](../../Assets/GameFramework/Runtime/UI/ArcLayoutGroup.cs) 沿 HP 外侧的下半圈排列，每弧最多六个，超过后向外增加一弧；每个图标独立朝向相机，避开 HP 数字，增减状态不再按行数抬高整组。`EffectSlots` 与脚下根节点同尺寸，Lua 只维护状态内容与复用。骑乘时汇总坐骑效果；只有可见状态图标接受悬停，详情仍由 MainHud 独立提示框显示。`Project Y/UI/同步脚下 HP AP 圆环` 定向保存 HudHealth Prefab 与 LuaReference/View 提示；原 UX/头顶同步入口也委托圆环构建，避免旧迁移恢复矩形血条。`GroundHealthAssets.Build` 可重复运行；Sync 同时保存 PanelConfig 的 IsWorldUI 标记，GraphicRaycaster 以三维物体阻挡状态图标射线。
- 旧二维事件棋盘仍由 IMGUI 绘制棋盘与角色标记；其血条也使用 MainHud Widget，通过 UIFollower 的显式屏幕点模式暂时挂回所属屏幕 Canvas，分别跟随脚下圈和头部飘字；返回三维模式时挂回原 WorldUIRoot。可选画面调试窗仍留在 Demo；旧侧栏、头顶 IMGUI 血条及重复探索信息已移除。
- 大地图地点由 `WorldSiteView` 在 MainHud 下持有名称 Tag，复用 `UIFollower`，取消 IMGUI 编号圆点。正交尺寸达到格半径的 64 倍常显，低于 56 倍切回仅悬停显示；滞回避免阈值闪烁。名称取真实地点快照，Tag 不阻断 UI 射线，但点击可导航到地点；场景拾取同时支持地点占地和建筑模型包围盒，其他 UI、拖拽镜头及模态面板阻止悬停。
- `WorldSiteLayout` 按轴坐标分块拾取真实六边形柱体；城镇/地牢使用 `worldTownId` 对应的完整城镇占地，独立事件/森林入口/水上地点使用实际入口格，不把地点附近任意土地当成其占地。`MapPreviewFocus` 仅改变渲染矩阵和颜色，地面、建筑、道路和地表装饰一同抬升；地图数据、寻路和旅行状态不变。轮廓按 8×8 轴坐标块缓存实例，遮罩只绘制选中轮廓投影内及其前方可能遮挡的块；非选中地形仍写深度遮挡。悬停不再清空全地图标记，静止镜头/指针复用遮罩与拾取，名称仅在快照或挂点变化时更新；[通用 UI 逆遮罩](../Framework/UI.md) 在轮廓外压半透明灰色。离开地图、打开面板、换世界和销毁时恢复实例并清理标签/遮罩。
- `BattleFeedbackSystem` 由 MainHud Prefab 持有，Lua `BattleFeedback.Changed` 只消费结算通知；Demo 在角色快照 Capture 后用同一命中延时提交反馈。每次实际攻击伤害独立排入震屏，下一次命中立即中断并重启当前震屏（包括普通命中打断强震屏），不会合并多次伤害或叠加振幅。镜头先计算基础位置再叠加偏移；二维棋盘叠加同源屏幕偏移。
- 连射仍同步结算，反馈使用原始 `impact.shot` 序号，在首次命中延时后按 `burstHitInterval`（默认 .2 秒）排开；此项序列化于 MainHud Prefab 的 BattleFeedbackSystem，可在 Inspector 调整。漏掉或未命中的子弹保留原时间空档，不补震屏；低帧率按发生时间顺序处理，以最新一次震屏的剩余进度显示。血条目标值仍合并为本次结算后的值。
- `impact.critical` 与 `impact.defeated` 分别采用默认 1.7 / 2.5 倍幅度，两者同时出现取较强值；致死伤害（含坐骑及持续伤害致死）只排一次强震屏，后续死亡通知不重复播放。普通持续伤害、未命中、零伤害与治疗不震屏。当前没有暴击判定，未来判定层可传 `GameEffects:ApplyPrepared(plan,{shot=n,critical=true})`；`QueueImpact(shotIndex,critical,defeated)` 是组件表现接口，不修改数值。
- `BattleFeedback.Changed` 将每笔正伤害的实际 `event.amount` 交给伤害数字队列，配置色通过 `DamageFeedback.Queue` 反射桥接传入，空色仍调用 `QueueDamage` 使用原普通/暴击色；颜色来源见 [GameEffect](GameEffects.md)。每笔伤害独立保存颜色，与震屏共用命中延时及逐发间隔。仅 `HudHealth` 绑定 `DamageNumbers`，持续伤害也飘字，治疗、未命中、零伤害和独立死亡通知不生成数字。绑定同时记录角色/血量身份以接住坐骑持续伤害；下坐骑保留已提交数字，更换角色清空。`DamageNumberAnimation` 复用池内模板，以缩放时间播放弹出、回弹、错位上浮及渐隐；字号随实际伤害按对数增长并封顶，暴击保留配置的数字颜色，额外放大、显示金色辉光/描边、“暴击!”与放射闪光。Overlay 下的辉光由字形网格绘制，不依赖相机 Bloom。模板与 UIFollower 均经资源工具显式绑定；时长、字号范围、伤害参考值、暴击倍率和上浮高度可在 Inspector 调整。
- `HudHealth` / `HudParty` 绑定 `HealthAnimation` 和 `HealthTrail`，淡色底层位于原生命条下方。`HealthBarAnimation` 协程先按曲线掉前景（默认 .22 秒），再掉底层（.38 秒）；等待命中与动画均使用缩放时间。连续伤害从当前显示值继续，重复投影不重启；治疗直接同步两层，更换角色/坐骑血量身份、隐藏及重开清除旧动效。时长、曲线、震屏像素幅度/频率/时长均可在组件 Inspector 调整。
- 圆环 Widget 按角色身份复用；已显示角色死亡时保留到双层血条与待播/活动数字全部结束。Retire 时允许两处 UIFollower 在头部/脚下目标销毁后继续投影最后世界位置，重新绑定/清除时释放，不把尸体加入可交互目标或业务存活列表。离场、隐藏与清空 HUD 取消反馈，空格跳过局部战斗动作时也结束震屏、血条和全部数字。
- 定向资源迁移 `Project Y/UI/同步战斗受击与双层血条` 仅保存 MainHud、HudHealth、HudParty 与 LuaReference/View 提示，保留现有布局和已调参数。检查入口 `Project Y/UI/验证战斗受击与双层血条` 在 PreviewScene 测试双层血条、逐发中断、漏发空档、暴击/死亡幅度、低帧率、暂停/跳过与具名 UI 动画，不进入 Play；`python -B Tools/Tests/run_lua.py Tools/Tests/battle_feedback.lua` 覆盖事件分类和实际 TrySkill 连射循环。
- 伤害数字沿用上述资源迁移入口保存 `HudHealth.DamageNumbers` 及模板。`Project Y/UI/验证伤害数字` 定向检查已保存绑定、类型颜色/暴击保色、字号/暴击、逐发空档、池复用色彩重置、坐骑身份、暂停/跳过、真实 xLua 桥接与死亡目标销毁后投影，并输出 `Docs/Previews/DamageNumbers.png`（普通/大伤害/暴击/流血/中毒/燃烧的三个动画阶段）；仅在已有 Editor 的 Edit Mode 执行，代码检查不能代替实际预览验收。
- 资源菜单 `Project Y/UI/创建 MainHud 与跟随血条` 创建 Prefab 和 LuaReference 绑定，重复执行保留手工布局。嵌套 BattleHUD 保持 Prefab 关联，但根节点必须显式设为单位缩放和零旋转：它作为 Widget 嵌入，不执行独立 LuaPanel.Initialize 的归一化。图标和基础布局继续由原资源同步工具维护。
- 最小检查：`Project Y/UI/验证 MainHud 与 UIFollower` 在独立 PreviewScene 验证导航、生命更新、战斗命令、缓存重开、战斗内容非零缩放、相机旋转/任意锚点的精确投影，以及重叠目标不会被移位，并输出 map/area/battle 三组截图。必须检查实际可见性，不能仅用 Lua visible 标记代替。此检查不进入 Play。基础战斗规则仍用 `battle_hud_core.lua`。

- 本次 UX 的增量迁移入口为 `Project Y/UI/应用 UX 布局`，通过 Unity MCP 调用 [UXLayoutAssets](../../Assets/GameFramework/Editor/UXLayoutAssets.cs)，保存现有 Prefab、LuaReference 和 View 提示，不进入 Play。

- 最小圆环检查：`Project Y/UI/验证脚下 HP AP 圆环` 在已有 Editor 的 Edit Mode / PreviewScene 中验证已保存绑定、真实 HudHealth Lua 刷新/隐藏/重开、HP/AP 比例、双挂点、相机旋转/缩放/渐隐、死亡保留与受伤缓降，并覆盖 1/3/6/7 个状态的外弧排列、朝向、溢出及 HP 间距；还在相同场景下对比不透明遮挡物开启前后的圆环像素，确认真实深度遮挡，输出带状态图标的 `Docs/Previews/GroundHealth-WorldSpace.png`。不进入 Play。

## 关键入口

- [地点标签](../../Assets/GameFramework/Samples/Adventure/WorldSiteView.cs) / [接入与生命周期](../../Assets/GameFramework/Samples/Adventure/WorldSitePresentation.cs) / [完整占地与拾取](../../Assets/GameFramework/Samples/Adventure/WorldSiteLayout.cs) / [地块抬升与轮廓](../../Assets/GameFramework/Samples/Map/MapPreviewFocus.cs)。[资源同步](../../Assets/GameFramework/Editor/WorldSiteUIAssets.cs) 的 `Project Y/UI/同步大地图地点标签与遮罩` 保存 `Resources/UI/WorldSiteOverlay` 与 `SceneFocusMask` Prefab 和显式绑定；[定向检查](../../Tools/Tests/world_sites_editmode.cs) 经 MCP 在 Edit Mode 临时 PreviewScene 检查近远景、占地、拾取、实际遮罩像素及退出恢复，不进入 Play。

- [共享交互查询](../../Lua/Game/Adventure/InteractionPrompt.lua) / [交互 Widget](../../Lua/UI/Widget/HudInteraction.lua) / [场景位置桥接](../../Assets/GameFramework/Samples/Adventure/InteractionPromptBridge.cs) / [永久资源同步](../../Assets/GameFramework/Editor/InteractionPromptAssets.cs)；最小逻辑检查 [interaction_prompt_core.lua](../../Tools/Tests/interaction_prompt_core.lua)。

- [MainHudModel.lua](../../Lua/Game/Adventure/MainHudModel.lua) / [MainHudCtr.lua](../../Lua/UI/Panel/MainHudCtr.lua)：投影与 UI 生命周期。
- [CharacterSkills.lua](../../Lua/Game/Adventure/CharacterSkills.lua) / [CharacterSkill.lua](../../Lua/UI/Widget/CharacterSkill.lua) / [技能栏检查](../../Tools/Tests/character_skills_core.lua)：技能上下文、所有权、效果适配与角色技能栏。
- [MainHudView.cs](../../Assets/GameFramework/Runtime/UI/MainHudView.cs) / [UIFollower.cs](../../Assets/GameFramework/Runtime/UI/UIFollower.cs)：布局、相机投影、缩放与隐藏。
- [MainHudAssets.cs](../../Assets/GameFramework/Editor/MainHudAssets.cs) / [MainHudValidation.cs](../../Assets/GameFramework/Editor/MainHudValidation.cs)：资源和最小验证。
- [BattleFeedbackSystem.cs](../../Assets/GameFramework/Runtime/UI/BattleFeedbackSystem.cs) / [BattleFeedback.lua](../../Lua/Game/Battle/BattleFeedback.lua)：战斗反馈调度；[HealthBarAnimation.cs](../../Assets/GameFramework/Runtime/UI/HealthBarAnimation.cs)：双层协程；[BattleFeedbackAssets.cs](../../Assets/GameFramework/Editor/BattleFeedbackAssets.cs)：资源绑定。
- [DamageNumberAnimation.cs](../../Assets/GameFramework/Runtime/UI/DamageNumberAnimation.cs) / [DamageNumberPopup.cs](../../Assets/GameFramework/Runtime/UI/DamageNumberPopup.cs) / [DamageNumberGlow.cs](../../Assets/GameFramework/Runtime/UI/DamageNumberGlow.cs)：数字池、动效与描边辉光；[DamageNumberValidation.cs](../../Assets/GameFramework/Editor/DamageNumberValidation.cs)：定向检查与预览。
- [main_hud_integration.lua](../../Tools/Tests/main_hud_integration.lua) / [动作设计](../../Docs/CharacterAnimationPlan.md)。

- [圆环网格](../../Assets/GameFramework/Runtime/UI/HealthRingMesh.cs) / [弧形文字](../../Assets/GameFramework/Runtime/UI/ArcText.cs) / [资源同步](../../Assets/GameFramework/Editor/GroundHealthAssets.cs) / [定向验证](../../Assets/GameFramework/Editor/GroundHealthValidation.cs) / [Lua 绑定验证](../../Tools/Tests/hud_health_rings.lua)。
