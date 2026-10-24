# 身体健康与创伤
关键词：创伤、伤势、伤害、身体健康、头部、躯干、四肢、永久致残、医疗、急救包、BodyHealth、InjuryRules。

## 文档目录
正文：状态与伤害 / 属性与治疗 / 界面与存档 / 验证；关键入口：数据 / 规则 / 配置 / UI。

## 正文

- `CombatActorData` 唯一持有六部位的当前/最大血量、创伤程度(0–100)、创伤类型、永久标记和恢复计划；`BodyHealth` 静态桥读写。稳定下标为头0、躯干1、左臂2、右臂3、左腿4、右腿5。角色 HP/MaxHP 都直接求六部位之和，不再维护另一份总血量。保留原属性公式的总上限，以头10%、躯干30%、四肢各15%分配，整数余量按最大小数余数及稳定下标分配。
- `GameEffects.Execute` 的直接技能命中先按 `BodyPartTable.weight` 选一处，再由 `BodyHealth.Hit` 扣该部位血量；溢出按其他部位当前血量比例分摊。单次攻击只检查最初选中部位的受击前状态，溢出不追加致残：第一次归零仍为红色，已空血部位再次直接受击才黑色永久致残。头/躯干同样沿用此规则，总HP归零才倒地；坐骑承担伤害时不伤骑手。持续伤害、事件通用伤害按当前血量分摊，不生成创伤/致残；零上限部位不参与选中。
- 血量与创伤独立。直接伤害无论创伤是否触发都会扣部位HP；非人形由 `CombatUnitTable.bodyInjuries=false` 保留普通伤害路径。`CombatEffectTable.injuryTypeId=0` 关闭该动作的随机创伤，空血再次受击仍可致残。普通回血按未致残部位缺血比例恢复、不会清创或复活；营地 Restore 可恢复倒地角色的可用部位，但不修复致残、不清创。无可恢复血量时回血物品不消耗。
- 创伤概率为 `min(95, floor(20 + 受击前部位缺血百分比*.65 + min(100,本次伤害/部位上限*100)*.2 + 动作injuryChanceBonus))`，同一战斗RNG先掷部位、再掷创伤。命中且触发后按实际伤害/部位上限×100×1.5×类型倍率累积12–45创伤；类型为挫伤、割裂伤、穿刺伤、烧伤。创伤达到100本身不致残；永久致残由部位空血后的再命中决定。读取、预览和治疗不掷骰。
- 显示和部位惩罚取“创伤程度、缺血百分比”中更严重者；非永久最高红色，黑色仅看永久标记。`CombatStats.Get` 在装备/成长/Buff之后按比例折减：头影响智力/侦察，躯干影响防御，手臂影响力量/武器熟练/巧匠，腿影响速度/移动。跨部位比例叠加，上限80%，非零惩罚后向下取整，不修改最大生命公式属性。`CombatStats.MoveRange` 覆盖玩家/AI/HUD，至少1格；骑乘使用坐骑距离。派生缓存以伤势Revision失效。
- `EquipmentSystem.TreatInjury` 在探索阶段校验队员、创伤、物资后，经 `BodyHealth.Treat` 消费共享背包物资；急救包91每次1个清除40创伤，不改变部位血量。无创伤、永久致残、物资不足不消费。既有战斗回血用途仍只补血；恢复失血和清除创伤需要分别处理。
- 疾病复用持久Buff和原存档：`DiseaseTable` 配置创伤后触发与药品，`DiseaseRules` 只查询/路由。首版新创伤有20%概率施加伤口感染11001，速度-2、防御-1，跨战斗和倒地保留，已有感染不重掷、不叠加。健康界面右下角用抗感染药190×1移除疾病；该命令不回血、不清创，药品不足不修改状态。药品来自初始背包及原商店模板，物品图标同步到 EquipmentAssetCatalog。
- 战士课程11630授予技能1630“创伤打击”：1级可学，消费一次学习机会，2AP主要行动、2回合冷却、近战1格、普通伤害倍率，动作1901额外提高35个百分点创伤概率（仍受95%上限限制）。需正常装备可用武器，沿用属性门槛、命中和技能事务；图鉴与说明表使用同一技能ID。
- 脚本指定的创伤可由 `BodyHealth.ScheduleRecovery` 登记恢复额度和绝对游戏分钟；`NarrativeSystem.TickBuffs` 同步调用 `AdvanceRecovery`。治疗优先消耗已登记额度，后续新伤不增加或延后原恢复，达到永久伤时取消计划。`CaptureBody/RestoreBody` 保存额度与到期值；旧档缺省0表示无恢复计划。健康详情显示预计小时与恢复额度；[神秘逃兵](SpecialEvents.md) 在正式入队后为初始五处创伤登记1/2/3日恢复。
- Inventory 装备预览右上角“身体健康”显示可点击六部位图，左/右以角色自身为准。右侧按部位HP/总HP、伤势说明、属性影响分段；每属性单独一行，数值减益红、增益绿。长内容用 `HealthDetailsScroll`；右下疾病有独立滚动区和用药按钮。切换部位/角色回到详情顶部，背包Tick同时观察部位和Buff Revision。所有组件由持久 LuaReference 绑定，沿用背包暂停/缓存及预览释放。
- 存档v23（仅队伍）/v24（完整远征）保存六部位HP及创伤，疾病沿用Effects。v21/v22保留创伤/致残/定时恢复，按原HP分配到可用部位；若旧HP超过未致残容量则截到容量。v1–v20先补无创伤记录，再分配原HP。新版本严格校验容量分配、HP求和、永久部位必须零HP及恢复计划；候选校验不改当前会话。总事务见[角色存档](CharacterSave.md)。
- 调整规则编辑所属源表并导表。`BodyHealthAssets.Sync` / `Project Y/装备/同步身体健康界面` 保存原生滚动区、疾病区和绑定，背包完整同步也调用它；不手改Prefab。静态文本、数值行完整模板和存档校验提示来自 Language/LuaTxt；固定文字同步 `ui-text-bindings.json`。

