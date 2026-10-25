# 技能与物品方块特效
关键词：粒子、特效、VFX、方块、立方体、技能表现、物品拾取、装备发光、Bloom、VisualEffectTable、预览。

## 文档目录
正文：配置与扩展 / 播放与生命周期 / 验证；关键入口：配置 / 桥接 / 渲染 / 预览。

## 正文

- `VisualEffectTable` 是统一表现库，覆盖全部技能独立配置和物品表现。16种构图覆盖斩弧、刺线、爆裂、方环、盾片、螺旋、光束、抛物弧、落雨、十字、柱、散射、符文、碎片、牵引、足迹；颜色以外也配置数量、大小、半径、高度、寿命、速度和重力。尺寸使用米、寿命使用秒，emission 为颜色亮度乘数。
- 新技能必须填写 `CombatSkillTable.visualEffectId`，引用有效且未被另一技能复用的 profile。现有普通、养成、准备、物品、生活和地格技能使用相同入口。`VisualEffectCatalog.Snapshot` 在远征显示宿主启动时校验完整映射，不根据名称推断特效。
- 新物品的 `EquipmentItemTable.visualEffectId` 默认为0，按 `kind` 从 `VisualEffectItemCategoryTable` 自动继承；非0是明确覆盖。当前 weapon/rune/magazine/ammo/module/wearable/material/consumable 八类完整覆盖。新增 kind 要同时增加其类别配置；错误覆盖或缺类别明确失败。
- 职业内容生成器 `skill_visual` 要求先在效果库编写与技能同ID的独立 profile，基础、准备、生活及选项技能均使用自己的ID；重生成保留已有特效参数，禁止继承模板的引用。内容检查同时校验全部技能的 profile ID唯一，以及构图、数量、大小、尺寸和运动时序的组合差异，不能只换颜色通过检查。
- 配置源可通过已有配置编辑器维护；改动后运行 `node Tools/ConfigEditor/exporter.mjs`，不要手改 `_Gen`。改表后需重新启动读取配置的会话；预览窗“重读配置”只读取原 JSON，不给运行中的 ConfigSystem 热更新。
- `VisualEffects` 把已结算事实存入 Battle 所有的短期队列：最多 128 条，复制技能/物品身份、施放与实际落点、楼层、逐发序号和 hit/miss/cast/pickup/use。它不保存玩法状态、不掷玩法随机数、不进存档。`DemoBridge` 在命令/轮询快照中一次性 Drain；新战斗、重开、读档及关闭清理历史，战斗结束保留致死末发。
- `ProjectileCombat` 按真实目标/发次记录，每个技能的多个 Effect 不重复爆炸；实际拦截落在遮挡格，未命中落点偏离目标。准备、状态、治疗、消耗品、缴械、拾回、驯服、施工和位移有明确入口；位移前保存起点。拾取只在 `MapLoot.Take` 成功转移后记录，满包失败不播；探索角色坐标取 AreaState 成员地格。
- `AdventureVisualEffects` 在 MapArea 三维场景消费事件，按角色动作 `impactDelay` 和同源 `BattleFeedbackSystem.BurstHitInterval` 调度；技能弹道额外显示直线/抛物弧，实际命中使用各自 profile。楼层作为格子身份的一部分，跨场景释放。旧二维事件棋盘没有三维粒子宿主，消费但不显示这些世界粒子。
- 武器本体、已安装组件、穿戴物通过 `EquipmentRules` 的显示 DTO 携带同源 profile，模型与已有显式挂点持有 `EquipmentEffectDisplay`。展示采用低频、小规模脉冲，跟随武器/骨骼变换；场景、背包、工坊复用。粒子不参与角色拾取及预览模型 bounds。HUD 肖像仍按外观变化渲染，不为粒子增加持续截图。
- `EquipmentVisualProfileTable` 按 `assetId` 给任意装备绑定持续外观，独立于品质和传奇机制。`LegendaryEquipmentVisualAssets.SyncSelected(assetIds)` 在已有装备 Prefab 上编译显式 `EquipmentVisualProfileView` 绑定：只替换指定原材质槽，保留基础颜色／金属度／光滑度，以通用 `EquipmentArcane` Shader 增加模型局部流动光带和呼吸辉光；原始材质引用保留，重复同步先恢复再应用。变更源表后需重新同步对应 Prefab。
- 持续外观的时间仍由 `WeaponModelView.TickEffects`／`PawnEquipmentView.TickEffects` 推进，暂停不自动流动；刚性穿戴物在实例创建时缓存可选组件，盾牌同样适用。粒子构图／运动继承物品的 `visualEffectId`，只在已配置局部锚点重用既有 `EquipmentEffectDisplay`／`BlockParticleEffects`，替代该件默认脉冲，未另建粒子引擎。每个锚点至多8粒、每件至多4个锚点；与原粒子共用预算。
- 可选装备点光不投影阴影、范围至多3米；`EquipmentVisualProfileView` 在当前渲染相机回调按层、视锥和配置距离筛选最近的最多4盏，隐藏表面或禁用对象不照明。组件无独立 Update、无逐帧层级搜索；销毁／禁用释放粒子与光源注册。材质时间使用缓存的 PropertyBlock，不克隆运行时材质、不改共享材质或世界 Bloom。
- `BlockParticleEffects` 使用真实立方体 Mesh、HDR 顶点色和 Resources 中的 URP Shader；硬面明暗保留轮廓，不使用柔边圆粒子。颜色乘数超过 1 的魔法可进入现有世界 Bloom；不额外创建 Volume 或改风格参数，相关契约见[渲染管线](../Framework/Rendering.md)。背包、工坊与独立特效预览使用原 Renderer 1，不启用世界 Bloom。
- 粒子仅由宿主 `Tick` 推进；世界使用缩放时间，预览使用独立时间，暂停不自动推进。空格跳过战斗表现清理待播和活动世界粒子；场景/对象销毁释放。mesh/material 全实例引用计数共享，系统槽复用；单事件最多 64、每实例最多 1024、全局最多 4096 活粒子，超预算只降低表现。装备与场景粒子使用独立随机源。
- 角色手记选中技能时，由 `InventoryCharacterView` 持有独立 `BlockParticleEffects`，直接复制技能 profile，在动作命中时播放，直射/抛射复用 beam/arc 轨迹、多发间隔 .2 秒；不读取或写入世界事件队列。图片窗口内按 profile 尺寸缩放表现，旋转跟随预览模型，使用未缩放时间，所以手记暂停世界时仍播放。重复点击替换旧播放、关闭释放；具体快照与验证入口见[角色养成](Progression.md)。
- 菜单 `Project Y/特效/方块特效预览` 从原表列出全部效果，支持选取、重播、暂停、循环、缩放、重读与打开配置。它使用独立 PreviewScene 和 URP 渲染请求，不修改场景或保存资源。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/visual_effect_catalog.lua` 验证覆盖、唯一配置、分类继承、错误暴露及新增资源 `.meta` 的 32 位十六进制 GUID/Importer；错误 GUID 会使 Unity 忽略 Shader，导致 Resources 加载失败。`visual_effect_events.lua` 验证真实结算路由、逐发/拦截/失败、位移前坐标、拾取提交与楼层；`equipment_workbench_preview.lua` 回归真实装备预览查询。初次接入的这些检查及一次离线 C# 编译已通过；后续已修正 Shader 的无效 GUID，尚未完成实际 Shader/Bloom 视觉验收。

## 关键入口

- [效果库](../../Config/Tables/Adventure/VisualEffectTable.json) / [物品默认类别](../../Config/Tables/Equipment/VisualEffectItemCategoryTable.json)。
- [职业内容生成器](../../Tools/ProfessionExpansion/build_content.py) / [内容检查](../../Tools/ProfessionExpansion/validate_content.mjs)：新增技能独立特效的生成约束与源表检查；特效参数仍以效果库源表为准。
- [VisualEffectCatalog.lua](../../Lua/Game/Presentation/VisualEffectCatalog.lua)：配置校验和 C# 数据投影；数组桥接使用真实数组，避免只读代理的 raw length 为 0。
- [VisualEffects.lua](../../Lua/Game/Presentation/VisualEffects.lua)：有界事件队列；[AdventureVisualEffects.cs](../../Assets/GameFramework/Samples/Adventure/AdventureVisualEffects.cs)：场景坐标、命中时机和清理。
- [BlockParticleEffects.cs](../../Assets/GameFramework/Samples/Adventure/BlockParticleEffects.cs) / [BlockParticle.shader](../../Assets/GameFramework/Resources/Rendering/BlockParticle.shader)：图案、预算、随动与 HDR。
- [EquipmentEffectDisplay.cs](../../Assets/GameFramework/Samples/Adventure/EquipmentEffectDisplay.cs)：装备脉冲；[BlockEffectPreviewWindow.cs](../../Assets/GameFramework/Editor/BlockEffectPreviewWindow.cs)：独立预览。
- [装备持续外观源表](../../Config/Tables/Equipment/EquipmentVisualProfileTable.json) / [EquipmentVisualProfileView.cs](../../Assets/GameFramework/Samples/Adventure/EquipmentVisualProfileView.cs) / [通用辉光 Shader](../../Assets/GameFramework/Resources/EquipmentArcane.shader) / [外观同步工具](../../Assets/GameFramework/Editor/LegendaryEquipmentVisualAssets.cs)：先导入基础装备 Prefab，再按 assetId 定向同步；普通装备亦可绑定。首次15件源表已完成材质名／锚点形状静态检查，实际 Shader 编译及 Unity 预览由本次集成步骤另行验证。
