# 远征与角色存档
关键词：开始菜单、StartMenu、加载游戏、多存档、CampaignSaves、存档列表、世界种子、地图规模、F5、legacy、保存远征、CharacterSave、v20、战争迷雾、LOD、势力、占领、解放、编制。

## 文档目录
正文：开始菜单与存档目录 / 保存范围 / 提交流程 / 验证；关键入口：状态 / 服务 / 菜单 / 桥接。

## 正文

- 宿主启动先显示 `StartMenu` 首页，不自动生成世界。新游戏页选择 `CampaignStartTable` 身世、uint种子0–4294967295与2500／10000／30000／100000格。首批12身世分别使用 AdventureDemo/EquipmentDemo 配方101–112；继承配方5的全部地貌随机池及剧情集市附近出生规则，三人队伍首位为领队，保留一格招募位。旧配方1–5不修改，旧档仍按保存的recipeId恢复。种子在UI和命令边界校验，原始文本不经有符号int参数截断；探索HUD可重新打开菜单或选档页。
- `CampaignStarts.Get/List/Preview` 只解析配置：`id/name/description/adventureRecipeId/coins`；预览按真实开局包及角色默认装备汇总数量和自动装备者。菜单左侧滚动选择12身世，右侧展示背景、领队/同行、金币、装备/补给图标；选择与翻阅不发物品。当前身世不会自动赋予专属剧情或结局。
- `CampaignMenu.NewGame(...,startId)` 经加载桥传到 `CampaignCreation.New`；省略ID仅为旧调用默认1，非法或不存在ID在建世界前拒绝。候选任务保留所选配置，Commit按对应配方创建队伍/实际库存，设置 `flag:campaign_start`，再按配置重置金币并保存独立新档。标记使用原叙事事实保存，配方ID和实际装备仍由原Data掌管；读档不重播初始化，不改变旧档缺少身世标记的兼容规则。
- “创建世界并开始”通过[Loading](../Framework/Loading.md)分阶段准备世界与候选渲染，再提交会话及初始独立存档；按钮成功表示已受理加载。进度、文案轮换、失败与取消所有权见 Loading 模块；选档加载仍为原同步流程。
- 菜单为Adventure模块的Popup模态Panel，打开时暂停世界、阻挡场景输入，不能用Back直接关闭首页；子页提供返回首页，有会话时首页/选档页显示返回游戏。NarrativeView 首页/选档页820×640、身世页1100×640，通过CampaignMenu.Font取得字体，不依赖MainHud；选择行复用NarrativeEntry，物资预览复用MissionReward，组件全部走LuaReference。
- 每次从菜单成功创建世界后，才调用 `CampaignSaves.NewCampaign` 分配独立路径并保存初始远征；新文件为 `Application.persistentDataPath/Characters/Campaigns/<GUID N>.json`。F5及“保存远征”更新当前档，不覆盖其他远征。初始保存失败会明确提示“世界已创建但未保存”，当前新档身份仍可用F5重试；不能把仅分配ID当成写档成功。
- `CampaignSaves.List` 从档案本身读取本地保存时间、种子、世界规模和“3名队员 · Lv1 / Lv2 / Lv3”摘要，按保存时间倒序排列，不另写索引。损坏JSON、未知版本、超限文件或无效摘要应逐项显示错误并禁用加载，不隐藏为“没有存档”；目录级读取失败显示错误。摘要可读不代表完整世界校验已通过，真正加载仍执行下述准备事务。
- 原 `Characters/party-v1.json` 以opaque ID `legacy` 出现在列表中，显式加载后成为当前档，后续F5原位更新并保留备份。新槽只接受规范GUID编号，不允许传入任意文件路径；使用显式filePath构造测试服务时，legacy就是该文件，新槽只位于其同目录的Campaigns子目录，不访问玩家默认目录。槽身份由文件位置决定；当前保存版本见下方保存范围。
- 读写只允许map/area阶段，商队交互、商店、对话、营地和战利品窗口打开期间拒绝操作。保存四人以内的角色ID/模板、外观、HP/MaxHP、特质、等级经验、属性/天赋、已学技能、学习机会、当前/已加入职业及养成RNG；另保存金币/玩家等级、武器配件、弹匣余弹、防具耐久、独立物品堆与背包布局。
- 当前写入格式为v23（仅队伍）/v24（完整远征），沿用原v8/v9对保存范围的区分。背包保留旧stacks作为主堆，新增piles记录独立堆ID/物品ID/数量及nextPileId，布局保留每堆的位置与旋转；v1–v9显式迁移为空独立堆数组和计数器1。重复堆ID、无效计数器、总量溢出、缺位置或位置碰撞均在替换当前库存前拒绝。
- v23/v24 增加独立部位HP及上限，总HP为六部位之和；旧v21/v22保留创伤/致残/恢复计划并分配旧HP，永久部位不分配血量。新版本拒绝部位容量、总量或永久状态不一致，规则见[身体健康与创伤](BodyInjuries.md)。
- v21/v22 增加[身体健康与创伤](BodyInjuries.md)：队员、区域敌人和世界队伍成员保存六部位损伤、创伤类型与永久标记；旧v1–v20迁移为健康，新版本缺记录或非法永久状态在Prepare拒绝。
- v20 增加[大地图探索记录](WorldFog.md)：保存地图格数和已发现格，当前可见范围按小队位置重建；缺字段、重复/越界格及地图格数变化在 Prepare 阶段拒绝。v18 及更旧完整远征保留原地图与队伍位置，首次迁移仅揭开当前位置周围。
- v13/v14 增加远征全队共享的[协同发现](SkillTips.md)。`AdventureData` 持有稳定 ID 1–65535 的 bitset（ID-1 位），`skillSynergies={format:1,bits:Base64}` 只保存到最后非零字节。v1–v12 显式迁移为空；新版本缺字段、非法/非规范 Base64、超限、尾零和越界位均在 Prepare 拒绝。Lua 配置校验核对每个发现 ID；Apply 在玩家通知前一起提交，Reset 清空；读档不根据现有装备补发现。
- v9 保存地图种子、配方及目标格数、访问与一次性故事触发、当前区域、已探索/可见格、队员站位、居民位置、敌群生命/驯服/掉落结算、容器剩余内容/搜索进度/原始装备实例及物理耐久。静态布局按同一配方重新生成并校验，已击败敌人和已拿走掉落不会刷新；区域行走路径不续走。
- v12 增加[大地图队伍](WorldParties.md)的路段进度、目的地、货物、独立随机流与已击败状态。v16 的 `expedition.parties` 必须带 `rosterVersion=1`、角色序号和势力状态：每支队伍保存稳定成员实例、生命/伤势、外观、特质、效果与掉落标记，以及势力、职责、家园、任务/目标与决策时刻；成员装备继续保存于同一 EquipmentData。区域敌群用 `partyId/detached` 引用队伍编制，不再复制同一角色，恢复时重连对象，重复角色或错误战场归属在准备阶段拒绝。
- v16 同时保存外交增量及变更时间/原因、据点原势力/守卫/占据者、占领/解放/保护时刻、补员储备与恢复时刻；冲突保存双方队伍、目标据点、推进/最低结束/消失时刻、结果和独立随机流。玩家正在参与的战斗仍禁止保存；世界中自行推进的冲突可以随探索档保存，读档不会通过重新掷骰初始化它们。
- v18 增加[三级世界模拟](WorldLOD.md)：每队的精度、已模拟/下次到期时间、摘要行程起终点和时刻、满生命战力；冲突保存是否物化及延迟货舱。v16与更早版本按保存时钟初始化调度，旧战场明确为已物化，不重播历史。仅未物化冲突允许缺少MapArea；待落地货物纳入同一物品ID/唯一所有权校验。
- v9/v11/v12/v14 完整远征仍走原世界恢复事务，保留地图种子、区域探索、人物伤势与已存在的掉落，不按仅队伍档重开世界。v9/v11 原本没有世界队伍，恢复后补建新系统；v12/v14 保留已有队伍路线、货物、已击败状态，标记 `LegacyFactions` 后补势力与编制。若旧队伍已有区域战场，`AdoptLegacyParty` 收用原战场角色实例及伤势/掉落标记；仅没有旧编制的队伍创建成员，旧已击败队伍保持死亡。迁移完成后下次写入v24。
- 商人库存的 `hasOccupationRecovery/occupationRecoveryAt` 保存最后处理的解放时刻；旧档缺标记迁移为未处理（内部-1），游戏分钟0是有效解放时间。恢复后重开不能重复扣除同次损失；补货创建的新库存重新按当前恢复进度处理，具体交易规则见[商店](Shop.md)。
- [大地图旅行](WorldTravel.md)保存当前位置、途中步进、剩余路线、遭遇随机流、历史停靠及战场。继续后旅行暂停，玩家可明确恢复或改路。
- [营造](Construction.md)的工事、挖掘与损伤，以及工具障碍的清除/尝试次数随远征保存。战斗和事件进行阶段不能保存。v1–v8 没有地图记录，只能导入角色并开始新地图，界面明确显示迁移结果。
- v8 持续效果增加 Buff 组件数值快照及游戏分钟到期/周期时刻；v1–v7 显式补为空快照，保留旧效果的数值与回合计数。新复合状态的身份、组件顺序、生命周期和计时由 [GameEffect](GameEffects.md) 校验。
- v7 武器和防具增加单词缀 `affixId`，见[装备品质](Equipment.md)；v1–v6 的装备显式迁移为普通（ID 1），不随机补品质。v7 缺词缀、未知 ID 或不适用的类型在提交前拒绝。实体恢复不重新生成词缀，下一次新装备仍使用原存档种子与 nextId。
- v6 引入武器/防具耐久、[营地](Camp.md)设施/仓库/生产订单、[同行关系](PartyStory.md)/救援/荣誉及带日期和参与者的经历日志。版本 1–5 显式迁移为满耐久和空的新系统；v6 及以后缺新字段明确拒绝。日志日期须依序不减且不晚于叙事时钟。
- 版本 1–4 保留技能、专精、学习次数与 RNG，清除旧随机候选；Lua 配置校验阶段按 GrowthProfile 补初始职业及对应准备技，不额外发学习机会。v5 及以后缺职业、无效职业或当前职业不在已加入列表明确拒绝。
- 继续保存 [NPC 商店](Shop.md)库存和补货周期（v1–3 迁移为空）、角色/坐骑持续 GameEffect（v1/2 迁移为空）及[叙事状态](Narrative.md)：任务、击杀计数、事实、好感/招募、声望与游戏时钟（v1 迁移为新叙事初始状态）。临时商店/对话/营地面板不保存，打开期间禁止读写；未知版本拒绝。
- 可变状态仍归 C# Data。`CharacterSaveState` 是这些 Data 的内部序列化实现，不能在 Lua 另存一套角色/库存。恢复时保留 `EquipmentData` 对象身份，避免系统缓存指向旧库存。
- 保存先在内存验证，再写入当前档同目录的 `.tmp` 并Flush，以Replace/Move提交，已有档案保留 `.bak`，每档上限32 MiB；列表忽略临时/备份文件。`CharacterSaveService.Save/Prepare/Apply` 原接口保留，新增能力经静态反射桥 `CampaignSaves` 调用，不手改生成wrapper。
- `PrepareSelected(service,id,currentEquipment)` 只准备候选并记录来源服务/槽ID，不改变当前身份或磁盘。Lua继续调用 `CharacterSave.Validate` 与 `ExpeditionSave.Prepare`，在独立Data和静态地图中核对配置、库存、区域及世界状态；全部通过才执行 `RestorePrepared/Apply`。Apply验证候选归属，在所有Data提交后、玩家Changed通知前切换当前ID/路径；失败准备不能把后续F5指向未加载的档案。
- 损坏文件、未知版本、失效配置或背包重叠都明确报错，保持当前队伍；不会静默生成默认角色或把不兼容存档当作有效数据。旧版职业迁移只改独立 prepared 角色，全部校验成功后才提交。
- 提交先恢复全部Data与当前存档身份，再发布一次玩家变更通知；监听器只能读取完整提交后的队伍、金币、叙事、营地、关系和日志。每份prepared只能提交一次。
- 既有开始菜单验证记录：原生StartMenu UI检查4组已通过，使用实际Prefab/Widget与隔离命令适配器，覆盖首次无HUD、种子/规模、坏档禁载及缓存重开；多档真实服务6组通过，包含损坏/未来版本逐档隔离、当前档提交与旧档兼容。[真实开局命令检查](../../Tools/Tests/campaign_menu_flow.lua)另验证种子/规模边界、初始独立存档、跨世界选档恢复和F5目标。该轮使用隔离PreviewScene及系统临时目录，不读写玩家档案，未进入Play；这些历史结果不代表本次v16势力扩展已经通过完整集成验证。
- 2026-10-16 已在现有 Unity Editor 的独立 LuaEnv、临时文件与真实公开服务上通过 v9 定向验收：真实区域邻格移动、敌群击败与掉落、部分领取不重生、原武器存回未破坏箱后的 ID/词缀、当前区域/迷雾/站位、箱体动态阻挡、玩家通知时序、火炬开关、原子覆盖与 `.bak`，以及损坏 JSON/未知版本 99 拒绝后保持当前会话。未进入 Play，不代表长期游玩或所有旧档迁移已验收。
- 旧 `Project Y/角色/验证外观生成与角色存档` 与 [v6 联合存档回归](../../Tools/Tests/gameplay_v6_save_integration.lua)保留历史测试范围；其中部分用例假定读档重开地图、敌装过滤及旧版本号替换，与 v9 远征契约不同，不能直接作为本轮通过依据。当前入口使用下方公开服务验收脚本；旧版迁移的完整磁盘矩阵仍需单独定向检查。

