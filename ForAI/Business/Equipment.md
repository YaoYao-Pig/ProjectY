# 装备与改装 Demo

关键词：装备、品质、单词缀、附魔、缴械、耐久、维修、武器种类、扩充槽位、四槽工坊、握柄、柄尾配重、弓臂、弓弦、枪口、枪托、触媒、符文、转施、3D 改装、EquipmentWorkbench。

## 文档目录

正文：入口 / 状态与规则 / 资源和配置 / 验证；关键入口：实现与产物。

## 正文

- 正式远征使用 `AdventureDemoTable.equipmentRecipeId → EquipmentDemoTable`；配方 1 保留完整装备演示，配方 2 仅提供三人基础主武器、少量治疗/营造物资、撬棍和火炬。`equipUnitIds/equipWeaponIds` 指定自动穿戴，`StarterWeapons.Plan` 先检查成员唯一性、属性、背包原实例和角色默认装备冲突，随后只移动实例，不重复发放；读档不执行此初始化。最小检查为 `Tools/Tests/campaign_equipment.lua`。

- 宝箱生成、概率池、敌人死亡掉落、满包保留及事件战后拾取见[宝箱与敌人掉落](Loot.md)；EquipmentSystem 的搜刮门面委托 `Game.Loot.MapLoot`，装备与背包仍负责实际授予事务。

- 武器、防具和戒指每个实体持有一个品质词缀 ID；`EquipmentAffixTable` 定义类型池、相对权重、伤害倍率、命中百分点及有符号穿戴属性，1 固定为无修正的普通。首批 12 种名称、13 行（破损按武器/防具拆行），普通不加名称前缀；权重 0 仅停止随机生成，不使已有实例失效。无独立稀有度层或重铸入口。
- 词缀表 `color` 配置显示色，支持带或不带 `#` 的 3/4/6/8 位十六进制；`EquipmentAffixes.NormalizeColor` 校验并展开短色号，非法值直接报错。`EquipmentPresentation` 统一生成“● 名称”富文本和分组详情，名称跟随品质色，正负数值、要求达标状态、标题/数值/注释按颜色与字号区分。`Affixes:Name` 仍返回纯文本供日志与业务使用。
- `EquipmentSystem.OnInit` 通过 `EquipmentAffixes:Define` 将各物品的适用池注册到 C#；独立构造 EquipmentData 的工具/夹具也必须先注册，再授予装备。所有新武器/防具统一由 C# 按远征种子、实例 ID 和物品 ID 加权确定词缀；初始装具、奖励、商店购买和敌装共用此入口。商店销售模板，列表明确标注“随机词缀”，购买成功时生成。
- 宝箱生成时 `MapLoot:Add → Prepare → EquipmentAffixData.PrepareLoot` 建立未领取的完整武器/防具实体；重复 Prepare 幂等，搜索与拾取不重抽。双向存取、缴械、捡起和维修均保留同一实体及词缀。耐久归零显示“已损毁”，与“破损”品质区分；读档保留词缀，旧档迁移见[角色存档](CharacterSave.md)。
- 武器伤害/命中词缀只作用于对应武器的攻击，触媒法术取实际选中的触媒且只应用一次；防御、治疗等不要求触媒的固有动作和换弹不获得武器词缀。伤害倍率与既有倍率相乘，命中在所有修正后限制为 0–100。穿戴属性先合并装备基础值与词缀，再乘耐久效能并按绝对值四舍五入；损毁时正负属性都归零，装配硬门槛仍排除全部装备加成。背包显示基础值、品质修正与当前穿戴值，工坊和已搜索战利品显示品质名称/详情，不新增 LuaReference 绑定。

