# 战斗 HUD

关键词：BattleHUD、技能栏、悬停、选中、追踪多选、目标确认、取消、命中预览、拦截概率、友伤风险、战斗日志、富文本、LogOpen、LogToggle、物品槽、行动顺序、AP、图标、Sprite。

## 文档目录

正文：接入与所有权 / 配置与资源 / 布局与操作 / 验证；关键入口：控制器、视图、资源工具。

## 正文

- 弹药栏显示当前实体弹匣的实际弹种名称及余弹/容量，取自 `EquipmentAmmoTable`，不按弹匣默认弹种推测。弹种选择与装填在探索工坊完成，战斗继续按既有规则换备用弹匣，详见[装备与弹药](Equipment.md)。[ammunition_ui.lua](../../Tools/Tests/ammunition_ui.lua) 定向覆盖实际 HUD 投影、工坊选择和护甲日志，不替代 Play 视觉验收。

- 复用 [UI 框架](../Framework/UI.md)：`BattleHUD` 是 Main 层、非模态、缓存、不可 Back 关闭的 Panel；`BattleAction/BattleParty` 通过 `CreateWidget` 创建并随 Panel 释放；`BattleTurn` 模板由行动顺序列表复用，Cell 的创建、显示、回收、释放回调托管其控制器生命周期。组件均通过 Prefab 的 LuaReference 绑定。
- 远征流程由 [MainHud](MainHud.md) 持有嵌套的 BattleHUD Prefab 和 `BattleHUDContent` Widget；进入/离开 battle 显示/隐藏内容，复用原技能与回合命令。独立 `BattleHUD` Panel/Bridge 保留给定向检查，不与 MainHud 同时打开。原地战场及全视口相机保留，世界血条改为屏幕 UIFollower。
- 移动按钮显示本回合剩余距离；选择技能不改变角色移动状态，再点同一技能或按Esc取消选中，可回到尚未耗尽的移动预算。成功施放后或距离耗尽后显示“移动已结束”；取消/失败不扣距离，分段与AP契约见 [战斗](Battle.md)。
- `BattleHUDModel.Build` 只投影真实 BattleData/CombatActorData 和装备数据：生命、AP、防御、Guard、移动/主要行动额度、弹匣余弹、行动顺序及日志；读取 `BattleData.Phase` 显示战前部署，部署行动栏只显示当前与尚未部署的队员。技能列表和说明使用装备后的 `SkillIds/Skill`，可用性复用 `SkillBudget/CanUseSkill`，包含冷却和弹药不足原因；不维护业务状态副本。
- 多方颜色由 `Battle:PresentationTeam` 投影：玩家与盟军绿色、主敌红色、独立第三方黄色（即使敌对），动物保持黄色。行动条、健康条、场景圈与日志使用同一显示编号；控制权仍只认玩家 side 1，绿色盟军自动行动，黄色第三方的可攻击性由实际关系查询决定。`AdventureRuntimeDemo` 自动推进所有非玩家 side。
- 控制器的 `Battle.Changed` 订阅归 visibleScope，只标脏、下一 Tick 读取完整结果；显示选择状态来自 Demo 的 `BattleHUDRevision`。技能选择、移动、结束回合、自动/手动 AI 仍通过既有命令和权限检查。隐藏时释放订阅及工具提示；复用缓存不会重复绑定按钮。
- `CombatSkillTable.iconId` 引用 [BattleIconTable](../../Config/Tables/Adventure/BattleIconTable.json)。每行 `spritePath` 可为空；非空必须是 `Assets/...` 下已导入为 Sprite 的资源。`BattleHUDTable` 的四个物品槽显示 `ConsumableTable` 的真实数量、消耗与可用性；按钮通过 `use_item` 命令自用，空位不可操作。当前最多配置四种战斗消耗品；[装备背包和 3D 改装](Equipment.md)使用独立的探索阶段面板。
- 换图流程：编辑表 → `node Tools/ConfigEditor/exporter.mjs` → Edit Mode 菜单 `Project Y/UI/同步战斗图标引用`。资源工具把 Sprite 直接序列化到 BattleHUD Prefab，运行时按 ID/路径校验，不动态搜索或加载；空路径禁用 Icon Image，保留槽位边框与文字。Sprite 当前采用单 Sprite 资源路径，不按图集子资源名解析。
- 生成式技能图标使用[技能图标管线](../Tools/SkillIcons.md)：逐技能配方、统一低细节像素风格、原图与版本追溯，发布后回填上述配置；`Project Y/UI/导入技能图标并同步引用` 先设置 Sprite 导入参数，再复用图标引用同步。
- 首次菜单 `Project Y/UI/创建战斗 HUD` 创建并注册四个 Prefab，同时导出 Lua View 提示；重复执行保留已有内容。可以直接编辑 `Assets/DynamicAsset/UI/Prefabs/Battle/` 的布局与样式；通用 PanelGenerator 不会重建其内容。
- 行动顺序通过 [UIScrollList](../Framework/UIScrollList.md) 横向展示完整存活单位队列，支持拖拽、滚轮及底部滚动条；不足一屏时自动隐藏滚动条。`TurnList` 绑定列表 LuaReference，`TurnTemplate` 绑定禁用的 BattleTurn 模板。普通状态刷新只重绑可见项，保留浏览位置；角色、回合、阶段切换及缓存重开回到队首。Edit Mode 菜单 `Project Y/UI/同步战斗行动顺序滚动栏` 升级已有 Prefab 和导出绑定。最小回归为 `python Tools/Tests/run_lua.py Tools/Tests/battle_turn_scroll.lua`，涵盖完整队列、复用点击、位置保留及重开；通用滚动与尺寸检查见 UIScrollList。
- `BattleHUDView` 负责安全区域、布局、字体、图标及日志滚动。沿用 UIRoot 的 1280×720 / match 0.5；左下两排技能/道具，四格技能分页；部署时显示职业准备技能和“结束部署”，关闭自动AI切换。顶部从当前角色开始的横向行动顺序列表；回合命令、自动行动与日志开关共用底部操作区，展开日志位于操作区与行动条之间。嵌入 MainHud 时由宿主通过 `SetRightInset` 为右侧栏及打开的菜单预留宽度；独立 Panel 不预留。可用宽高不足时统一缩放战斗控件，禁止为日志高度回退到底部覆盖操作区。可用宽度低于 1050 或底部剩余日志宽度不足 320 时隐藏紧凑日志，仍可手动展开；字体优先用 Prefab 的 preferredFont。HP/AP 与状态图标由 [MainHud 的 HudHealth](MainHud.md) 展示。
- 战斗日志由 `BattleLog.Format` 根据结算元数据生成已转义富文本，用色号与字号区分角色、动作、目标、结果、生命分数、防御／护卫及实际概率判定；UI 不通过正则解析日志含义，也不为显示掷骰。`BattleData.AddLog` 保留最多 80 条，`BattleHUDModel.logs` 按旧到新投影全部记录。紧凑卡片只显示最后 3 条；点击 `LogOpen` 或 `LogToggle` 展开完整记录，`LogClose` 或再次点击 `LogToggle` 收起，缓存重开恢复紧凑状态。探索 MainHud 的经历摘要仍属于独立的 Chronicle 投影。
- `BattleLogPresentation.Set` 反射桥将格式化文本交给原生 View。`Logs` 是启用 rich text、14 号基础字号、自动换行及 ContentSizeFitter 的 Text，位于绑定的 `LogScroll` 内；Viewport、Mask、Scrollbar 及 `LogOpen/LogClose/LogTitle` 均持久序列化。展开默认定位最新记录；读者停在底部时跟随新增记录，向上翻阅时保留滚动偏移，不拉回底部。`Project Y/UI/同步战斗日志展开界面`（`BattleHUDAssets.SyncLogExpansion`）仅升级已有 BattleHUD Prefab 并导出绑定；本轮已保存迁移，MainHud 内嵌 BattleHUD 继承同一绑定。
- 数字键1–4选择当前页技能；通常Enter结束己方回合，Esc取消技能并切回仍可用的移动模式，F定位战场。追踪多选期间，结束回合按钮改为“确认释放 已选/上限”，Enter同样只确认施放；移动按钮改为取消，Esc或再次点击当前技能清空选择。点击敌人切换入选，允许1至上限个不同目标，空列表不可确认；不自动补选。选择列表归Demo的临时表现状态，切换角色/回合/阶段、技能失效或离开战斗时清理，确认才向规则提交整组目标，不提前扣AP/弹药/CD。
- 悬停目标使用规则快照中的 `targetPreviews` 展示实际目标命中率、拦截概率、遮挡数与友军风险，不能把“路径有遮挡”显示成必定不可攻击，也不能把追踪显示成必中。提示只读，不掷骰；没有额外的友伤确认弹窗。多选目标高亮保留，悬停明细与当前选择数量在既有Hint/Tooltip中显示；普通单目标仍点击即提交，转施后的any法术等待选择自己/队友/敌人。伤害及拦截契约见 [战斗](Battle.md)。
- 技能说明使用[结构化技能 Tips](SkillTips.md)：彩色标签、统一参数、TMP 术语导航及发现式协同遮罩；目标命中预览仍使用原 Tooltip。
- 技能超过四个时分页，可悬停说明；头顶 GameEffect 的悬停由 MainHud 负责。不可用技能展示 AP、行动额度或目标原因；道具点击直接自用，满血治疗、AP不足与库存不足显示明确原因，道具无需数字快捷键。
- `BattleAction` 复用原生 Button ColorTint 的 0.12 秒悬停/按压过渡；`UIPointerState` 继续提供禁用技能的原因提示。选中投影使用金棕底色、3 px 金框与顶部几何对勾，鼠标移出保持选中；数字快捷键与点击使用同一投影。不可用技能的文字/图标减淡，点击仍按真实 `row.available` 拒绝。只有存在性、可用性或选中状态变化才重写 ColorBlock，普通快照刷新不会重置悬停；隐藏清空视觉投影，缓存重开按当前选择恢复，Pointer 的 OnDisable 清除旧悬停。
- 新版反馈需在 Edit Mode 执行 `Project Y/UI/同步战斗技能悬停与选中反馈`（`BattleHUDAssets.SyncActionFeedback`）；只升级 `BattleActionWidget` 的既有 Button / Selected 结构，保留 LuaReference Key 和原有槽位布局。第一次创建 BattleAction 也应用相同样式；不需新增绑定或重新生成 xLua Wrapper。
- 最小检查：`python Tools/Tests/run_lua.py Tools/Tests/battle_hud_core.lua`；Edit Mode 菜单 `Project Y/UI/验证战斗 HUD` 使用独立 PreviewScene、真实 C# 战斗数据与实际 Panel/Widget，检查点击、资源刷新、回合权限、空图及缓存重开退订，不进入 Play。此检查的输入适配器只模拟 Demo 的选择状态，实际场景输入需在用户开启 Play 后验收。

