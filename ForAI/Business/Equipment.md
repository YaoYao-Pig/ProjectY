# 装备与改装 Demo

关键词：装备、武器种类、等级、属性要求、单手剑、大剑、双手巨剑、推进器、槽位引线、法杖、符文、步枪、弹匣、搜刮、3D 改装、持握、EquipmentWorkbench。

## 文档目录

正文：入口 / 状态与规则 / 资源和配置 / 验证；关键入口：实现与产物。

## 正文

- 远征探索阶段按 `I` 或点侧栏“装备工坊”；选择队员、武器，点击模型外侧挂点标签安装/卸下组件。挂点标记经两段引线连到左右停靠标签，随模型旋转/缩放投影更新，同侧标签避让；左右侧由 EquipmentSocketTable.calloutSide 配置。面板使用现有 Panel/Widget、LuaReference、模态输入和暂停租约；关闭时释放离屏相机、模型、灯光与 RenderTexture。
- `AdventureData.Equipment` 是本次远征共享库存的唯一权威状态：独立武器实例、各有余弹的实体弹匣、堆叠符文/散装弹药。Lua EquipmentSystem 管理命令和掉落，EquipmentRules 解析技能与临时显示快照。重新开始远征清空库存；没有磁盘存档或网格背包。
- 初始八把未装备武器、两只满弹匣和散装弹药由 EquipmentDemoTable 配置。地牢入口附近按可达路径距离放置宝箱、地面符文和弹药；靠近一格后通过侧栏或 `E` 搜刮。宝箱含推进器，打开后同一远征重复进入不刷新。搜刮记录归 MapAreaStateData，战斗中禁止搜刮、换装和改装。
- EquipmentCategoryTable 定义种类；EquipmentWeaponTable 关联种类、level、damageMultiplier、requirementId、技能及持握模板。背包按种类/等级排序，用左右箭头筛选。单手剑、大剑、双手巨剑各两档、六把独立模型；单手剑/大剑没有改装槽，巨剑只有剑脊推进器槽。推进器作为通用组件复用 EquipmentRuneTable，匹配 thruster 槽与 slash 技能组，当前提高劈砍伤害 35%，不额外消耗 AP。
- 属性要求是软门槛：可照常装备，解析技能时通过 CombatStats.Get 读取含特质的当前属性。EquipmentRequirementTable 配属性 ID/需求值、每点缺口惩罚及上下限，EquipmentAttributeTable 映射属性名。当前每少一点属性伤害减 8%（最低保留 35%）、命中减 3 个百分点（最多减 40）；仅作用于该武器授予的技能，保留职业治疗/防御。伤害按基础技能 × 武器倍率 × 需求系数 × 组件倍率结算；工坊显示当前/需求和实际削弱。
- 散射头石使敌方法术最多选三名合法目标；追加目标位于主目标两格内，仍须满足施法者射程和视线，按距离/实例 ID 稳定选择，每目标 70% 伤害。精准杆石增加射程 2、命中 20 个百分点、伤害 25%、法术 CD 1。倍率相乘，其余加算；数值全部来自表。
- 枪械装备增加点射、连射、换弹技能，并替换模板基础攻击；防御和职业治疗保留。卸下 Demo 武器后恢复角色模板的初始武器、外观及技能。点射一发，连射三发，12 发实体弹匣。战斗换弹 2 AP，自动取兼容且余弹更多的备用弹匣，旧弹匣回背包并保留子弹。探索中点击背包弹匣可用散装弹药补弹；选择弹匣挂点装入/卸下不耗 AP。
- CombatSkillTable 配置技能组、命中、CD、自身回合、连击数、每发耗弹、伤害倍率和动作模板。命中用 BattleData 独立种子随机流；旧技能默认 100% 不掷骰。CD 在使用时写入，在自身回合开始减一，基础 CD 1 表示下个自身回合可用，精准后的 CD 2 需多等一次。每次战斗部署清 CD，弹药跨战斗保留。reload 是独立 self 效果，不能混入伤害效果链。
- 外观沿用低多边形纯色材质。八个武器 Prefab 显式绑定零个或多个挂点，EquipmentAssetCatalog 序列化资源和物品 Sprite。物品 iconPath 与技能 BattleIconTable.spritePath 空字符串表示留白。姿态、手肘/手掌位置、动作时长/抬手/后坐/俯仰/偏航/侧倾、工坊初始角度/缩放均配表；双手持握用 offHandFollowsWeapon 让副手跟随武器短动作。人物仍使用无骨骼的独立手臂网格。
- 配置在 `Config/Tables/Equipment/` 十三张表及 Adventure 的 CombatSkill/CombatEffect 表。修改后通过 ConfigEditor 导表；新增资源/挂点/图标执行 Edit Mode 菜单 `Project Y/装备/同步模型与改装界面`，需要当前 AdventureDemo。同步会定向补齐旧工坊的引线、分类按钮、属性文本和行 Layout 绑定，并保留其余人工布局。不得编辑 Prefab/importer YAML 或生成的 xLua 包装器。
- 最小验证：`equipment_integration.lua` 覆盖搜刮/符文/散射/CD/弹药与实际 Panel/Widget；`equipment_melee_integration.lua` 覆盖分类/两档武器、软门槛与特质、推进器合法性、伤害结算和筛选/空槽 UI，均在独立 Edit Mode LuaEnv 注入真实 FrameworkServices。`equipment_preview.lua` 是截图夹具，初始化后必须 Shutdown 并清除辅助全局函数。基础回归为 adventure_core.lua、battle_hud_core.lua；不自动进入 Play 或跑全量测试。

## 关键入口

- [权威库存](../../Assets/GameFramework/Runtime/Data/EquipmentData.cs) / [装备命令](../../Lua/Game/Equipment/EquipmentSystem.lua) / [技能与外观解析](../../Lua/Game/Equipment/EquipmentRules.lua)。
- [工坊控制器](../../Lua/UI/Panel/EquipmentWorkbenchCtr.lua) / [行 Widget](../../Lua/UI/Widget/EquipmentRow.lua) / [3D 预览](../../Assets/GameFramework/Runtime/UI/EquipmentWorkbenchView.cs)。
- [人物姿态与动作](../../Assets/GameFramework/Samples/Adventure/PawnEquipmentView.cs) / [武器挂点](../../Assets/GameFramework/Samples/Adventure/WeaponModelView.cs) / [资源同步](../../Assets/GameFramework/Editor/EquipmentAssets.cs)。
- [配置源](../../Config/Tables/Equipment/) / [法杖与枪源](../../Art/EquipmentDemo/Source/EquipmentDemo.blend) / [近战与推进器源](../../Art/EquipmentDemo/Source/EquipmentMelee.blend) / [制作脚本](../../Art/EquipmentDemo/Scripts/) / [Unity 资源](../../Assets/DynamicAsset/EquipmentDemo/) / [预览](../../Art/EquipmentDemo/Previews/)。
- [装备集成](../../Tools/Tests/equipment_integration.lua) / [近战集成](../../Tools/Tests/equipment_melee_integration.lua) / [预览夹具](../../Tools/Tests/equipment_preview.lua) / [当前检查记录](../../Art/EquipmentDemo/Integration/validation.md)；战斗生命周期见[战斗](Battle.md)，地图持久性见[MapArea](MapArea.md)。
