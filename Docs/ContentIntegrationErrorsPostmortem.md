# 内容接入报错复盘：交易价格、技能特效与武器挂点

日期：2026-10-25。范围：本次用户连续反馈的三项运行时报错。本文归纳原因、修复证据和验证缺口；现行模块契约仍以对应 ForAI 文档为准。

关键词：缺交易价格、抗感染药190、独立特效1630、武器挂点数量、基础武器101–104、模板复制、共享Prefab、内容接入、回归验证。

## 结论

三项错误都发生在**内容配置与消费端约定不一致**的边界。Lua／C# 的报错是在明确指出缺失或冲突；修复需要补齐关联配置、正确划分资源身份，并验证实际使用路径。

| 报错 | 触发位置 | 直接原因 | 修复原则 |
| --- | --- | --- | --- |
| `WorldTradePriceTable missing price: itemId=190` | `WorldParties.New`，系统初始化 | 抗感染药已存在于物品表和商店，交易价目表缺少该物品 | 按已有商店售价补齐交易价格 |
| `Each skill requires its own visual effect: 1630` | `VisualEffectCatalog.Snapshot`，显示宿主启动 | 创伤打击1630引用了破势一击101的特效，违反技能特效独占约定 | 为全部同类遗漏建立独立特效，并修正生成逻辑 |
| `武器挂点数量与配置不一致` | `WeaponModelView.Apply`，队员肖像／装备显示 | 四把零槽基础武器共用了带挂点的原武器Prefab | 复用源模型，分别保存符合各自挂点契约的Prefab |

三项数据审计分别确认了独立问题。堆栈显示它们依次位于“系统初始化 → 显示宿主启动 → 队员显示更新”：前一处异常会阻止程序执行到后一处。因此，修好一项后才暴露下一项，并不表示前一次修复制造了下一次错误；也不能据第一项消失就认定其余入口已通过。

## 一、抗感染药缺少交易价格

**事实与原因**

- 物品190“抗感染药”已加入 `EquipmentItemTable`，`ShopEntryTable[190]` 已有25金币售价，但 `WorldTradePriceTable` 没有对应记录。
- 商队支持出售背包物品，因此价目表必须覆盖全部物品；“有商店售价”不能替代“有商队交易价格”。排查时163件物品中，只有190缺价。
- `WorldParties.New` 在随机补货之前检查完整覆盖，初始化因此终止。这里不是随机补货失败，也不是需要重编译C#。

**修复与验证**

- 新增交易记录 `{id:190, itemId:190, price:25}`，沿用既有定价，没有猜测价格或添加默认售价。
- 使用正式导表器生成二进制，定向导入 Unity 的价格资源，确认 Resources 读取的字节与导出文件一致。
- 既有 [world_trade_prices.lua](../Tools/Tests/world_trade_prices.lua) 通过，涵盖全部物品价格覆盖、真实商队补货、缺价诊断及重复价格拒绝。

**漏检点**：完整启动检查曾发现此阻断，但当时改用最小职业服务验证后，将缺价保留为后续问题。局部功能通过不能覆盖这个已知的启动失败。已有价格来源足以确定修复，应在交付时处理该关联遗漏。

当前规则与入口：[商队交易契约](../ForAI/Business/WorldParties.md)、[交易价格源表](../Config/Tables/Travel/WorldTradePriceTable.json)、[初始化校验](../Lua/Game/Adventure/WorldParties.lua)。

## 二、新技能复用了独占特效

**事实与原因**

- 技能1630的 `visualEffectId` 为101，与“破势一击”共用配置；它只是遍历过程中首先触发错误的技能。
- 全表审计发现51项同类遗漏：创伤打击1项、枪械技能4项、职业新增动作46项。这里的46按技能表记录计数：40条主动／准备／生活技能、5个选项变体和1个模式动作，不包含6项被动，与设计稿能力总数的统计口径不同。
- 职业生成脚本直接写入基础模板特效ID，选项变体又复制父技能的该字段，导致其中46项共享引用。另外5项的配置重复已确认，生成来源未在本次排查中追溯。
- 特效行确实存在，普通外键检查能够通过；但项目另有“每技能独立profile”的约束。已有专项检查还要求构图、尺寸或时序存在区别，不能仅换ID或颜色。

**修复与验证**

- 为51项动作各补独立profile，按动作配置构图、粒子数量、大小和节奏，保留原技能的伤害、消耗等玩法参数。
- 生成器的 `skill_visual` 要求独立配置已存在；基础技能、生活技能及变体均引用自身profile，重新生成时保留已编写的特效参数。
- `validate_content.mjs` 增加全部技能的特效ID唯一性及结构签名检查。运行时原有断言继续保留。
- [visual_effect_catalog.lua](../Tools/Tests/visual_effect_catalog.lua) 7组通过；Unity内实际执行 `VisualEffectCatalog.Snapshot → BlockEffectCatalog.Read`，成功读取124技能、156特效和163物品。见[原生检查结果](../Art/ProfessionArsenal20261025/Integration/visual-effect-catalog-check.json)。

**漏检点**：之前的职业内容检查验证了引用存在，却没有覆盖唯一性；原生集成验证了学习、装备和战斗规则，没有调用显示宿主的特效目录入口。项目已有相关专项测试，但当次没有纳入验收选择。

当前规则与入口：[特效契约](../ForAI/Business/VisualEffects.md)、[特效源表](../Config/Tables/Adventure/VisualEffectTable.json)、[生成器](../Tools/ProfessionExpansion/build_content.py)、[内容检查](../Tools/ProfessionExpansion/validate_content.mjs)。

## 三、零槽基础武器共用了有槽Prefab

