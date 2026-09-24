# 战斗 HUD

关键词：BattleHUD、技能栏、物品槽、行动顺序、AP、战斗资源、自适应、图标、Sprite。

## 文档目录

正文：接入与所有权 / 配置与资源 / 布局与操作 / 验证；关键入口：控制器、视图、资源工具。

## 正文

- 复用 [UI 框架](../Framework/UI.md)：`BattleHUD` 是 Main 层、非模态、缓存、不可 Back 关闭的 Panel；`BattleAction/BattleParty/BattleTurn` 是独立 Widget，通过 `CreateWidget` 创建并随 Panel 释放。组件均通过 Prefab 的 LuaReference 绑定。
- `AdventureRuntimeDemo.SetView` 在进入/离开 battle 时调用 `UI.BattleHUDBridge` 打开/关闭；同场景保留原地战场，战斗相机使用全视口。UI 上的指针输入不会同时触发地格命令。世界棋子标签及旧事件棋盘仍由 Demo 绘制。
- `BattleHUDModel.Build` 只投影真实 BattleData/CombatActorData 和装备数据：生命、AP、防御、Guard、移动/主要行动额度、弹匣余弹、行动顺序及日志。技能列表和说明使用装备后的 `SkillIds/Skill`，可用性复用 `SkillBudget/CanUseSkill`，包含冷却和弹药不足原因；不维护业务状态副本。
- 控制器的 `Battle.Changed` 订阅归 visibleScope，只标脏、下一 Tick 读取完整结果；显示选择状态来自 Demo 的 `BattleHUDRevision`。技能选择、移动、结束回合、自动/手动 AI 仍通过既有命令和权限检查。隐藏时释放订阅及工具提示；复用缓存不会重复绑定按钮。
- `CombatSkillTable.iconId` 引用 [BattleIconTable](../../Config/Tables/Adventure/BattleIconTable.json)。每行 `spritePath` 可为空；非空必须是 `Assets/...` 下已导入为 Sprite 的资源。`BattleHUDTable` 的四个物品槽仍是不可操作的占位；[装备背包和 3D 改装](Equipment.md)使用独立的探索阶段面板。
- 换图流程：编辑表 → `node Tools/ConfigEditor/exporter.mjs` → Edit Mode 菜单 `Project Y/UI/同步战斗图标引用`。资源工具把 Sprite 直接序列化到 BattleHUD Prefab，运行时按 ID/路径校验，不动态搜索或加载；空路径禁用 Icon Image，保留槽位边框与文字。Sprite 当前采用单 Sprite 资源路径，不按图集子资源名解析。
- 首次菜单 `Project Y/UI/创建战斗 HUD` 创建并注册四个 Prefab，同时导出 Lua View 提示；重复执行保留已有内容。可以直接编辑 `Assets/DynamicAsset/UI/Prefabs/Battle/` 的布局与样式；通用 PanelGenerator 不会重建其内容。
- `BattleHUDView` 仅负责安全区域、布局、字体和图标。沿用 UIRoot 的 1280×720 / match 0.5；底栏最大宽 1232，逻辑宽度低于 1120 时技能/物品变两行，低于 900 时资源与命令上移。顶部行动顺序、左侧队伍、右侧可收起日志不拦截空白战场。字体优先用 Prefab 的 preferredFont，未指定时使用系统中文字体。
- 数字键 1–8 选择当前页技能，Enter 结束己方回合，Esc 切回可移动模式，F 定位战场；技能超过八个时分页。技能/物品槽可悬停说明，不可用技能展示 AP、行动额度或目标原因；物品槽不可操作。
- 最小检查：`python Tools/Tests/run_lua.py Tools/Tests/battle_hud_core.lua`；Edit Mode 菜单 `Project Y/UI/验证战斗 HUD` 使用独立 PreviewScene、真实 C# 战斗数据与实际 Panel/Widget，检查点击、资源刷新、回合权限、空图及缓存重开退订，不进入 Play。此检查的输入适配器只模拟 Demo 的选择状态，实际场景输入需在用户开启 Play 后验收。

## 关键入口

- [BattleHUDCtr.lua](../../Lua/UI/Panel/BattleHUDCtr.lua) / [BattleHUDBridge.lua](../../Lua/UI/BattleHUDBridge.lua)：框架接入与命令适配。
- [BattleHUDModel.lua](../../Lua/Game/Battle/BattleHUDModel.lua)：只读表现快照；规则仍见[战斗](Battle.md)。
- [BattleHUDView.cs](../../Assets/GameFramework/Runtime/UI/BattleHUDView.cs) / [UIPointerState.cs](../../Assets/GameFramework/Runtime/UI/UIPointerState.cs)：布局、图标与悬停。
- [BattleHUDAssets.cs](../../Assets/GameFramework/Editor/BattleHUDAssets.cs)：首次创建、LuaReference 绑定及图标同步；[BattleHUDTable.json](../../Config/Tables/Adventure/BattleHUDTable.json)：四个物品展示槽。
- [BattleHUDValidation.cs](../../Assets/GameFramework/Editor/BattleHUDValidation.cs) / [battle_hud_integration.lua](../../Tools/Tests/battle_hud_integration.lua)：定向 UI 桥接检查。
