# 队员关系与持久经历
关键词：队员关系、好感、仇恨、厌恶、友好、挚友、爱恋、误伤、芥蒂、协作、救援、死门、道歉、追忆、PartyStory。

## 文档目录
正文：状态与真实事件 / 战外交流 / 保存与显示 / 验证；关键入口：规则 / 状态 / 界面 / 检查。详细数值、参考与后续规划见[关系设计](../../Docs/PartyRelationshipDesign.md)。

## 正文

- `Adventure.partyStory` 订阅 `Battle.Changed`，关闭注销；新开局清空关系与战斗临时记录。权威状态为 `AdventureData.PartyBonds`，新状态经 `PartyRelationshipState` 反射桥接访问；Lua 只持配置和显示投影。关系按稳定 actorId 存无向对，覆盖出战与后备全编制，与 [NPC 好感](Narrative.md)独立。
- 好感 −100～100；五档下限依次为 −100、−60、−20、30、60。初始0为一般。爱恋是独立标记，符合条件后由玩家明确确认；疏远不会自动分手。阶段升降均记录真实变化，关系阶段无隐式战斗属性或自动追击。
- `battle_started` 只登记真正参战的玩家编制角色；旁观者、动物、后备不自动参与。共同胜利且双方存活默认 +2、共战次数 +1；结算幂等。有本场友伤的对保留共战次数但无胜利好感。
- 即时治疗必须真实恢复生命；普通照料至少恢复最大生命5%，默认 +3/+2，每场每对两次。生命≤25%为救援+12，0血死门救回+20，共享每场每对一次；同一治疗只取一种奖励。自疗、部署、持续和满血治疗不计入。傲慢／孤僻降低普通照料收益；真实救援仍按旧规则移除配置指定特质，并累计个人救援与守望者荣誉。
- 两名队员同轮先后对同一敌人造成直接有效伤害，协作+3，每对每轮一次、每场两次。周期、零伤害、未命中、`impact.legendaryDebt` 传导排除。此入口记关系，不新增协力攻击技能。
- 误伤按结算伤害占最大生命比例扣分，默认2～18，打入死门取18，同时积累芥蒂。使用 `GameEffects` 的 `hpBefore/hpAfter/periodic/incomingDamage/healthActorId`，坐骑生命变化不算骑手本人伤害。
- 同场发生友伤的对不再获得彼此正向战斗互动。己方／自伤造成的HP损失形成目标级临时债务，任何治疗先抵扣友伤，剩余恢复才算有效帮助；用“治疗前HP+未偿债务”判断救援，防止第三人刷人为救援。以上战斗收据只保留本场。
- 芥蒂0～100；未化解时治疗／救援收益减半、向下取整且至少1，交谈只+1；道歉默认+2好感/−8芥蒂，交谈−1芥蒂，干净胜利−1芥蒂。每对每日一次战外交流，与恋爱身份动作共享额度。
- `Social/CanSocial` 只允许map/area且无其他对话。双方须存活；对亡故伴侣解除当前关系为显式例外，仅允许幸存者执行。爱恋要求好感≥60、共胜≥3、无芥蒂、双方无当前伴侣；返回朋友或珍藏亡故伴侣记忆不扣好感，不删除过去。
- `ChronicleEntryData` 固定保存真实游戏分钟、日期、地点、主客体、精确参与者和实际好感变化；旧纪事不随当前关系改写。关系页仅列双方最近三条，完整历史继续在角色经历页查看。
- [角色存档](CharacterSave.md) 自v47/48起写入partyStory.format=2及负分、芥蒂、互动次数、每日交流、爱恋；旧1–46保留原分值/救援/荣誉与历史，新字段显式从空开始。准备阶段拒绝未知/重复角色对、超范围数据、未来交流日期、多重当前伴侣和救援合计错误。关系容量按全编制角色数计算；恢复覆盖临时历史。
- 角色手记总览点击 `Traits` 中的关系标签进入详情／交流选项，动作先预览再确认，确认固定首行；不可用动作可查看原因。新增原生 `TraitDetailScroll` 绑定保证共同记忆可滚动。重建CharacterGrowthPanel后须执行[原生绑定脚本](../../Tools/UI/ensure_relationship_scroll.cs)恢复此包装并导出视图类型；不手改Prefab YAML。所有新增正文使用Language/LuaTxt或表text字段。

## 验证与关键入口

- [PartyStory.lua](../../Lua/Game/Progression/PartyStory.lua) / [PartyStoryRules.lua](../../Lua/Game/Progression/PartyStoryRules.lua)：事件、对话资格、纪事和规则；[CharacterGrowthCtr.lua](../../Lua/UI/Panel/CharacterGrowthCtr.lua)的Relationship复用绑定控件。
- [PartyBondData.cs](../../Assets/GameFramework/Runtime/Data/PartyBondData.cs) / [PartyRelationshipState.cs](../../Assets/GameFramework/Runtime/Data/PartyRelationshipState.cs)：唯一状态、持久化与限次；[ChronicleEntryData.cs](../../Assets/GameFramework/Runtime/Data/ChronicleEntryData.cs)：历史。
- [规则表](../../Config/Tables/Progression/PartyStoryRuleTable.json) / [阶段表](../../Config/Tables/Progression/PartyBondStageTable.json) / [荣誉表](../../Config/Tables/Progression/PartyHonorTable.json)。
- 离线最小检查：`python -B Tools/Tests/social_source_check.py`；文案检查：`node Tools/Tests/ui_localization_sources.mjs`。
- 需已编译／导表的定向检查：[C#状态](../../Tools/Tests/party_relationship_data_editmode.cs)、[战斗与临时存档宿主](../../Tools/Tests/party_relationship_integration_editmode.cs)及[social_integration.lua](../../Tools/Tests/social_integration.lua)、[原生UI宿主](../../Tools/Tests/party_relationship_ui_editmode.cs)及[social_ui_integration.lua](../../Tools/Tests/social_ui_integration.lua)。[边界检查](../../Tools/Tests/party_relationship_edges.lua)可用同一无UI宿主替换Lua脚本路径运行，不依赖世界初始化。
- 仅按改动范围运行；这些入口不授权启动Editor、Play、全量验证或反复编译。本次结果及并行改动导致的完整复验缺口见[设计与验证记录](../../Docs/PartyRelationshipDesign.md)。
