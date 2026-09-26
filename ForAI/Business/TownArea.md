# 城镇街区与漫游

关键词：城镇小地图、Town、第三人称、WASD、小队跟随、居民、工匠、巡游、酒馆、铁匠铺、商店、冒险公会、广场、露天摊位、山城、联排、台地、台阶、坡道、上下层道路、街桥、连续室内、真实比例、米制建筑、屋顶剖切。

## 文档目录

正文：配置与生成 / 运行状态和控制 / 模型与验证；关键入口：配表 / 规则 / 显示 / 资源。

## 正文

- 城镇是 [MapArea](MapArea.md) 的 Town 策略，通过真实大地图聚落实例入口进入。默认 64×64、六边形半径 1.5、整队移动间隔 0.5 秒；`MapAreaTable.discovery=open` 公开街区，地牢仍为 explore 视线探索。地图中心在配置的尺寸内，四周是不可通行的庭院边界。
- 关系链为 `MapAreaEntranceTable.townId → MapAreaTable.profileId → MapAreaTownTable`。当前集市、小村庄、城堡镇区、隐居聚落四种普通配方分别控制设施集合、民居数、居民数、街区池、摆件池、道路半径和景观树。城堡镇区目前是功能设施较齐全的街区配方，未新增内城堡玩法。最高档王城通过独立的地形分区、街网与临街生长配方接入，见[王城 MapArea](RoyalTown.md)。
- `TownGenerator` 的 `generationVersion=2` 使用四条等高街、八组街区预设、穿城低街和一座上层街桥。`TownTerrain` 先生成高程与可走边，再按种子旋转整体、选择街区/设施/住宅/摊位组合。`MapAreaTownBlockTable` 定义住宅槽、设施锚点、摆件槽；槽位只在平整且完整的占地上放置；设施按 `lotSlideCells/facilitySlideRows` 有限滑移，住宅按 `houseSearchRadius` 在预设附近找完整地块。台阶与桥头通行区先保留，不能被扩大的建筑挤占。必须保持全部公共道路与门前连通；可选陈设冲突时跳过，必需设施或住宅数量不足明确报错。
- 台地参数在 `MapAreaTownTable`：`streetRows` 是低到高四条局部 r 坐标，`terraceHeight` 是单级米制高差；`halfWidth/valleyHalfWidth` 控制街区和低街宽度，`rampLength/rampWidth/stairRise` 控制坡道、台阶；`maxWalkRise/maxEdgeRise` 共同限制可走边。默认四层 0/2.4/4.8/7.2 米；山地主题 `reliefScale=1.15`。调高度必须连同坡长与通行阈值检查，生成失败不降级成平地。
- `bridgeWidth/bridgeThickness/bridgeClearance/bridgeAssetId` 控制上层桥路。桥面是独立 `layer=1` 地格，桥下 `layer=0` 保留通行；每格持有六个顶点高度和明确邻接，只有桥两端接高街，桥边不得跃下。上下层共享 q/r 但 index 不同，寻路/编队/NPC/点击/交互必须使用同一张有高度约束的道路图；公共约定见 [MapArea](MapArea.md)。
- `MapAreaTownFacilityTable` 定义设施集合、说明、模型池、交互半径和服务 NPC。`MapAreaTownLotTable.assetId → MapAssetTable` 控制模型，`footprintQ/R` 是可旋转的固体占地（墙和家具），`entryQ/R` 是占地外的真实门洞接入格。`scaleMode=meters` 保持模型米制尺寸，`grid` 沿用格半径缩放；人物始终固定尺度，可进入设施、联排、宫殿与城门采用米制。
- `MapAreaTownInteriorTable.id` 对应地块 ID，配置上盖资源、室内可走格、内部服务点、地板色及制作尺度。`TownBuildings` 预留完整室内，只保留室内与真实门格之间的双向边，侧墙/窗下不连到街上。`navRadius=1.5` 与制作占地必须一致；改变地格尺度需同步重做模型与占地，不能自动拉伸门窗家具。`doorWidth/doorHeight/storeyHeight` 是制作规格，调表后需同步模型。
- 新模型把 Structure（地面、下墙、家具）与 Cover（上墙、屋顶）分开；两者共享同一固体占地，属于同一建筑，不是两份玩法障碍。`cell/prop.interiorId` 和 `prop.cutaway` 随布局快照传给 C#；渲染从所有队员的权威占格推导打开的室内，最后一人离开后恢复，同步更新第三人称相机持有的障碍列表。无需切场景、传送或存另一份“当前建筑”状态。
- 已开放酒馆、铁匠铺、商店、公会、面包房、药草铺、小礼拜堂、仓库、马厩首层，以及王宫接见厅和瞭望塔底层值守室。普通住宅与上层房间尚未开放。人物约 1.78 米、底座直径 1.38 米；商用门洞 3×2.4 米、首层层高 3.2 米，桌高 0.78 米、柜台 1.04 米。角色沿同一六边形道路图连续进出，仍非自由碰撞角色控制器。
- `MapAreaTownThemeTable` 按入口 Region 选择草地/山地/湖岸/河岸/森林/雪地色、路色、广场色、树模型及台地高差倍率。主 Region 决定几何和城外地表；城市铺装按独立材质配方选择，见[地表与光照](MapPresentation.md)；建筑门口和完整占地保持平整，台地之间通过专门的坡道/台阶通行。
- 住宅池通过 `houseUnits` 计数：新三种米制联排模型每组包含 3 栋、占 13 格，`houseCount` 表示栋数，完整组团不能拆开凑数。相邻房屋贴合，组团后方封闭庭院不作为公共通路；旧单栋住宅和特殊设施模型保留，配置决定是否使用。
- `MapAreaTownNpcTable.partIds → PawnPartTable` 配置居民和工匠，复用[棋子挂点](PawnArt.md)，不把 NPC 加入主角队伍或战斗单位表。服务 NPC 在设施服务点旁待机，室内设施限制在同一室内并避开门洞，额外居民沿门前路点来回巡游，到一圈终点停留；本版是固定棋子姿势，没有骨骼步行动画。
- 静态设施、NPC 定义和巡游路线归 Lua 布局；`MapAreaNpcData` 的占格、游标、时钟和 `MapAreaStateData` 的交互目标是唯一可变状态。`TownResidents.Tick` 让居民避开其他 NPC、队员当前格及整队剩余路线；遇阻尝试绕向前方少量路点；迎面堵塞时编号较大的居民向有出口的空邻格侧让，保留巡游游标，每次最多一步。交谈时目标 NPC 暂停，退出区域不在后台巡游；重进保留所有人的位置。
- 默认第三人称：WASD 发已连通的六邻接方向命令、同伴使用现有编队规划；松开键停止待执行路线，按住空格停止。右键拖动转镜头、滚轮拉近拉远；V 切换俯视点击移动。仍是六边形移动原型，不是自由移动 CharacterController。镜头同时检查由阻挡占地裁切的模型包围盒与真实台地/桥面三角形；棋子按当前移动边采样坡面、台阶，不吸到另一层。
- E 查看附近设施或 NPC，Esc 关闭说明；距离按道路图计算，不能隔着桥面交谈，交互期间不能带队走路。可进入设施的介绍点均在室内；尚无交易、锻造或任务业务。
- Unity 菜单 `Project Y/地图/打开城镇漫游测试` 复用 AdventureDemo；用户自行 Play 后选择城镇地点。地图资源现有 112 项，含[环境装饰](MapDressing.md)；棋子/装备资源按各自配置表同步，不固定其数量；改表经 exporter，模型须定向导入并执行远征菜单“同步地图资源引用”。新增棋子部件才需要“同步棋子资源引用”；运行时始终用空 Rig 按表装配。
- 本套资源位于 `Art/TownLowPoly` / `Assets/DynamicAsset/TownLowPoly`：原 16 个模型保留，新增 `Town_RowHousesA/B/C`（ID 50–52）和 `Town_SkyBridge`（ID 53），新源为 `TerracedTown.blend`。街桥 FBX 只含栏杆与梁柱，地面由 `TownSurfaceRenderer` 按导航顶点生成；不能把桥当作落地实体柱。新模型复用共享哑光材质，未增加纹理依赖。
- 最小算法检查：`town_core.lua` 覆盖四配方、连通、完整占地、NPC 路线、确定性、上下层身份、桥下净空和四人上下桥；`squad_movement.lua`、`maparea_core.lua` 检查共有导航的基本回归。Edit Mode 菜单 `Project Y/地图/验证城镇漫游` 使用真实 C# 状态检查巡游、门口交互、桥上/桥下往返与重进，不进入 Play。`preview_town.cs` 使用真实路线快照核对顶点采样、分层拾取并输出全景/街景/桥上/桥下图片。
- **当前检查（2026-09-25）**：普通四配方、王城四种子与不同 Region、地表引用和室内四人进出检查通过。原生 Unity Edit Mode 预览使用真实入口和 28 名 NPC，完成 11 处室内进出/交互/上盖恢复及重进；12 个扩展 FBX 的米制尺寸、材质槽和场景绑定已核对。新增模型完成 894 条人物净空射线检查；报告见下方。主动请求一次项目编译，未主动进入 Play；后续用户自行试玩的只读检查确认视觉时钟运行且 Demo 未报错。

