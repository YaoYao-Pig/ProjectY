# 宝箱生成与敌人掉落

关键词：宝箱、容器、陶罐、木箱、板条箱、武器架、桌子、耐久、破坏、掉落、战利品、搜刮 UI、LootSession、概率、掉落池、满包。

## 文档目录

正文：生成与配置 / 状态与领取 / 事件战场 / 验证；关键入口：规则 / 权威状态 / 检查。

## 正文

- 正式远征的基础开局见[装备配方](Equipment.md)。地牢/森林箱分别保底少量木料，另抽装具、配件、药品或火炬；陶罐与桌面使用独立生活补给池 7，不混入宝箱的进阶装备。守卫宝库池 5 固定按权重抽两次，包含骑士剑、进阶双手剑、戒指、步枪等，重复命中仍按原规则合并数量。敌人保持原实例装备掉落，额外池仅提供材料、药品和弹药。`campaign_equipment.lua` 对正式起始包及 128 个种子的补给/宝库结果做定向检查。

- [持续 GameEffect](GameEffects.md) 在探索中造成的死亡，经 `GenerateActorDrops / MapLoot:ActorDrops` 复用同一套掉落规则与 DropResolved 标记；战斗结算的 `EnemyDrops` 也委托此入口。

- `Game.Loot` 管理容器布局、攻击、掉落与领取；`EquipmentSystem` 保留 `InitializeLoot/Loot/LootSnapshot` 门面。物品、搜索进度、取空状态仍归 C# `MapAreaLootData`，其持有唯一 `ContainerState` 保存耐久、破坏、占地、旋转和解锁状态；新增类型通过反射桥接并由 `Runtime/Data/link.xml` 保留，不手改生成 Wrapper。
- `ContainerLayout.Populate` 在地图冻结前生成 `containerPlans`，先保留敌人完整占地、NPC 出生点与旧入口补给。`MapAreaChestRuleTable` 配置地图、数量、距离、间距和楼层；`spawnChance` 是每张地图每条规则独立判定一次的出现概率，命中后再抽数量。支持 reachable / rooms / wall / goal / fixed / props、房间样式/分区/预设筛选与掉落池覆盖；props 关联已有陈设，避免重复模型和库存。空间不足明确报错；阻挡容器不得封死原可达地面，每个容器保留可达交互侧。
- `ContainerTerrain` 将 C# 状态叠加到现有工事/地形视图，探索与原地战斗共享动态阻挡；破坏后恢复原地面，不修改冻结布局。新增陶罐、木箱、板条箱、宝箱、首领奖励箱、武器架、桌子与上锁箱示例；旧非阻挡入口补给保留。耐久数值和生成密度是可调示例配置。
- 可选 `layer`（默认-1）限定宝箱楼层，间距只比较同层箱子；[三层沉船](Shipwreck.md)分别给下舱/主甲板/高台配置数量。搜刮接近判断还检查真实导航距离，不能隔楼板领取同q/r物品；宝箱模型随地格剖切隐藏，不改容器状态。
- `EquipmentLootTable` 定义 open / search / break / tool 交互、已装备工具标签、首次工具开启回合数、耐久、结构防御、多格占地和各状态模型。`unlockEncounterId` 引用本地点敌群实例，清除后才允许打开或破坏；首领奖励示例绑定第 1 敌群，不新增首领单位。poolId=0 使用固定物品，否则引用随机池；地图规则可覆盖池。开放式武器架/桌面只显示真实剩余物品，取走后移除展示物件。
- `LootPoolTable.mode=independent` 时逐条按 chance 判定；weighted 时按 `LootEntryTable.weight` 抽 `drawCount` 次，允许重复并合并同物品数量。每次命中再抽 minCount..maxCount；独立池可为空，加权池必须有正权重。生成时固定内容，打开、攻击、领取失败和同次远征重进均不重抽。
- `CombatSkillTable.affectsContainers` 显式允许即时伤害作用于容器。`ContainerCombat` 共用技能伤害公式（结构防御替代角色防御）、射程与[配置弹道](Battle.md)、命中、连射、弹药与冷却；范围技能在 maxTargets 限额内扩展到容器，多格只计一次。直射/抛射在探索和战斗中均检查途中角色，容器自身仍须位于当前视野且与攻击者同层。战斗沿用 AP 与行动额度，容器不进回合名单或胜负统计；探索通过角色技能栏选择容器，每次有效攻击推进 1 探索回合，世界回合也推进技能冷却。
- 破坏只改变原记录的耐久/可搜刮状态和模型，原剩余物品留在现场；已取走的物品不会再出现。未破坏陶罐不能搜刮，工具箱可装备对应工具开启或用攻击破坏。不会损毁内部物品；破坏后空容器无残骸模型时隐藏。跨运行存档范围沿原远征契约。
- `EnemyDropTable.unitId` 关联敌人的额外随机战利品；实装武器/防具由 `EquipmentCombatState.DropActor` 从原所有者移入尸体容器，保留相同实例 ID、耐久、永久损伤、符文和已装弹匣余弹，敌池 3/4 不再随机复制武器/防具。精确刺击保留护甲耐久，火焰/重击可能产生破损装具，均可拾取并按[装备维修规则](Equipment.md)修复。只对 HP=0、Team=2 且未驯服的敌人结算，`CombatActorData.DropResolved` 防止重复；即使无随机池，实际穿戴物也会掉落。
- 缴械当场在目标脚下创建 102 号落地装备容器并移出真实武器；模型直接使用剩余武器的物品资源。503 拾取武器在主手空出、同层可达相邻格、满足属性与双手规则时花 2 AP 直接装备原实例，不借用背包容量，AI 可用同一命令捡回。未在战中捡回的物品走现有战后搜索/拖拽；容器持有原实例且原库存不再持有，领取成功置 Count=0 并释放引用，失败保持两侧状态。未领取地面物品只在同次远征保持，不扩大角色存档的地图重建范围。
- 原地战斗结束时，无论胜利或败退，已死亡敌人的战利品都留在其真实地格；活着或被驯服的敌人不生成击杀掉落。同格多个来源可以共存，显示层作小幅偏移；规则仍使用原格。胜利后继续探索，败退按既有流程返回大地图，可治疗后重返。
- 靠近一格通过 E 或 HUD“搜刮”打开 `Loot` 模态窗口：左侧共享网格背包，右侧容器物品；不再自动入包。初始只显示物品剪影，不暴露名称或数量；打开后使用未缩放时间按顺序逐件转圈搜索（每件 1.1 秒），已揭示物品可立即拖入左侧，支持 R 旋转和右键取消。右侧可滚动，搜索刷新不取消正在进行的拖拽。
- 搜刮窗口背包网格为 624×520（当前 12×10 背包每格 52 个 UI 单位）；右侧为 6 列、每格 80 的连续网格。每个 `MapAreaLootData.SearchGrid` 唯一保存位置和旋转；首次打开按原掉落顺序初始化，容量至少 6×6，初始物品较多时扩到所需行数，之后整理或存入不会自动扩容。物品取走释放格子，关闭和同次远征重进保留位置；已揭示物品可以在右侧拖动、旋转或合并同类堆叠。点击物品在右下方显示独立图标和完整名称；未搜索物品仍只显示剪影。
- 胜利结算自动汇总本场新生成的容器，即使没有物品也显示结算窗口；不把旧掉落、附近宝箱一并收入。金币、经验和败退流程沿原契约。`LootSessionData` 只持有窗口范围，物品剩余量、独立装备实例条目、揭示状态和搜索进度由原 `MapAreaLootData` 持有；关闭、离开和重进不会重抽或重复领取。新远征清空搜索会话。
- 领取通过 `Adventure:TakeLoot → MapLoot:Take → LootSessionData.Take → EquipmentData.ReceiveLoot`，左侧背包存入通过 `MapLoot:Put → LootSessionData.Put`，容器内整理通过 `MapLoot:Move → LootSessionData.Move`；全部先验证精确落点，再提交两侧状态。存入武器保留同一实例、符文和已装弹匣，弹匣保留余弹，防具保留实例；不会通过重新发放配置物品丢失状态。只允许左侧背包物品存入，已穿戴装备和已装入武器的独立弹匣不能直接拖出。组件/弹药按选中堆转移，落到空格保留为独立堆，拖到已揭示同类堆叠上才合并；背包中已有同类物品不再强制要求合并。碰撞、越界、满包、未搜索或取消均不改变库存。
- 单容器可直接双向存取。战斗窗口默认汇总查看与领取，通过 Sources 下拉框明确选定某个敌人的容器后才能整理或存入，存入物仍落在该容器原来的地格；不同容器的容量、位置和搜索状态独立。自己存入的物品立即可见。仍在场景中的空箱可再次打开存放，存入后撤销取空标记；取空且无残留模型的地面掉落保持隐藏。未领取或已存入的物品仍仅在同次远征的地图记录中保留。
- 【获得】日志仅记录实际拖入物品；空箱在关闭时记日志。`Adventure:CloseLoot` 在关闭窗口后触发已取空容器的探索事件，避免剧情打断搜刮；窗口使用框架的模态输入、缓存和暂停租约。
- 旧世界事件的战斗也转入 `E_MapAreaType.Battlefield` 的持久小地图：`BattlefieldGenerator` 沿用原 CombatEncounterTable 的半径、障碍概率与敌方坐标，战斗/战后共用同一布局。`Loot.EventBattlefieldAreaId` 指定地图定义；当前世界事件由 resolving 经 `BeginEventArea` 进入区域战斗。胜利后可走动拾取、离开和重进，不重复触发旧事件或奖励；战場缓存与其他小地图在新远征时统一清空。当前配置的带战斗事件均来自大地图，不支持把已有区域内事件替换成另一张独立战场。
- `EquipmentItemTable.kind=consumable` 与材料/弹药一样允许同物品多堆，数量查询按物品ID汇总，支持原有拾取、网格转移与角色背包存档。急救包91、备战药剂92的使用与AP事务见[战斗](Battle.md)，库存耗尽由 `EquipmentData.ConsumeStack` 释放对应网格位置；拾取物品本身不会把其使用效果授予为角色技能。
- 状态持久性沿用同次远征的地图记录；角色存档仍按原约定保存队伍/背包并重建地图，不把地面未领取物品当作跨运行存档。
- 永久界面入口为 `LootAssets.Sync`（菜单 `Project Y/装备/同步搜刮与结算界面`），通过 Unity MCP 保存 Prefab、PanelConfig 和 LuaReference；运行时不查找子节点。新类型使用 xLua 反射桥接和 link.xml 保留，不需要为此次接入重新生成全量绑定。
- 最小离线检查：`python -B Tools/Tests/run_lua.py Tools/Tests/loot_core.lua` 与 `loot_ui_core.lua`。Unity MCP 执行 `Tools/Loot/run_checks.cs` 检查真实状态、逐件事务、满包、重进和战斗范围；执行 `Tools/Loot/run_ui_checks.cs` 在独立 Edit Mode PreviewScene 中检查真实两栏 UI、指针拖拽、自动揭示和暂停释放，并导出 `Docs/Previews/Loot/` 预览；均不启动 Play。
- 容器定向检查：`python -B Tools/Tests/run_lua.py Tools/Tests/containers_core.lua`；真实 C# 状态用 Unity MCP 执行 `Tools/Loot/run_container_checks.cs`，创建独立 Edit Mode 数据验证耐久、领取、冷却、行动点和重进。资源引用以 `EquipmentAssets.SyncSelected({}, {200,201,202,205,206})` 定向同步；原生 Prefab 保留已制作网格/材质，不强制套用 FBX 导入器。
- `Tools/Loot/container_visual_checks.cs` 在独立 PreviewScene 验证配置模型、材质、模型拾取与剩余物品显示，导出 `Docs/Previews/Loot/containers-full.png` 和 `containers-empty.png`；不启动 Play，不修改当前场景。

