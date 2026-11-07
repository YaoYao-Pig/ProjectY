# 奇幻头部制作与随机外观
关键词：头部雕刻、lowpoly脸、耳朵、哥布林头、男女贴图、随机捏脸、BlendShape、HeadSculptStudy、HeadSculptExpansion。

## 文档目录
正文：正式接入 / 制作约束 / 验证；关键入口：技能 / 源 / 游戏资源 / 检查。

## 正文

- 原型五个头加本轮五张新面容，以十个新增 `*_sculpt_*` ID 接入正式目录；原 29 个模块保留，当前共 39 个可见模块。新增男脸、女脸受种族/性别筛选；已有存档按保存的头 ID 还原，不重新随机。
- 新面容为两张人类男脸、两张人类女脸、一张哥布林女脸。面容、UV 和贴图作为一个头部模块选择；六个形态键再由 `PawnHeadShapes` 按 seed 与 head ID 确定性生成小幅变化，不消耗全局 RNG、不改骨骼。
- `Integration/catalog.json` 的可选 `source/texture/skinBase` 指向独立 FBX、albedo 和身体肤色基准；旧模块为空时仍读原合并 FBX。`HeadSculptAssets.Sync` 增量同步新头，保留旧 Mesh GUID、装备目录和默认外观；完整 `Build` 也识别多来源。
- 贴图均为 1024² albedo，通过 `_BaseMap` 绑定独立 URP Lit 材质；`HeadSculpt_*` 角色使用相对种族色倍率，身体 Skin 使用该脸的肤色基准乘同一倍率，避免重复染色。
- `SaveAsset` 保留形态帧；`ImportPart` 转换基础顶点和形态增量后重映射至原 23 骨骨架。源文件保留参考骨架，正式头部 FBX 仅导出 Head 的有效变形链；不能让空权重四肢的错误绑定通过误差检查。
- 正式导出只对参考骨架做既有轴向转换，不再额外旋转脸网格；已在 Unity 核实正面为 +Z。仅 Blender 朝向或同名骨骼检查不足以证明游戏朝向正确。
- 本批 `ModelImporter.importBlendShapeNormals=None`，保留基础切面法线；Calculate 曾产生接近翻转的形态法线，在嘴唇/耳朵出现黑纹。重导须保留现有 `.meta` 并复查真实 Unity 视图。
- 皮肤为闭合连续网格，眉眼、胡茬由投射贴图表达，不包含眼球或表情骨骼。颈根保持源接口 Z=1.368，按原身体颈套留小量覆盖余量；头发仍独立。穿戴适配见[自动贴合](EquipmentAutoFit.md)。
- 旧 `Art/HeadSculptStudy` 保留为可编辑原型与独立参数预览，其候选替换 ID、预览种子算法不等同于正式 ID/算法；不能用原型五头 FBX 覆盖正式合并资源。
- 已在 Edit Mode 验证：2048 次随机可到达十个新头、旧 ID 保留、形态帧与 GUID 重导保留、形态后蒙皮误差约 1.2e-7、24 组穿戴与网格释放。网页七项定向检查通过。主动请求两次 C# 编译，第二次释放修复经用户确认；未进入 Play、未运行全量游戏测试。

## 关键入口

- [制作 Skill](../../.agents/skills/fantasy-head-sculpt/SKILL.md) / [原型源](../../Art/HeadSculptStudy/Source/HeadSculptStudy.blend) / [原型预览](../../Art/HeadSculptStudy/Review/index.html)。
- [正式扩展源](../../Art/HeadSculptExpansion202610/Source/HeadSculptExpansion.blend) / [制作烘焙导出](../../Art/HeadSculptExpansion202610/Scripts/build_expansion.py) / [追加目录](../../Art/HeadSculptExpansion202610/Scripts/author_catalog.py)。
- [游戏 FBX](../../Assets/DynamicAsset/PawnCustomization/HeadSculpt/HeadSculptExpansion.fbx) / [贴图](../../Assets/DynamicAsset/PawnCustomization/HeadSculpt/Textures/) / [Unity 实际面容](../../Art/HeadSculptExpansion202610/Previews/unity-five-new-heads.png)。
- [增量导入](../../Assets/GameFramework/Editor/HeadSculptAssets.cs) / [网格与形态帧转换](../../Assets/GameFramework/Editor/PawnCustomizationAssets.cs) / [种子形态](../../Assets/GameFramework/Samples/Adventure/PawnHeadShapes.cs) / [外观规则](../../Assets/GameFramework/Runtime/Data/PawnCustomizationRules.cs)。
- [原型制作](../../Art/HeadSculptStudy/Scripts/head_study.py) / [耳朵修订](../../Art/HeadSculptStudy/Scripts/refine_ears.py) / [原型验证](../../Art/HeadSculptStudy/Integration/validation.json)。
- [Unity 定向检查](../../Tools/Tests/head_sculpt_integration.cs) / [真实渲染](../../Tools/Tests/head_sculpt_preview.cs) / [结果](../../Art/HeadSculptExpansion202610/Integration/unity-validation.json) / [网页种子对照](../../Tools/CharacterPreview/tests/head-sculpt.test.mjs)。
