# 世界人物、通用招募与个人成长
关键词：People、普通居民、全民招募、动机、牵挂、熟人、敌方交涉、身份连续、个人成长、经历分支。

## 文档目录
正文：身份 / 招募与入口 / 成长 / 保存与边界 / 验证；关键入口：模型 / 数据 / 配置 / UI。

## 正文

- `Adventure.people` 解释世界人物规则；权威人物状态归 `AdventureData.People`，通过反射桥 `PeopleState.Get/Prepared` 访问。居民身份为 `resident:<siteId>:<stableId>`，分配600000000起的独立actor ID；姓名、动机、熟人、属性、外观首次生成后保持，跨城同stableId不会串人。浏览不标记认识，真实开启交谈才 `Meet`。
- 普通居民的详情与场景外观共享其真实 `CombatActorData`，入队转移同一实例，保留出生属性、成长、特质、外观和伤势。既有剧情NPC保留原任务招募契约；已入队剧情/开局队员可建立个人成长档案，不补计历史事件。人形模板统一补齐成长及外观配置；动物沿原驯服规则。
- `PeopleProfileTable` 定义谋生脱困、求学、守护牵挂、战阵认同四类动机及可配置门槛。普通自由居民按种子/地点/稳定身份选取适用动机；同城按稳定顺序配对真实熟人。`PeopleNameTable` 提供24个名字；同一名字不是人物主键。
- 居民近身E或单位详情的独立“交谈”按钮进入 `PeopleDialogue`；服务商人、银行、码头等职务入口保持，职务人物暂不离岗。剧情NPC从原有对白进入。交谈要求探索阶段、存活、可达，不能通过详情远程招募或绕过城镇封锁。
- 谋生可支付预支或通过本人委托/熟人帮助取得信任；求学检查存活队员已学技能数，另有完成本人委托后资助路线；守护要求完成本镇清剿/护送，或熟人已入队且信任足够；敌方交涉要求真实战绩、队员等级和解约费用。条件查询不扣资源，提交重验来源、容量、站位与金币后转移。
- 完成本人真实委托增加本人信任40、熟人信任20；熟人入队增加信任20。委托凭据复用已保存的Narrative事实。正在进行/就绪的本人委托必须先完成，避免委托人消失；后续每日委托不选已招募居民，全镇无人时当天不生成委托。
- 主动追上非传奇、未绑定战场、至少两名存活成员且有人形的世界队伍，可在接触面板选择交涉；遭到自动袭击仍正常开战。世界角色转队保留装备实例与伤势，移除原编制对应实力权重并失效力量缓存；最后一名存活成员暂不转移。没有新增俘虏、复活、离队或随机背叛系统。
- `PeopleDialogueSession` 以 `DialogueId=-2` 和临时PersonKey复用现有对白面板；所有配置查询与镜头前分流，仍用 `DialogueVersion` 拒绝旧点击。地图会话把原世界队伍ID保存在 `DialogueLocalNpcId`，世界接触面板关闭清ContactId后仍能校验原来源；居民会话则保存本地NPC ID。
- `PersonalGrowthStage/ChoiceTable` 提供4种动机各2阶段、每阶段2选项，共8阶段16分支。真实开战时登记队员与递增战斗凭据；结算仅计当时参战且存活的队员。危急救援沿PartyStory实际成功回执，正式研习成功才计学习，赠技不计。个人凭据持久去重，浏览/读档不推进。
- 第一阶段授予专属经历特质；第二阶段替换本人第一阶段特质，授予独立终阶特质与对应技能。已掌握技能明确显示但仍获得新的特质。玩家在人物交谈中看到条件进度及真实奖励，明确选择后才提交阶段，并写入个人经历。不可同时获取同阶段两个分支。
- 存档v49/50保存People与成长凭据；旧1–48档迁移为空人物档案，不追溯补造经历。未入队居民保存完整Actor，世界/区域/已入队人物保存真实实例引用；已初始化成长的敌人新增成长/施法/称号快照。准备阶段校验姓名/动机、来源、共享引用、生命、牵挂及分支奖励一致性后再提交。
- 个人成长上限为两阶段，熟人关系目前为同城配对与信任传播；未实现全世界复杂亲缘网络、NPC自主职业成长、长期个人任务链或关系驱动背叛。

## 关键入口

- [People.lua](../../Lua/Game/Adventure/People.lua)、[PeopleRules.lua](../../Lua/Game/Adventure/PeopleRules.lua)：人物生成、招募、世界来源、委托与战斗回执；[PeopleState.cs](../../Assets/GameFramework/Runtime/Data/PeopleState.cs)：持久身份、共享实例、转移及保存验证。
- [PersonalGrowth.lua](../../Lua/Game/Progression/PersonalGrowth.lua)、[PersonalGrowthRules.lua](../../Lua/Game/Progression/PersonalGrowthRules.lua)、[配置](../../Config/Tables/People/)：经历条件、二选一、特质替换与奖励校验。
- [PeopleDialogue.lua](../../Lua/Game/Narrative/PeopleDialogue.lua)、[会话桥](../../Assets/GameFramework/Runtime/Data/PeopleDialogueSession.cs)、[UnitDetailsCtr.lua](../../Lua/UI/Panel/UnitDetailsCtr.lua)：实际交谈与培养入口。
- [people_rules.lua](../../Tools/Tests/people_rules.lua)、[personal_growth_core.lua](../../Tools/Tests/personal_growth_core.lua)、[people_dialogue.lua](../../Tools/Tests/people_dialogue.lua)：定向离线检查；[people_state_editmode.cs](../../Tools/Tests/people_state_editmode.cs)、[people_integration_editmode.cs](../../Tools/Tests/people_integration_editmode.cs)：真实数据与隔离服务/临时存档检查。仅按开发技能授权范围执行，不启动Editor或Play。
- [add_people_talk.cs](../../Tools/UI/add_people_talk.cs)：原生保存UnitDetails交谈按钮及语言绑定；[install_content.mjs](../../Tools/People/install_content.mjs)：通过内容中心review/save合入经历特质并统一导表，不手改生成物。
