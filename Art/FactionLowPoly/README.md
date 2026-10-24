# 势力据点模型

三件单格大地图微缩据点，沿用既有 `MapLowPoly` / `WorldPartyLowPoly` 的硬边网格、低饱和纯色和米制尺度。它们只负责外观；势力、实力、地形生成、攻占及交互由玩法配置控制。

| 模型 | 轮廓 | Unity 尺寸 X × Y × Z | 三角形 |
| --- | --- | --- | --- |
| Faction_OrcStockade | 粗木围寨、兽骨门、兽皮帐篷 | 1.520 × 1.140 × 1.520 | 872 |
| Faction_GoblinCamp | 两座矮棚、歪斜瞭望塔、稀疏木栅 | 1.520 × 1.362 × 1.530 | 876 |
| Faction_ElfGrove | 双高树、平台树屋、木阶与符石 | 1.520 × 2.470 × 1.520 | 716 |

- 可编辑源：[FactionStrongholds.blend](Source/FactionStrongholds.blend)。`FactionStrongholds_Source` 中三个网格各保留落地原点；`FactionStrongholds_Overview` 使用网格副本并排展示。原件和展示布局分开，不带展示位移导出。
- Unity 资源：`Assets/DynamicAsset/FactionLowPoly/Models/`，14 个共用哑光材质在同级 `Materials/`。全部材质为 URP Lit，金属度 0、光滑度 0.08，不依赖贴图。
- `AdventureDemo.worldPartyBindings` 在原有 7 项后追加三项；未更改原有模型引用。运行期通过现有大地图队伍模型快照机制显示据点。
- 地块半径为 1；全部网格水平最大半径不超过 0.789。模型底部 Y=0、Unity +Z 为正面、根旋转为零、缩放为一。
- 导出复用项目 `export_map_static_fbx.py`，只对导出副本烘焙 Z 轴 180°；Unity `bakeAxisConversion=true`，Scale Factor 1，Convert Units 开启，禁用动画，保留平面法线。

初建脚本：[build_faction_sites.py](Scripts/build_faction_sites.py)，拒绝覆盖已有源。后续在 Blender 中修改明确的源网格，再使用 [export_faction_sites.py](Scripts/export_faction_sites.py) 的 `export(overwrite=True)`。Unity 使用 [import_unity.cs](Scripts/import_unity.cs) 进行定向资源导入、材质映射和追加绑定，保持既有 GUID；不调用全局 Refresh。

已完成的最小检查：Blender 网格占地与落地原点检查、实际 FBX 导出、Unity 尺寸/三角数/单位根变换/材质映射检查，以及和旧兽人棋子、商队、民居同框的静态斜俯视预览。未启动 Unity、未进入 Play、未触发项目脚本编译、未进行游戏或全量测试。

- [源资源清单](Integration/asset-manifest.json)
- [Unity 导入记录](Integration/unity-import.json)
- [Unity 实际预览](Previews/faction-sites-unity.png)
- [预览脚本](Scripts/preview_unity.cs)：使用临时 PreviewScene，完成后释放，不保存到游戏场景。
