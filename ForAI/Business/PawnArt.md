# LowPoly 小队棋子资源

关键词：主角小队、战棋棋子、人物模型、圆形底座、模块化装备、武器、护甲、挂点、PawnLowPoly。

## 文档目录

正文：资源与装配契约 / 当前接入范围 / 验证；关键入口：模型 / 配置 / 预览。

## 正文

- 棋子延续[地图模型](MapArt.md)的硬边、纯色和低饱和调色板，以圆形底座、略大的头手和武器剪影体现桌面战棋。身体高约 1.78 米，底座直径 1.38 米；固定人物尺度，不随 MapArea 地格半径缩放。
- 源文件、脚本、暂存和预览位于 `Art/PawnLowPoly/`；Unity FBX 在 `Assets/DynamicAsset/PawnLowPoly/Models/`。16 个部件共用已有地图材质，四套装配 Prefab 为剑盾卫士、游侠弓手、法师、双手战士。战士用独立握持身体与双手剑；身体不合并装备，装备网格保留挂点局部原点，不能统一移到底部。当前均为固定棋子姿势，没有骨骼步行动画。
- Unity +Y 向上、+Z 为正面。身体/底座挂点为零；mainHand=(-0.5,0.98,0.28)、offHand=(0.5,0.98,0.28)、head=(0,1.59,0)、chest=(0,1.05,0)、back=(0,1.13,-0.2)。部件在挂点下使用零位移、零旋转和单位缩放；导出沿用经过验证的静态地图 FBX 预设与 bakeAxisConversion。
- `PawnPartTable` 配置部件路径和插槽；`PawnTemplateTable.unitId → CombatUnitTable` 关联角色，partIds 组合外观。`PawnAppearance` 校验角色映射唯一、插槽互斥、必需身体/底座及资源引用；空装备插槽合法。这是初始外观配置，不是已实现的背包或装备玩法。
- `PawnRig.prefab` 绑定七个实际 Transform；`PawnView.ApplyAppearance` 按插槽替换发生变化的部件，不在运行时搜索挂点，不携带装备玩法状态。`AdventureRuntimeDemo` 序列化 Rig 和全部部件引用，Lua 导出的部件 ID/路径必须与绑定一致。四人占格和移动状态见[局部地图](MapArea.md)。
- Edit Mode 菜单 `Project Y/远征/同步棋子资源引用` 按表生成 Rig、四个装配样例并保存当前 AdventureDemo 引用；模型/路径变更后执行。装配样例是可查看的美术 Prefab，运行时用空 Rig 按外观快照组装，避免把预装装备复制两遍。
- 最小检查 `python -B Tools/Tests/run_lua.py Tools/Tests/pawn_appearance.lua` 使用真实导表结果，覆盖四套模板、资源存在、插槽冲突与空装备。实际角色实例和部件资源需再用 Unity Edit Mode 检查；不自动进入 Play。
- 已用真实远征快照在 Unity Edit Mode 装配四人、执行移动并静态渲染；AdventureDemo 保存 16 项部件引用和七挂点 Rig。`PawnView` 实测卸下剑盾再装回，网格数量恢复且不重复。配置/快照/编队定向检查、6 项 MapArea 集成及 7 项事件战斗回归通过；人工 Play 交互未代为执行。

## 关键入口

- [可编辑源](../../Art/PawnLowPoly/Source/PawnCommon.blend) / [模型清单](../../Art/PawnLowPoly/Integration/pawn-models.json) / [Unity 部件](../../Assets/DynamicAsset/PawnLowPoly/Models/) / [装配 Prefab](../../Assets/DynamicAsset/PawnLowPoly/Templates/)。
- [部件表](../../Config/Tables/Adventure/PawnPartTable.json) / [外观模板表](../../Config/Tables/Adventure/PawnTemplateTable.json) / [外观解析](../../Lua/Game/Adventure/PawnAppearance.lua)：资产关系走配置，产物遵循[配置管线](../Framework/Config.md)。
- [Blender 预览](../../Art/PawnLowPoly/Previews/pawn-common-kit.png) / [Unity 比例预览](../../Art/PawnLowPoly/Previews/pawn-common-unity.png) / [Unity 尺寸记录](../../Art/PawnLowPoly/Integration/pawn-common-unity.json)。
- [制作脚本](../../Art/PawnLowPoly/Scripts/build_pawn_common.py) / [导出脚本](../../Art/PawnLowPoly/Scripts/export_pawn_common.py)：初次创建入口，后续定向修改源作品并导出，不能重放初始化来覆盖已有资产。
- [配置检查](../../Tools/Tests/pawn_appearance.lua)：不启动 Editor 或 Play。
- [双手战士制作](../../Art/PawnLowPoly/Scripts/build_warrior.py) / [四套模板预览](../../Art/PawnLowPoly/Previews/pawn-squad-kit.png)。
- [挂点装配](../../Assets/GameFramework/Samples/Adventure/PawnView.cs) / [资源同步菜单](../../Assets/GameFramework/Editor/PawnAssetMenu.cs)：运行时组合与 Editor 序列化绑定。
- [Unity 地牢编队预览](../../Art/PawnLowPoly/Previews/squad-maparea-unity.png) / [装配与换装检查记录](../../Art/PawnLowPoly/Integration/squad-unity.json) / [真实 Lua 快照入口](../../Art/PawnLowPoly/Scripts/preview_squad.lua) / [MCP 静态预览片段](../../Art/PawnLowPoly/Scripts/preview_squad.cs)：临时 PreviewScene 完成后关闭，不修改当前地图或启动 Play。
