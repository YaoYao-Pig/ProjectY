# 队员关系与持久经历
关键词：队员关系、救援、共战、关系阶段、特质消除、孤僻、守望者、荣誉、游戏日期、PartyStory。

## 文档目录
正文：真实事件 / 权威状态与存档 / 展示与验证；关键入口：模型 / 数据 / 配置 / 检查。

## 正文

- `Adventure.partyStory` 订阅 `Battle.Changed`，关闭时注销；新开局清理关系与临时战斗记录。数据由 `AdventureData.PartyBonds` 的 C# `PartyStoryData` 持有，Lua 只保存配置、依赖与显示投影。关系是稳定 actorId 的无向对，与 [NPC 对玩家好感](Narrative.md)独立。
- `battle_started` 记录当场真实参战队员；探索队伍中的旁观者与动物不自动参与。`Adventure:SettleBattle` 在战斗清理前显式调用 `Settle`；共同胜利且双方存活，各对关系增加 10、共同取胜次数增加 1。重复结算不再奖励。
- 危急救援要求正式 `combat` 阶段、不同己方参战角色、即时真实治疗量大于 0、治疗前生命在 `(0, 25% MaxHP]`；直接读取 `GameEffects` 发出的 `hpBefore/hpAfter/periodic`。自疗、部署、周期治疗、满血治疗和旁观者不计入。每场每个无向角色对最多计一次救援，关系加 25，救援者的个人次数加 1。
- 真实获救后按 `PartyStoryRuleTable.removeTraitIds` 移除特质，并记录原因和救援对象。当前包含既有“傲慢”和新增“孤僻”；傲慢原有速度加成不变，孤僻是实际防御 -2。初始特质仍由 `GrowthProfileTable` 决定，读取旧角色不会强加新特质。
- 关系范围 0–100，`PartyBondStageTable` 定义同行、信任（30）与生死与共（60）；跨越阈值时双方获得固定经历。阶段本身没有隐式战斗数值加成或协力能力。
- `PartyHonorTable` 定义自动荣誉，当前“守望者”需要本人累计三次真实救援。达成后保存荣誉身份、记录经历并显示在角色手记；当前荣誉无属性加成，不代表实体勋章、制作或可转授授勋。
- `ChronicleEntryData` 固定保存游戏分钟、日期、地点、主角、行为对象、精确参与者与关系变化；旧通用记录使用当前队伍/个人，`RecordPair` 仅涉及双方。日期读取 Narrative 的真实游戏时钟，个人页按参与者过滤。经历正文不会因之后特质或关系变化而改写。
- [角色存档](CharacterSave.md) v6 保存关系、个人救援次数、荣誉与完整经历。恢复必须覆盖新地图初始化时的临时历史；旧存档没有的关系与经历从空开始，不伪造过去。结构校验拒绝未知角色、重复关系/荣誉、不连续序号和救援合计不符；Lua 再校验荣誉配置与次数。
- 角色手记总览复用 `Traits` 标签及详情显示关系和荣誉，经历页显示“第 N 日 HH:mm”。标签区域可滚动，不新增 Prefab 绑定；状态变化同时检查关系 Revision 与历史条数。
- 无需导表的最小离线检查：`python -B Tools/Tests/social_source_check.py`，直接读取本模块源表，验证救援边界、同场去重、特质因果、关系阈值、日期/双方与荣誉。`social_integration.lua` 用真实战斗效果及独立临时存档验证 C# 状态和读取；`social_ui_integration.lua` 用真实 Prefab 验证标签、详情、历史和缓存重开。后两者需要集中编译、导表后的独立预览宿主，不因文档存在而自动执行。

## 关键入口

- [PartyStory.lua](../../Lua/Game/Progression/PartyStory.lua) / [PartyStoryRules.lua](../../Lua/Game/Progression/PartyStoryRules.lua)：监听、结算、投影和配置验证。
- [PartyBondData.cs](../../Assets/GameFramework/Runtime/Data/PartyBondData.cs) / [ChronicleEntryData.cs](../../Assets/GameFramework/Runtime/Data/ChronicleEntryData.cs) / [AdventureData.cs](../../Assets/GameFramework/Runtime/Data/AdventureData.cs)：权威状态、DTO、精确参与者与恢复。
- [PartyStoryRuleTable](../../Config/Tables/Progression/PartyStoryRuleTable.json) / [PartyBondStageTable](../../Config/Tables/Progression/PartyBondStageTable.json) / [PartyHonorTable](../../Config/Tables/Progression/PartyHonorTable.json)：救援、关系和荣誉内容。
- [定向离线检查](../../Tools/Tests/social_source_check.py) / [真实状态检查](../../Tools/Tests/social_integration.lua) / [真实 UI 检查](../../Tools/Tests/social_ui_integration.lua)。