## 关键入口

- [BattleHUDContent.lua](../../Lua/UI/Widget/BattleHUDContent.lua)：MainHud 内战斗内容；[BattleHUDCtr.lua](../../Lua/UI/Panel/BattleHUDCtr.lua) / [BattleHUDBridge.lua](../../Lua/UI/BattleHUDBridge.lua)：独立检查入口。
- [BattleHUDModel.lua](../../Lua/Game/Battle/BattleHUDModel.lua)：只读表现快照；规则仍见[战斗](Battle.md)。
- [BattleLog.lua](../../Lua/Game/Battle/BattleLog.lua)：结算事实的富文本格式器；[BattleLogPresentation.cs](../../Assets/GameFramework/Runtime/UI/BattleLogPresentation.cs) / `BattleHUDView.SetLog`：原生日志展开和滚动。最小检查 [battle_log_core.lua](../../Tools/Tests/battle_log_core.lua) 核对格式、转义和真实概率元数据，[battle_log_ui.lua](../../Tools/Tests/battle_log_ui.lua) 检查展开／收起、80 条全文、3 条摘要与缓存重开，均用 `python -B Tools/Tests/run_lua.py <测试路径>`。本轮离线 UI 检查及 [battle_log_editmode.cs](../../Tools/Tests/battle_log_editmode.cs) 原生检查已通过；后者覆盖真实 Prefab 绑定、滚动高度、翻阅保留、底部跟随、小屏展开和 Unity 富文本颜色，不要求进入 Play。
- [BattleTargetSelection.cs](../../Assets/GameFramework/Samples/Adventure/BattleTargetSelection.cs)：Demo临时多选、确认/取消与风险提示的反射桥；不保存战斗资源或复制目标合法性规则。[tracking_selection_editmode.cs](../../Tools/Tests/tracking_selection_editmode.cs)在隔离真实Demo上检查切换、去重、上限、快照失效及取消；实际资源事务由 [tracking_projectiles_integration.lua](../../Tools/Tests/tracking_projectiles_integration.lua)验证，均不要求进入Play。
- [BattleHUDView.cs](../../Assets/GameFramework/Runtime/UI/BattleHUDView.cs) / [UIPointerState.cs](../../Assets/GameFramework/Runtime/UI/UIPointerState.cs)：布局、图标与悬停。
- [hud_responsive_editmode.cs](../../Tools/Tests/hud_responsive_editmode.cs)：在空闲 Edit Mode 通过 Unity MCP 执行，使用真实 MainHud / BattleHUD Prefab 的隔离 PreviewScene，检查六种尺寸、菜单及日志开关共 24 组布局的边界与互不遮挡，以及缓存复用后释放菜单占用；不进入 Play、不改变用户 Game 视图。
- [BattleHUDAssets.cs](../../Assets/GameFramework/Editor/BattleHUDAssets.cs)：首次创建、LuaReference 绑定及图标同步；[BattleHUDTable.json](../../Config/Tables/Adventure/BattleHUDTable.json)：四个物品展示槽。
- [BattleHUDValidation.cs](../../Assets/GameFramework/Editor/BattleHUDValidation.cs) / [battle_hud_integration.lua](../../Tools/Tests/battle_hud_integration.lua)：定向 UI 桥接检查。
- [反馈最小检查](../../Tools/Tests/battle_action_feedback.lua)：`python Tools/Tests/run_lua.py Tools/Tests/battle_action_feedback.lua`，覆盖刷新保留、选择/移出、禁用点击、空槽和缓存重用；[原生 Edit Mode 片段](../../Tools/Tests/battle_action_feedback_editmode.cs)通过[真实 Widget 检查](../../Tools/Tests/battle_action_feedback_integration.lua)读取 CanvasRenderer 实际悬停/选中/禁用颜色并验证缓存重开、Pointer 清理和单次点击监听，不进入 Play。2026-10-16 已完成原生样式同步并通过该检查。独立 Edit Mode 克隆的 Pointer 启用 `runInEditMode` 以接收正常 Play 中的 OnDisable；不修改 Prefab 或组件的运行模式声明。
