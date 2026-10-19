# 远征与角色存档
关键词：继续游戏、保存远征、随机开局、探索存档、角色存档、磁盘保存、CharacterSave。

## 文档目录
正文：范围 / 提交流程 / 验证；关键入口：状态 / 服务 / Lua / HUD。

## 正文

- 探索 HUD 的菜单提供“保存远征 [F5]”和“继续游戏”。只允许 map/area 阶段；商店、对话、营地和战利品窗口打开期间拒绝读写。新游戏不覆盖磁盘存档；继续恢复最近一次手动保存。
- 单槽路径为 `Application.persistentDataPath/Characters/party-v1.json`。保存四人以内的角色 ID/模板、外观、HP/MaxHP、特质、等级经验、属性/天赋、已学技能、主动学习机会、当前/已加入职业及养成 RNG；另保存金币/玩家等级、武器配件、弹匣余弹、防具耐久、堆叠与背包布局。
- 当前写入格式为v10（仅队伍）/v12（完整远征），沿用原v8/v9对保存范围的区分。背包保留旧stacks作为主堆，新增piles记录独立堆ID/物品ID/数量及nextPileId，布局保留每堆的位置与旋转；v1–v9显式迁移为空独立堆数组和计数器1。重复堆ID、无效计数器、总量溢出、缺位置或位置碰撞均在替换当前库存前拒绝。
- v9 保存地图种子、配方及目标格数、访问与一次性故事触发、当前区域、已探索/可见格、队员站位、居民位置、敌群生命/驯服/掉落结算、容器剩余内容/搜索进度/原始装备实例及物理耐久。静态布局按同一配方重新生成并校验，已击败敌人和已拿走掉落不会刷新；区域行走路径不续走。
- v12 增加[大地图队伍](WorldParties.md)的路段进度、目的地、货物、独立随机流与已击败状态；v9/v11 远征档显式初始化新队伍，交互窗口不保存。
- [大地图旅行](WorldTravel.md)保存当前位置、途中步进、剩余路线、遭遇随机流、历史停靠及战场。继续后旅行暂停，玩家可明确恢复或改路。
- [营造](Construction.md)的工事、挖掘与损伤，以及工具障碍的清除/尝试次数随远征保存。战斗和事件进行阶段不能保存。v1–v8 没有地图记录，只能导入角色并开始新地图，界面明确显示迁移结果。
- v8 持续效果增加 Buff 组件数值快照及游戏分钟到期/周期时刻；v1–v7 显式补为空快照，保留旧效果的数值与回合计数。新复合状态的身份、组件顺序、生命周期和计时由 [GameEffect](GameEffects.md) 校验。
- v7 武器和防具增加单词缀 `affixId`，见[装备品质](Equipment.md)；v1–v6 的装备显式迁移为普通（ID 1），不随机补品质。v7 缺词缀、未知 ID 或不适用的类型在提交前拒绝。实体恢复不重新生成词缀，下一次新装备仍使用原存档种子与 nextId。
- v6 引入武器/防具耐久、[营地](Camp.md)设施/仓库/生产订单、[同行关系](PartyStory.md)/救援/荣誉及带日期和参与者的经历日志。版本 1–5 显式迁移为满耐久和空的新系统；v6 及以后缺新字段明确拒绝。日志日期须依序不减且不晚于叙事时钟。
- 版本 1–4 保留技能、专精、学习次数与 RNG，清除旧随机候选；Lua 配置校验阶段按 GrowthProfile 补初始职业及对应准备技，不额外发学习机会。v5 及以后缺职业、无效职业或当前职业不在已加入列表明确拒绝。
- 继续保存 [NPC 商店](Shop.md)库存和补货周期（v1–3 迁移为空）、角色/坐骑持续 GameEffect（v1/2 迁移为空）及[叙事状态](Narrative.md)：任务、击杀计数、事实、好感/招募、声望与游戏时钟（v1 迁移为新叙事初始状态）。临时商店/对话/营地面板不保存，打开期间禁止读写；未知版本拒绝。
- 可变状态仍归 C# Data。`CharacterSaveState` 是这些 Data 的内部序列化实现，不能在 Lua 另存一套角色/库存。恢复时保留 `EquipmentData` 对象身份，避免系统缓存指向旧库存。
- 保存先在内存验证，再写入同目录临时文件并 Flush，以 Replace/Move 提交；已有档案保留 `.bak`。文件上限 32 MiB。读取先准备独立角色、库存和探索 Data，再生成独立静态地图、核对区域布局/配置；全部通过才替换当前会话。`ExpeditionPersistence` 提供反射桥接，禁止手工编辑生成绑定。
- 损坏文件、未知版本、失效配置或背包重叠都明确报错，保持当前队伍；不会静默生成默认角色或把不兼容存档当作有效数据。旧版职业迁移只改独立 prepared 角色，全部校验成功后才提交。
- 提交先恢复全部 Data，再发布一次玩家变更通知；监听器只能读取完整提交后的队伍、金币、叙事、营地、关系和日志。每份 prepared 只能提交一次。
- 2026-10-16 已在现有 Unity Editor 的独立 LuaEnv、临时文件与真实公开服务上通过 v9 定向验收：真实区域邻格移动、敌群击败与掉落、部分领取不重生、原武器存回未破坏箱后的 ID/词缀、当前区域/迷雾/站位、箱体动态阻挡、玩家通知时序、火炬开关、原子覆盖与 `.bak`，以及损坏 JSON/未知版本 99 拒绝后保持当前会话。未进入 Play，不代表长期游玩或所有旧档迁移已验收。
- 旧 `Project Y/角色/验证外观生成与角色存档` 与 [v6 联合存档回归](../../Tools/Tests/gameplay_v6_save_integration.lua)保留历史测试范围；其中部分用例假定读档重开地图、敌装过滤及旧版本号替换，与 v9 远征契约不同，不能直接作为本轮通过依据。当前入口使用下方公开服务验收脚本；旧版迁移的完整磁盘矩阵仍需单独定向检查。

## 关键入口

- [保存服务](../../Assets/GameFramework/Runtime/Data/CharacterSaveService.cs) / [Data 序列化](../../Assets/GameFramework/Runtime/Data/CharacterSaveState.cs)。
- [远征 Data 序列化](../../Assets/GameFramework/Runtime/Data/ExpeditionSaveState.cs) / [地图预检与恢复](../../Lua/Game/Adventure/ExpeditionSave.lua)；[原生公开服务验收](../../Tools/Tests/campaign_save_integration.lua)由独立 Edit Mode LuaEnv 和临时路径运行，覆盖真实区域移动、敌掉落/领取、原装备存回阻挡箱、完整磁盘读写与损坏记录拒绝；不启动 Editor 或进入 Play。
- [配置校验与读写命令](../../Lua/Game/Adventure/CharacterSave.lua) / [HUD](../../Lua/Game/Adventure/MainHudModel.lua) / [桥接](../../Lua/Game/Adventure/DemoBridge.lua)。
- [Editor 验证](../../Assets/GameFramework/Editor/CharacterIntegrationValidation.cs) / [真实集成检查](../../Tools/Tests/character_integration.lua)。
