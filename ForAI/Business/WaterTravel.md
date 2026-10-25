# 码头与水上旅行

关键词：码头、工人、破损、修复、清敌、材料、河船、购船、客运、野外停靠、水路、WaterTravel。

## 文档目录

正文：世界与城内水岸 / 操作与状态 / 存档与验证；关键入口：规则、数据、资源与检查。

## 正文

- 码头自世界生成 v9 启用，新世界默认 v10；`MapDocks.Build` 从真实城镇可步行范围选择水岸，一城最多一码头，以 `town.id` 为稳定身份。初始结构／威胁用独立种子产生；v8 及以前没有新增码头，原地形和城市布局不改变。配置在 `DockSettingsTable`。
- `MapAreaSystem:Entrances` 传递 `source.dock` 与生成版本；普通城与王城的 `TownWaterfront` 在 v10 生成整侧连续水域：岸线沿码头朝向横贯城市该侧，各横向截面从岸线向外一直是水，延伸至地图边界；保护道路、设施、门口与坡道，岸线带有凹湾、岬角和自然高低起伏，码头接入处保持平整。水格不能步行，靠岸公共甲板有明确双向步行边。`area.waterfront` 提供码头、工人、设施、甲板资源与落脚格身份。无合格候选明确报错，不把纯背景水作为完成。已保存 v9 世界由 `TownWaterfrontLegacy` 保留原水湾和地格身份，不在读档时重切岸线。
- 大小地图显示同一 `WaterTravelData` 码头状态。城内 `LayoutSnapshot(water?)` 可接收水行规则门面以投影当前完整／破损模型；独立静态预览省略参数时使用初始模型。甲板靠岸部分两态共用，破损段没有通行格；修复只更换显示，不重排城市。
- 靠近工人按 E 打开 `Harbor`。恢复任务可以需要交材料、附近清敌或两者；接取后仅玩家侧敌对击杀在该码头岸格 `threatRadius` 内累计，材料交付重新检查背包并只扣一次。恢复为当前世界持久状态。任务手记的城镇页列出已接／已完成码头任务；工人不使用每日随机委托作为恢复状态。
- 当前默认木材物品 81 ×6、附近击杀3、整队河船180金币；客运10金币起步＋每水路格1金币，船行每格2游戏分钟。均可配表，不代表最终平衡。普通船承载当前整队，无耐久、升级、船战或多船管理。
- 客运仅列已发现、存在实际水路的目的港；出发和目的港还需营业且满足城镇服务条件。付款后显示小船按真实水路行进，暂停／倍速复用世界旅行；不能中途改客运目的地。抵港前再次检查状态和实际水格，失效时保留付款／旅程并暂停，恢复后继续时间会重试抵港。
- 自有船：在码头购买和登船；大地图点水格规划航行。航行到安全岸边后，点相邻岸格下船；步行回船旁，再点停泊船所在水格登船。上下船必须处于格点，半格不能切换。岸格须无建筑／地形阻挡、高差合格且有可步行内陆邻格。船留在原水格，公共客运不搬运自有船。
- `WaterNavigation` 共用水格深度、相邻水位差和瀑布阻断规则；客运与自有船不穿陆地或跨不连通水系。陆地商队仍用原步行代价；登船脱离护送，水上禁止与陆地队伍接战，也不积累陆地随机遭遇时钟。世界时间、岸上队伍和实际航行位置附近的迷雾继续更新。
- C# `WaterTravelData.For(AdventureData)` 持有码头恢复、唯一船的位置／归属、`walk/ferry/owned` 模式、付款和目的港；`WorldTravelData` 仍是唯一队伍坐标／路线／边进度。Lua 仅维护不可变布局索引与水路缓存。登离船经边界检查后使用 `Relocate`，活动路线禁止重定位。
- 存档可选 `waterTravel.format=1` 随远征 Capture／Prepare／Apply；v9 及以后必须有完整码头集合。候选阶段检查船停泊引用、水路每条边及客运终点／目的地点的一致性，再提交并保持 Data 身份；旧版本缺字段为空，无船。继续游戏暂停，航行中不重新扣票款。
- 表内名称和描述是 `text`；菜单／状态／报错来自 `Language.Water*`，详见[本地化](../Framework/Localization.md)。资源与原生绑定见[美术接入](../../Art/DocksLowPoly/Integration/README.md)。设计背景及首版外范围见[设计文档](../../Docs/DocksAndWaterTravelDesign.md)。