**事实与原因**

`EquipmentRules:WeaponVisual` 按武器的 `socketIds` 产生显示数据；`WeaponModelView.Apply` 要求Prefab的挂点数量、ID和Anchor与该数据一致。以下四组无法由同一个Prefab同时满足：

| 零槽基础武器 | 共用的原武器 | 原Prefab挂点ID |
| --- | --- | --- |
| 101 练习铁剑 | 40 民兵铁剑 | 6、204、205、206 |
| 102 简易猎弓 | 616 蛛纹缚足弓 | 128、264、265 |
| 103 学徒木杖 | 1 旅法者法杖 | 1、2 |
| 104 短柄手斧 | 70 伐木斧 | 225、226、227 |

- 基础武器“无改装槽”是明确的玩法配置。错误发生在资源复用：复用了源几何之外，还复用了带 `WeaponModelView.mounts` 的Prefab包装。
- 模型、材质、图标和目录引用存在，只能说明资源可以找到；不能证明实际 `Apply` 时符合挂点契约。
- 原基础武器测试将“与来源武器使用相同 `assetId`”写成预期，固化了错误的资源复用方式。其装备资格、基础技能和姿态等检查仍然有效，但未覆盖原生挂点应用。

**修复与验证**

- 为101–104分配独立assetId和 `Starter_101.prefab` 至 `Starter_104.prefab`，通过 Unity 原生接口保存零挂点包装；原FBX、图标、握点和姿态微调继续复用。
- 原武器1／40／70／616的带槽Prefab保持不变。直接删掉共享Prefab的挂点会损坏它们，给基础武器补槽又会改变玩法，因此均不采用。
- 更新基础武器测试：要求源模型相同、包装资源独立，并继续验证零槽、基础技能、图标和握点。
- 新增[真实装备快照检查](../Tools/Tests/weapon_socket_contract_integration.lua)及[原生显示检查](../Tools/Tests/weapon_socket_contract_editmode.cs)。当次覆盖57武器、136个兼容配件组合、374次实际 `Apply`、16次基础／原武器往返切换，全部通过。见[检查结果](../Art/ProfessionArsenal20261025/Integration/weapon-socket-contract-check.json)。

**漏检点**：把“可以复用模型”扩大成了“可以复用完整Prefab”；测试同时遗漏了资源契约和消费者调用。共享资源必须先确认其组件、挂点等使用约定兼容。

当前规则与入口：[装备契约](../ForAI/Business/Equipment.md)、[显示数据生成](../Lua/Game/Equipment/EquipmentRules.lua)、[挂点消费者](../Assets/GameFramework/Samples/Adventure/WeaponModelView.cs)、[基础武器检查](../Tools/Tests/starter_weapon_set.lua)。

## 共同根因与交付教训

| 共性 | 本次表现 | 后续应检查什么 |
| --- | --- | --- |
| 内容新增没有沿依赖关系检查完整 | 新物品漏交易价，新技能漏独立特效 | 从新增记录追到实际消费它的模块，确认关联表和资源要求 |
| 模板复制携带了不应复用的身份 | 特效ID继承模板，Prefab身份沿用原武器 | 区分可以共享的源模型／参数与必须独立的业务或资源身份 |
| 引用检查覆盖不了跨表语义 | 外键有效，但唯一性、全覆盖和组件布局不符合要求 | 同时检查“存在、覆盖、唯一、兼容”，按模块选择适用项 |
| 局部验证被扩大解释 | 学习和战斗通过，显示初始化与角色模型仍失败 | 报告准确说明已执行入口；初始化被阻断时保留明确的验收边界 |
| 测试预期本身可能错误 | 基础武器测试要求共享assetId | 依据正确玩法契约审查测试，并实际调用资源消费者 |

这次修复保留了缺价、特效独占和挂点一致性校验。默认值、忽略多余挂点或吞异常，会让问题变成错误价格、错误表现或旧配件残留，不能替代内容修复。

## 后续同类改动的最小验证选择

| 变更类型 | 已有检查入口 | 必须证明的结果 |
| --- | --- | --- |
| 新增物品、交易或商店内容 | `python -B Tools/Tests/run_lua.py Tools/Tests/world_trade_prices.lua` | 全物品覆盖，真实补货可用，价格来源明确 |
| 新增或复制技能、特效 | `python -B Tools/Tests/run_lua.py Tools/Tests/visual_effect_catalog.lua`；职业批次另用 `node Tools/ProfessionExpansion/validate_content.mjs` | 所有技能含生活／变体均能解析独立特效 |
| 新增／复用武器模型、改挂点 | 基础武器相关时运行 `starter_weapon_set.lua`；原生入口为 `weapon_socket_contract_editmode.cs` | 配置与Prefab一致，真实Apply及装卸／切换成功 |
| 修改配置后交付 | 正式导表，定向导入变化的配置资源，再验证实际读取入口 | 源JSON、生成二进制与Unity读取内容一致 |

以上按改动选择最小范围，并遵守项目测试／Editor约束；不是每次运行全部测试的要求。此次没有新增统一CI任务、自动提交门禁或一键全工程验收，也没有进行完整Play验收。这里列出的防回归建议不能写成已自动执行的能力。

具体自动化边界：全物品价格覆盖仍由运行时初始化和专项测试检查，导表器未新增反向覆盖校验；共享Prefab的挂点契约检查已加入新测试，但尚未加入 `EquipmentAssets.SyncSelected` 的写入前预检。

本文引用的通过结果来自此前三次修复；本次整理文档只核对源码、记录与链接，没有重新运行游戏测试。完整修复时间线见[职业扩展交付记录](ProfessionExpansionImplementation.md)。
