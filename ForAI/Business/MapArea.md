# MapArea 局部探索地图

关键词：MapArea、小地图、局部地图、地牢内部、三层生成、功能分区、组团、多格设施、变宽通道、预设房间、陈设、探索迷雾、墙壁遮挡、原地战斗、96×96。

## 文档目录

正文：入口与所有权 / 生成与配置 / 体验与验证；关键入口：系统 / 数据 / 展示。

## 正文

- 大地图聚落实例经 `MapAreaEntranceTable.townId → areaId` 生成单一交互入口；同一城镇的分散建筑共享入口。`AdventureSystem:Visit` 按 `areaConfigId` 进入 MapArea，旧营地/野外事件保留。入口带真实 Region ID/类型、坐标、高度与地貌混合权重，地图本身仍使用[大地图](Map.md)的只读快照。
- `MapAreaGenerator` 按 `E_MapAreaType` 注册策略与独立参数表。当前仅 Dungeon 可生成；Town 已配置入口但返回明确“策略待实现”，不会套用地牢。以后新增类型应注册自己的生成策略，不在入口或渲染器内硬编码类型分支。
- `MapAreaTable` 定义类型、策略参数 ID、宽高、六边形半径、视野、移动间隔和种子盐。默认地牢 96×96，共 9216 格（包含实体墙），地格半径 1.5；格子使用轴向 q/r，与 BattleBoard 共用 HexGrid。调整 hexRadius 放大地面间距、通道和陈设，不改变格数、寻路与视野半径的格单位。尺寸目前配置范围 32–192，房间数量/半径也需与面积匹配，放置次数耗尽明确报错。
- 地牢 `generationVersion=3`：`DungeonRooms/DungeonDistricts` 按功能分区选择、聚合和绘制房间；`DungeonGenerator` 优先连接同分区，再跨分区并添加缩短折返的回路；`DungeonPassages` 绘制变宽通道；`DungeonProps` 布置物件。默认一级洞穴 2 个、二级随机房间 5 个、三级预设 3 个。入口/目标由 presetId 指定，种子仍由远征种子、稳定聚落实例 ID 与配置盐派生。
- `MapAreaDungeonTable` 控制数量、尺寸、间隔、分区、入口/目标和回路。通道最小半径 2、最大 4，连续噪声与扩厅产生 5/7/9 格断面，两向平滑限制逐段变化；扩宽不侵入房间。房门至少 5 格，房间中心保留半径 4 的 61 格战斗区。不连通则明确报错，不降低净宽兜底。`connections.radii` 与 `path` 一一对应，`radius` 保留最小净宽契约。
- `MapAreaDistrictTable` 定义功能分区及归一化锚点；房间按 districtId 聚合，主厅先放，附属房间在合法候选中偏好同分区。整体镜像/换轴/扰动带来变化；人工房间共用分区建筑轴。`MapAreaRoomStyleTable` 配置 cavern / hall / lobed / apse、边缘起伏、设施池和覆盖率。`MapAreaRoomPresetTable.tiles` 是轴向固定格罩（`.` 地面，`#` 墙），`MapAreaRoomPlacementTable` 是固定局部坐标陈设；模板仅整体旋转/平移，连接不得挖坏模板墙体。
- `MapAreaPropTable` 映射模型、缩放、视线和摆放方式。`footprintQ/footprintR` 成对定义可旋转占地，替代旧 footprintRadius；必须含原点且不重复，大型设施使用 13/19 格。固定陈设冲突直接报错；随机陈设先大后小，以覆盖率为目标，沿墙/建筑轴或天然成片摆放，避开保留区，切断地面连通则回滚。`cell.blocked` 决定移动，`blocksSight` 决定视线；物件格仍是地板，不按 blocked 挤出墙。资源见[地图模型](MapArt.md)。
- `MapAreaThemeTable` 将 Region 类型映射到墙高、房间尺度、走廊曲折、细微高度、颜色及柱模型。几何使用入口主 Region，颜色按入口地块混合权重融合，预设铺地色再与地貌混色；固定模板不随 Region 缩放其格罩与摆件，保证设计结构。
- `MapAreaSystem` 保存冻结后的静态布局；`AdventureData.Areas` 的 C# `MapAreaData/MapAreaStateData` 保存唯一可变状态：当前地点、成员 ID/占格、领队格、已发现格、可见格、同步路径帧与移动时钟。`CellIndex` 保持首名存活队员的格子。重进保留每个人的位置；存活名单变化时在当前锚点附近重新部署，开始新远征统一清空。当前无跨运行存档。
- 探索仅部署 1–4 名存活队员，全员倒地时要求先回营地。点击已发现地面以六邻接 BFS 规划领队路径；`SquadMovement` 用局部距离场和同帧占位组合让同伴保持后方队形，侧格受阻时跟随前一人足迹。每步最多一格，不重格、不迎面交换，离领队的可行走距离不超过 4 格；领队可等待让位，抵达后同伴收拢。规划失败保留旧路线并说明原因，不传送或穿墙。
- 路径所有成员都只能经过已发现格。`SetSquadRoute` 接收按帧展开的全员位置并在 C# 中一次验证/保存，`Advance` 按游戏 Tick 同时推进整队；停止与重新点目标都从当前真实位置开始。墙体挡视线，面对的墙格可见，当前视野为全员视野并集。Lua 规划临时表不作为第二份可变状态。
- `BattleBoard.FromArea` / `MapAreaSystem:BattleWindow` 从现有格子裁出同坐标窗口并共享格子身份。当前只是地形接口，尚未接敌人感知、队员部署、原地切换战斗或战后恢复；旧事件战斗仍走独立的小棋盘。
- Unity 菜单 `Project Y/地图/打开 MapArea 地牢测试` 复用 `AdventureDemo.unity`，Play 后点击“古代地下迷宫”地点。左键移动、空格停止、滚轮缩放、中键/WASD 平移、右键旋转；侧栏可跟随小队、查看全图与完整结构。调试显示不解锁探索状态，测试返回按钮允许在任意位置返回大地图。
- `MapAreaRenderer` 使用已绑定、配表指定的低模柱与陈设做 GPU 实例渲染；未知格压平，未知陈设隐藏，已发现但不在视野内的地块/陈设变暗。静态快照进入时复制一次，包含房间等级/名称、通道宽度、模型与物件占地；动态快照按需更新。显示数据不持有 LuaTable，也不作为玩法状态；调试完整结构显示房间等级与名称。
- `SquadPawnRenderer` 按 `members(actorId,cellIndex)` 显示独立棋子，平滑位置和朝向，不决定占格。模型高度固定，地格半径 1.5；进入区域创建，离开/销毁时释放，身体和装备通过显式 Prefab 挂点组合。资源与同步菜单见[棋子资源](PawnArt.md)。
- 新 C# Data/API 先编译，再使用真正的 `XLua/Generate Code` 生成桥接并等待编译；不得手改 Gen。改表仍经现有 exporter，Lua schema、bytes、清单分别导出到现有 `_Gen` 目录。
- 最小算法检查：`python -B Tools/Tests/run_lua.py Tools/Tests/maparea_core.lua`，覆盖六种 Region、代表性种子、连通、确定性、视线、共享坐标、通道净宽、战斗区与模板完整性。真实 C# 状态/显示快照检查：Edit Mode 菜单 `Project Y/地图/验证 MapArea 地牢`；不切场景、不进入 Play。修改建筑资源后在远征场景执行“同步地图资源引用”。