## 关键入口

- [BodyInjuries.cs](../../Assets/GameFramework/Runtime/Data/BodyInjuries.cs)：状态、治疗事务与快照校验；[InjuryRules.lua](../../Lua/Game/Battle/InjuryRules.lua)：触发、属性与显示快照。
- [BodyPartTable](../../Config/Tables/Adventure/BodyPartTable.json) / [InjuryStageTable](../../Config/Tables/Adventure/InjuryStageTable.json) / [InjuryTypeTable](../../Config/Tables/Adventure/InjuryTypeTable.json) / [InjurySettingsTable](../../Config/Tables/Adventure/InjurySettingsTable.json) / [InjuryTreatmentTable](../../Config/Tables/Adventure/InjuryTreatmentTable.json) / [DiseaseTable](../../Config/Tables/Adventure/DiseaseTable.json)：规则配置。
- [DiseaseRules.lua](../../Lua/Game/Battle/DiseaseRules.lua)：持久疾病、症状与用药事务。
- [BodyHealthPresenter.lua](../../Lua/UI/BodyHealthPresenter.lua) / [BodyPartGraphic.cs](../../Assets/GameFramework/Runtime/UI/BodyPartGraphic.cs) / [BodyHealthAssets.cs](../../Assets/GameFramework/Editor/BodyHealthAssets.cs)：界面、矢量轮廓与持久绑定。
- [定向集成检查](../../Tools/Tests/body_injuries_integration.lua) / [Edit Mode 宿主](../../Tools/Tests/body_injuries_editmode.cs)：真实伤害、移动/速度、治疗事务、界面生命周期、当前/旧档与非法数据；使用隔离 Services 和操作系统临时存档，不触碰用户存档。
- [预览脚本](../../Tools/Tests/body_health_preview.cs) / [实际 UI 预览](../../Docs/Previews/BodyHealth/BodyHealth.png)：真实 Prefab + Lua Presenter 离屏渲染，并检查文本高度；不进入 Play、不改当前场景。

定向集成已覆盖九组：整数血量求和/上限变化、归零后二次致残/溢出、低血量与创伤打击概率、持续伤害/坐骑/感染、实际学习与施放、普通回血/清创/定时恢复、疾病用药、真实UI滚动/颜色/装备回归、新旧存档与非法求和。未进入Play、未运行全量测试。预览检查真实界面和单个感染摘要的可见高度。
