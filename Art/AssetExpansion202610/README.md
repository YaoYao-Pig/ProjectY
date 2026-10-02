# Project Y · 2026 年 10 月资产补充

[打开可浏览资产档案](gallery.html)。支持类别筛选、名称/背景搜索、正侧背与斜视大图、参考来源及 FBX 下载。

## 交付

| 分组 | 数量 | 内容 |
| --- | ---: | --- |
| Terrain | 36 模型 | 沼泽、黑暗森林、岩浆、火山、蘑菇森林各 3 地块；装饰 4/4/4/4/5 |
| Dungeon | 20 模型 + 6 纹理 | 6 罐器、14 陈设；3 墙面、3 地面 |
| Items | 35 模型 | 食物 10；医疗、药水、护甲、戒指、符文各 5 |
| Weapons | 55 模型 | 单手剑、巨剑、弓、弩、长枪、短枪、盾、匕首、法杖各 5；瞄准镜、消音器各 5 |
| Shipwreck | 19 模型 | 2 大地图船只标识；船壳、连续甲板、艉楼、桅帆与船用陈设 |
| ShipwreckV2 | 16 模型 | 三层大型船体分件、舱门、吊床、厨房、餐桌、货架等设施 |
| ShipwreckProps | 20 模型 | 航海、生活、修补与医疗小物件，已参与船舱摆放 |
| ShipwreckWeapons | 10 模型 | 弯刀、登船刀、船钟锤、锚斧、鱼叉、匕首、弩、弓、杖、短铳 |

每组 `Source/` 是可编辑 Blender 来源；`Staging/` 是独立 FBX；`manifest.json` 记录尺寸、面数、原点、材质、故事与参考。`Previews/` 保存正、侧、背、斜视和逐项联系表。`UnityPreviews/` 是实际导入后的离屏渲染，不是 Blender 图的复制。

Unity 产物在 `../../Assets/DynamicAsset/AssetExpansion202610/<分组>/`：`Models/`、`Materials/`、`Prefabs/`，地牢另有 `Textures/`，物品和武器另有 `Icons/`。Unity 资源通过 AssetDatabase/ModelImporter/PrefabUtility 原生 API 制作，没有手写 YAML。材质为 URP/Lit；源 `.blend` 不进入 Assets。

## 参考与故事

每项至少关联 2 张实际网络查找且看过的知名游戏参考图，存来源页、图片地址、借鉴点和本地参考档案。参考图只用于研究，不作为交付纹理或模型复制。小说意象采用可核查文本的简短归纳；故事为本批原创。

武器及配件背景见 [Weapons/Backgrounds.md](Weapons/Backgrounds.md)；护甲、戒指、符文及消耗品故事见 [Items/lore.md](Items/lore.md)。武器/装备每件均超过 100 个汉字；食物使用较短的风味描述。

## 审核边界

逐件正、侧、背和斜视已经用于人工目视审核；发现问题后修正并重渲。保留具体问题和结论，不把自动网格检查当作审美通过。技术证据见各组 `unity_validation.json` 与 `manifest.json`；统一检查见 `audit.json`。初始四组仅做资产检查；后续沉船专题按轮次集中编译，并做定向算法与原生会话检查。没有启动 Unity、进入 Play 或运行全量游戏测试。

最初四组尚未写入地图/物品配表、随机生成池、掉落池、持握和插槽配置。沉船专题已注册资源并接入大地图水域选址、独立船形小地图与补给匣。护甲是静态可装配模型，未完成角色蒙皮或逐体型穿戴验证；角色实装时须按真实挂点复核。

六张地牢纹理已建独立材质并做 3×3 平铺目视检查；保留非零边缘像素差值，不宣称数学周期无缝。现有 `MapPreviewInstanced.shader` 只使用程序图案与颜色，没有 `_BaseMap`；要在随机地牢里显示新纹理，需后续接入纹理采样与材质池。

当前沉船专题见 [ShipwreckV2/README.md](ShipwreckV2/README.md)：长宽各约三倍、三层1595可走格，已经接入默认遗址。原 [Shipwreck/README.md](Shipwreck/README.md) 保留旧版制作与大地图标识来源。每轮编译和检查由各专题单独记录。

## 制作与复核入口

- [公共管线](shared_pipeline.py)：独立场景、导出、源存档和视图；使用 Blender MCP 执行。
- [Unity 导入片段](import_assets.cs)：替换 group，必要时填写 onlyNames，只针对该批资源导入和建立 Prefab。
- [Unity 离屏预览](capture_unity.cs)：独立 PreviewScene，结束即释放，不改变游戏场景。
- [纹理导入](import_textures.cs)、[图标导入](import_icons.cs)。
- [图册生成](build_gallery.py)、[统一审核](audit_pack.py)。
- [地形审核](Terrain/review.md)、[地牢审核](Dungeon/review.json)、[物品审核](Items/review.json)、[武器审核](Weapons/review.json)。

构建脚本不是无条件重新生成整个项目的入口。已有作品保留；重新制作时只操作对应分组自己的对象，Unity 更新必须保留原 `.meta`/GUID。