## 关键入口

- [保存服务](../../Assets/GameFramework/Runtime/Data/CharacterSaveService.cs) / [目录元数据与CampaignSaves桥](../../Assets/GameFramework/Runtime/Data/CampaignSaveCatalog.cs) / [Data 序列化](../../Assets/GameFramework/Runtime/Data/CharacterSaveState.cs)。
- [世界队伍编制与序列化](../../Assets/GameFramework/Runtime/Data/WorldPartyData.cs) / [外交、据点、冲突与反射桥](../../Assets/GameFramework/Runtime/Data/WorldFactionData.cs) / [商人库存损毁标记](../../Assets/GameFramework/Runtime/Data/ShopData.cs)。[faction_data_editmode.cs](../../Tools/Tests/faction_data_editmode.cs)提供独立内存 Data 的引用恢复、旧编制接管和库存幂等检查；完整v16磁盘迁移与实机验收须另行执行，不能把脚本存在当作通过。
- [远征 Data 序列化](../../Assets/GameFramework/Runtime/Data/ExpeditionSaveState.cs) / [地图预检与恢复](../../Lua/Game/Adventure/ExpeditionSave.lua)；[原生公开服务验收](../../Tools/Tests/campaign_save_integration.lua)由独立 Edit Mode LuaEnv 和临时路径运行，覆盖真实区域移动、敌掉落/领取、原装备存回阻挡箱、完整磁盘读写与损坏记录拒绝；不启动 Editor 或进入 Play。
- [配置校验与读写命令](../../Lua/Game/Adventure/CharacterSave.lua) / [HUD](../../Lua/Game/Adventure/MainHudModel.lua) / [桥接](../../Lua/Game/Adventure/DemoBridge.lua)。
- [StartMenuCtr.lua](../../Lua/UI/Panel/StartMenuCtr.lua) / [菜单打开桥](../../Lua/UI/CampaignMenuBridge.lua) / [CampaignMenu.cs](../../Assets/GameFramework/Samples/Adventure/CampaignMenu.cs) / [宿主](../../Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs)：菜单输入、会话阻挡及开始/加载入口。[CampaignMenuAssets.cs](../../Assets/GameFramework/Editor/CampaignMenuAssets.cs)提供 `Project Y/远征/创建开始菜单`，只创建缺失资源。
- [CampaignStartTable.json](../../Config/Tables/Adventure/CampaignStartTable.json) / [CampaignStarts.lua](../../Lua/Game/Adventure/CampaignStarts.lua)：身世源数据与预览；[start_origin_assets.cs](../../Tools/Tests/start_origin_assets.cs) 经 Unity MCP 在 Edit Mode 定向补齐开始菜单绑定并同步新物品图标，新建基础菜单后也使用此入口。
- [campaign_starts.lua](../../Tools/Tests/campaign_starts.lua) 与 [start_profiles_config.lua](../../Tools/Tests/start_profiles_config.lua) 使用 `Tools/Tests/run_lua.py`，检查选择/预览/一次提交和12套配置；[start_origins_editmode.cs](../../Tools/Tests/start_origins_editmode.cs) 经 Unity MCP 执行 [菜单检查](../../Tools/Tests/start_menu_integration.lua) 与 [真实开场/存档检查](../../Tools/Tests/campaign_origin_integration.lua)，使用独立PreviewScene及系统临时存档，输出[选择页预览](../../Docs/Previews/Starts/selection.png)，不进入Play或访问用户存档。
- [菜单原生检查](../../Tools/Tests/start_menu_editmode.cs)执行[实际UI测试](../../Tools/Tests/start_menu_integration.lua)，不创建真实世界或存档；[多档真实服务检查](../../Tools/Tests/campaign_slots_integration.lua)必须使用操作系统临时目录下未使用的显式保存路径，覆盖新档隔离、目录摘要、候选提交、当前档覆盖、坏档/路径拒绝与legacy。
- [Editor 验证](../../Assets/GameFramework/Editor/CharacterIntegrationValidation.cs) / [真实集成检查](../../Tools/Tests/character_integration.lua)。