- 远征探索阶段按 `I` 或点侧栏“背包与装备”，从[网格背包](Inventory.md)右下进入武器工坊；选择队员、武器，点击模型外侧挂点标签安装/卸下组件。挂点标记经两段引线连到左右停靠标签，随模型旋转/缩放投影更新，同侧标签避让；左右侧由 EquipmentSocketTable.calloutSide 配置。面板使用现有 Panel/Widget、LuaReference、模态输入和暂停租约；关闭时释放离屏相机、模型、灯光与 RenderTexture。
- `AdventureData.Equipment` 是本次远征实际装备的唯一权威状态：玩家背包、双方已装备武器/防具、实体弹匣和堆叠物共用实例 ID 空间；只有共享背包物品占 `Grid`，敌有物不在背包/工坊列表中。`InitialLoadout:ApplyEnemy` 在敌人首次生成时直接建立装备，不占玩家容量，之后重入不补发；敌模板 4/5 的身甲与主手由 `CharacterLoadoutTable` 配置。Lua EquipmentSystem 管理命令，EquipmentRules 解析实际装备的技能、属性和外观，双方不再从模板伪造武器。重新开始远征清空库存；[角色存档](CharacterSave.md)仅保留队伍和背包范围。
- `EquipmentConditionData` 随武器/防具实体保存当前耐久、当前上限、初始上限与阈值标记，初始 100。耐久从当前上限的至少一半跌到不足一半时，永久扣初始上限 5%（最低 20）；同次损伤不重复扣，修复后重新允许越阈值扣减。效能为 `(当前上限+当前耐久)/(2×初始上限)`，耐久 0 为 0；武器技能倍率与防具属性按效能计算，防具属性取最近整数。破损武器不授予攻击、不能当触媒；已学技能保留身份但仍受实际武器/触媒条件限制。
- 背包选中装备后用“维修”消费铁件 83 和金币：每缺 25 点耐久需 1 铁件（向上取整），每缺 1 点需 1 金币。`EquipmentSystem:Repair/RepairQuote` 统一预算；C# 先检查材料、金币与物品，再一起提交，恢复到当前上限，永久损伤不恢复。耐久引发的 HP 上限重算保留伤势且不会抬高当前 HP。按钮由 `EquipmentRepairAssets.Sync` 持久绑定，常规 `InventoryAssets.Sync` 也包含该步骤；不在业务 Lua 查找子节点。
- 真实装备转移和保甲掉落见[战利品](Loot.md)。501 缴械、502 精确刺击由铁剑 40/骑士剑 41 授予；503 拾取武器与无有效主手时的 504 徒手攻击为人形通用战斗动作。缴械优先主手、否则副手；双方均失去同一实体武器及其技能/外观。`CombatSkillTable.weaponWear` 控制每发使用损耗，`CombatEffectTable.equipmentDamage/killEquipmentDamage` 控制身体甲、头盔、盾牌受击及致死附加磨损，精确刺击为 0，火焰与重击较高。
- 初始九把未装备武器（含长弓）、两只满弹匣、散装弹药和七件未穿戴防具（含盾牌）由 EquipmentDemoTable 配置。地牢入口附近按可达路径距离放置宝箱、地面符文和弹药；靠近一格后通过侧栏或 `E` 搜刮。宝箱含推进器，打开后同一远征重复进入不刷新。搜刮记录归 MapAreaStateData，战斗中禁止搜刮、换装和改装。
- 配件也可在城镇铁匠服务台按 E 购买；商店供应散装弹药和实体满弹匣。价格、数量与物品由[事件选项](Adventure.md)配置，共用 `CanGrant/Grant` 容量检查和唯一库存；背包不足或金币不足不扣费。成功搜刮/购买进入游戏内【获得】日志。
- EquipmentCategoryTable 定义种类；EquipmentWeaponTable 关联种类、level、damageMultiplier、requirementId、技能及持握模板。工坊列表按种类/等级排序，用左右箭头筛选。挂点以每件武器的 `socketIds` 为准；30把非staff武器已统一补齐下表组合，原始大剑42/43、长弓46及旧工具也具备改装槽。推进器仍复用 EquipmentRuneTable，匹配thruster槽与slash技能组，不新增物品实例类型。

