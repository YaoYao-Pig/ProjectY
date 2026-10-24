# 势力关系与大地图冲突
关键词：势力、组织、外交、关系、合作、敌对、实力、兽人、哥布林、树精灵、劫掠、据点、占领、解放、恢复、三方混战、黄色第三方。

## 文档目录
正文：关系与战略 / 战场与据点 / 持久化与表现 / 验证；关键入口：规则、数据、配置、模型。

## 正文

- 世界现按[三级 LOD](WorldLOD.md)调度：近层精算，中层批量推进，远层直接结算；本页的关系、占领和资源契约保持不变。v18 增加调度与未物化战场持久化，完整规则和性能预算以 LOD 文档为准。

- 复用 Narrative `FactionTable` 的稳定组织 ID；新增铁牙战团、草刺部族、高树林庭、灰路匪帮与野生生态身份。玩家关系为策略初值加现有声望；NPC 间使用双向配表及 C# 关系覆盖。同盟不传递，中立与同盟分开。野兽不参与据点进攻。
- `WorldFactionsData` 归 `WorldPartiesData` 所有；据点归属、占据者、解放时间、储备、恢复时间、外交覆盖与冲突均在 C#。Lua 只持规则、布局和查询缓存；不能修改只读 Map 快照。
- 原有城镇归人类势力；新增据点按 `WorldFactionTable.regionTypes/siteCount/modelPath` 筛选干地、净距、邻接通路，作为持久旅行地点追加，保持基础地图身份。森林承载树精灵驻地，高树剪影来自据点模型；本轮未新增独立的高树森林地形枚举。候选不足时不会强行生成不适宜据点。
- 世界队伍持有唯一 Actor 编制，保存伤势、外观和效果。守军固定驻地，移动队按真实归属据点限制巡逻范围。实力来自实际存活成员与战斗属性，死亡/受伤降低实力；查询缓存按模拟分钟和结算失效。
- 决策先排除不敌对、不可达、超程、留守不足、储备不足、路线威胁过高与保护期，再比较优势、收益、行程、安全和行为偏好。现有任务有评分优势；目标失效清除旧路径。攻城使用局部战力与防御系数，不能直接用势力总实力决定开战。
- 性能契约：距离与静态硬门槛在寻路前筛选，获选路线交给 `WorldParties:ApplyRoute`；不要给 `Plan` 加接收格子查询多返回值的可选尾参。玩家/势力实力共用失效边界；接触检测先做本次队伍查询快照和空间筛选，保持先攻顺序。暂停地图的未变化轮询通过 `DemoBridge` 返回 `unchanged`，C# 跳过完整读取与 HUD 同步；实际测量与边界见[性能修复](../../Docs/FactionPerformance.md)。
- 商队避开停止服务的城镇；移动队受伤或取得货物后返回据点。补员/治疗消耗有限储备，驻军和已回家的移动队共用恢复节奏。劫获货物转移原实例；运回据点后消耗为有上限的补给，不复制物品。全灭移动队不会凭空在野外复活。
- 敌对 NPC 队伍在实际可达的接触范围内创建唯一冲突，停止世界移动。近层后台按分钟推进同一批 Actor 的生命，中远层按 LOD 批量或摘要结算；默认至少 45 分钟后结算伤亡，最长 150 分钟后按剩余状态判定撤退/胜负。玩家加入后暂停该冲突后台结算，使用当前伤势；世界时间沿用战斗暂停规则。
- `WorldConflicts` 当前一场持有最多两支 NPC 队伍，玩家加入形成最多三方。关系逐对决定敌我；合作方由 AI 控制，仍与玩家 side 分开；主要敌方红色、盟军绿色、独立第三方黄色，即使第三方敌对也保持黄色。颜色不决定可攻击或可治疗对象，详见[战斗](Battle.md)。
- 点击交战中的友好商队可选“参与这场战斗”，不会因此宣战；两方都不敌对时保持中立。主动攻击非敌对队伍降低玩家声望。战后 Actor、货物、掉落和关系只结算一次；幸存者脱离战场但保留伤势。
- 攻陷不会改写原城镇/任务 NPC 身份。占据状态阻断交易、居民交互与招募；玩家再次进入原地点会进入该坐标的解放战场。只有玩家胜利才解除占据，原城镇随后可重新进入。解放后默认 24 游戏小时免袭，商品/可招募 NPC 从 35% 开始，72 小时恢复；参数均配表。库存每个补货实例、每次解放仅削减一次，见[商店](Shop.md)。
- 战斗结束生成可搜刮遗迹，默认 24 游戏小时后停止进入；正在使用的区域等离场后再到期。过期记录保留于存档以维持地点 ID，不再出现在地图入口；不是释放所有历史 Data 的内存回收器。
- v18 完整远征沿用 v16 唯一队伍编制，并保存 LOD 调度与未物化战场；战场仅存队伍引用并在读档重连，历史遗迹的 Detached 引用不复活角色。旧档迁移保留基础世界、路线、货物和既有战场伤势；不手改 xLua 生成包装器，新增 MapArea API 通过 `FactionPersistence` 反射桥使用。详见[存档](CharacterSave.md)。
- 三种据点真实 FBX 与材质已导入，AdventureDemo 的 `worldPartyBindings` 增量追加，Lua 快照提供据点模型行，点击回到正常旅行入口。纯色低多边形资源、源文件和同框预览见[资源说明](../../Art/FactionLowPoly/README.md)。

## 验证

- 原生 Lua：`python -B Tools/Tests/run_lua.py Tools/Tests/factions_core.lua`、`faction_services.lua`、`battle_sides.lua`；对应外交、战略、后台生命周期、服务恢复及多方战斗。相关回归按改动选 `world_parties_core.lua`、`world_travel_core.lua`，不全量运行。
- `faction_data_editmode.cs` 为现有 Editor 的内存代码体，覆盖真实 Data、引用/随机流与存档拒绝、货物转移、商店幂等，不打开场景或用户存档。
- `factions_editmode.cs` 在独立 PreviewScene/LuaEnv 与临时存档运行 `factions_integration.lua`，覆盖真实生成、后台伤亡、援助/三方战斗、NPC 攻陷、玩家解放与远征存读；结果写 `Art/FactionLowPoly/Integration/gameplay-validation.txt`。不进入 Play。
- 本轮完成一次主动项目编译、上述真实数据检查与静态模型预览；未进行长时间 Play 和完整平衡性验收。

## 关键入口

- [外交与评分](../../Lua/Game/Adventure/FactionRules.lua) / [战略与恢复](../../Lua/Game/Adventure/WorldFactions.lua) / [冲突与介入](../../Lua/Game/Adventure/WorldConflicts.lua) / [队伍移动与交互](../../Lua/Game/Adventure/WorldParties.lua)。
- [势力 Data](../../Assets/GameFramework/Runtime/Data/WorldFactionData.cs) / [队伍与编制](../../Assets/GameFramework/Runtime/Data/WorldPartyData.cs) / [完整远征持久化](../../Assets/GameFramework/Runtime/Data/ExpeditionSaveState.cs)。
- [势力配置](../../Config/Tables/Travel/WorldFactionTable.json) / [初始外交](../../Config/Tables/Travel/WorldFactionRelationTable.json) / [数值规则](../../Config/Tables/Travel/WorldFactionRuleTable.json)。
- [设计依据与边界](../../Docs/FactionSystemDesign.md) / [原生检查](../../Tools/Tests/factions_core.lua) / [真实集成](../../Tools/Tests/factions_integration.lua) / [模型预览](../../Art/FactionLowPoly/Previews/faction-sites-unity.png)。
