# 持武动作模组与局部握点
关键词：攻击模组、单手、剑盾、双手共持、双持、法杖、弓、枪型、offset、Vector3、握点。

## 文档目录
正文：选择 / 坐标契约 / 运行与边界 / 验证；关键入口：配置 / Lua / 播放 / 网页。

## 正文

- 动作模组按主手种类/手数、副手状态和 gunClass 精确匹配。覆盖空手、单手（含只有副手）、剑盾、共持、双持、法杖、弓、步枪；新增枪型需新增相应匹配行，不静默退回其他枪型。匹配重复或无规则立即报错。
- `EquipmentMotionModuleTable` 选择基准姿势、独立 Hold 配置、主/副动作及副手解算方式；`EquipmentMotionMatchTable` 负责装备组合；`EquipmentWeaponTable.gripId → EquipmentGripTable` 负责每件武器的几何抓握点。旧 WeaponTable.poseId 已迁移到握点配置，避免两处维护。
- 分层归属：几何握点是武器共享数据；模组/姿势是通用持握方式；`EquipmentHoldAdjustmentTable` 仅记录 `(weaponId,moduleId,hand)` 的专属 `rotationOffset`。weaponId 是武器型号而非库存实例；hand 为 main/off，双手共持的一件武器使用 main。重复组合报错；缺行明确表示零修正、继承模组基准，不从其他模组或另一只手借值。
- 专属旋转在当前动作基准朝向后以四元数叠加，顺序不能改成欧拉角相加；独立于 main/offRotation（手掌握点旋转）。待机、移动、攻击、双持和无动画的刚体表现都读取同一修正；双手共持保留主握点基准锚点，按旋转后的第二握点解算左臂。源配置由 Lua 解析为 Pose.WeaponRotationOffset/OffWeaponRotationOffset，网页按同一组合键读取。
- 握点位置使用武器根节点的本地 Vector3（米），旋转为本地 XYZ 欧拉角（度）；包含主握点与第二握点，支持非零偏移和 Prefab 缩放。右手掌对齐主握点；共持时左手对齐主武器第二握点，双持时左手对齐副武器自己的主握点。
- 武器根节点应用主握点的逆变换；共持 IK 使用实际缩放后的两握点。骨骼名称、参考姿势和骨长不因微调改变。`EquipmentPoseTable` 的 mainHand 是武器基准原点，弓的原点可以位于角色左侧，不再等同于右手掌位置。
- 模组的 `holdId` 对应 PawnAnimations 的独立待机/移动允许集；同步入口仅在缺失时从 `sourceHoldId` 复制，保留作者之后的修改。基础身体片段可复用，武器轨迹按 Action 配置；弓使用独立动作 8，避免继承步枪动作 2 的朝向轨迹。
- 法杖采用持杖手与施法手分工，`lockWeaponOrientation` 保持施法时的杖身朝向。双持剑向身体外侧倾斜；巨剑推进器挂点已沿剑脊上移。上述内容均为表现，不修改命中或伤害数值。
- 当前枪资源为步枪；其他枪型可由 gunClass 扩展。弓已使用真实弓资源和基础射击模组，身体参考现有射击片段；专用拉弦片段与弓弦变形尚未制作。无需把这一内容边界与“没有弓模组”混为一谈。
- 编辑步骤：修改模组/匹配/握点表 → 现有导表器 → 新 Hold 执行“同步持武模组动画配置” → 查看真实 Unity 角色 → “导出角色网页资源”。握点向量也可用[角色工坊](../Tools/CharacterPreview.md)的三维手柄/数值编辑并自动写回源表，再点“导出游戏配置”。网页保留真实 PawnView/Tick 采样，编辑时重算挂点与双臂，不能只绑裸手骨而遗漏挂点旋转修正。
- `EquipmentGripValidation` 测试 11 种持武组合的非零位置/旋转及 0.8 倍步枪；`PawnGearValidation` 测试装备与各族体型的完整动作采样。已有动作变更后定向复查，不自动启动 Play 或扩大为全量项目测试。

## 关键入口

- [模组](../../Config/Tables/Equipment/EquipmentMotionModuleTable.json) / [匹配规则](../../Config/Tables/Equipment/EquipmentMotionMatchTable.json) / [武器握点](../../Config/Tables/Equipment/EquipmentGripTable.json)。
- [持握专属旋转](../../Config/Tables/Equipment/EquipmentHoldAdjustmentTable.json)：可选组合修正；网页恢复默认会删除该组合行。
- [选择器](../../Lua/Game/Equipment/EquipmentMotion.lua) / [装备快照与技能表现](../../Lua/Game/Equipment/EquipmentRules.lua)。
- [动作与 IK](../../Assets/GameFramework/Samples/Adventure/PawnAnimationView.cs) / [武器对齐](../../Assets/GameFramework/Samples/Adventure/PawnEquipmentView.cs) / [同步](../../Assets/GameFramework/Editor/EquipmentMotionAssets.cs)。
- [握点检查](../../Assets/GameFramework/Editor/EquipmentGripValidation.cs) / [模组离线检查](../../Tools/Tests/equipment_motion.lua) / [网页导出](../../Assets/GameFramework/Editor/PawnEquipmentWebExport.cs)。
