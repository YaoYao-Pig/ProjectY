# 模块化角色与有限捏人
关键词：捏人、脸型、体型、男女、精灵、哥布林、龙人、兽人、随机外观、PawnCustomization。

## 文档目录
正文：资源 / 组合契约 / 范围与验证；关键入口：目录 / 装配 / 制作 / 网页。

## 正文

- 首批 29 个 Blender 模块：男女各三档身体、五族男女各两种脸、三种发型；另有明确的无发选项。种族为人类、精灵、哥布林、龙人、兽人。角色维持相同关节位置、四肢长度与身高，以头脸和轮廓区别；没有尾翼、表情骨骼或自由滑杆。
- 源文件位于 `Art/PawnCustomization/Source`，FBX 经 `Staging` 进入 `Assets/DynamicAsset/PawnCustomization`；沿用现有[棋子动画](PawnAnimation.md)的 23 骨参考姿势。新增模块不得改名、重排层级或应用未核实的骨架变换。
- `Integration/catalog.json` 是制作目录；`PawnCustomizationAssets.Build` 读取它与实际 FBX，校验 bind pose，按骨名重映射并生成规范坐标下的 Mesh、独立 URP Lit 材质和 `PawnCustomization.asset`。已有 Mesh/目录资源更新保留 GUID；运行时换色使用 `_BaseColor`，参见[渲染管线](../Framework/Rendering.md)。
- `PawnCustomizationData/PawnCustomizationRules` 归 Runtime/Data；保存版本、种子、种族、男女、实际身体/脸/发型 ID、三类颜色索引。`Rules.Randomize(seed, race?, sex?)` 使用局部 uint32 状态，根据目录筛选可用模块；龙人只允许短脊或无发。同步菜单生成 Resources 的只读目录，`CharacterAppearanceService` 校验并写入 `CombatActorData.CustomizationJson`，不在视图中随机。
- `PawnCustomizationView` 绑定实际骨骼和三个蒙皮显示节点；`PawnView.ApplyAppearance` 接收 `PawnAppearanceData.Customization`。战斗、探索和背包快照传递同一个 `customizationJson`；未提供时仍可使用原动画身体。
- `PawnAnimationAssets.Attach` 重建动画身体后重建定制绑定，避免重新同步动画丢失引用。`PawnCustomizationPreset` 保存网页描述及显示组件引用，用于导入的独立 Prefab。
- `PawnTemplateTable.appearancePoolId` 与 `CombatEncounterTable.appearancePoolId` 引用 `CharacterAppearancePoolTable`。池配置种族/性别及权重、同群同族开关；当前主角默认池 1，废墟遭遇使用可编辑的池 6，池 7 演示逐名混编。`CharacterAppearance.lua` 在主角、旧棋盘敌人和地牢敌群创建时分配一次，不消耗战斗 RNG；同地点重进保留原敌人实例与外观。
- [角色存档](CharacterSave.md)保存完整描述及角色/背包状态。网页 JSON 仍只表示外观；装备所有权由 EquipmentData 保存，网页试穿不改写存档。
- 新增 `PawnGearFits.blend` 和 42 个装备贴合网格：五族三种头饰、六种身体的三类护甲和披风、通用裤靴与箭袋。头饰为耳角留空间；穿戴覆盖区选择预生成的身体网格（42 个遮挡版本），覆盖头发时保留外观选择，卸下恢复。已绑定蒙皮的贴合装备要求穿戴偏移为零，偏移应在源参考姿势中制作。
- `PawnPartTable.equipmentItemId` 将旧模板手持物接入真实装备目录和[动作模组](EquipmentMotion.md)；盾牌及左右戒指沿骨骼挂点，武器含符文/弹匣/推进器使用真实 Prefab。装备匹配、身体遮挡与随机外观各有独立职责。
- 最小检查菜单 `Project Y/角色/验证模块化角色与网页蒙皮` 在独立 PreviewScene 检查 Avatar、60 套脸/体型组合与 180 个动作采样，比较实际 BakeMesh 和导出所用蒙皮公式，保存 `Integration/unity-validation.json` 与五族男女截图。数学一致性不替代装备穿模或落脚效果的视觉验收。
- 装备检查 `PawnGearValidation.RunRace` 覆盖每族 132 套装备组合和 3,960 个待机/移动/完整攻击采样，检查骨骼、握点及武器/头部凸包相交；`RunLegacy` 覆盖 360 套旧模板装配。检查结果是所采样动作的证据，不是任意新资产/新动画的自动兼容保证。未启动新的 Play 验收。

## 关键入口

- [Blender 源](../../Art/PawnCustomization/Source/PawnCustomization.blend) / [制作脚本](../../Art/PawnCustomization/Scripts/build_modules.py) / [制作目录](../../Art/PawnCustomization/Integration/catalog.json)。
- [正式目录](../../Assets/DynamicAsset/PawnCustomization/PawnCustomization.asset) / [目录与规则](../../Assets/GameFramework/Samples/Adventure/PawnCustomizationCatalog.cs) / [装配组件](../../Assets/GameFramework/Samples/Adventure/PawnCustomizationView.cs)。
- [外观数据与随机规则](../../Assets/GameFramework/Runtime/Data/PawnCustomizationRules.cs) / [外观服务](../../Assets/GameFramework/Runtime/Data/CharacterAppearanceService.cs) / [配置池生成](../../Lua/Game/Adventure/CharacterAppearance.lua) / [池配置](../../Config/Tables/Adventure/CharacterAppearancePoolTable.json)。
- [装备源](../../Art/PawnCustomization/Source/PawnGearFits.blend) / [装备制作](../../Art/PawnCustomization/Scripts/build_gear_fits.py) / [装备导入](../../Assets/GameFramework/Editor/PawnGearFitAssets.cs) / [装备验收](../../Assets/GameFramework/Editor/PawnGearValidation.cs)。
- [生成、绑定、网页导出与 JSON 导入](../../Assets/GameFramework/Editor/PawnCustomizationAssets.cs) / [最小验收](../../Assets/GameFramework/Editor/PawnCustomizationValidation.cs)。
- [网页工坊](../Tools/CharacterPreview.md) / [五族男女预览](../../Art/PawnCustomization/Previews/unity-races.png)。
