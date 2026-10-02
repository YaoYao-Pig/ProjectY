# 矿井地牢

关键词：矿井、废弃矿道、Mine、三层、坍塌、破损楼板、透视下层、木支架、铁轨、矿车。

## 文档目录

正文：入口与生成 / 分层与洞口 / 资源与验证；关键入口：配置 / 算法 / 检查。

## 正文

- `E_MapAreaType.Mine=6`、`MapAreaTable.id=50` 使用独立 `MineGenerator` 策略；世界建筑、地点样式和入口均为 ID 7。地点复用偏远遗址选址方案 401，最多两处，保留原地形与净距限制；没有合格地点不强制生成。经原 `AdventureSystem:Visit` 进入，沿用队员位置、探索迷雾和重进状态。
- 六边形半径 1 米、64×64 底层采样；真实开采区追加 layer1/2 格。下层 0 米、中层 5 米、上层 10 米，从上层西侧进入，下层东侧为探索目标。每层包含中部洞厅和东西作业区，配置房间格罩加确定性边缘噪声；宽矿道和每对楼层的两条直梯组成回路。
- 地面使用 `MapAreaSurfaceTable` 50–52：下层暗岩、中层旧土、上层浮尘；层间明度帮助辨认洞口深度，不参与高度或通行判定。
- `MapAreaMineFloor/Room/Opening/StairTable` 分别负责楼层、房间、坍塌洞口和连续梯道；模型不生成导航。坍塌格没有上层楼板、岩壁或垂直通行边，下方保留真实工作棚和矿道；层间只能经明确楼梯边移动。楼板厚 0.35 米，人物净空不低于配置值 2.2 米。
- 共用 `LayeredFloorBuilder.Reset/Add/AddStair/Connect` 创建空底图、楼板、逐边连续梯面和双向导航，检查上下层净空；`LayeredFloorEdges` 仍是城镇、沉船及矿井的邻接实现。`layeredVisibility=true, layerCount=3` 启用通用分层视线，详见 [MapArea](MapArea.md)。
- 所有矿井地格和陈设属于 `cutawayGroup=1`，`cutawayLayer` 为实际层号；梯道使用起始层。领队下降时剖开覆盖层，返回上层恢复；留在上层时只通过真实洞口看见下层。剖切同步作用于绘制、拾取、镜头和探索高亮，不修改权威地格及发现记录。
- 资源 900–905 是入口、木架、矿轨、矿车、矿簇和工作棚，保留米制与低多边形纯色风格。木架立柱单独阻挡，3.5 米开口可穿行；矿轨在缺口和设施前终止。固定设施和矿簇检查实际支撑、占格和连通性。当前没有新增矿井战斗规则。
- 来源、实测尺寸和 Unity Prefab 路径见 [资源清单](../../Art/AssetExpansion202610/Mine/README.md)。入口采用完整单格模型，Web 地图使用 `mine` 轮廓。资源引用沿原“同步地图资源引用”流程保存。
- 定向离线检查：`python -B Tools/Tests/run_lua.py Tools/Tests/mine_core.lua`；通用视线夹具：`python -B Tools/Tests/run_lua.py Tools/Tests/layered_visibility.lua`。检查真实配置、多种子、洞口、支撑、净空、逐边梯面、确定性和四人往返。
- `mine_visibility_perf.lua` 是有限次数的实际矿井视线基准；同次小队可见性计算共用临时几何查询，射线路径模板只缓存相对坐标，不保存地图或动态工事状态。`mine_columns.cs` 检查岩壁矩阵、下层净空、拾取与剖切，不创建场景物件。
- `mine_render_preview.cs` 是 Unity MCP `execute_code` 方法体，加载 `mine_integration_preview.lua` 创建独立状态，检查实际入口、逐步探索、下层发现、楼梯往返、重进、楼层拾取和剖切，并在独立 PreviewScene 输出 `Docs/Previews/Mine/`。不启动 Play，不保存用户场景；离线结果不代替实际渲染检查。

## 关键入口

- [MineGenerator.lua](../../Lua/Game/MapArea/MineGenerator.lua) / [MineFloors.lua](../../Lua/Game/MapArea/MineFloors.lua) / [MineProps.lua](../../Lua/Game/MapArea/MineProps.lua)：策略、开采区、设施和通路。
- [LayeredFloorBuilder.lua](../../Lua/Game/MapArea/LayeredFloorBuilder.lua) / [LayeredVisibility.lua](../../Lua/Game/MapArea/LayeredVisibility.lua)：通用楼板梯道与视线。
- [矿井参数](../../Config/Tables/MapArea/MapAreaMineTable.json) / [楼层](../../Config/Tables/MapArea/MapAreaMineFloorTable.json) / [房间](../../Config/Tables/MapArea/MapAreaMineRoomTable.json) / [洞口](../../Config/Tables/MapArea/MapAreaMineOpeningTable.json) / [楼梯](../../Config/Tables/MapArea/MapAreaMineStairTable.json) / [主题](../../Config/Tables/MapArea/MapAreaMineThemeTable.json)：唯一源配表。
- [算法检查](../../Tools/Tests/mine_core.lua) / [原生状态检查](../../Tools/Tests/mine_integration_preview.lua) / [实际渲染检查](../../Tools/Tests/mine_render_preview.cs)。
