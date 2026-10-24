# 职业、兼职与特殊武器交付记录

日期：2026-10-25。范围来自已确认的[设计草案](ProfessionExpansionDesign.md)；本轮实现源码、配置、Blender 资源、Unity 资源与最小验证。

## 已接入内容

- 新增炼金师、吟游诗人、神官、咒术师、决斗家、驯兽师六职业，总职业数11。完成设计的40项主动／准备／探索能力及6项被动；另有5个明确的技能选项与1个动物模式工具动作。已学能力跨职业保留，转职本身不白送新技能；六棵被动树分别开放，收益仍需投入天赋点。
- 状态链包括破绽、咒印、余音、涂层／附刃、安可、代罪／赎罪、转祸、蒸馏爆破，以及被动的每轮／每场限制。提交前校验，未命中正常付费，无效目标／材料不足不扣资源。退步、换位与救援显式选落点；绊索公开显示，普通及强制移动使用同一触发规则。
- 野外萃取、酒馆采风、随军诊护、识咒、循迹连接实际植物、城镇、伤势、武器实例与可见动物观测。礼式决斗在公会附近原地图空地进行，单人单敌，25%生命认输、保证金、日限及清场恢复已接入。
- 独立战宠与骑乘共享同一动物实例；动物没有额外完整回合，指令支付主人行动。驱赶保留借机风险，夹击／气味提供流血，救援检查合法落点；状态、伤势、亲密度与楼层随保存恢复。死亡与模式切换不能刷新生命。

## 十二把特殊武器

| ID | 武器 | 形态与配套方向 |
| --- | --- | --- |
| 8001 | 炼金蒸馏杖 | 蒸馏器／试剂瓶杖头，炼金与触媒施法 |
| 8002 | 腐蚀注射剑 | 可见储液段与细长针刃，单手状态剑术 |
| 8003 | 共鸣鲁特琴 | 独立琴身／琴弦，吟游支援 |
| 8004 | 行军七弦琴 | 横梁弦架与手柄，吟游节奏 |
| 8005 | 慈悲香炉杖 | 悬环香炉杖头，神官保护 |
| 8006 | 守夜祷锤 | 分瓣锤头与祷饰，单手神官兵装 |
| 8007 | 缚咒纺锤杖 | 环绕晶核与垂坠符饰，咒术触媒 |
| 8008 | 血契仪刀 | 深色仪式刀刃与血槽，真实可识别诅咒 |
| 8009 | 银线刺剑 | 窄刃与护手，决斗破绽 |
| 8010 | 捕刃左手匕 | 双侧捕刃叉，单手／副手近战 |
| 8011 | 驯群钩杖 | 钩形杖头与挂饰，驯兽兼修触媒 |
| 8012 | 狼牙猎弓 | 兽牙弓臂与真实弓弦，驯兽／游侠 |

- 12件均有原创 Blender 几何、独立 FBX、Unity 原生 Prefab、现有 URP 调色板映射和模型图标。总计10,232三角面；源几何通过尺寸、原点、封闭性、UV、法线检查。
- 职业不限制装备；属性要求、主副手／双手、触媒、改装槽及技能都使用现有装备规则。新增武器和五种试剂进入现有商店与交易价格配置。
- [模型总览](../Art/ProfessionArsenal20261025/Previews/weapons-contact-sheet.png)／[源模型](../Art/ProfessionArsenal20261025/Source/ProfessionWeapons.blend)／[模型清单](../Art/ProfessionArsenal20261025/Integration/models.json)／[Unity实际导入报告](../Art/ProfessionArsenal20261025/Integration/unity-import.json)。
- 最终资源位于 `Assets/DynamicAsset/ProfessionArsenal20261025/`；通过现有 `EquipmentAssets.SyncSelected` 生成 Prefab、图标并更新目录，未手写 YAML／GUID。

## 实际验证

