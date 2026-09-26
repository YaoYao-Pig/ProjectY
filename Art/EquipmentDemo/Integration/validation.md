# 装备 Demo 检查记录

## 2026-09-25：近战武器与外置引线

- 本轮主动请求一次集中 C# 编译，随后运行 XLua/Generate Code 生成绑定；未修改后反复主动编译。Unity 最终无 error。编辑器提示 LayoutElement 缺 EmmyLua 专用类型适配而使用 Component，仅影响生成注释。
- 新增七个 FBX（六把剑、一个推进器），已完成 Blender 源保存、导出、Unity 轴向/单位/材质核对、八把武器 Prefab 与资源目录同步。19 个装备资源中本轮七个使用项目共享纯色材质。
- 新增近战集成 5 项通过：三类两档、软门槛与特质、推进器兼容/库存往返、实际伤害/AP/动作/CD、分类与空槽 UI。旧装备集成 6 项通过，包含宝箱领取推进器。
- 旧装备集成首次受工作区地牢代码与生成配置不同步影响；重新导表并定向导入配置后通过。基础 adventure_core 首次遇到并行开发的 MapDressing 不存在 cell.index；再次检查时该代码已被并行修改修正，本轮未覆盖它；复跑 5 项全通过。battle_hud_core 3 项通过。
- 工坊四比例：1280×720、1024×768、2560×1080、720×1280；均已实际渲染并查看，验证标签在预览区内、引线起点对应挂点。另查看巨剑装卸推进器对比、单手剑无槽、三类持握与短动作静态帧。连续应用角色快照不重复生成网格，关闭工坊后预览相机数为 0。
- 截图方法体：`Scripts/capture_melee_workbench.cs`、`Scripts/capture_melee_pawns.cs`；通过 Unity MCP execute_code 在独立 PreviewScene 执行，不属于 Assets 编译目录。相关截图为 `Previews/workbench-leaders-*.png`、`workbench-colossal-*.png`、`melee-pawns-*.png`、`melee-kit.png`。
- 本轮未进入 Play、未完整构建，鼠标拖动/按键及实际战斗连续动画的 Play 人工验收未执行；短动作只验证编辑模式静态帧。

## 前版：法杖、步枪与装备工坊

- 主动 C# 编译两次：首次集中编译，以及用户批准的预览释放修正编译；对应 xLua 绑定均通过菜单生成。最终 Console 无 error。
- Equipment Edit Mode 集成：6 项通过，使用真实 C# 库存/角色/弹匣/地图状态与实际 UI Panel/Widget。
- 地牢战斗集成：5 项通过；BattleHUD 集成：4 项通过。
- Lua 最小回归：adventure_core 5 项、battle_hud_core 3 项、adventure_snapshot 5 项、adventure_lifecycle 6 项通过。部分老夹具补充了新增的 Equipment 依赖。
- 工坊真实 Unity 渲染：1280×720、1024×768、2560×1080、720×1280；基础法杖、安装符文、步枪视图已人工查看。关闭后预览相机残留数 0。
- 资源：12 个 FBX 导入并映射项目材质，Staff/Rifle 武器 Prefab、EquipmentAssetCatalog、两个框架 UI Prefab、PawnRig/AdventureDemo 的引用已保存。
- 后续检测到已有会话进入 Play，仅只读查询：Adventure 为 area、装备库存含两把武器，Console 无 error。未主动开启 Play，未操作该会话的背包或角色；实际鼠标拖动、按键与人物短动作的 Play 验收未执行。人物独立静态截图也因保留该 Play 会话未执行。
- 可复用检查片段：Tools/Tests/equipment_editmode.cs；截图片段：Art/EquipmentDemo/Scripts/capture_workbench.cs、capture_equipped_pawns.cs。它们是 Unity MCP execute_code 的方法体，不属于 Unity 编译目录。
