# 五生态地形扩充 · 2026-10

本目录包含 15 款精确拼接地块与 21 款可拆装饰物。地块遵循现有 MapLowPoly 半径 1 的尖顶六边形契约；Blender 顶面 Z=0、底面 Z=-1。装饰物以米为单位、底部落地原点，正面 Blender -Y，导出后按项目 importer 契约对应 Unity +Z。

| 生态 | 地块 | 独立装饰物 |
| --- | --- | --- |
| 沼泽 | 泥炭、苔毯、淤土 | 垂柳、香蒲、空心腐木、朽桩 |
| 黑暗森林 | 腐殖土、盘根暗土、衰败土 | 古橡、荆棘拱、黑松、缚石盘根 |
| 岩浆 | 冷却壳、余烬、火山渣 | 石琴、黑曜断刃、喷气孔、分岔裂隙 |
| 火山 | 灰原、凝灰岩、硫华 | 火山锥、塌口古火山、硫华烟囱、凝灰尖塔 |
| 蘑菇森林 | 菌丝土、孢子床、陈年菌毯 | 红巨伞、褐母子菌、蓝灯菌、层生菌、马勃巢 |

`manifest.json` 保存每模型实际尺寸、三角面、共享材质、参考映射及导出参数。`materials.json` 保存线性色与 sRGB 调色板。`Source/Terrain.blend` 是可编辑来源，`Staging/` 是 FBX 暂存，Unity 目标为 `Assets/DynamicAsset/AssetExpansion202610/Terrain/`，主批次统一导入。

`References/reference_index.json` 保存 10 张已搜索并实际观看的游戏截图，包括页面 URL、原图 URL、原始尺寸、借鉴点与本地归档。每资产映射对应生态的两张截图。截图仅作研究，不进入模型贴图或 Unity 发行资产。设计采用项目既有纯色硬边风格，重新构造低多边形体块，未提取游戏模型或复刻特定道具。

小说意象来自 William Morris《The Wood Beyond the World》VI–VIII 章的林缘、荆棘、橡树、灰色岩墙及裂隙，见 [Project Gutenberg 原文](https://www.gutenberg.org/cache/epub/3055/pg3055-images.html)。它用于整体探险气氛和构图语汇，不声称小说具有 Minecraft 菌群或熔岩生态。

水位、地图高度和装饰分布由现有地图数据控制。底块没有固定岸线、边缘倒角或随机位移；熔岩裂隙为可独立旋转的装饰。资源生产没有新增玩法、占地阻挡或刷物规则。

制作脚本与最小验证在 `Scripts/`。三视图和斜俯视图位于 `Previews/`；逐项人工视觉记录在 `review.json`。`mesh_qa.json` 验证闭合组件、退化三角形、UV、单位根变换、地块精确接缝和装饰落地原点。这里的 Blender 通过不替代 Unity 实际材质、导入轴向或运行布局验证。

## 运行时接入

- 五生态对应 E_MapRegion 7–11，36 个 Prefab 对应 MapAssetTable 1000–1035；MapBiomeTable 的三款底块池与装饰池都已接入，开始菜单配方5从全部十一地貌按种子抽取。原六地貌随机配方4保留候选池供旧存档重建。
- 复用现有湖盆/森林/山地采样；原模型、材质及 GUID 保留。无 tintMaterial 的新地块在真实渲染器中保留多色材质槽，避免所有变体被统一染色。熔岩裂隙为装饰，不新增熔岩水面或伤害玩法。
- 旅行地形及六类局部地图主题已覆盖新枚举；随机战场使用对应地表和装饰资源。远征场景已通过原生同步工具保存全部资源引用。
- 定向检查：`Tools/Tests/map_ecology.lua` 验证 2500 格地图的实际模型引用、干地与五类战场；`Tools/Tests/map_ecology_editmode.cs` 检查真实场景绑定、多色材质和离屏画面。实际 [总览与近景](../../../Docs/Previews/MapEcology/contact-sheet.jpg) 包含全部 15 款底块与 21 款装饰；未进入 Play。
