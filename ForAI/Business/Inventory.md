# 网格背包与角色装备

关键词：Inventory、网格背包、矩形占位、拖拽、旋转、收纳、满包、头盔、身体甲、双戒指、裤子、鞋子、副手、双持、盾牌、角色预览、模型图标、导出管线。

## 文档目录

正文：入口与交互 / 状态与事务 / 配置与边界 / 生成与验证；关键入口：数据、命令、视图和测试。

## 正文

- 装备预览右上角“身体健康”切换到六部位健康图，查看创伤、属性影响并消耗医疗物资治疗，规则与界面同步见[身体健康与创伤](BodyInjuries.md)。

- 远征探索阶段按 `I` 或侧栏“背包与装备”打开 Inventory Panel。全队共享一个网格，每位角色独立穿戴头部、身体甲、左右戒指、裤子、鞋子，另有主手、副手，共八个装备槽。工坊由背包右下按钮进入，规则见[装备与改装](Equipment.md)。
- 拖动物品移动，物品图标按抓取位置跟随鼠标，浮在网格裁剪区域之外且不拦截指针；松手、取消或关窗时清除。拖动中 `R` 围绕抓取点旋转 90°、右键取消；绿色/红色表示落点是否合法。背包与搜刮共用此拖拽表现。可在装备槽与背包之间拖动，也可选中后穿戴、卸下或原地旋转。戒指默认使用空左槽，否则右槽；拖到指定戒指槽可明确选择。失败时保持原位置与装备关系。背包使用框架模态输入、暂停租约及缓存生命周期。
- `AdventureData.Equipment` 持有所有权和物品数量；`EquipmentData.Grid` 唯一保存背包矩形位置。键 `w/m/g + 实例 ID` 区分武器、实体弹匣、防具；`s + 物品 ID` 保留每种物品的主堆身份，`p + 独立堆 ID` 标识额外堆；同类组件、弹药、材料和消耗品可同时有多堆。Lua通过 `InventoryStacks.Key(row)` 读取各堆稳定键，Count为该堆数量、CountItem为同类总数。穿戴和已装入武器的组件不单独占格；敌人实际装备也在同一 ID 空间中，仅按 Grid/当前队员过滤展示。目前没有堆叠上限、按数量拆分按钮、嵌套容器或负重；耐久、永久损伤与“维修”按钮规则见[装备](Equipment.md)，角色与共享背包可通过[角色存档](CharacterSave.md)手动保存/读取。
- 手动拖放按实际落点决定：空白合法矩形另放一堆，指针覆盖另一同类堆时才合并；拖自身仍是移动，不吸附到背包中第一堆同类物品。背包内部也可合并同类堆。预览与松手共用放置判定，碰撞/越界红框只取消，不提交可能被舍入成合并点的坐标。普通奖励/购买仍自动并入已有活堆；消耗、填弹、营造、维修和装配按主堆优先、独立堆ID递增耗用，返回配件优先并入现存活堆。
- 网格移动、穿戴替换、符文/弹匣交换先规划再提交。替换优先利用来源空出的矩形，放不下旧物品则整体拒绝；[搜刮窗口](Loot.md)共用拖拽宿主，通过 `IInventoryGridTarget` 提供右侧落点预览，支持左右双向转移和容器内整理，单次失败不改变库存。场景容器接收完整物品实例及已装配件，不通过重新发放重置物品。普通奖励仍检查整组容量。战斗换弹复用容量检查并保留旧弹匣余弹，探索外禁止背包整理。
- EquipmentItemTable 配未旋转的 width/height；EquipmentDemoTable 配 bagWidth/bagHeight 和初始物品，目前 12×10。EquipmentWearableTable 配兼容槽和属性加成；`ring` 同时兼容左右戒指。CombatStats.Get 叠加已穿戴装备属性；穿脱后调用角色原有 SetMaxHP 契约保留已受伤害，倒地不复活。防具通过 mount/position/rotation 配置挂点和偏移；新增戒指、裤子、鞋子模型的源文件为 Art/EquipmentDemo/Source/InventoryWearables.blend。
- `EquipmentSystem.OnInit` 配置空背包尺寸及物品占格/词缀定义，使开始菜单首次读档能直接校验；此阶段不发放物品、不创建队伍或世界。`Start` 仍按新游戏配方重新配置空网格并发放初始物品。`inventory_core.lua` 覆盖空会话初始化；真实读档边界由[多档服务检查](../../Tools/Tests/campaign_slots_integration.lua)的独立空背包用例覆盖。
- [旅行火炬](MapPresentation.md)沿用非装备堆叠，占共享背包而不占手部；背包详情说明用途和 `T` 开关。照明可用性读取背包实物数量，不把仓库或场景容器中的火炬算作随身物品。
- EquipmentWeaponTable.hands 决定单手/双手；单手剑可放主手或副手，双手武器要求副手为空，冲突时提示先卸下。副手武器和盾牌共用 offhand 槽，交换同样受背包容量事务保护。EquipmentWeaponData.Hand 明确 weapon/offhand，Equipped 仅查主手、Offhand 查副手；回包时清空 Hand。副手攻击从 offhandSkillId 授予，使用副手自身倍率/属性门槛/组件；当前为 2 AP 次要动作、70% 技能倍率，不消耗主要动作。盾牌通过普通穿戴属性提供防御。
- 武器和防具的装配属性硬门槛、施法触媒与适配器专精规则见[装备](Equipment.md)。`InventoryModel.Rows` 的 `equipMask` 与实际穿戴命令共用 `EquipmentRules:CanEquip`，失败不修改所有权或背包；详情显示不计装备加成的当前值与需求。卸下、回包不要求属性达标，旧档已穿戴物可以正常取下。
- InventoryCharacterView 复用 PawnView/PawnEquipmentView 和真实装备快照，支持旋转/缩放，八个停靠槽以两段引线连接实际挂点。左右以角色自身为准：主手/右戒指连接角色右手（本地 +X），副手/左戒指连接角色左手（本地 -X）；正面预览时分别位于画面左侧、右侧。持握模板统一采用此方向，旋转预览时引线跟随实际手部。主角无装备时使用基础身体，不再保留模板假头盔/护甲/手持物；敌人的人形模板现通过[动作模组](EquipmentMotion.md)解析手持物，城镇 NPC 保持原模板。卸下主武器保留职业基础技能。模型预览、RenderTexture 和灯光随 Panel 隐藏释放；LuaReference 显式绑定 Character，部件资源按 ID/路径验证。
- EquipmentItemTable.iconMode 为 model/file/none：model 通过 assetId 解析 EquipmentAssetTable.prefabPath，以 iconRotation/iconPadding 按占格宽高比渲染长边 512 像素透明 PNG 到 iconPath 并导入为 Sprite。取景使用实际网格顶点的投影范围，竖长武器额外优化屏幕内转角以填满占格，避免模型包围盒与横放姿态造成大量透明留白；预览使用专用无后处理相机。file 保留手工图片，none 必须空路径。图标是离线产物，运行时不截图。导出使用独立 PreviewScene，保持已有图标 GUID，保存资源目录引用；不重建武器挂点 Prefab。
- InventoryModel 只产生显示快照并路由规则；InventoryPanelView 只布局、复用序列化 tile 模板、处理指针和落点预览，无权修改库存。Layout.GridSize 决定网格显示空间（普通背包默认 504×420，搜刮界面单独配置）；窄物品格优先显示图标，完整名称在选择后的详情中显示。Lua 通过 LuaReference 的 Inventory、按钮及文本键访问组件。视图快照的数值与 bool 必须始终显式存在，不依赖 nil 转默认值。
- 背包与搜刮物品快照同时提供纯文本 `name` 和必填 UI 富文本 `displayName`；C# 网格和拖拽标签读取后者。未搜索物品不显示品质色或名称。装备详情按属性、品质效果、耐久和要求分组，修正/不满足要求使用颜色和文字共同说明；`ItemDetail` 已重挂到持久化滚动容器，切换选中物品时通过既有文本引用回到顶部。配色和样式同步入口见[装备品质](Equipment.md)。
- `Repair/RepairText` 已在实际 Inventory Prefab 持久绑定，生成的 View 提示同步导出。`InventoryAssets.Sync()` 末尾也调用 `EquipmentRepairAssets.Sync()`，重建/升级背包时一并补齐维修入口；定向菜单为 `Project Y/装备/同步耐久维修按钮`，只在 Edit Mode 执行。2026-10-14 经现有 Unity 菜单同步及绑定类型检查通过，本次未进入 Play。
- 首次接入顺序：导表 → 集中编译 C# → `XLua/Generate Code` 并等待生成代码编译 → Edit Mode 菜单 `Project Y/装备/导出物品模型图标并同步背包`。它导入模型、映射材质、导出图标后调用背包同步，补齐八槽/3D 预览和 LuaReference，导出 View 提示。已有 2D 背包首次定向升级，升级后不重复重排；单独重导图标用 `仅导出物品模型图标`，仅同步界面用 `同步背包界面`。不手改生成绑定或 Prefab YAML。编译/Editor 操作仍遵守用户当前授权。
- 最小离线检查：`python Tools/Tests/run_lua.py Tools/Tests/inventory_core.lua` 检查真实配表属性、双戒指槽、快照类型和命令边界；`inventory_equipment_core.lua` 检查双手互斥、副手技能倍率、真实外观快照及模型文件。`inventory_integration.lua` 在真实 C# 数据和实际 Panel 上检查碰撞/旋转、满包事务、换弹、搜刮、副手盾剑互换、次要攻击结算和预览暂停释放；可复用 `equipment_editmode.cs` 注入方式，将测试路径替换为该文件。后者需完成编译/绑定/Prefab 同步，不能把离线检查当作 Unity 验收。

