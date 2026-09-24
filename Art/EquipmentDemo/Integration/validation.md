# 装备 Demo 检查记录

- 主动 C# 编译两次：首次集中编译，以及用户批准的预览释放修正编译；对应 xLua 绑定均通过菜单生成。最终 Console 无 error。
- Equipment Edit Mode 集成：6 项通过，使用真实 C# 库存/角色/弹匣/地图状态与实际 UI Panel/Widget。
- 地牢战斗集成：5 项通过；BattleHUD 集成：4 项通过。
- Lua 最小回归：adventure_core 5 项、battle_hud_core 3 项、adventure_snapshot 5 项、adventure_lifecycle 6 项通过。部分老夹具补充了新增的 Equipment 依赖。
- 工坊真实 Unity 渲染：1280×720、1024×768、2560×1080、720×1280；基础法杖、安装符文、步枪视图已人工查看。关闭后预览相机残留数 0。
- 资源：12 个 FBX 导入并映射项目材质，Staff/Rifle 武器 Prefab、EquipmentAssetCatalog、两个框架 UI Prefab、PawnRig/AdventureDemo 的引用已保存。
- 后续检测到已有会话进入 Play，仅只读查询：Adventure 为 area、装备库存含两把武器，Console 无 error。未主动开启 Play，未操作该会话的背包或角色；实际鼠标拖动、按键与人物短动作的 Play 验收未执行。人物独立静态截图也因保留该 Play 会话未执行。
- 可复用检查片段：Tools/Tests/equipment_editmode.cs；截图片段：Art/EquipmentDemo/Scripts/capture_workbench.cs、capture_equipped_pawns.cs。它们是 Unity MCP execute_code 的方法体，不属于 Unity 编译目录。
