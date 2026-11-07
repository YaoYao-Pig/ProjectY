# 单位特质与侦察详情
关键词：特质、侦察、感知对抗、单位详情、敌人情报、遇敌解锁、技能使用发现、NPC 属性、未知信息、问号、UnitInspection、UnitDetails。

## 文档目录
正文：特质与信息范围 / 检定与消耗 / 身份与保存 / 验证；关键入口：规则 / 目标 / UI / Data。

## 正文

- 特质复用 `CombatTraitTable`、`CombatUnitTable.traitIds` 和已有成长档案；它们参与真实属性与战斗计算。队伍中已招募成员及其所属动物的属性和特质全部已知，其他单位只能读取已揭示字段。养成和招募本身分别见[角色养成](Progression.md)、[NPC](Narrative.md)。
- 当前可见敌人或接触的世界队伍自动揭示生命、行动力、护卫、施法点四组资源；进入共享快照时记录，无需打开详情。详情页可见居民也遵循同一资源规则。被动发现不投骰、不扣 AP/时间、不占侦察机会，离开视野仍保留知识；速度、防御等数值属性和特质继续侦察。
- 技能按单位实例的 `skill:<id>` 保存：`Battle:ObserveSkillUse` 在执行前抓取详情目标列表的可见性及稳定身份，成功后提交；失败指令、不可见单位和仅浏览不解锁。借机攻击、多目标、格子、落点及容器技能共用此入口，最后一击清场也保留使用前身份。此可见性沿用详情列表，不额外执行特殊技能领悟模块的逐角色视线检定。
- 详情页在特质栏下列出技能，未使用的名称/说明为问号；已发现但当前技能集合中不再提供的技能仍可查看。己方技能全部已知。战斗 HUD 与共享快照只输出已知技能，过滤不改变敌方 AI 的真实技能集合；技能说明读取 `CombatSkillTable` 的本地化正文。
- 主 HUD 菜单的“单位详情 · 侦察”打开 `UnitDetails`，战斗行动序列卡可打开对应单位；浏览、切换目标/观察者和重开页面不投骰、不扣费。未知属性名称与数值、特质名称与说明均显示 `？？？`，战斗 HUD 的相关数值也遵循同一已知状态。
- 探索中可选存活队员；战前准备及战斗中只允许当前行动的己方队员。检定为双方各掷 `d20 + floor(实时侦察 scouting)`，使用独立随机流；平局或较低总值失败。胜差为 1–4／5–9／10–14／15–19／≥20 时依次揭示侦察池的 20%／40%／60%／80%／100%，向上取整。侦察池只含属性和特质，不含四组自动已知资源及技能；失败保留所有已有知识。
- 揭示顺序保持原字段序列去掉四组资源后的顺序：侦察、速度、防御、其他属性按配置 ID，特质按 ID 交错排列。生命、行动力、护卫、施法点分别是 `health/actionPoints/guard/casting` 分组，其余字段为 `attribute:<code>` 或 `trait:<id>`。保存字段身份，不保存某次显示数值；已知值随真实状态更新。
- 每个世界中每个目标全队仅能检定一次，失败也永久占用机会。探索检定消耗 5 游戏分钟，战前与战斗检定消耗 1 AP 次要行动；提交前重新核对目标可见性、观察者、首次机会和行动预算，拒绝时不掷骰或消费资源。打开详情本身不是行动。
- 目标列表包含已招募成员、所属动物、区域当前可见敌人与居民，以及大地图正在接触的世界队伍；不借详情页查看战争迷雾外的单位。普通居民由[世界人物](People.md)保存真实角色，`UnitInspectionNpcTable`映射其创建模板，探测与招募共享实例；剧情NPC继续复用原配置及固定招募身份的只读投影。详情新增独立交谈入口，观察按钮的投骰、消耗及一次机会契约不变。
- 身份键区分实例：剧情/传奇 NPC 为 `npc:<npcId>`，普通居民为 `resident:<siteId>:<stableId>`，持久敌人为 `actor:<actorId>`；旧临时事件敌人追加地点/事件/选项上下文，决斗追加地点/游戏日，避免复用临时 ID 串用观察结果。招募后仍按同一 NPC 身份查询，但己方直接全知。
- 唯一可变观察状态归 `AdventureData` 的 `UnitInspectionData`；静态反射桥 `UnitInspections.Get/Prepared` 提供访问，不修改生成 wrapper。`Reveal` 合并免费发现，`Observed` 区分是否用过检定；只有被动知识的记录观察者/骰点/胜差为零，`Count` 包含这类记录。检定结果与后续技能发现互相保留，历史观察者离队或死亡不清除全队知识。内层格式 2 兼容格式 1 的原检定记录，新世界重置；换图/战斗重建/读档不重掷。保存事务见[角色存档](CharacterSave.md)。
- C# 预检拒绝缺记录、非法格式/RNG、重复目标/字段与无效身份；Lua 继续核对已知属性和特质仍存在于当前配置。旧档迁移为空知识，不凭当前装备、模板或招募状态补做检定。
- 旧1–42档另有一次固有特质迁移：在独立 prepared 状态中遍历完整已招募编组、所属动物、区域敌群及世界编制，按真实实例去重，仅补模板中本次新增的7–11号特质，不补回傲慢、孤僻等经历特质。只在原生命上限有效时重算上限，沿身体系统保留部位伤害、创伤和零生命/死亡状态，并同步受影响世界成员的 LOD 战力；全部完成后才进入正常校验和提交。
- 定向检查覆盖规则边界、旧档迁移、配置身份、HUD 遮罩、C# 记录和 RNG 往返。原生检查在隔离 PreviewScene 中使用真实 Prefab、按钮、规则与 C# Data，验证免费浏览、一次性提交、探索/部署/战斗扣费、关闭释放输入和暂停；存档检查使用独立临时目录验证完整启动、真实居民投影及 Save/Prepare/Validate/Apply。当前这些定向检查已通过，未进入 Play；不代替实际游玩验收，也不自动授权启动 Editor 或全量测试。
- 本次资源/技能发现改动已通过离线规则、目标可见性、配置身份、HUD 遮罩、特殊技能调用入口回归及编译后托管数据往返检查；原生 UI/完整存档集成脚本已同步规则但本次未重跑，未进入 Play。