## 关键入口

- [MapAreaSystem.lua](../../Lua/Game/MapArea/MapAreaSystem.lua)：入口、会话、探索命令与快照；[MapAreaGenerator.lua](../../Lua/Game/MapArea/MapAreaGenerator.lua)：类型注册、种子和 Region 主题。
- [DungeonGenerator.lua](../../Lua/Game/MapArea/DungeonGenerator.lua) / [DungeonRooms.lua](../../Lua/Game/MapArea/DungeonRooms.lua) / [DungeonDistricts.lua](../../Lua/Game/MapArea/DungeonDistricts.lua) / [DungeonPassages.lua](../../Lua/Game/MapArea/DungeonPassages.lua) / [DungeonProps.lua](../../Lua/Game/MapArea/DungeonProps.lua)：分区、混合生成、变宽连接和设施；[MapAreaLayout.lua](../../Lua/Game/MapArea/MapAreaLayout.lua)：寻路、视线与只读契约。
- [MapAreaData.cs](../../Assets/GameFramework/Runtime/Data/MapAreaData.cs)：探索权威状态；[配置目录](../../Config/Tables/MapArea/)：九张源表；[本版 review](../../Docs/MapAreaDungeonV3-Review.md)：算法参考、配表入口与预览。
- [MapAreaRenderer.cs](../../Assets/GameFramework/Samples/Adventure/MapAreaRenderer.cs) / [MapAreaViewData.cs](../../Assets/GameFramework/Samples/Adventure/MapAreaViewData.cs)：Unity 地形与探索显示；交互宿主见[远征 Demo](Adventure.md)。
- [算法检查](../../Tools/Tests/maparea_core.lua) / [集成检查](../../Tools/Tests/maparea_integration.lua)：最小验证入口。
- [编队规划](../../Lua/Game/MapArea/SquadMovement.lua) / [编队检查](../../Tools/Tests/squad_movement.lua)：1–4 人、转角、窄口、真实地牢往返的逐帧占格/邻接约束；[棋子显示](../../Assets/GameFramework/Samples/Adventure/SquadPawnRenderer.cs)：只读显示副本。