| 分类／武器ID | 最终槽位组合 | 数量 |
| --- | --- | --- |
| 步枪：2、604–606 | magazine＋rail＋muzzle＋stock | 4 |
| 单手剑：40–41、607–609 | catalyst＋edge＋grip＋pommel | 4 |
| 双手大剑：42–43、610–612 | edge＋grip＋pommel | 3 |
| 双手巨剑：44–45、613–615 | thruster＋edge＋grip＋pommel | 4 |
| 弓：46、616–618 | rail＋bowlimb＋bowstring | 3 |
| 工具：70–74、619–620 | edge＋grip＋pommel | 3 |

- 新增73个挂点201–273，只向已有 `socketIds` 尾部追加；旧39个挂点的ID、顺序和定义保留，已安装配件继续按旧ID解析。四把法杖1/601–603不改槽。新类型 `grip/pommel/bowlimb/bowstring/muzzle/stock` 各有两件配套组件；每个类型只装匹配的配件，弹匣仍为单一实体仓位。坐标由[新槽位放置脚本](../../Art/SocketExpansion202610/Scripts/place_sockets.py)依据实际Unity武器根局部bounds生成，仅调整新增挂点，每侧最多两枚引线标签。
- 工坊支持4槽，按钮及Socket4/SocketText4的LuaReference、四套引线均已持久绑定；工作缓存按绑定数组长度初始化，配置超过容量或同侧超过2个标签时明确报错。`EquipmentAssets.SyncWorkbenchSlots`只升级已有工坊挂点，保留其他布局；武器挂点在原Prefab内增补，保留旧组件及挂点身份。[原生UI检查](../../Tools/Tests/workbench_four_slots_editmode.cs)验证第四槽装卸、4→2→3→4切换与标签避让，[实际装配](../../Art/SocketExpansion202610/Integration/validate_unity.cs)验证30武器/172个兼容组合；均在隔离Edit Mode完成，未进入Play。
- 武器 `tagIds` 按展示顺序引用 EquipmentWeaponTagTable 的稳定字符串 ID；同一武器可有多个标签，和分类筛选、持握 `kind/hands` 独立。`EquipmentRules:WeaponTags(itemId)` 返回标签行，`HasWeaponTag(itemId,tagId)` 查询单个标签；未知或重复标签报错。工坊详情顶部通过 EquipmentTag Widget 逐个展示并自动换行，切换武器时复用并隐藏多余标签。现有大剑/巨剑包含“双手剑”，巨剑另有“巨剑”标签；标签的工具分类、清障和开锁见[工具武器与临时障碍](ToolWeapons.md)。
- 工坊用 `EquipmentRules:PreviewWeapon` 建立所选单件武器的只读查询上下文，技能和动作不混入角色真实副手/盾牌；属性要求仍读取所选角色当前属性，符文继续读取所选武器实例。浏览不修改装备所有权、背包或 Revision，实际装备仍走 HandAllowed 的双手冲突检查。回归：`python -B Tools/Tests/run_lua.py Tools/Tests/equipment_workbench_preview.lua`，覆盖持盾/双持时浏览所有武器及直接预览副手实例。
- 装配不限制职业，武器和防具通过 `EquipmentRules:CanEquip(actor,itemId,stats)` 校验属性硬门槛；读取 `CombatStats:Get(actor,name,true)`，计入基础、成长、特质与状态，排除全部装备加成。`EquipmentRequirementTable` 定义门槛，`EquipmentWearableTable.requirementId` 也引用该表；现有轻型防具使用无额外门槛的规则 46。工坊按钮、背包装配预览和命令、开局/招募初始装具使用同一查询。初始装具整组预检后才授予；不合法配置明确失败。
- 已装备后属性下降或旧档不达新门槛，不自动卸装；武器技能仍按包含穿戴加成的实时属性计算原有软惩罚。当前每少一点属性伤害减 8%（最低保留 35%）、命中减 3 个百分点（最多减 40）；只作用于该武器授予的技能。伤害按基础技能 × 武器倍率 × 需求系数 × 组件倍率结算，工坊分别显示装配门槛与已装备削弱。
- 施法条件由 `CombatSkillTable.catalystKind` 配置，`none` 无要求，`arcane` 要求有效触媒；`CheckSkillEquipment(actor,skill,stats)` 返回可用性、原因及实际触媒。法杖由 `EquipmentWeaponTable.catalystKind` 原生提供 arcane；适配器物品 93 装入剑的 catalyst 槽后，要求 `EquipmentRuneTable.requiredTalentId=301`（奥术兵装）才能提供触媒。专精复用角色持久化天赋等级，不检查当前职业。查询按主手优先、副手其次，敌人同样读取实际主副手及配件提供的触媒；技能身份不因装备丢失，模板固有法术也不被基础攻击替换表删除。法术组件效果取实际选中的触媒，普通武器攻击仍取对应武器。
- 武器601–620与配件701–720沿用七种分类（法杖/步枪/单手剑/双手大剑/双手巨剑/弓各3，工具2），共23个装备专属技能1601–1623、4个新Buff、60个可复用效果。武器保留原类别基础攻击与换弹，专属技能仅用于battle；所有技能有图鉴节点，但不加入研习池。商店均可补货，8件进入现有加权掉落池。`EquipmentWeaponTable.description` 在背包显示用途，独特技能仍由实际装备决定。
- 新 `rail/edge` 挂点供具有对应槽的枪弓/近战武器使用，旧四种槽不变；`EquipmentRuneTable.skillGroup=physical` 同时匹配weapon/slash。技能本身可配置 `maxTargets/splashRadius`，与配件取较大覆盖值，不逐件累加目标数；默认自动追加目标仍须满足主目标邻域、自身射程与合法弹道。追踪手选及概率遮挡见 [战斗](Battle.md)。命中自疗、护卫、标签条件、状态消耗与驱散契约归 [GameEffect](GameEffects.md)，不在武器ID上写特判。
- 扩展配件 501–530 包含杖头10、杖身8、巨剑机械组件8、剑用触媒4；复用 `EquipmentRuneTable` 和现有四类挂点，不增加物品实例类型。`onHitEffectIds` 只追加到匹配技能组的对敌伤害技能，纯状态/治疗/自身技能不触发；继续使用命中后的概率与 Buff 执行器。射程/命中/冷却允许负向取舍，结算将敌方技能射程限制至少1、命中0–100、冷却不低于0；不修改共享技能行。背包配件详情显示挂点、数值、触发概率与专精要求。
- 30件均加入杂货商店独立补货池，其中5件也作为[旅行事件](Adventure.md)奖励。设计与可编辑模型在 `Art/EquipmentExpansion202610`，Unity FBX/图标在 `Assets/DynamicAsset/EquipmentExpansion202610`；物品/资源ID一一对应，图标由真实模型渲染。现有武器挂点与存档格式继续复用。
- 分类槽组件730–741均为 `module`，通过 `EquipmentRuneTable.skillGroup=physical` 同时作用于weapon/slash；倍率、命中、射程、CD和目标上限继续走既有规则。护手织带复用1350的自身护卫至少2点，汲血配重复用1358的存活流血目标自疗，破甲枪口复用1359的小额伤害/装备磨损；潮线弓弦用1362以40%概率施加已有潮湿Buff，不另建状态系统。12件均进入商店模板1独立补货，731/734/737/738另入现有加权池5，不增加抽取次数。逐件实际作用与取舍见[制作清单](../../Art/SocketExpansion202610/README.md)。
- 散射头石使对敌法术目标上限至少三名，默认自动从主目标两格内按距离/实例ID选取合法目标，每目标70%伤害；具备追踪手选能力时使用 [战斗](Battle.md) 的显式目标列表。精准杆石增加射程2、命中20个百分点、伤害25%、法术CD1。倍率相乘，其余加算；数值全部来自表。
- `CombatSkillTable.allowTransfer` 是自身法术的显式白名单；`EquipmentRuneTable.transferSelf/transferRange` 独立于伤害命中附加效果。`EquipmentRules:Skill` 保留原技能身份及消耗，在常规组件处理后把允许转施的self法术改为any和固定距离；普通rangeBonus不会继续扩大转施距离。配置要求原目标self、spell组、非item、效果全部recipient=target且属于可转向的状态/治疗/护卫/清除动作；换弹、拾武、道具及source收益不会因此改接收者。准备技能仍只能在准备阶段使用。
- 转施符文石721装在shaft槽，与head散射组件可同时存在；固定4格内可选自己、队友或敌人，当前白名单为追踪术1624、战场祈愿508、奥术凝聚403。追踪术由法杖1/601–603授予，也可在法师职业课程中学习，并登记同ID图鉴节点；Buff生命周期归 [GameEffect](GameEffects.md)。符文由商店模板1补货、加权掉落池5获取。物品复用资产3与Item_12.png，新增物品ID仍须通过 `EquipmentAssets.SyncItemIcons` 保存到Catalog，不能仅填写已有图片路径。
- 枪械装备增加点射、连射、换弹技能，并替换模板基础攻击；防御和职业治疗保留。卸下或损坏主武器后获得弱近身徒手攻击，不恢复模板射击/斩击；外观只显示实际穿戴物，详见[背包](Inventory.md)。点射一发，连射三发，12 发实体弹匣。战斗换弹 2 AP，自动取兼容且余弹更多的备用弹匣，旧弹匣回背包并保留子弹。共享背包只供己方换弹；敌人捡到枪械后可使用枪上原有余弹，不能读取或消耗玩家备用弹匣。探索中点击工坊库存列表的弹匣可用散装弹药补弹；选择弹匣挂点装入/卸下不耗 AP。
- CombatSkillTable 配置技能组、命中、CD、自身回合、连击数、每发耗弹、伤害倍率和动作模板。命中用 BattleData 独立种子随机流；旧技能默认 100% 不掷骰。CD 在使用时写入，在自身回合开始减一，基础 CD 1 表示下个自身回合可用，精准后的 CD 2 需多等一次。每次战斗部署清 CD，弹药跨战斗保留。reload 是独立 self 效果，不能混入伤害效果链。
- 外观沿用低多边形纯色材质。武器 Prefab 按配置显式绑定零个或多个挂点，EquipmentAssetCatalog 序列化资源和物品 Sprite。物品图标由[模型图标管线](Inventory.md)生成或手工指定；技能 BattleIconTable.spritePath 空字符串表示留白。[持武模组与握点](EquipmentMotion.md)按双手装备匹配模组，EquipmentPoseTable 提供基准姿势，EquipmentGripTable 配每件武器的本地握点；公共棋子已使用 [Humanoid 动画与握点求解](PawnAnimation.md)，无动画绑定的外观保留原刚体显示。动画时长和轨迹由 PawnAnimations.asset 调整，装备规则仍使用同一份物品/技能表。
- 配置在 `Config/Tables/Equipment/` 的装备表及 Adventure 的 CombatSkill/CombatEffect 表。修改后通过 ConfigEditor 导表；新增资源/挂点/图标执行 Edit Mode 菜单 `Project Y/装备/同步模型与改装界面`，需要当前 AdventureDemo。同步会定向补齐旧工坊的引线、分类按钮、属性文本和行 Layout 绑定，并保留其余人工布局。不得编辑 Prefab/importer YAML 或生成的 xLua 包装器。
- 最小验证：`equipment_integration.lua` 覆盖搜刮/符文/散射/CD/弹药与实际 Panel/Widget；`equipment_melee_integration.lua` 覆盖分类/两档武器、软门槛与特质、推进器合法性、伤害结算和筛选/空槽 UI，均在独立 Edit Mode LuaEnv 注入真实 FrameworkServices。`equipment_preview.lua` 是截图夹具，初始化后必须 Shutdown 并清除辅助全局函数。基础回归为 adventure_core.lua、battle_hud_core.lua；不自动进入 Play 或跑全量测试。
- 标签 UI 单独同步入口为 `Project Y/装备/同步武器标签界面`（`EquipmentAssets.SyncWeaponTagsUI`），只注册标签 Widget 并更新工坊绑定；全量装备资源同步也会包含它。标签数据回归复用 `equipment_workbench_preview.lua`，实际 Widget 的多标签→单标签→多标签切换复用 `equipment_melee_integration.lua`。
- 触媒配件复用既有 RunePrecision 模型（资产 3）及 Item_12 图标，无新 FBX；剑新增挂点需通过 `EquipmentAssets.SyncSelected(new[]{40,41},new int[0])` 保存到实际 Prefab，并调用 `SyncItemIcons()` 注册物品 93 的已有 Sprite。离线检查 `equipment_catalyst_core.lua` 覆盖主副手触媒、专精、属性硬门槛与事务；`equipment_catalyst_integration.lua` 验证真实库存及工坊，仍须独立 Unity 宿主。