- 水面保持统一水位，按离岸深度从浅青绿过渡至深蓝；共享角顶点的颜色一致，避免逐格边框。陆岸与水床的变化来自布局，水面不随河床起伏。v10 水格不绘制被不透明水面覆盖的河床顶面／外壁，避免地图外沿出现土色围框；逻辑水深和阻挡保留。

## 关键入口

- [选址](../../Lua/Game/Map/MapDocks.lua)、[城内水岸](../../Lua/Game/MapArea/TownWaterfront.lua)／[v9兼容布局](../../Lua/Game/MapArea/TownWaterfrontLegacy.lua)、[配置](../../Config/Tables/Travel/DockSettingsTable.json)。
- [航行规则](../../Lua/Game/Adventure/WaterTravel.lua)、[水路判定](../../Lua/Game/Adventure/WaterNavigation.lua)、[权威状态与序列化](../../Assets/GameFramework/Runtime/Data/WaterTravelData.cs)、[远征保存接入](../../Assets/GameFramework/Runtime/Data/ExpeditionSaveState.cs)。
- [码头控制器](../../Lua/UI/Panel/HarborCtr.lua)、[原生界面](../../Assets/DynamicAsset/UI/Prefabs/WorldParty/HarborPanel.prefab)、[大地图码头／船显示](../../Assets/GameFramework/Samples/Adventure/WorldWaterView.cs)、[城内水面](../../Assets/GameFramework/Samples/Adventure/TownWaterRenderer.cs)。
- [最小地图检查](../../Tools/Tests/waterfront_core.lua)：`python -B Tools/Tests/run_lua.py Tools/Tests/waterfront_core.lua`；陆路回归为 `world_travel_core.lua`。
- [真实 Data](../../Tools/Tests/water_travel_data.cs)、[Lua＋Data 夹具宿主](../../Tools/Tests/water_travel_integration.cs)／[用例](../../Tools/Tests/water_travel_integration.lua)、[实际世界往返与磁盘保存](../../Tools/Tests/water_travel_smoke.cs)／[流程](../../Tools/Tests/water_travel_smoke.lua)：在已打开且空闲的 Editor 通过 `execute_code` 执行脚本体，独立 Data/LuaEnv/PreviewScene，不进入 Play，不改玩家存档。
- [v10整侧水岸预览宿主](../../Tools/Tests/waterfront_preview.cs)／[布局生成](../../Tools/Tests/waterfront_preview.lua)、[全景](../../Art/DocksLowPoly/Previews/waterfront-v10-2-coast.png)、[码头近景](../../Art/DocksLowPoly/Previews/waterfront-v10-2-dock.png)、[预览记录](../../Art/DocksLowPoly/Integration/waterfront-v10-preview.json)。本次整侧岸线检查覆盖两个真实港口及普通／王城样本：逐截面向外全水、单一水域连通、岸线起伏／深度变化、建筑保护、四人落脚和v9布局兼容均通过；一次主动C#编译及v10真实双港往返／航行中磁盘读写通过，未进入Play。
- [首版及当前往返结果](../../Art/DocksLowPoly/Integration/production-smoke.txt)、[真实城内预览](../../Art/DocksLowPoly/Previews/town-waterfront-unity.png)、[Unity 模型预览](../../Art/DocksLowPoly/Previews/Unity.png)。验证种子20261025，10000格，配方5：码头2/3对应地点7/8，水路30格。
- 首版验收的一次主动 C# 编译通过，上述定向检查与真实窗口创建／往返／航行中磁盘读写通过；未进入 Play 或完整构建。全局文案扫描被无关 `DiceRollCtr.lua` 缺少 `DiceAdvantageRoundResult` 键阻挡；本次33个使用的 `Water*` 文案键已单独核对默认值和导出表。seed42王城的原有必需地块11布局失败在无水岸对照中同样存在，本次未修改该规划器。
