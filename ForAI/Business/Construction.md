# 巧匠营造与战斗地形
关键词：巧匠、营造、栅栏、木墙、踏台、高台、铲子、浅坑、壕沟、材料、Construction、技能图谱。

## 文档目录
正文：技能与消费 / 地形与生命周期 / 表现与验证；关键入口：配表 / 规则 / 状态 / 资源。

## 正文

- [技艺图谱](Progression.md)按一级领域和二级技法收录主动技能，营造下分筑障、架设、土工与拆除。`SkillAtlasTable` 的前置关系同时约束真实研习候选；巧匠属性已开放 `skillDirection`。
- 技能 301–306 为简易栅栏、木墙、简易踏台、射击高台、挖掘浅坑、开挖壕沟；307 为全员通用的破坏工事。施工走战斗地格技能入口，原地 MapArea 战场支持；旧独立棋盘没有持久场地，明确拒绝施工。
- `ConstructionTable` 配置耐久及巧匠系数、相对高度、移动附加距离、高处射程、阻挡、材料、工具和可挖地表。六种施工技能为战斗用途；破坏工事额外支持探索，每次消耗配表的世界回合数，避免遗留工事阻断后无法清理。
- 材料 81–83 为营造木料、麻绳、铁件，使用已有共享网格背包的 `material` 堆叠；由勘探工具箱提供，角色存档允许此类型。施工先校验占格、射程、视线、材料与装备工具，再提交。配置只读数组必须复制成实体 Lua 数组后跨 xLua 传入，否则 C# 数组可能为空。
- `ConstructionData` 是唯一可变状态，持有地点、格子、技能与耐久；`EquipmentData.ConsumeMaterials` 在完整验证后统一扣料和释放空堆叠占格。Lua 缓存仅引用 C# 记录并按 Revision 失效，不维护第二份耐久或库存。
- 地点内的工事、坑沟在战后与离开重进时保留；新远征清空。与既有角色存档一致，不保存地图改造到磁盘。静态 `MapAreaLayout` 不变，`ConstructionTerrain` 提供稳定格子身份的动态只读投影，供探索与战斗共用。
- 静态地格字段（索引、坐标、邻接等）直接读取原布局，不查询工事。`Construction:Records(site)` 按 C# Revision 刷新既有记录引用缓存；探索每次同步规划使用 `NavigationView()`，当前地点无工事时直接使用静态布局，有工事时仅对访问格生成局部查询视图。查询不持久保存；下一命令重新检查版本，常规动态投影仍立即反映增删和高度变化。
- 栅栏阻挡移动但不阻挡射线；木墙同时阻挡射线。双方通过破坏工事行动造成结构伤害；敌方寻路被封死时会接近可达工事并攻击。入口、出口、上层格、单位、临时障碍、陈设及未取走的可见战利品格不能施工。
- 高台抬高原单格站立面，仍为 layer 0，不创建桥下通路或通用多层战斗；上下有移动附加距离，高台上的远程攻击对低处目标获得配置射程。拆毁恢复原格高度和通行；多格坐骑不能跨不同高度的改造地面站立。
- 坑沟要求施术者实际装备 `shovel` 标签武器；仅配表的泥土/草地表面可挖，铺装与岩地拒绝。进入坑沟增加移动距离，显示地面和棋子站位同步降低；坑沟不是可攻击的结构。
- `MapAreaViewData` 从只读快照更新显示地面、站立高度、格角与阻挡；模型走 `ConstructionAssetCatalog` 的直接 Prefab 引用。`PawnMotion` 以相同施工移动代价求显示路径，并在站立面消失时同步同格棋子高度；探索网格按施工 Revision 更新。
- Blender 源与导出在 `Art/Construction/`，Unity 模型/材质在 `Assets/DynamicAsset/Construction/`；仅同步这些资源与材料图标，保留原场景和其他装备资源。
- 定向检查：`python -B Tools/Tests/run_lua.py Tools/Tests/construction_core.lua`。真实数据通过 Unity MCP 执行 `Tools/Construction/run_gameplay_checks.cs`，显示边界执行 `terrain_view_checks.cs`，模型预览执行 `preview_models.cs`；使用独立 Edit Mode 数据/PreviewScene，不进入 Play。它们不是全量测试授权。

## 关键入口

- [ConstructionTable](../../Config/Tables/Progression/ConstructionTable.json) / [Construction.lua](../../Lua/Game/Battle/Construction.lua)：规则、材料、施工、拆除与显示快照。
- [ConstructionData.cs](../../Assets/GameFramework/Runtime/Data/ConstructionData.cs)：记录、结构伤害与材料提交。
- [ConstructionTerrain.lua](../../Lua/Game/MapArea/ConstructionTerrain.lua) / [BattleBoard.lua](../../Lua/Game/Battle/BattleBoard.lua)：动态投影与带移动代价的路径。
- [ConstructionAssets.cs](../../Assets/GameFramework/Editor/ConstructionAssets.cs) / [ConstructionRenderer.cs](../../Assets/GameFramework/Samples/Adventure/ConstructionRenderer.cs)：导入、资源绑定与场景模型。
- [建模脚本](../../Art/Construction/Scripts/build_construction.py) / [Blender 源](../../Art/Construction/Source/Construction.blend) / [Unity 资源预览](../../Docs/Previews/SkillAtlas/construction-models.png)。
- [算法检查](../../Tools/Tests/construction_core.lua) / [真实状态检查](../../Tools/Tests/construction_integration.lua) / [显示检查](../../Tools/Construction/terrain_view_checks.cs)。
