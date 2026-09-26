# 地图环境装饰

关键词：装饰物、倒木、芦苇、石井、货车、晾晒架、矿道木架、遗骨、晶簇、MapDressingLowPoly。

## 文档目录

正文：资源与配置 / 生成约束 / 修改与验证；关键入口：三类生成器 / 源作品 / 检查。

## 正文

- 24 类环境陈设对应 `MapAssetTable` ID 89–112、`MapAreaPropTable` ID 17–40。自然组为倒木、树桩、蕨类、蘑菇、芦苇、野花、石堆、立石；街区组为石井、货车、草垛、柴堆、晾晒架、告示牌、水槽、灯柱；地牢组为碎石、遗骨、破矿车、烛台、锁链柱、矿道木架、覆苔残像、晶簇。完整对照以 `Integration/kit.json` 和源表为准。
- 源文件在 `Art/MapDressingLowPoly/Source/MapDressing.blend`，Unity 使用 `Assets/DynamicAsset/MapDressingLowPoly/Models` 的 24 个 FBX，合计 7018 三角形。硬边、纯色、米制、单位根变换，静态导出沿用 [地图资源](MapArt.md) 的轴转换。旧颜色复用共享材质，新增颜色在本目录独立材质中共享；不依赖贴图。
- 大地图 `MapDecorationRuleTable` 按主导地貌、密度、坡度、缩放及两格内水岸/道路关系筛选。`MapDressing.Build` 在原树木与岩石散布后执行，避开水格、道路、建筑和已有装饰；`clearance` 控制建筑/装饰净距。位置噪声不消耗其他生成阶段的随机序列，陈设只影响显示。Web 使用配置的占位轮廓，不加载 FBX。
- 城镇 `MapAreaTownTable.dressingProfileId → MapAreaTownDressingTable` 控制物件池、数量上限、间距及临街/临建筑距离。`TownDressing.Apply` 适用于普通镇、村庄、城堡镇、隐居群落与王城；在建筑与街网之后、居民路线之前执行。仅选地面层平坦公共园地，避开室内、入口一格邻域、保留区和坡面。整件试摆后检查可走格全连通，不满足便回滚。
- 地牢功能设施仍走旧 `propIds/propCount/propCoverage`；`DungeonProps.Dress` 使用单独的环境陈设预算，避免被大设施覆盖率提前耗尽。一级洞穴读取 `MapAreaDungeonTable.basicDressingIds/basicDressingCount`；二级样式与三级预设读取 `dressingPropIds/dressingCount`。按房间用途沿墙选择候选，保留中央战斗区与所有走廊，试摆后检查全图连通。
- 新 `MapAreaPropTable.scaleMode=meters` 保持模型实际尺寸；旧物件使用 `grid`。大件沿局部 q 轴占连续三格，小件占一格；显示朝向与足迹旋转同源。小地图陈设为阻挡物，视线分别由 `blocksSight` 决定。矿道木架是整件阻挡陈设，不把其视觉开口当作通道。数量均为上限，不为凑数挤入不合法空位。
- 地牢墙地配方与渲染契约归 [地图材质与环境表现](MapPresentation.md)。灯柱/烛台的暖色部分是模型配色，不新增点光或互动业务。
- 修改源表后运行 exporter，结果仍写入各加载目录的 `_Gen`。模型更新保留 meta，通过原生 Unity MCP 定向导入并同步 AdventureDemo、MapRuntimePreview 两场景的资源绑定。`configure_dressing.py` 是首次迁移记录，拒绝重放；后续直接维护源表，不重复覆盖用户调参。
- 定向检查 `python Tools/Tests/run_lua.py Tools/Tests/map_dressing.lua`：六地貌地牢、五类城镇、大地图、确定性、全图连通、设施可达、保留区、米制缩放、房间材质一致以及 24 类物件覆盖。编辑态 `preview_dressing.cs/.lua` 使用真实生成器、快照、场景绑定与运行时显示器截图，不启动游戏会话或 Play。

## 关键入口

- [大地图规则](../../Config/Tables/Map/MapDecorationRuleTable.json) / [散布实现](../../Lua/Game/Map/MapDressing.lua)。
- [城镇规则](../../Config/Tables/MapArea/MapAreaTownDressingTable.json) / [城镇实现](../../Lua/Game/MapArea/TownDressing.lua)。
- [地牢陈设](../../Lua/Game/MapArea/DungeonProps.lua) / [占地与缩放](../../Config/Tables/MapArea/MapAreaPropTable.json)。
- [源作品](../../Art/MapDressingLowPoly/Source/MapDressing.blend) / [建模](../../Art/MapDressingLowPoly/Scripts/build_dressing.py) / [清单](../../Art/MapDressingLowPoly/Integration/models.json) / [Unity 导入记录](../../Art/MapDressingLowPoly/Integration/unity-import.json)。
- [模型概览](../../Art/MapDressingLowPoly/Previews/blender-gallery.png) / [城镇实际预览](../../Art/MapDressingLowPoly/Previews/town-dressing-street.png) / [苔藓地牢](../../Art/MapDressingLowPoly/Previews/dungeon-5-surface-15.png) / [木板地牢](../../Art/MapDressingLowPoly/Previews/dungeon-1-surface-16.png)。
- [算法检查](../../Tools/Tests/map_dressing.lua) / [Unity 预览片段](../../Art/MapDressingLowPoly/Scripts/preview_dressing.cs) / [Lua 快照](../../Art/MapDressingLowPoly/Scripts/preview_dressing.lua) / [导入](../../Art/MapDressingLowPoly/Scripts/import_dressing.cs) / [场景绑定](../../Art/MapDressingLowPoly/Scripts/bind_dressing.cs)。