## 关键入口

- [UnitInspection.lua](../../Lua/Game/Adventure/UnitInspection.lua)：`CanObserve/Observe/Build/Known`；[UnitInspectionTargets.lua](../../Lua/Game/Adventure/UnitInspectionTargets.lua)：目标可见性、身份和居民投影；[居民映射](../../Config/Tables/Adventure/UnitInspectionNpcTable.json)。
- [UnitDetailsCtr.lua](../../Lua/UI/Panel/UnitDetailsCtr.lua)：详情页；[MainHudCtr.lua](../../Lua/UI/Panel/MainHudCtr.lua)、[BattleHUDContent.lua](../../Lua/UI/Widget/BattleHUDContent.lua)：菜单与行动序列入口；[BattleHUDModel.lua](../../Lua/Game/Battle/BattleHUDModel.lua)：战斗投影。
- [UnitInspectionData.cs](../../Assets/GameFramework/Runtime/Data/UnitInspectionData.cs)：一次性记录、独立随机和保存；[CharacterSave.lua](../../Lua/Game/Adventure/CharacterSave.lua)：`ValidateInspections` 当前配置预检。
- [UnitTraitMigration.lua](../../Lua/Game/Adventure/UnitTraitMigration.lua)：旧档固有特质的 prepared 迁移；[迁移检查](../../Tools/Tests/unit_trait_migration.lua)：共享实例、后备/动物、伤害/死亡保留、幂等与坏数据拒绝。
- [规则检查](../../Tools/Tests/unit_inspection.lua)、[配置存档检查](../../Tools/Tests/unit_inspection_save.lua)：使用 `Tools/Tests/run_lua.py`；[托管数据检查](../../Tools/Tests/unit_inspection_data.ps1)：传入已有 `Assembly-CSharp.dll`，不编译、不访问玩家存档。
- [原生资源安装](../../Tools/UI/build_unit_details.cs)：通过 Unity MCP 保存两个 Prefab、绑定、注册与语言清单；[原生 UI 检查](../../Tools/Tests/unit_details_editmode.cs) 调用 [Lua 按钮检查](../../Tools/Tests/unit_details_ui.lua)，生成 [未知信息预览](../../Docs/Previews/UnitDetails/unknown.png)。[真实保存服务检查](../../Tools/Tests/unit_inspection_integration_editmode.cs) 调用 [完整启动及读写检查](../../Tools/Tests/unit_inspection_integration.lua)；[信息遮罩检查](../../Tools/Tests/unit_inspection_visibility.lua) 覆盖战斗日志、行动条和共享快照。
