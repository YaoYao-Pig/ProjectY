# 六职业专属武器

2026-10-25：依据已确认的六职业扩展，新增 12 把原创低多边形武器。源码与可编辑 Blender 文件保存在 Assets 外；FBX 显式导出，材质沿用项目现有 MapLP 纯色调色板，不依赖程序材质或外部贴图。

| 物品 ID | 职业 | 名称 | 模型 | 兼容动作 |
| --- | --- | --- | --- | --- |
| 8001 | 炼金师 | 炼金蒸馏杖 | Profession_AlembicStaff | staff |
| 8002 | 炼金师 | 腐蚀注射剑 | Profession_CausticInjector | sword |
| 8003 | 吟游诗人 | 共鸣鲁特琴 | Profession_ResonanceLute | staff |
| 8004 | 吟游诗人 | 行军七弦琴 | Profession_MarchingLyre | staff |
| 8005 | 神官 | 慈悲香炉杖 | Profession_MercyCenser | staff |
| 8006 | 神官 | 守夜祷锤 | Profession_VigilMace | sword |
| 8007 | 咒术师 | 缚咒纺锤杖 | Profession_HexSpindle | staff |
| 8008 | 咒术师 | 血契仪刀 | Profession_BloodCovenKnife | sword |
| 8009 | 决斗家 | 银线刺剑 | Profession_SilverRapier | sword |
| 8010 | 决斗家 | 捕刃左手匕 | Profession_ParryingDagger | sword |
| 8011 | 驯兽师 | 驯群钩杖 | Profession_PackmasterCrook | staff |
| 8012 | 驯兽师 | 狼牙猎弓 | Profession_FangBow | bow |

## 实际产物

- [源模型](Source/ProfessionWeapons.blend)：12 件独立网格，握柄原点为零，无父级、动画或未应用修改器。
- [预览场景](Source/ProfessionWeaponsPreview.blend)与[整体预览](Previews/weapons-contact-sheet.png)：展示副本与导出母版分离。
- [模型检验记录](Integration/models.json)：三角面、尺寸、材质、体积、UV、边界和导出文件信息。
- [调色板](Integration/palette.json)：12 种复用材质的 sRGB 色值。
- `Staging/*.fbx`：暂存导出。正式模型位于 `Assets/DynamicAsset/ProfessionArsenal20261025/Models/`。
- [复制记录](Integration/staging.json)：暂存文件与正式模型逐一校验 SHA-256。

## 几何与导出契约

每把为 456–1,624 三角面，合计 10,232。全部网格组件封闭，边界边和非流形边均为零；面面积非零、整体有符号体积为正，全部有一层有限值 UV。模型的平面色块使用真实几何与显式材质槽。

Blender 1 单位等于 1 米，长轴 +Z；使用既有 Arsenal 的 `export_map_static_fbx`，仅导出副本旋转 Blender Z 轴 180°，启用 bake_space_transform，Unity 要求 bakeAxisConversion=true、globalScale=1、静态模型无动画。导出后长轴为 Unity +Y，正面 +Z。

鲁特琴的琴颈跨越握柄原点，琴体位于握柄下方；七弦琴拥有独立短柄。它们接入现有持杖/施法姿态，不包含演奏动画。注射剑、祷锤、仪刀和刺剑采用现有单手近战动作；弓采用现有弓动作，弓弦为静态几何。

## 原生导入

复用 `EquipmentAssets.SyncSelected`，在配置含 8001–8012 后一次同步选中武器，自动生成 `WeaponModelView` Prefab、目录引用与模型图标。所有材质均已存在于 `EquipmentDemo/Materials` 或 `MapLowPoly/Materials`，无需新建材质或业务 C#。定向调用请求见 `Tools/ProfessionExpansion/weapon_unity_import.json`。

本文件建立时已完成 Blender 连接、建模、几何校验、暂存 FBX、源文件归档、整体预览与正式 FBX 复制。Unity 原生导入/持握检查由主流程执行，其实际结果应以 `Integration/unity-import.json` 为准。未自动启动 Editor、进入 Play 或触发 C# 编译。
