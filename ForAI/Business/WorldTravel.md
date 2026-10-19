# 大地图旅行与随机遭遇
关键词：旅行、行军、大地图移动、路线、暂停、倍速、改路、沿途事件、随机遇敌、随机战场、WorldTravel。

## 文档目录
正文：操作 / 状态与时间 / 路线与遭遇 / 验证；关键入口：配表、数据、规则与展示。

## 正文

- 大地图左键点击地面或地点规划旅行；点击新位置改路，空格暂停/继续世界时间，键盘 1/2/3 分别选择 1×/2×/4× 时间流速，导航按钮对应相同三档。暂停时规划或修改路线仍保持暂停。“小队待命／前往”行定位小队并跟随，F 仍为全图视角。地图显示[小队旗帜与游荡队伍](WorldParties.md)、剩余路线与地点悬停名；导航显示目标、当前地形和剩余游戏分钟。抵达地点后才调用原事件/区域入口。
- `Adventure.travel` 是 Lua 规则门面；`WorldTravelData.For(AdventureData)` 持有权威位置、当前边进度、剩余路线、目标、倍速、暂停状态和独立随机流。Lua 只保存配置、寻路图及 C# 遭遇记录导出的不可变地点投影。改路保留已行进的边及进度，从下一格重规划，不瞬移；无效路线不改现有行程。
- 大地图通过 Narrative.AdvanceMinutes 结算世界时间及到期的长效 Buff，再触发到达/遭遇；新远征默认走时，小队原地待命或抵达普通地图格后仍继续流逝，抵达当帧未用完的预算继续作为待命时间消耗。空格暂停、UI 暂停租约、营地及队伍交互窗口会阻止移动和时间推进；进入事件或局部区域后停止本帧大地图计时。Narrative 的自动昼夜仅在局部探索阶段继续按原规则推进，避免大地图双重计时。倍速同时缩放移动与时间；改路、查看和暂停不重抽随机数。
- `WorldTravelTable` 配基础耗时、现实秒到游戏分钟换算、道路倍率、高差成本/上限、检查间隔和触发率；`WorldTravelTerrainTable` 配地域耗时、战场障碍率、地面材质和障碍模型池。复用 MapPathfinder 算法，旅行代价与道路生成配置独立。水格不可步行，过陡邻边不可通过；目前没有船行或跨河桥梁，水域目的地明确拒绝。
- 随机检查只按实际行军分钟在走完一格时结算，原地待命不累积随机事件检查；可见敌人的接近与接触仍按世界时间结算，能够攻击静止小队。到达目标优先，最后一格不插入遭遇。`WorldTravelEventTable` 中 eventId 与 encounterId 必须恰好一个为正，可按地域筛选、加权抽取；普通事件复用现有选项和经历。没有存活队员时不触发途中遭遇，仍可返回原营地求援。
- 遇敌直接由 map → resolving → Battlefield → battle，不伪造事件选项。以当前大地图地域和新地点 ID 生成独立小战场；地面/障碍随地形变化，森林复用已绑定的橡树、松树资源。相同世界种子与遭遇 ID 可复现，不同遭遇生成新地图；出生点与敌方部署保留连通。复用部署、战斗结算和搜刮，战场及未取战利品在本次远征保留，可重返。
- `BattlefieldElevation` 在同一 layer 0 地表生成二至三级台地，实际 `height` 按 `MapAreaBattlefieldTable.heightStep` 抬高。峰顶平台清除障碍，所有邻接地格高差最多一级；不把出生格单独压平制造断崖，双方出生点仍能走到全部非阻挡格与最高峰。台地中心/层数随独立种子变化；高打低收益见[战斗](Battle.md)。
- 途中事件/遇敌会暂停并保留原目的地。处理事件或离开战场回到遭遇位置后，按空格或点击“继续时间”恢复原路线；战后不自动继续赶路。显式新远征重置旅行；[远征存档](CharacterSave.md)保留当前位置、路线步进、随机流与未领取战场，继续后旅行暂停；旧版队伍档仍从营地重开地图。
- 大地图简单事件自动结算后保留 `result` 阶段，等待 StoryEvent 显示结果并由玩家确认“返回旅途”；不能在同帧直接回 map，否则异步显示轮询看不到窗口。复杂事件仍先显示选项。`world_travel_event_ui.lua` 使用真实事件规则、UI 同步入口及控制器验证结果可见、重复同步不重复发奖、确认后关闭和复杂事件回归；不启动 Unity。
- 最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/world_travel_core.lua` 覆盖寻路、地形成本、暂停边界和实际随机战场生成；`Tools/Tests/world_travel_data.ps1 -AssemblyPath <已编译程序集>` 覆盖真实 C# 进度、改路原子性、遇敌保留路线、帧预算/倍速随机一致性及直接遇敌阶段转换。相关回归为 `adventure_snapshot.lua`、`loot_core.lua`。连续时钟的待命三档倍率、暂停改路、抵达剩余预算、HUD、模态窗口与敌人追击静止玩家，由 `world_clock_editmode.cs` 在独立 PreviewScene/LuaEnv 中验证；本轮上述定向检查及一次主动 C# 编译通过，未进入 Play。

## 关键入口

- [旅行规则表](../../Config/Tables/Travel/WorldTravelTable.json) / [地形与战场表](../../Config/Tables/Travel/WorldTravelTerrainTable.json) / [途中事件池](../../Config/Tables/Travel/WorldTravelEventTable.json)。
- [权威旅行状态](../../Assets/GameFramework/Runtime/Data/WorldTravelData.cs) / [旅行规则](../../Lua/Game/Adventure/WorldTravel.lua) / [远征接入](../../Lua/Game/Adventure/AdventureSystem.lua) / [时钟](../../Lua/Game/Narrative/NarrativeSystem.lua)。
- [地图拾取与路线展示](../../Assets/GameFramework/Samples/Adventure/WorldTravelView.cs) / [展示宿主](../../Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs) / [HUD 投影](../../Lua/Game/Adventure/MainHudModel.lua) / [随机战场](../../Lua/Game/MapArea/BattlefieldGenerator.lua)。
- [台地生成](../../Lua/Game/MapArea/BattlefieldElevation.lua) / [台地配置](../../Config/Tables/Loot/MapAreaBattlefieldTable.json) / [连通性与高地收益检查](../../Tools/Tests/battlefield_elevation_core.lua)。

- [连续世界时钟验收](../../Tools/Tests/world_clock_integration.lua) / [Edit Mode 宿主](../../Tools/Tests/world_clock_editmode.cs) / [结果](../../Art/WorldPartyLowPoly/Integration/world-clock-validation.txt)。
