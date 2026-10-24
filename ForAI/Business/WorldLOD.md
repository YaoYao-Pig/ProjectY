# 世界模拟与渲染 LOD
关键词：LOD、三级、关系LOD、模拟分级、远方结算、100ms、视锥剔除、相机、实例池、抽象行程、升降级、v18。

## 文档目录
正文：模拟分级 / 状态和存档 / 渲染分级 / 验证；关键入口：Lua、C#、配表。

## 正文

- 模拟按主角大地图位置分级，外交始终使用同一权威关系表。`WorldSimulationLodTable` 默认近层半径 8 格、间隔 1 游戏分钟；中层外半径 24 格、间隔 10 分钟；远层间隔 60 分钟。升层进入配置范围立即生效，降层增加 2 格缓冲；不因 LOD 改变敌友身份。
- `WorldPartiesData.Due` 在 C# 一次分类并返回到期任务，Lua 不再每分钟遍历所有队伍。玩家追赶/交互目标及玩家参战队强制近层；真实待结算路线进入近区时提前升级，初始近层队伍的相邻队伍也单轮升级，避免边界两队漏战，不递归扩大到全图。
- 护送委托的 `escort_wait/escort` 商队始终进入近层，与其交战的冲突按双方较高精度推进；存在活跃护送时 `WorldParties.SyncClock` 将长时间推进拆成整分钟边界，保证沿路真实接触不会被摘要路线跳过。只对活跃护送启用此例外；委托状态缓存按 `TownMissionData.Revision` 重建，完整流程见[大地图队伍](WorldParties.md)。
- 近层使用原精细移动与关系行为；中层一次推进已保存路线并做批量决策；远层按摘要行程和战力结算，省略中间逐格寻路。静态陆地连通分量在绑定世界时建立，摘要目的地必须属于同一可达陆地；行程保存开始/到达时刻，到期才落地。
- 升层会将尚未到期的摘要行程恢复为真实路线，按已消耗比例定位一次，之后继续剩余行程；不重新回血、不补跑远层的每一分钟、不提前使用未来时间。`SimulatedAt/NextSimulationAt/Lod` 均在 C#，保留未结算时间债务和小数分钟。
- 队伍的满生命战力在初始化、补员和实际战斗后校准，C# `StrategicPower` 根据真实 HP 计算当前摘要战力。近层继续使用完整属性查询。归属、伤亡、货物、保护期和据点占据仍沿用[势力系统](Factions.md)。
- 远方冲突首先只有 `Materialized=false` 的记录，不生成 MapArea。中层批量更新战损，远层在交战窗口结束后一次结算结果；玩家已参战时完全禁止后台推进。远层省略散落装备的细节掉落，商队物理货舱仍保留唯一所有权。
- 胜方无法承接货舱时转入冲突 `PendingCargo`；玩家靠近未过期遗迹时再生成空战场、Detached 历史队伍引用，并把待落地货物转入容器一次。不会从原队伍重生幸存者或补满生命。
- 据点恢复按经过的战略周期补账，保持收入封顶与恢复成本的顺序；近处静止驻军只参与恢复/战场任务，不做移动或接触扫描。近区接触使用近层查询缓存，不能再次遍历所有远队。历史冲突清理使用 C# 未过期列表；当前玩家所在战场不会被删除。
- v18 完整远征保存调度、摘要行程、战力基值、未物化冲突与待落地货物。v16 及更旧档在当前世界时钟建立新调度，不重播创建以来的历史；旧战场明确视为已物化。已有基础地图、队伍实例、伤势与货物保留。
- 渲染 LOD 独立按相机视锥与观看距离决定。默认近/中外阈值 40/100 倍格半径，正交相机使用地面落点与缩放；近景完整，中景减少树石、细地被与阴影，远景保留地形/水体和地点标记。视野外不提交对应空间桶；可见桶重新合批，避免远景 draw call 膨胀。
- 队伍/势力据点完整模型只在近景可见时创建，默认每帧最多新建 2 个、激活 8 个，完整模型最多 96 个；离开视野进入复用池，满池可按同一预算换出闲置异类模型。剔除使用完整模型包围盒及视锥余量，玩法拾取不依赖实例是否存在。详细约定见[大地图预览渲染](../Tools/MapRuntimePreview.md)。

## 验证

- [world_lod.lua](../../Tools/Tests/world_lod.lua) 与 [factions_core.lua](../../Tools/Tests/factions_core.lua)：原生 Lua 检查批量推进、升层、相同外交、一次结算/物化、经济补账和遗迹清理。
- [faction_lod_data_editmode.cs](../../Tools/Tests/faction_lod_data_editmode.cs)：真实 C# 调度、边界、时间债务、小数分钟、抽象行程、序列化与货物所有权；[world_map_lod_cpu.cs](../../Tools/Tests/world_map_lod_cpu.cs)：真实相机视锥、模型预算、复用/换出、相机外零活动详细对象。均在现有空闲 Editor 中隔离运行，不进入 Play。
- [world_lod_editmode.cs](../../Tools/Tests/world_lod_editmode.cs) 运行 [world_lod_integration.lua](../../Tools/Tests/world_lod_integration.lua)，实际通过 v18 摘要行程存读、未物化远战结算/货物持久化与一次物化、追赶和接近升层不重复推进；[结果](../../Art/FactionLowPoly/Integration/lod-gameplay-validation.txt)。另通过 [world_sites_editmode.cs](../../Tools/Tests/world_sites_editmode.cs) 的地点完整占地、悬停、GPU 轮廓遮罩像素与退出恢复回归。
- [world_lod_performance_editmode.cs](../../Tools/Tests/world_lod_performance_editmode.cs) 执行 [world_lod_performance.lua](../../Tools/Tests/world_lod_performance.lua)，输出新的 [LOD 性能记录](../../Art/FactionLowPoly/Integration/performance-lod.txt)，不覆盖旧基准。2026-10-23 同一万格/45 队/60 游戏分钟样本为 **86ms**，符合本次 100ms 目标；单次推进最大 30ms，初始化和界面快照另列，不计入模拟预算。该结果不是所有世界密度下的硬实时保证或 Play/GPU 帧率结论。
- 本轮集中主动编译一次并通过上述 Data、渲染 CPU 和定向 Lua 检查；未进入 Play，未全量构建。

## 关键入口

- [模拟调度规则](../../Lua/Game/Adventure/WorldLOD.lua) / [队伍接入](../../Lua/Game/Adventure/WorldParties.lua) / [冲突精度](../../Lua/Game/Adventure/WorldConflicts.lua) / [三级配表](../../Config/Tables/Travel/WorldSimulationLodTable.json)。
- [调度与权威编制](../../Assets/GameFramework/Runtime/Data/WorldPartyData.cs) / [路线批进](../../Assets/GameFramework/Runtime/Data/WorldTravelData.cs) / [抽象战场](../../Assets/GameFramework/Runtime/Data/WorldFactionData.cs)。
- [相机分级](../../Assets/GameFramework/Samples/Map/MapRenderLod.cs) / [地形批次](../../Assets/GameFramework/Samples/Map/MapPreviewRenderer.cs) / [队伍模型池](../../Assets/GameFramework/Samples/Adventure/WorldPartyView.cs)。
