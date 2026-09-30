# 棋子 Humanoid 动画
关键词：动画、动作、骨骼、蒙皮、Avatar、Humanoid、Quaternius、UAL、双手握点、暂停、死亡。

## 文档目录
正文：资源 / 播放契约 / 验证与边界；关键入口：制作 / 运行时 / 配置。

## 正文

- 公共身体来自原 PawnCommon 的独立副本，23 骨、Unity 映射 22 个人体节点；原始静态资源仍保留。Unity 模型朝 +Z、米制，Animator 禁用根位移。身体与裤腿/靴子用蒙皮，其余硬质附件挂骨骼。
- `PawnRig` 已绑定 `PawnAnimationView`，按 `PawnAnimationSet.BodyParts` 替换身体部件 1/15/19；城镇 NPC 17/18 保持原外形。`PawnAssetMenu` 重建 Rig 时保留动画接入。静态装配样例 Prefab 仍用于查看原部件。
- UAL1 Standard 的免费包实际有 43 个片段，采用不带 Root Motion 的 Unity FBX；CC0 许可证、哈希、原包、动作清单保留于 `Art/PawnAnimation/ThirdParty`、`Integration`。不包含专门拉弓动作，也没有宣称这些片段覆盖全部武器动作。
- `PawnAnimations.asset` 配置动作模板→状态/Clip/时长/命中比例、`UseAuthoredGrip/GripKeys/OffGripOffset` 武器轨迹、持握姿态→待机/握点旋转/手头间距、移动与播放速度、倒地保留时间和底座高度。首次生成从 EquipmentActionTable 初始化；已存在资产保留作者修改。新增动作需同步 AnimatorController 的同名状态。
- `CombatActorData.RecordAction` 额外保留最多 8 条只读表现记录，覆盖 AI 一次命令的攻击+防御。`CombatSnapshot.presentationActor` 是同步读桥接入口；`AdventureViewData.ReadActor` 当场复制记录，不持有该 actor 或 LuaTable。高频快照按动作序号去重，初次可见不补播旧动作。
- 规则仍立即结算伤害、AP、冷却和奖励；动作只呈现结果。HP 降低播放受击，HP=0 播放倒地。MapArea 单独输出 `defeated`，不混入存活敌人、占格或 HUD；离开视野不会被当作死亡。
- `PawnMotion` 在实际导航边上插值到权威目标格；不会直线穿墙。动作在移动结束后播放，命中反馈按队列预计时长延迟。Demo 等当前表现结束再自动 AI/接受下一条战斗命令；战斗中空格跳过表现，结算退出局部场景前保留倒地播放。
- 世界动画由 renderer 传入 `Time.deltaTime` 手动驱动；角色页面用独立 `Time.unscaledDeltaTime`。Animator 与旧刚体手臂不同时写姿势。双手握点通过显式绑定的两段手臂求解，弹匣沿原插槽配置显示换弹位移。
- `PawnAmbientMotion` 使用角色 ID 派生的独立 System.Random，按权重选待机/步态、初始进度和微小播放速度差，不消费玩法或 Unity 随机数。持握配置限定待机池；默认每 4–9 秒换待机、7–13 秒换步态，避免连续选同一片段，以 .35 秒交叉淡化。普通步态在 Walk/Jog 间混合，另一套在 Formal Walk/Sprint 间混合；步态切换保留周期进度。暂停不推进计时，基础循环不阻塞战斗命令。
- `BattleMoveSpeed` 当前为 7.5 米/秒，相对原来的 5 为 1.5 倍；战斗角色路径显示与动画步频使用该速度，不修改 AP、射程或权威落点。探索移动节奏仍由 MapArea 配置决定。
- 当前提供基础待机/行走/跑步、斩击与镜像副手斩击、施法/射击/换弹、受击/倒地、搜刮/交谈。大剑/巨剑使用 `Punch_Cross` 的身体发力作为参考，叠加单独的双手刀刃轨迹；巨剑动作 6 为肩侧转刃、快速斜下劈、收势，切割阶段保持剑身宽面法线垂直于挥砍方向，避免用侧面拍击；时长 .60 秒，命中位于进度 .48。专用弓拉弦、推进器特效、细分重武器招式和地形脚底 IK 属于后续动作内容。
- 最小验收：菜单 `Project Y/角色/验证 Humanoid 动画接入` 在独立 PreviewScene 检查实际 Avatar、蒙皮、握点、去重、暂停、倒地和绕墙路径。多姿势同帧截图使用 BakeMesh 防止 GPU 蒙皮缓存误导；场景角色不逐帧烘焙，UI 手动离屏预览遵循[渲染快照契约](../Framework/Rendering.md)。已在获准的实际 Play 中验证探索进入战斗、角色不同待机状态和四格移动，移动实测约 7.48 米/秒。

## 关键入口

- [资源配置](../../Assets/DynamicAsset/PawnAnimation/PawnAnimations.asset) / [资源生成](../../Assets/GameFramework/Editor/PawnAnimationAssets.cs) / [验收](../../Assets/GameFramework/Editor/PawnAnimationValidation.cs)。
- [动画播放](../../Assets/GameFramework/Samples/Adventure/PawnAnimationView.cs) / [配置类型](../../Assets/GameFramework/Samples/Adventure/PawnAnimationSet.cs) / [路径表现](../../Assets/GameFramework/Samples/Adventure/PawnMotion.cs)。
- [绑定源](../../Art/PawnAnimation/Source/PawnHumanoid.blend) / [初次绑定脚本](../../Art/PawnAnimation/Scripts/rig_body.py) / [导出脚本](../../Art/PawnAnimation/Scripts/export_rig.py)；导出旋转独立副本，不能对已绑定源直接应用静态 FBX 导出流程。
- [首轮检查记录](../../Art/PawnAnimation/Integration/unity-validation.json) / [预览](../../Art/PawnAnimation/Previews/) / [完整计划与当前范围](../../Docs/CharacterAnimationPlan.md)。
- [穿模复查脚本](../../Art/PawnAnimation/Scripts/check_weapon_clearance.cs)：MCP Edit Mode 片段，逐帧检查步枪射击/换弹、大剑/巨剑动作的握点、手头间距及武器/头盔凸包相交，并截图正面/左右侧面；不启动 Play。
- [巨剑下劈复查](../../Art/PawnAnimation/Scripts/check_colossal_slash.cs)：定向检查两把巨剑的刃口切割方向、双手握点、头盔避让、播放时长，以及大剑/步枪基本回归；在独立 PreviewScene 运行。
- [待机/步态选择](../../Assets/GameFramework/Samples/Adventure/PawnAmbientMotion.cs) / [变化验收](../../Assets/GameFramework/Editor/PawnAmbientValidation.cs)：角色间片段与相位差异、相同角色种子的可重复性、暂停、随机数隔离及四人实际蒙皮预览。
- [Play 移动记录](../../Art/PawnAnimation/Integration/live-move-speed.json) / [Play 血条与姿态记录](../../Art/PawnAnimation/Integration/live-hud-check.json) / [镜头远近检查](../../Art/PawnAnimation/Integration/live-camera-check.json)。
