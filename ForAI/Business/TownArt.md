# 城镇建筑细化与农场资源
关键词：建筑优化、木筋房、描边、风车、磨坊、谷仓、麦田、稻草人、TownStylized。

## 文档目录

正文：资源与来源 / 游戏接入 / 验证；关键入口：源 / 导入 / 配表与预览。

## 正文

- 对现有 8 个模型增量细化：酒馆/铁匠铺/商店/公会 Cover、三组联排住宅、世界地图城堡。增加结构木梁、窗板、屋面层次；城堡补后塔尖顶、吊桥和贴合原七格平台的护城水渠。原 FBX 路径与 GUID 保留；商业建筑 Structure、门洞与室内导航未改。
- 新增 `Town_Windmill / Town_Granary / Town_WheatGarden`：风车磨坊、谷仓草捆、围栏麦田与稻草人。共享 URP Lit 哑光材质，仅新增两种麦草色；没有贴图依赖。风车叶片等当前为静态网格，没有引入烟雾、风摆或农夫互动逻辑。
- 商业建筑、城堡和麦田的细化来源在 `Art/TownStylized/Source`。联排、风车、谷仓已进一步改成空心首层并拆结构/上盖，当前源转到 `Art/TownOpenBuildings/Source/OpenBuildings.blend`，见[可进入建筑](TownArea.md)；本目录旧源保留，不能重放旧细化脚本覆盖可进入版本。静态轴转换仍使用地图既有 FBX 预设。
- 农场资源为 MapAssetTable ID 113–115、MapAreaPropTable ID 41–43，采用米制；风车/谷仓使用七格包络中的真实室内及入口，麦田沿 q 轴三格占地。已进入城镇/村庄 dressing 池；风车/谷仓现在经 `buildingLotId` 接入[室内规则](TownArea.md)，原接入记录与 `PendingConfig` 仅作历史，不作为配置源。
- 模型全部顶点按真实六边形并集校验；尖顶/叶片/围栏也不能超过占地。四座商业建筑沿原室内与门洞边检查人物左右净空。截图使用实际生成器和当前导入资源，临时 PreviewScene/VolumeStack 在结束后恢复释放，不进入 Play。
- 后续维护活动源表，再执行 exporter、定向导入配置 `.bytes` 并同步两个场景引用；不能重放首次接入脚本。数量、道路、候选地形与连通性规则不变。模型路径不变的八项细化沿用原引用。保存场景时不能连带保存未获授权的用户编辑。

## 关键入口

- [当前源文件](../../Art/TownStylized/Source/) / [增量建模](../../Art/TownLowPoly/Scripts/refine_town_style.py) / [模型清单](../../Art/TownStylized/Integration/models.json)。
- [定向导入](../../Art/TownStylized/Scripts/import_style.cs) / [导入记录](../../Art/TownStylized/Integration/unity-import.json) / [占地验证](../../Art/TownStylized/Integration/footprints.json)。
- [游戏配表接入](../../Art/TownStylized/Scripts/configure_farm.py)：首次迁移记录，拒绝覆盖已有 ID；后续直接维护源表，遵循[配置管线](../Framework/Config.md)。
- [真实村庄预览](../../Art/TownStylized/Scripts/preview_style.cs) / [街景](../../Art/TownStylized/Previews/village-windmill.png) / [城堡](../../Art/TownStylized/Previews/castle-refined.png) / [预览记录](../../Art/TownStylized/Integration/preview.json)。
- 生成与道路规则归[城镇](TownArea.md)，摆放规则归[环境陈设](MapDressing.md)，描边与像素参数归[渲染管线](../Framework/Rendering.md)。