- 配置检查：29张增量源表、3492项引用、6职业、46项设计能力、12武器与5种试剂通过；生成产物由正式导表器写出。
- `profession_combat_core.lua`：10组真实 Lua／配置检查通过，覆盖命中／致死／多发一次性消费、AP／材料事务、被动触发与期限、免疫转祸、移动和机关。C#边界使用隔离适配器。
- `profession_beasts_core.lua`：9组通过，覆盖指令预算、借机中断、救援、同实例切换与上下层占位。
- `profession_exploration.lua` 和 `profession_duels_core.lua` 通过，后者5组涵盖原地图单挑落位、保证金、日限、认输后的队形／装备／会话清理。
- `profession_combat_state.ps1` 对实际编译程序集的3组检查通过：权威计数与位移、精确状态转移和保存恢复、机关生命周期。
- `profession_landing_editmode.cs` 在隔离 PreviewScene 中5项通过：选择、落点、取消、失效撤选、无预先消费。
- `profession_expansion_editmode.cs` 使用实际 FrameworkServices、xLua、C#角色与正式配置，9组通过：六职业学习与跨职保留、12武器装备／触媒／技能、原生资源目录与图标、缺材料零消费零随机推进、水瓶接导流、真实绊索、动物身体伤势与楼层保存恢复、单挑非致死认输与返回探索。
- `profession_companion_reconnect_editmode.cs` 对实际程序集补验通过：完整远征把队伍动物记录重连到原区域实体后，仍保留同一身份、独立模式、楼层、伤势和跨区坐标；已归属动物不再用出生区域坐标边界拒绝读档，普通敌人的位置校验保持。
- 本地化来源扫描通过；文档链接和相关 diff 格式检查通过。实际 Unity 控制台在最终编译与验证后无错误。
- 后续修复显示宿主启动的独立特效校验失败：为创伤打击1630、四项新增枪械技和46项职业动作补齐51条独立 profile；当前124技能映射唯一、结构签名唯一。修正内容生成器对基础／选项技能的模板引用，并将全技能特效校验加入内容检查。`visual_effect_catalog.lua` 7组和源表检查通过；在现有 Edit Mode 的独立 xLua 中执行实际 `VisualEffectCatalog.Snapshot → BlockEffectCatalog.Read`，成功读取124技能／156效果／163物品。只定向导入两张配置资源，未触发项目编译或进入Play；未将目录检查视为全部粒子视觉验收。
- 后续修复角色装备显示的挂点契约错误：基础武器101–104原配置零槽，却共用40/616/1/70的有槽包装。已创建四个独立零槽Prefab并注册assetId101–104，保留原FBX、图标和握点，原升级武器挂点不变。基础武器规则3组通过；原生隔离验证对全部57武器进行136个实际配件装卸组合、374次 `WeaponModelView.Apply` 和16次基础／原武器切换，全部通过。此次只改配置、原生资源、测试及文档，无运行时代码或项目编译变更。

## 编译与未覆盖范围

- 主动请求脚本编译4次：初次发现新增单挑／诊护脚本未被 Unity 登记；获用户确认后定向导入并重试，随后发现并行弹药改动的 `EquipmentAmmunition.cs` 同样未登记；第二次获批补导入后编译通过。最后修正完整远征动物重连的楼层保存，第三次获批补编译与定向重连检查通过。此前 Editor 自行编译不计入主动请求次数。
- 只做隔离 Edit Mode 验证；未进入 Play，未启动新 Editor，未运行全量测试、完整构建或修改玩家存档。没有新增 xLua 生成包装；新数据入口使用已有静态反射桥模式并维护 link.xml。
- 当时完整 Adventure 启动的附加检查被物品190“抗感染药”缺交易价格阻断，职业原生集成采用最小真实服务并通过。后续根据用户启动报错，已按现有 `ShopEntryTable[190]` 的25金币补齐 `WorldTradePriceTable`、正式导表并定向导入 Unity；`world_trade_prices.lua` 的全物品覆盖、真实商队补货及缺价／重复价检查通过，Unity Resources 字节与新导出一致。本次修复未触发项目编译或进入 Play，不把价格检查视为整个世界游玩验收。
- 旧 `character_skills_core.lua` 在原有“斩击1不支持life”的过时断言处失败，当前原始配置已支持life；未将其记为本轮通过，也未为通过测试修改存量技能语义。

## 维护入口

- [职业战斗](../ForAI/Business/ProfessionCombat.md)、[职业探索与单挑](../ForAI/Business/ProfessionExploration.md)、[动物](../ForAI/Business/Animals.md)、[养成](../ForAI/Business/Progression.md)。
- [配置清单](../Tools/ProfessionExpansion/content_manifest.json)、[内容静态检查](../Tools/ProfessionExpansion/validate_content.mjs)、[定向资源导入请求](../Tools/ProfessionExpansion/weapon_unity_import.json)。