- `EquipmentWeaponTable.onHitEffectIds` 引用共享效果动作，附加到实际主/副手的物理攻击（包含已研习的 weapon/slash 技能），法术和支持动作不继承；不修改共享技能行。命中后由 [GameEffect](GameEffects.md) 处理概率、状态互斥和计时，技能自身也可直接引用同一动作。

## 关键入口

- [装备展示格式](../../Lua/Game/Equipment/EquipmentPresentation.lua) / [原生样式同步](../../Assets/GameFramework/Editor/EquipmentPresentationAssets.cs)：Edit Mode 菜单 `Project Y/装备/同步品质与装备详情样式` 定向保存 Inventory、Loot、EquipmentWorkbench、EquipmentRow；常规生成入口也复用同一升级方法。背包与搜刮详情使用实际 ScrollRect/ContentSizeFitter，复用原 `ItemDetail` 绑定，不新增运行时节点搜索。相关四个 Prefab 已于 2026-10-15 同步保存；本轮未进入 Play 验收。

- [品质词缀表](../../Config/Tables/Equipment/EquipmentAffixTable.json) / [品质配置规则](../../Lua/Game/Equipment/EquipmentAffixes.lua) / [实体词缀与生成桥接](../../Assets/GameFramework/Runtime/Data/EquipmentAffixData.cs)。最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/equipment_affix_core.lua`；[真实 C# 数据检查](../../Tools/Tests/equipment_affix_data.ps1)接收 `-AssemblyPath`，仅加载已编译程序集，覆盖确定性生成、容器事务、维修/缴械、存档实体往返及无效词缀拒绝，不启动 Editor、不编译、不读写用户存档。实际 UI 与完整 JsonUtility 旧档迁移仍需现有 Unity 宿主验收。

- [耐久实体](../../Assets/GameFramework/Runtime/Data/EquipmentConditionData.cs) / [战斗装备转移与维修事务](../../Assets/GameFramework/Runtime/Data/EquipmentCombatState.cs)。定向离线检查 `python -B Tools/Tests/equipment_salvage_core.py` 直接读取源表；[真实实例检查](../../Tools/Tests/equipment_salvage_integration.lua) 覆盖阈值、维修事务、缴械实体/余弹、满包拒绝、重复领取与 HP 重算，需现有 Unity 独立宿主，不由离线检查启动 Editor。

- [十月物品与武器资产库](../../Art/AssetExpansion202610/README.md) / [可浏览档案](../../Art/AssetExpansion202610/gallery.html)：45 武器、10 枪械配件、10 食物、医疗/药水/护甲/戒指/符文各 5 件；独立 FBX、Prefab、原始模型、参考与原创背景。尚未写入物品配表、掉落、持握或插槽配置；刚性护甲和指饰的角色适配须在接入时另行检查。
- [权威库存](../../Assets/GameFramework/Runtime/Data/EquipmentData.cs) / [装备命令](../../Lua/Game/Equipment/EquipmentSystem.lua) / [技能与外观解析](../../Lua/Game/Equipment/EquipmentRules.lua)。
- [工坊控制器](../../Lua/UI/Panel/EquipmentWorkbenchCtr.lua) / [行 Widget](../../Lua/UI/Widget/EquipmentRow.lua) / [3D 预览](../../Assets/GameFramework/Runtime/UI/EquipmentWorkbenchView.cs)。
- [武器标签表](../../Config/Tables/Equipment/EquipmentWeaponTagTable.json) / [标签 Widget](../../Lua/UI/Widget/EquipmentTag.lua)。
- [人物姿态与动作](../../Assets/GameFramework/Samples/Adventure/PawnEquipmentView.cs) / [武器挂点](../../Assets/GameFramework/Samples/Adventure/WeaponModelView.cs) / [资源同步](../../Assets/GameFramework/Editor/EquipmentAssets.cs)。
- [配置源](../../Config/Tables/Equipment/) / [法杖与枪源](../../Art/EquipmentDemo/Source/EquipmentDemo.blend) / [近战与推进器源](../../Art/EquipmentDemo/Source/EquipmentMelee.blend) / [制作脚本](../../Art/EquipmentDemo/Scripts/) / [Unity 资源](../../Assets/DynamicAsset/EquipmentDemo/) / [预览](../../Art/EquipmentDemo/Previews/)。
- [装备集成](../../Tools/Tests/equipment_integration.lua) / [近战集成](../../Tools/Tests/equipment_melee_integration.lua) / [预览夹具](../../Tools/Tests/equipment_preview.lua) / [当前检查记录](../../Art/EquipmentDemo/Integration/validation.md)；战斗生命周期见[战斗](Battle.md)，地图持久性见[MapArea](MapArea.md)。

- [30件配件清单](../../Art/EquipmentExpansion202610/manifest.json) / [Blender源](../../Art/EquipmentExpansion202610/Source/EquipmentAttachments.blend) / [模型总览](../../Art/EquipmentExpansion202610/Previews/attachments-contact-sheet.png) / [内容写入脚本](../../Art/EquipmentExpansion202610/Scripts/author_config.py) / [真实Unity装卸与挂点检查](../../Art/EquipmentExpansion202610/Integration/unity-import.json) / [实际装配预览](../../Art/EquipmentExpansion202610/Previews/unity-installed.png) / [30件规则检查](../../Tools/Tests/equipment_expansion.lua)。

- [20武器+20配件设计](../../Art/ArsenalExpansion202610/design.json) / [幂等写表脚本](../../Art/ArsenalExpansion202610/Scripts/author_config.py) / [可编辑模型](../../Art/ArsenalExpansion202610/Source/ArsenalMasters.blend) / [Unity挂点转换](../../Art/ArsenalExpansion202610/Integration/anchors.json) / [104个实际装卸组合](../../Art/ArsenalExpansion202610/Integration/unity-import.json) / [武器总览](../../Art/ArsenalExpansion202610/Previews/weapons-contact-sheet.png) / [配件总览](../../Art/ArsenalExpansion202610/Previews/attachments-contact-sheet.png)。FBX/Prefab/图标位于 `Assets/DynamicAsset/ArsenalExpansion202610`；`EquipmentAssets.SyncSelected` 会一次导出全部选中资源对应的model图标，避免武器与配件同批加入时只导武器图标。

- [转施符文源表](../../Config/Tables/Equipment/EquipmentRuneTable.json) / [技能资格](../../Config/Tables/Adventure/CombatSkillTable.json) / [追踪与转施定向检查](../../Tools/Tests/tracking_config_core.lua)：覆盖固定射程、原消耗、白名单、图标/模型引用与实际获取入口。

- [本批规则/资源验收记录](../../Art/ArsenalExpansion202610/Integration/runtime-validation.json) / [七类实际装配预览](../../Art/ArsenalExpansion202610/Previews/unity-installed.png)。新武器继承基准Grip与已有HoldAdjustment，避免只复制握点遗漏精调朝向；导入工具曾集中编译一次，完整Play仍未运行。
- [分类槽扩充清单](../../Art/SocketExpansion202610/README.md) / [12件模型manifest](../../Art/SocketExpansion202610/manifest.json) / [源模型](../../Art/SocketExpansion202610/Source/WeaponAttachments.blend) / [总览](../../Art/SocketExpansion202610/Previews/contact-sheet.png)。[weapon_socket_expansion.lua](../../Tools/Tests/weapon_socket_expansion.lua)覆盖30把武器的原ID前缀与新组合、12配件数值/效果和获得路径，按 `python -B Tools/Tests/run_lua.py Tools/Tests/weapon_socket_expansion.lua` 独立检查，不执行原生资源同步或Play。