## 关键入口

- [LootRules](../../Lua/Game/Loot/LootRules.lua) / [ChestGenerator](../../Lua/Game/Loot/ChestGenerator.lua) / [MapLoot](../../Lua/Game/Loot/MapLoot.lua)。
- [生成阶段](../../Lua/Game/Loot/ContainerLayout.lua) / [动态阻挡](../../Lua/Game/Loot/ContainerTerrain.lua) / [容器攻击](../../Lua/Game/Loot/ContainerCombat.lua) / [耐久状态](../../Assets/GameFramework/Runtime/Data/ContainerState.cs) / [示例配表](../../Tools/Loot/configure_containers.py)。
- [掉落源表](../../Config/Tables/Loot/) / [容器表现](../../Config/Tables/Equipment/EquipmentLootTable.json) / [配表制作脚本](../../Tools/Loot/configure_loot.py)。
- [地图与容器状态](../../Assets/GameFramework/Runtime/Data/MapAreaData.cs) / [击杀结算标记](../../Assets/GameFramework/Runtime/Data/CombatActorData.cs) / [战斗结算](../../Lua/Game/Adventure/AdventureSystem.lua)。
- [LootSessionData](../../Assets/GameFramework/Runtime/Data/LootSessionData.cs) / [精确放置事务](../../Assets/GameFramework/Runtime/Data/EquipmentLootTransfer.cs) / [LootModel](../../Lua/Game/Loot/LootModel.lua)。
- [LootCtr](../../Lua/UI/Panel/LootCtr.lua) / [LootPanelView](../../Assets/GameFramework/Runtime/UI/LootPanelView.cs) / [圆环](../../Assets/GameFramework/Runtime/UI/LootSearchGraphic.cs) / [界面生成](../../Assets/GameFramework/Editor/LootAssets.cs)。
- [事件战场生成](../../Lua/Game/MapArea/BattlefieldGenerator.lua) / [规则检查](../../Tools/Tests/loot_core.lua) / [真实状态检查](../../Tools/Tests/loot_integration.lua)。
