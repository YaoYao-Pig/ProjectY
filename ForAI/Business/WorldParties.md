# 大地图可见队伍
关键词：商队、游荡敌人、追击、强盗、哥布林、兽人、巨狼、岩石巨兽、队伍旗帜、买卖、货物、WorldParties。

## 文档目录
正文：时间与移动 / 接触与战斗 / 交易与存档 / 资源与验证；关键入口：配表、规则、Data、展示。

## 正文

- 大地图每支队伍显示一个独立三维棋子，玩家使用旗帜；点击队伍追赶，悬停显示名称与目的地或状态。现有全图与小队定位操作仍由[旅行](WorldTravel.md)提供。
- `WorldPartiesData.For(AdventureData)` 持有实体、每队的 `WorldTravelData`、独立随机流、目的地、战场、交易会话及货物；Lua 只保存地图索引、配置和城际连通查询。新远征清空实体；不在地图生成快照内放可变队伍。
- 队伍按叙事游戏分钟推进，采用整游戏分钟模拟、显示层插值。小队待命时仍走世界时间，商队和敌人继续移动；空格暂停全部队伍，数字键 1/2/3 选择 1×/2×/4×。局部探索和营地等待推进游戏时间时，外部队伍继续旅行。模态交互冻结时间；队伍接触会显式暂停，关闭后需按空格继续。
- 商队只连接有可走陆路的不同城镇；抵达后补货并驶往另一城镇。水格和陡坡沿用玩家旅行成本，不瞬移、不跨无路水域。找不到有效城际路线时不生成那支商队。
- 敌人局部游荡，进入探测范围后追赶玩家；到邻格且陆路可达时接触开战。点击商队只在追上后显示交易/攻击选项；远程交易、无存活队员接触及过期点击均拒绝。
- 战斗复用持久随机战场、部署和搜刮。胜利将商队剩余货物转入战场容器，实体只移除一次；未拾取物品留在战场。撤退/败北后该队驻留原位置并获得脱战保护，再次交战沿用原战场和敌人伤势。当前不自动补生被消灭队伍。
- 巨狼在战斗中占两格，岩石巨兽占四格，大地图仍为单格。`CombatBodyTable` 为非人形单位提供通用占位；不登记成可驯服/骑乘动物。部署、寻路、射线阻挡、距离和地格高亮使用完整占地，模型放在占地中心。
- 商队库存由 `MapAreaLootData` 保存，与战利品共用物理装备转移。购买一次一件；出售背包中的一件装备或一整堆物品。已装备物品须先卸下；售出的词缀、耐久、配件及弹匣保留在原实例中。抵达城镇时整批更新货物。
- `WorldTradePriceTable` 覆盖所有物品，已有商店商品沿用原售价；收购单价为售价乘 `sellMultiplier` 后向下取整。金币为整数，售价 1 的物品收购价为 0。购买先检查金额/背包空间，出售先检查库存版本/货舱空间，成功后才改变金币。商队交易不改变原城镇商店的购买流程。
- 完整远征 v12 保存队伍位置、路段进度、目的地、随机流、货物和已击败状态；接触窗口不入档，读档后玩家旅行暂停。v9/v11 远征档显式初始化新队伍；保存/读取时必须先关闭队伍窗口。详见[存档](CharacterSave.md)。
- 源资源在 `Art/WorldPartyLowPoly/Source/`，Unity 资源在 `Assets/DynamicAsset/WorldPartyLowPoly/`。七种地图棋子与两件战斗身体共九个 FBX，纯色 URP Lit、米制、零根旋转、单位缩放。`AdventureDemo.worldPartyBindings` 绑定地图模型；巨兽身体走已有 `pawnBindings`。
- UI 使用 `WorldParty` Panel、`NarrativeEntry` Widget 与显式 LuaReference；`NarrativeAssets.CreateWorldParty` 只创建缺失资源。模型导入脚本只改本套资源及 AdventureDemo 的相关绑定，不重建其他棋子资源。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/world_parties_core.lua` 与 `world_travel_core.lua`；真实 Data、买卖、UI、战斗结算及存档使用 `world_parties_editmode.cs` 的独立 PreviewScene/LuaEnv/临时存档。当前已通过上述检查、一次主动 C# 编译及模型导入/静态预览；未进入 Play，不代表长时间游玩验收。

## 关键入口

- [队伍表](../../Config/Tables/Travel/WorldPartyTable.json) / [统一规则](../../Config/Tables/Travel/WorldPartyRuleTable.json) / [交易价格](../../Config/Tables/Travel/WorldTradePriceTable.json) / [怪物占位](../../Config/Tables/Travel/CombatBodyTable.json)。
- [规则](../../Lua/Game/Adventure/WorldParties.lua) / [权威数据与货物转移](../../Assets/GameFramework/Runtime/Data/WorldPartyData.cs) / [实体展示](../../Assets/GameFramework/Samples/Adventure/WorldPartyView.cs) / [交互控制器](../../Lua/UI/Panel/WorldPartyCtr.lua)。
- [多格部署](../../Lua/Game/Battle/BodyFootprints.lua) / [远征存档预检](../../Lua/Game/Adventure/ExpeditionSave.lua)。
- [建模源](../../Art/WorldPartyLowPoly/Source/WorldParties.blend) / [怪物源](../../Art/WorldPartyLowPoly/Source/WorldMonsters.blend) / [导入与绑定](../../Art/WorldPartyLowPoly/Scripts/import_unity.cs) / [资源清单](../../Art/WorldPartyLowPoly/Integration/asset-manifest.json)。
- [移动目标追赶检查](../../Tools/Tests/world_parties_chase.lua) / [实际显示与拾取宿主](../../Tools/Tests/world_parties_presentation.cs) / [显示检查结果](../../Art/WorldPartyLowPoly/Integration/presentation-validation.txt)。
- [Unity 预览](../../Art/WorldPartyLowPoly/Previews/world-parties-unity.png) / [导入检查](../../Art/WorldPartyLowPoly/Integration/unity-import.json) / [真实集成检查](../../Tools/Tests/world_parties_integration.lua) / [Edit Mode 宿主](../../Tools/Tests/world_parties_editmode.cs) / [结果](../../Art/WorldPartyLowPoly/Integration/gameplay-validation.txt)。
