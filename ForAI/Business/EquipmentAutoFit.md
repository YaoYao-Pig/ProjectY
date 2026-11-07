# 角色穿戴物自动贴合
关键词：装备贴合、自动适配、头盔、护甲、背饰、裤靴、包络、PawnEquipmentAutoFit。

## 文档目录
正文：设计与实现 / 生命周期 / 验证边界；关键入口：运行时 / 预览 / 检查。

## 正文

- `PawnCustomizationView.CreateFit` 先按种族、体型选原 `GearFit`，再在共同绑定姿势下生成角色专用的网格副本。身体、原装备网格、骨骼与权重均不改写；原动画继续驱动新网格。
- 换脸、换体型通过原 `Revision → PawnEquipmentView.SetCustomization` 链路重建穿戴；换装时只计算新穿戴物。不逐帧计算，不改变战斗数据、装备实例或存档。

| 部位 | 本轮规则 |
| --- | --- |
| 头饰 | 从头型提取头顶包络，排除鼻子、外侧耳尖和高角；按帽体支撑截面调整宽度和深度，保留高度与长冠轮廓。沿用头饰隐藏头发的规则。 |
| 胸甲、衣袍 | 沿高度采样身体和装备截面，连续调整躯干宽深并留余量；袖子保持已有体型对应的骨骼贴合。 |
| 背饰 | 按躯干背面调整整体前后间距，保留披风/箭袋内部形状。 |
| 裤靴 | 在主权重骨骼的局部空间中，仅扩张可能挤入身体的径向包络，保留长度。 |
| 手持物、戒指 | 沿用已有挂点与[持握契约](EquipmentMotion.md)，不进入此网格适配路径。 |

- 余量和比例限值由 `PawnEquipmentAutoFit` 统一维护。当前是换装时的几何适配，没有布料模拟；特殊装饰、开口与极端体型仍需视觉验收。
- 新 Mesh 由 `PawnAutoFitMeshOwner` 持有。`WeaponModelView.Remove` 显式释放，`OnDestroy` 提供销毁保障，编辑态也启用。没有变形时复用原 Mesh，不销毁共享资源。
- [角色工坊](../Tools/CharacterPreview.md)从 Unity 导出实际适配结果：头饰按头部 ID、其余穿戴按体型 ID 生成预览变体。当前 132 个预览记录来自原 42 套资源，浏览器选择对应结果，不重新近似计算。
- 独立武器预览夹具补齐真实 `ProfessionExploration.OnEquip` 依赖，并按配置属性要求培养展示角色；仍调用真实 `CanEquip` 和装备命令，不生成世界、不修改玩家角色。
- 已检查四种头型（旧头、新男脸、新女脸、哥布林女脸）×六种穿戴共 24 组，其中 16 组产生新网格，均核对释放、拓扑/权重和原网格不变。[左原款／右自动贴合](../../Art/HeadSculptExpansion202610/Previews/unity-autofit-before-after.png)为实际 Unity 渲染。未进入 Play，未覆盖所有动画下的穿模情况。

## 关键入口

- [适配计算](../../Assets/GameFramework/Samples/Adventure/PawnEquipmentAutoFit.cs) / [网格所有权](../../Assets/GameFramework/Samples/Adventure/PawnAutoFitMeshOwner.cs) / [创建穿戴](../../Assets/GameFramework/Samples/Adventure/PawnCustomizationView.cs) / [统一移除](../../Assets/GameFramework/Samples/Adventure/WeaponModelView.cs)。
- [源资源选择](../../Assets/GameFramework/Samples/Adventure/PawnCustomizationCatalog.cs) / [原贴合资源](../../Assets/GameFramework/Editor/PawnGearFitAssets.cs)：继续负责种族、体型、遮挡与发型覆盖。
- [最小集成检查](../../Tools/Tests/head_sculpt_integration.cs) / [实际对照](../../Tools/Tests/equipment_autofit_preview.cs) / [结果](../../Art/HeadSculptExpansion202610/Integration/unity-validation.json)：经 Unity MCP 在独立 Edit Mode PreviewScene 执行。
- [网页导出](../../Assets/GameFramework/Editor/PawnCustomizationAssets.cs) `ExportFittedParts` / [独立装备夹具](../../Tools/CharacterPreview/export_equipment.lua)。
