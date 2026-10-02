# 矿井资源

延续 Project Y 纯色硬边地图风格，以木支架、成段铁轨、装矿车、铜矿和工作棚表达废弃矿道。全部为原创静态网格，无贴图依赖。入口用于大地图；其余使用真实米制。

| ID | 名称 | Unity 尺寸 X × Y × Z（米） | 三角面 |
| --- | --- | --- | --- |
| 900 | Mine_Entrance | 1.5694 × 1.6000 × 1.4750 | 408 |
| 901 | Mine_TimberSupport | 4.2900 × 3.0000 × 0.5265 | 144 |
| 902 | Mine_Rail | 1.1500 × 0.1450 × 1.7321 | 156 |
| 903 | Mine_Cart | 1.3010 × 1.0200 × 1.8000 | 592 |
| 904 | Mine_OreCluster | 1.5002 × 1.2000 × 1.4041 | 324 |
| 905 | Mine_Workstation | 2.7000 × 1.8100 × 1.6575 | 432 |

- `Source/Mine.blend` 保留源场景与展示副本；`build_mine.py` 为初次制作脚本，拒绝覆盖已有命名场景。
- `Staging/*.fbx` 使用项目静态 FBX 管线：导出副本烘焙 Blender Z 轴 180°，开启 `bake_space_transform`；Unity `bakeAxisConversion=true`，单位缩放、零根旋转。
- Unity 产物：`Assets/DynamicAsset/AssetExpansion202610/Mine/{Models,Materials,Prefabs}/`。Prefab 与模型同名，原点在地面中心，Unity +Z 为正面。
- `Mine_Entrance` 所有水平顶点通过半径 1 尖顶六边形范围检查；暗洞采用封闭实体。
- `Mine_TimberSupport` 两柱内侧之间 3.5 米，顶角有斜撑；总宽 4.29 米。中央必须可通过，不能按整模型包围盒生成阻挡。模型没有 Collider，通行由地图配置负责。
- `Mine_Rail` 沿 Unity +Z，长度 `sqrt(3)`，对应半径 1 六边网格相邻中心距。轨条连续，枕木最大高 0.145 米。
- 十二种共享 URP Lit 哑光材质。`materials.json` 同时记录 sRGB 色值与 Blender 线性颜色。
- `manifest.json` 为源网格清单；`unity_validation.json` 为 Unity 实测尺寸、根变换和材质检查。全部模型零非流形边、零退化面、具有 UV。

实际预览：`Previews/mine-kit.jpg`（Blender）、`UnityPreviews/mine-kit.jpg`（Unity）、`UnityPreviews/entrance-context.png`（与既有民居和石拱地牢入口同框）。仅定向导入本目录，在离屏 PreviewScene 检查；未启动 Editor、进入 Play 或主动触发工程 C# 编译，未更改用户场景。未在本资源子任务中验证运行时地图生成和交互。