## 关键入口

- [城镇配方](../../Config/Tables/MapArea/MapAreaTownTable.json) / [设施](../../Config/Tables/MapArea/MapAreaTownFacilityTable.json) / [街区预设](../../Config/Tables/MapArea/MapAreaTownBlockTable.json) / [模型与占地](../../Config/Tables/MapArea/MapAreaTownLotTable.json) / [NPC](../../Config/Tables/MapArea/MapAreaTownNpcTable.json) / [Region 主题](../../Config/Tables/MapArea/MapAreaTownThemeTable.json)。
- [室内与制作尺度配置](../../Config/Tables/MapArea/MapAreaTownInteriorTable.json) / [建筑占地与门洞规则](../../Lua/Game/MapArea/TownBuildings.lua) / [剖切显示](../../Assets/GameFramework/Samples/Adventure/MapAreaRenderer.cs)。
- [生成器](../../Lua/Game/MapArea/TownGenerator.lua) / [台地与分层道路](../../Lua/Game/MapArea/TownTerrain.lua) / [巡游规则](../../Lua/Game/MapArea/TownResidents.lua) / [命令与快照](../../Lua/Game/MapArea/MapAreaSystem.lua) / [权威状态](../../Assets/GameFramework/Runtime/Data/MapAreaData.cs)。
- [第三人称镜头](../../Assets/GameFramework/Samples/Adventure/TownWalkCamera.cs) / [台地、台阶与桥面渲染](../../Assets/GameFramework/Samples/Adventure/TownSurfaceRenderer.cs) / [NPC 显示](../../Assets/GameFramework/Samples/Adventure/TownNpcRenderer.cs) / [操控与演示 UI](../../Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs)。
- [Blender 源](../../Art/TownLowPoly/Source/TownKit.blend) / [模型预览](../../Art/TownLowPoly/Previews/town-kit.png) / [Unity 模型](../../Assets/DynamicAsset/TownLowPoly/Models/) / [NPC 样例](../../Assets/DynamicAsset/TownLowPoly/Templates/) / [导入尺寸与 GUID](../../Art/TownLowPoly/Integration/unity-import.json)。
- [实际运行街景](../../Art/TownLowPoly/Previews/town-user-play.png)：用户自行进入 Play 后只读截取的城镇画面，未代替人工操控验收。
- [建模脚本](../../Art/TownLowPoly/Scripts/build_town_kit.py) / [铁匠与摊位扩展](../../Art/TownLowPoly/Scripts/expand_town_kit.py) / [定向导入](../../Art/TownLowPoly/Scripts/import_town.cs)：建模初始化不得重放覆盖已有作品，后续按对象定向编辑。
- [山城源文件](../../Art/TownLowPoly/Source/TerracedTown.blend) / [新模型 Blender 预览](../../Art/TownLowPoly/Previews/terraced-kit.png) / [山城建模脚本](../../Art/TownLowPoly/Scripts/build_terraced_kit.py) / [四个新模型定向导入片段](../../Art/TownLowPoly/Scripts/import_terraced.cs)。
- [山城 Unity 导入记录](../../Art/TownLowPoly/Integration/terraced-unity-import.json) / [全景](../../Art/TownLowPoly/Previews/town-terraced-overview.png) / [桥上](../../Art/TownLowPoly/Previews/town-terraced-bridge.png) / [桥下](../../Art/TownLowPoly/Previews/town-terraced-underpass.png) / [预览检查记录](../../Art/TownLowPoly/Integration/town-preview.json)。
- [算法检查](../../Tools/Tests/town_core.lua) / [真实数据检查](../../Tools/Tests/town_integration.lua) / [Unity 预览片段](../../Art/TownLowPoly/Scripts/preview_town.cs)。
- 街区组织参考：[香港石板街](https://www.discoverhongkong.com/eng/place-to-go/travel.guide-pottinger-street.html)的坡地台阶与沿街建筑、[尾道坡道](https://nihonisan-onomichi.jp/en/bunkazai01_hilly-roads/)的山坡街道；本项目采用奇幻低模改编，不复刻真实建筑。

- [可进入建筑源](../../Art/TownInteriorLowPoly/Source/WalkableTown.blend) / [新模型](../../Assets/DynamicAsset/TownInteriorLowPoly/Models/) / [导入记录](../../Art/TownInteriorLowPoly/Integration/unity-import.json) / [几何通路检查](../../Art/TownInteriorLowPoly/Integration/geometry-check.json)。
- [室内算法检查](../../Tools/Tests/town_interiors.lua) / [真实远征预览 Lua](../../Art/TownInteriorLowPoly/Scripts/preview_interiors.lua) / [Unity 预览](../../Art/TownInteriorLowPoly/Scripts/preview_interiors.cs) / [运行报告](../../Art/TownInteriorLowPoly/Integration/preview.json)：无需启动 Editor 或进入 Play；运行前确认当前已打开的 Editor 为 Edit Mode。
- [新版城镇全景](../../Art/TownInteriorLowPoly/Previews/city-overview.png) / [门洞与人物比例](../../Art/TownInteriorLowPoly/Previews/tavern-door-walk.png) / [酒馆内部](../../Art/TownInteriorLowPoly/Previews/tavern-interior-plan.png) / [铁匠铺内部](../../Art/TownInteriorLowPoly/Previews/smithy-interior-walk.png)。

- [扩展建筑 Blender 源](../../Art/TownExpansionLowPoly/Source/TownExpansion.blend) / [六类模型预览](../../Art/TownExpansionLowPoly/Previews/six-buildings.png) / [建模脚本](../../Art/TownExpansionLowPoly/Scripts/build_expansion.py) / [模型清单](../../Art/TownExpansionLowPoly/Integration/models.json)：新资源 ID 77–88，地块 ID 25–30、设施 ID 8–13；普通配方选择子集，王城包含全部六类。
- [导入记录](../../Art/TownExpansionLowPoly/Integration/unity-import.json) / [模型净空](../../Art/TownExpansionLowPoly/Integration/geometry-check.json) / [室内与环境预览报告](../../Art/TownExpansionLowPoly/Integration/preview.json) / [昼夜和地表框架](MapPresentation.md)。
