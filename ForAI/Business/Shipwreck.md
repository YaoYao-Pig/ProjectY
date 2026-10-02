# 沉船与废弃商船遗址

关键词：Shipwreck、沉船、废弃船只、科克船、开阔水域、中型副本、下舱、主甲板、艏楼、艉楼、楼梯、分层剖切。

## 文档目录

正文：水域选址 / 三层船体与陈设 / 显示与验证；关键入口：生成 / 配表 / 检查。

## 正文

- 下舱、主甲板与艏艉高台的直墙接缝使用 [MapArea 共用封边规则](MapArea.md)，从实楼板补至船壳周界木带内缘及高台横向墙线。封边没有可行走格身份；主甲板破口、梯井与完整六角导航保持原样，剖切随所属楼板处理。

- `E_MapAreaType.Shipwreck=5`、`MapAreaTable.id=40` 是独立策略，通过 `MapAreaSystem:Entrances → AdventureSystem:Visit` 进入，沿用返回、重进位置与战利品状态。小艇表示往返方式，未增加海上移动或游泳。
- 大地图 `MapWaterSites/GetWaterSites()` 保持独立概率、等水位连通片面积、完整水格圆盘、深度、上限与净距检查。无合格候选不强制生成，入口及标识都落在真实水面；规则和标识600/601不随副本扩大改变。默认远征种子20260921生成pointId=300010。
- `generationVersion=2`：船长99米、最大宽36.6米；64×80底层采样、六角半径1米，追加楼板后总cell数超过采样格数。下舱layer0高0米，主甲板layer1高4米，艏艉平台layer2高7.2米；人物、门和家具保持米制，不随船体放大。
- `MapAreaShipwreckTable/FloorTable` 定义船壳剖面、分层覆盖、0.4米安全内缩与水面。每个可走平格的中心及六角顶点必须完整位于本层轮廓内。主甲板左舷x<-8.1、z=6..15破口不开放；下舱可在其下延续，但不产生垂直跳落边。水面-1.15米不可走且不挡视线。
- `ShipwreckFloors` 由同一导航数据生成薄木板与楼梯，不用整块不透明FBX覆盖楼梯井。`StairTable` 两条中央横梯连接下舱/主甲板，艏艉各一条梯连接高台；`LayeredFloorEdges` 与最新城镇二楼共用明确双向邻接和边角顺序。梯面逐边连续，踏步0.16米，楼板厚0.24米；板底净空不足2米的下层格封闭。所有开放格连通，不允许跨层传送或跳落。
- `RoomTable` 提供船员卧舱、货舱/军械、厨房餐舱、前部储藏、船长室、艏楼器材间、主甲板和两处高台。四人小队可沿真实梯道逐区往返；随机小物避开房间目标与梯道保留通路。家具与舷壁之间不连通的至多3格小死角保留木板外观，但不作为可走岛。
- `PlacementTable` 指定共享原点船壳、真实门洞舱壁和固定家具。实体阻挡按Unity实际bounds及门洞左右立柱计算，不堵住门心；墙模块偏移只用于真实拼缝。桅杆仅基座阻挡，船壳/高帆不形成整块镜头障碍。新结构资源800–815位于 `ShipwreckV2/Prefabs`。
- `DressingTable` 是独立小物池，资源830–849位于 `ShipwreckProps/Prefabs`。18种桌面小物使用实际餐桌/船长桌的支撑高度与安全矩形，绳结/滑轮放地面；按实际非对称bounds防止悬空、越边和重叠，所有小物缩放为1。配置count是目标数量，至少放一件每种资产；可用支撑槽不足时减少额外重复件。
- 楼板用现有 `TownSurfaceRenderer` 薄面、踏步、BVH拾取和PawnMotion贴地采样。`cutawayGroup/cutawayLayer` 控制下舱整体覆盖层；`coverInteriorId` 仅标识高台覆盖的真实室内，不把露天高台变成室内。下舱隐藏主/上甲板、上部船壳及上层道具；主甲板露天区保持高台可见，进入其下方舱室才剖开对应高台；回到露天或登上平台恢复。模型、地板、拾取、镜头避障、格子高亮及宝箱模型使用同一剖切状态。
- `discovery=open` 全图可见。宝箱规则按layer分别生成下舱3–4、主甲板2–3、高台1–2个补给匣；沿用现有搜刮和重进状态，不新增敌人或战斗规则。搜刮距离按真实导航图判定，不能隔楼板打开同q/r的箱子。
- 改表经原导出器；资源引用通过既有地图同步流程保存。美术结构契约在 [structure_contract.json](../../Art/AssetExpansion202610/ShipwreckV2/structure_contract.json)，模型bounds在 [unity_bounds.json](../../Art/AssetExpansion202610/ShipwreckV2/unity_bounds.json)，小物支撑来源见 [manifest.json](../../Art/AssetExpansion202610/ShipwreckProps/manifest.json)。
- 离线最小检查：`python -B Tools/Tests/run_lua.py Tools/Tests/shipwreck_v2.lua`，检查三个种子、全层四人往返、逐边高程、净空、完整六角、家具和桌面支撑、分层宝箱及原大地图点位。导出真实 `layout_snapshot.json/navigation.json/world_snapshot.json` 到 `Art/AssetExpansion202610/ShipwreckV2/Integration/`。旧shipwreck.lua入口转发至此。
- `shipwreck_v2_preview.lua` 在已有独立Editor `FrameworkServices/LuaEnv` 中执行真实访问、两条下舱梯、艏艉高台、船长室、露天恢复和重进，返回9组 `{name,layout,view}` 供原渲染器可视验收，并直接UTF-8保存原生状态/检查结果。此入口不启动Play，不需要临时Assets C#脚本；离线通过不代表原生检查已执行。

## 关键入口

- [ShipwreckGenerator.lua](../../Lua/Game/MapArea/ShipwreckGenerator.lua) / [ShipwreckFloors.lua](../../Lua/Game/MapArea/ShipwreckFloors.lua) / [ShipwreckProps.lua](../../Lua/Game/MapArea/ShipwreckProps.lua)：三层拓扑、通路保护与支撑陈设。
- [LayeredFloorEdges.lua](../../Lua/Game/MapArea/LayeredFloorEdges.lua)：与城镇二楼共用明确邻接。
- [楼层](../../Config/Tables/MapArea/MapAreaShipwreckFloorTable.json) / [梯道](../../Config/Tables/MapArea/MapAreaShipwreckStairTable.json) / [分区](../../Config/Tables/MapArea/MapAreaShipwreckRoomTable.json) / [固定陈设](../../Config/Tables/MapArea/MapAreaShipwreckPlacementTable.json) / [小物池](../../Config/Tables/MapArea/MapAreaShipwreckDressingTable.json)：唯一源配表。
- [MapWaterSites.lua](../../Lua/Game/Map/MapWaterSites.lua) / [水域规则](../../Config/Tables/Map/MapWaterSiteTable.json)：原世界点位。
- [MapAreaRenderer.cs](../../Assets/GameFramework/Samples/Adventure/MapAreaRenderer.cs) / [MapAreaViewData.cs](../../Assets/GameFramework/Samples/Adventure/MapAreaViewData.cs)：通用分层剖切与拾取。
- [离线检查](../../Tools/Tests/shipwreck_v2.lua) / [原生轨迹与预览](../../Tools/Tests/shipwreck_v2_preview.lua)：最小验证和真实快照。
