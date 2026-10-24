# 技能与物品方块特效
关键词：粒子、特效、VFX、方块、立方体、技能表现、物品拾取、装备发光、Bloom、VisualEffectTable、预览。

## 文档目录
正文：配置与扩展 / 播放与生命周期 / 验证；关键入口：配置 / 桥接 / 渲染 / 预览。

## 正文

- `VisualEffectTable` 是统一表现库，当前 104 条：72 个 CombatSkill 技能独立配置、32 个物品表现。16 种构图覆盖斩弧、刺线、爆裂、方环、盾片、螺旋、光束、抛物弧、落雨、十字、柱、散射、符文、碎片、牵引、足迹；颜色以外也配置数量、大小、半径、高度、寿命、速度和重力。尺寸使用米、寿命使用秒，emission 为颜色亮度乘数。
- 新技能必须填写 `CombatSkillTable.visualEffectId`，引用有效且未被另一技能复用的 profile。现有普通、养成、准备、物品、生活和地格技能使用相同入口。`VisualEffectCatalog.Snapshot` 在远征显示宿主启动时校验完整映射，不根据名称推断特效。
- 新物品的 `EquipmentItemTable.visualEffectId` 默认为 0，按 `kind` 从 `VisualEffectItemCategoryTable` 自动继承；非 0 是明确覆盖。当前 weapon/rune/magazine/ammo/module/wearable/material/consumable 八类完整覆盖，116 件物品中 88 件细分覆盖、28 件继承。新增 kind 要同时增加其类别配置；错误覆盖或缺类别明确失败。
- 配置源可通过已有配置编辑器维护；改动后运行 `node Tools/ConfigEditor/exporter.mjs`，不要手改 `_Gen`。改表后需重新启动读取配置的会话；预览窗“重读配置”只读取原 JSON，不给运行中的 ConfigSystem 热更新。
- `VisualEffects` 把已结算事实存入 Battle 所有的短期队列：最多 128 条，复制技能/物品身份、施放与实际落点、楼层、逐发序号和 hit/miss/cast/pickup/use。它不保存玩法状态、不掷玩法随机数、不进存档。`DemoBridge` 在命令/轮询快照中一次性 Drain；新战斗、重开、读档及关闭清理历史，战斗结束保留致死末发。
- `ProjectileCombat` 按真实目标/发次记录，每个技能的多个 Effect 不重复爆炸；实际拦截落在遮挡格，未命中落点偏离目标。准备、状态、治疗、消耗品、缴械、拾回、驯服、施工和位移有明确入口；位移前保存起点。拾取只在 `MapLoot.Take` 成功转移后记录，满包失败不播；探索角色坐标取 AreaState 成员地格。
- `AdventureVisualEffects` 在 MapArea 三维场景消费事件，按角色动作 `impactDelay` 和同源 `BattleFeedbackSystem.BurstHitInterval` 调度；技能弹道额外显示直线/抛物弧，实际命中使用各自 profile。楼层作为格子身份的一部分，跨场景释放。旧二维事件棋盘没有三维粒子宿主，消费但不显示这些世界粒子。
- 武器本体、已安装组件、穿戴物通过 `EquipmentRules` 的显示 DTO 携带同源 profile，模型与已有显式挂点持有 `EquipmentEffectDisplay`。展示采用低频、小规模脉冲，跟随武器/骨骼变换；场景、背包、工坊复用。粒子不参与角色拾取及预览模型 bounds。HUD 肖像仍按外观变化渲染，不为粒子增加持续截图。
- `BlockParticleEffects` 使用真实立方体 Mesh、HDR 顶点色和 Resources 中的 URP Shader；硬面明暗保留轮廓，不使用柔边圆粒子。颜色乘数超过 1 的魔法可进入现有世界 Bloom；不额外创建 Volume 或改风格参数，相关契约见[渲染管线](../Framework/Rendering.md)。背包、工坊与独立特效预览使用原 Renderer 1，不启用世界 Bloom。
- 粒子仅由宿主 `Tick` 推进；世界使用缩放时间，预览使用独立时间，暂停不自动推进。空格跳过战斗表现清理待播和活动世界粒子；场景/对象销毁释放。mesh/material 全实例引用计数共享，系统槽复用；单事件最多 64、每实例最多 1024、全局最多 4096 活粒子，超预算只降低表现。装备与场景粒子使用独立随机源。
- 菜单 `Project Y/特效/方块特效预览` 从原表列出全部效果，支持选取、重播、暂停、循环、缩放、重读与打开配置。它使用独立 PreviewScene 和 URP 渲染请求，不修改场景或保存资源。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/visual_effect_catalog.lua` 验证覆盖、唯一配置、分类继承、错误暴露及新增资源 `.meta` 的 32 位十六进制 GUID/Importer；错误 GUID 会使 Unity 忽略 Shader，导致 Resources 加载失败。`visual_effect_events.lua` 验证真实结算路由、逐发/拦截/失败、位移前坐标、拾取提交与楼层；`equipment_workbench_preview.lua` 回归真实装备预览查询。初次接入的这些检查及一次离线 C# 编译已通过；后续已修正 Shader 的无效 GUID，尚未完成实际 Shader/Bloom 视觉验收。

## 关键入口

- [效果库](../../Config/Tables/Adventure/VisualEffectTable.json) / [物品默认类别](../../Config/Tables/Equipment/VisualEffectItemCategoryTable.json)。
- [VisualEffectCatalog.lua](../../Lua/Game/Presentation/VisualEffectCatalog.lua)：配置校验和 C# 数据投影；数组桥接使用真实数组，避免只读代理的 raw length 为 0。
- [VisualEffects.lua](../../Lua/Game/Presentation/VisualEffects.lua)：有界事件队列；[AdventureVisualEffects.cs](../../Assets/GameFramework/Samples/Adventure/AdventureVisualEffects.cs)：场景坐标、命中时机和清理。
- [BlockParticleEffects.cs](../../Assets/GameFramework/Samples/Adventure/BlockParticleEffects.cs) / [BlockParticle.shader](../../Assets/GameFramework/Resources/Rendering/BlockParticle.shader)：图案、预算、随动与 HDR。
- [EquipmentEffectDisplay.cs](../../Assets/GameFramework/Samples/Adventure/EquipmentEffectDisplay.cs)：装备脉冲；[BlockEffectPreviewWindow.cs](../../Assets/GameFramework/Editor/BlockEffectPreviewWindow.cs)：独立预览。
