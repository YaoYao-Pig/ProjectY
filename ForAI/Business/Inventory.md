# 网格背包与角色装备

关键词：Inventory、网格背包、矩形占位、拖拽、旋转、收纳、满包、头盔、身体甲、双戒指、裤子、鞋子、副手、双持、盾牌、角色预览、模型图标、导出管线。

## 文档目录

正文：入口与交互 / 状态与事务 / 配置与边界 / 生成与验证；关键入口：数据、命令、视图和测试。

## 正文

- 远征探索阶段按 `I` 或侧栏“背包与装备”打开 Inventory Panel。全队共享一个网格，每位角色独立穿戴头部、身体甲、左右戒指、裤子、鞋子，另有主手、副手，共八个装备槽。工坊由背包右下按钮进入，规则见[装备与改装](Equipment.md)。
- 拖动物品移动，拖动中 `R` 旋转 90°、右键取消；绿色/红色表示落点是否合法。可在装备槽与背包之间拖动，也可选中后穿戴、卸下或原地旋转。戒指默认使用空左槽，否则右槽；拖到指定戒指槽可明确选择。失败时保持原位置与装备关系。背包使用框架模态输入、暂停租约及缓存生命周期。
- `AdventureData.Equipment` 持有所有权和物品数量；`EquipmentData.Grid` 唯一保存背包矩形位置。键 `w/m/g + 实例 ID` 区分武器、实体弹匣、防具；`s + 物品 ID` 标识同类组件/弹药的一堆。穿戴和已装入武器的组件不单独占格；同类堆叠保留原有数量语义，首版没有堆叠上限/拆分、嵌套容器、负重、耐久或磁盘存档。
- 网格移动、穿戴替换、符文/弹匣交换先规划再提交。替换优先利用来源空出的矩形，放不下旧物品则整体拒绝；搜刮先检查整个奖励包，空间不足不授予任何物品、不标记已搜刮。战斗换弹复用同一容量检查并保留旧弹匣余弹，探索外禁止背包整理。
- EquipmentItemTable 配未旋转的 width/height；EquipmentDemoTable 配 bagWidth/bagHeight 和初始物品，目前 12×10。EquipmentWearableTable 配兼容槽和属性加成；`ring` 同时兼容左右戒指。CombatStats.Get 叠加已穿戴装备属性；穿脱后调用角色原有 SetMaxHP 契约保留已受伤害，倒地不复活。防具通过 mount/position/rotation 配置挂点和偏移；新增戒指、裤子、鞋子模型的源文件为 Art/EquipmentDemo/Source/InventoryWearables.blend。
- EquipmentWeaponTable.hands 决定单手/双手；单手剑可放主手或副手，双手武器要求副手为空，冲突时提示先卸下。副手武器和盾牌共用 offhand 槽，交换同样受背包容量事务保护。EquipmentWeaponData.Hand 明确 weapon/offhand，Equipped 仅查主手、Offhand 查副手；回包时清空 Hand。副手攻击从 offhandSkillId 授予，使用副手自身倍率/属性门槛/组件；当前为 2 AP 次要动作、70% 技能倍率，不消耗主要动作。盾牌通过普通穿戴属性提供防御。
- InventoryCharacterView 复用 PawnView/PawnEquipmentView 和真实装备快照，支持旋转/缩放，八个停靠槽以两段引线连接实际挂点。左右以角色自身为准：主手/右戒指连接角色右手（本地 +X），副手/左戒指连接角色左手（本地 -X）；正面预览时分别位于画面左侧、右侧。持握模板统一采用此方向，旋转预览时引线跟随实际手部。主角无装备时使用裸露核心与独立手臂，不再保留模板假头盔/护甲/手持物；敌人和 NPC 模板不受影响。卸下主武器保留职业基础技能。模型预览、RenderTexture 和灯光随 Panel 隐藏释放；LuaReference 显式绑定 Character，部件资源按 ID/路径验证。
- EquipmentItemTable.iconMode 为 model/file/none：model 通过 assetId 解析 EquipmentAssetTable.prefabPath，以 iconRotation/iconPadding 按占格宽高比渲染长边 512 像素透明 PNG 到 iconPath 并导入为 Sprite；file 保留手工图片，none 必须空路径。图标是离线产物，运行时不截图。导出使用独立 PreviewScene，保持已有图标 GUID，保存资源目录引用；不重建武器挂点 Prefab。
- InventoryModel 只产生显示快照并路由规则；InventoryPanelView 只布局、复用序列化 tile 模板、处理指针和落点预览，无权修改库存。Lua 通过 LuaReference 的 Inventory、按钮及文本键访问组件。视图快照的数值与 bool 必须始终显式存在，不依赖 nil 转默认值。
- 首次接入顺序：导表 → 集中编译 C# → `XLua/Generate Code` 并等待生成代码编译 → Edit Mode 菜单 `Project Y/装备/导出物品模型图标并同步背包`。它导入模型、映射材质、导出图标后调用背包同步，补齐八槽/3D 预览和 LuaReference，导出 View 提示。已有 2D 背包首次定向升级，升级后不重复重排；单独重导图标用 `仅导出物品模型图标`，仅同步界面用 `同步背包界面`。不手改生成绑定或 Prefab YAML。编译/Editor 操作仍遵守用户当前授权。
- 最小离线检查：`python Tools/Tests/run_lua.py Tools/Tests/inventory_core.lua` 检查真实配表属性、双戒指槽、快照类型和命令边界；`inventory_equipment_core.lua` 检查双手互斥、副手技能倍率、真实外观快照及模型文件。`inventory_integration.lua` 在真实 C# 数据和实际 Panel 上检查碰撞/旋转、满包事务、换弹、搜刮、副手盾剑互换、次要攻击结算和预览暂停释放；可复用 `equipment_editmode.cs` 注入方式，将测试路径替换为该文件。后者需完成编译/绑定/Prefab 同步，不能把离线检查当作 Unity 验收。

## 关键入口

- [EquipmentData.cs](../../Assets/GameFramework/Runtime/Data/EquipmentData.cs) / [InventoryGridData.cs](../../Assets/GameFramework/Runtime/Data/InventoryGridData.cs)：权威数量、所有权和位置事务。
- [InventoryModel.lua](../../Lua/Game/Equipment/InventoryModel.lua) / [EquipmentSystem.lua](../../Lua/Game/Equipment/EquipmentSystem.lua)：背包命令、装备类型和奖励容量检查。
- [InventoryCtr.lua](../../Lua/UI/Panel/InventoryCtr.lua) / [InventoryPanelView.cs](../../Assets/GameFramework/Runtime/UI/InventoryPanelView.cs) / [InventoryItemView.cs](../../Assets/GameFramework/Runtime/UI/InventoryItemView.cs)：Panel 生命周期及拖拽表现。
- [InventoryCharacterView.cs](../../Assets/GameFramework/Runtime/UI/InventoryCharacterView.cs) / [EquipmentIconExporter.cs](../../Assets/GameFramework/Editor/EquipmentIconExporter.cs)：共享角色预览与模型图标导出。
- [InventoryAssets.cs](../../Assets/GameFramework/Editor/InventoryAssets.cs)：永久界面生成与绑定入口；[EquipmentWearableTable.json](../../Config/Tables/Equipment/EquipmentWearableTable.json)：防具配置。
- [离线检查](../../Tools/Tests/inventory_core.lua) / [副手与外观检查](../../Tools/Tests/inventory_equipment_core.lua) / [Unity 最小集成检查](../../Tools/Tests/inventory_integration.lua) / [现有 Edit Mode 宿主](../../Tools/Tests/equipment_editmode.cs)。