## 关键入口

- [EquipmentData.cs](../../Assets/GameFramework/Runtime/Data/EquipmentData.cs) / [InventoryGridData.cs](../../Assets/GameFramework/Runtime/Data/InventoryGridData.cs)：权威数量、所有权和位置事务。
- [InventoryModel.lua](../../Lua/Game/Equipment/InventoryModel.lua) / [EquipmentSystem.lua](../../Lua/Game/Equipment/EquipmentSystem.lua)：背包命令、装备类型和奖励容量检查。
- [InventoryCtr.lua](../../Lua/UI/Panel/InventoryCtr.lua) / [InventoryPanelView.cs](../../Assets/GameFramework/Runtime/UI/InventoryPanelView.cs) / [InventoryItemView.cs](../../Assets/GameFramework/Runtime/UI/InventoryItemView.cs)：Panel 生命周期及拖拽表现。
- [InventoryCharacterView.cs](../../Assets/GameFramework/Runtime/UI/InventoryCharacterView.cs) / [EquipmentIconExporter.cs](../../Assets/GameFramework/Editor/EquipmentIconExporter.cs)：共享角色预览与模型图标导出。
- [InventoryAssets.cs](../../Assets/GameFramework/Editor/InventoryAssets.cs)：永久界面生成与绑定入口；[EquipmentWearableTable.json](../../Config/Tables/Equipment/EquipmentWearableTable.json)：防具配置。
- [离线检查](../../Tools/Tests/inventory_core.lua) / [副手与外观检查](../../Tools/Tests/inventory_equipment_core.lua) / [Unity 最小集成检查](../../Tools/Tests/inventory_integration.lua) / [现有 Edit Mode 宿主](../../Tools/Tests/equipment_editmode.cs)。

- [独立堆桥接与消费规则](../../Assets/GameFramework/Runtime/Data/InventoryStacks.cs)；定向检查 `inventory_stack_ui.lua`（Lua投影/转发）与 `inventory_stacks_data.ps1 -AssemblyPath Library/ScriptAssemblies/Assembly-CSharp.dll`（已编译真实Data，不编译、不读取用户存档）。
