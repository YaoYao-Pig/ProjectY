# 暮潮号 · 中世纪沉船资源

本文为初版制作记录；当前进入后的地图已经由[三层扩建版](../ShipwreckV2/README.md)替代。此处的33米、25可走格及旧截图均作为历史保留，大地图标识继续使用。

19 件独立模型：2 个大地图标识，17 个船体构件与船用陈设。整体设计取中世纪柯克商船的宽腹、单桅方帆、高艉楼，结合奇幻游戏沉船遗址的大块面与破损层次。

暮潮号原是北方盐商共有的河海商船。暴雨之夜，船长为避开载着难民的小舟，主动驶离标记航道，船侧因此撞上沉在水下的旧塔尖。桅杆被扯裂，盐货浸满船舱，却没有一名乘客随船沉没。船员用备用艇往返运走旅人，把最后一段绳索系在铜钟架上，约定来年退潮时再回到这里。如今艉楼的门仍紧闭着，甲板散落湿木桶与旧货箱，断帆下偶尔传来钟舌碰响的声音。当地渔人把它视作归航的路标，也有人相信还未找到的账本记着一条被遗忘的商路。

## 文件

- [整船组合预览](Previews/assembled.png) / [俯视](Previews/assembled_top.png)
- [模型清单](manifest.json) / [实际坐标契约](asset_contract.json)
- [源文件](Source/Shipwreck.blend) / [展示源文件](Source/ShipwreckAssembly.blend)
- [三视图审核](review.json) / [审核说明](review.md) / [Unity 检查](unity_validation.json)
- [游戏参考档案](References/references.json) / [参考板](References/board.jpg)
- [生成脚本](build_shipwreck.py) / [组合预览脚本](preview_assembly.py)

Unity 资源位于 `Assets/DynamicAsset/AssetExpansion202610/Shipwreck/` 的 Models、Materials、Prefabs。已注册 `MapAssetTable` 600–618、独立 `Shipwreck=5` / 区域40，并同步远征和大地图测试场景的资源引用。

## 游戏接入与验证

默认远征种子 `20260921` 自然生成一处暮潮号遗址，大地图轴坐标 `(14,-24)`，水体206格；选址必须满足真实同水位连通水域、19格完整水域圆盘、最小水深、概率、数量上限和间距。没有合适水域时允许不生成。新远征会读取新配置；现有运行中的旧布局不会原地追加地点。

小地图使用32×40格的固定船形模板，实际可走甲板25格，入口到船艏目标10步；水域、破口和封闭艉楼不可行走。完整六角内缩后，随机货箱/木桶/碎木不能阻断主路或相互穿插，默认例生成14件结构/陈设与1–2个可搜刮补给匣。当前不生成新的敌群，也没有游泳或航海移动机制。

- [真实 Unity 生成预览](Previews/generated_hero.png) / [生成俯视](Previews/generated_top.png) / [真实水域标识](Previews/generated_world_marker.png)
- [真实导航图](Previews/generated_navigation.svg) / [默认种子与地点](Integration/world_sites.json)
- [原生会话检查](Integration/native_integration.json)：真实 Adventure:Visit、四人走到船艏并返回、离开大地图、重进保持成员位置和宝箱状态。
- [Unity 渲染检查](Integration/unity_generated_preview.json) / [水位检查](Integration/world_marker_preview.json) / [场景资源绑定](Integration/scene_bindings.json)
- 代码与配表入口见 [ForAI 沉船文档](../../../ForAI/Business/Shipwreck.md)。

本轮主动请求一次 C# 编译，完成后无控制台错误；没有启动 Editor、进入 Play 或运行全量测试。原生检查使用现有 Editor 的独立 Services / LuaEnv，生成预览使用实际快照和原 MapAreaRenderer / MapPreviewRenderer，结束释放 PreviewScene。

## 关键几何

- 主船约长33米、宽12米；甲板高度0，水面建议-1.15。艏朝 Unity +Z，艉朝 -Z。实际导入轴转换为 Unity `(X,Y,Z)=Blender(-X,Z,-Y)`。
- 船壳和甲板共享中心与原点。`SW_Deck_Cog` 顶高0，Unity X小于-2.7、Z在4到10之间为侧面破口；导航需内缩并检查完整六角边界。
- 艉楼是封闭障碍，暂不提供可进入船舱；残帆最低点超过3米，只阻挡桅杆底部即可。船壳不可用整个包围盒封住甲板或作为相机实墙。
- `SW_Map_WreckMarker`、`SW_Map_AbandonedCog` 为大地图单格缩制标识；不能直接放大它们充当小地图。
- 参考只借鉴形体与气氛。历史校正：[德国历史博物馆：Cog](https://www.dhm.de/mediathek/en/ship-types/milestones-in-the-history-of-european-shipbuilding/04-cog/)。小说意象：[William Morris《The Sundering Flood》第44章](https://www.gutenberg.org/cache/epub/25547/pg25547-images.html)，取水运、商旅及危险航途，不复制原文。
