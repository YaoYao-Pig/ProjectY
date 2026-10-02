# 暮潮号 · 三层沉船扩建

此版以原33×12.2米沉船为基础，将平面长宽各扩大约3倍至99×36.6米。原有25格可走平甲板不再作为中型副本标准；新增下层货舱、主甲板，以及抬高的船艏、艉楼平台。人物、门、生活设施和随身物件保持米制真实尺寸。

## 分层与资产

| 层 | 基准高度 | 用途 |
| --- | ---: | --- |
| 0 | 0米 | 货舱、船员生活舱、厨房餐厅等下层分区 |
| 1 | 4米 | 主甲板与高平台下方舱室 |
| 2 | 7.2米 | 抬高的船艏和艉楼平台 |

主甲板与下层之间有两条梯道；艏艉各有一条上行梯道。楼板、楼梯及梯井采用真实导航生成的薄网格，复用城镇楼层机制，外壳没有不可剖切的整张假甲板。详细字段与米制轮廓见 [结构契约](structure_contract.json)。

本目录16件新结构/设施包括分层船壳、门墙、宽门框、双吊床、厨房炉灶、餐桌双凳、货架、船长桌、武具架、铁笼和高桅。对应 MapAsset 800–815。另有 [20个小物品](../ShipwreckProps/README.md) 与 [10把新武器](../ShipwreckWeapons/README.md)。小物品按真实桌面支撑范围摆放；新武器本轮为独立资源，没有额外配置战斗数值或动作。

## 来源与审核

- [模型源](Source/ShipwreckV2.blend) / [FBX及尺寸清单](manifest.json) / [实际Unity包围盒](unity_bounds.json)
- [逐件正侧背审核](review.json) / [Unity导入检查](unity_validation.json)
- [参考图来源](references.json) / [参考板](References/board.jpg)
- [制作脚本](build_structure.py)：只管理本分组，不覆盖原V1或用户场景。

参考《Sea of Thieves》的上下甲板组织、航海桌和船舱功能，以及《Skyrim》的木舷、高艉与中世纪幻想轮廓。每件关联3份已实际查看的游戏图，全部是本项目重新建模。分件审核修正了枕头贴合、舵的楼层归属和船艏视图裁切；几何零非流形边、零退化面。

本目录的 Integration 保存生成与层间验证结果。最终玩法和剖切契约见 [ForAI沉船文档](../../../ForAI/Business/Shipwreck.md)。原V1来源继续保留，作为资源历史与大地图标识来源。

## 完成结果

默认种子的真实可走格为1595（下舱505、主甲板832、高台258），共有9个功能区、4条梯道和83件陈设。默认生成8个补给匣，配置范围6–9个；20种新小物全部参与摆放。入口至主要目标43步，原生四人验收路线共287个推进帧，实际经过三个楼层、全部梯道、各舱室并返回重进。

- [全船实际预览](Previews/generated-overview.png) / [下层俯视](Previews/generated-lower-plan.png)
- [船员舱](Previews/ship-lower-crew.png) / [厨房](Previews/ship-lower-galley.png) / [抬高船艏](Previews/ship-forecastle-upper.png) / [船长室剖切](Previews/ship-captain-interior.png)
- [三层导航图](Previews/navigation_layers.svg)
- [离线检查](Integration/offline_validation.json) / [原生四人检查](Integration/native_validation.json) / [Unity层级显示与拾取](Integration/unity_multilevel_validation.json)

九个真实状态均核对了楼板、陈设和宝箱的显示层及正确拾取。下舱时隐藏全部上层平楼板；回露天主甲板恢复艏艉高台；进入船长室只隐藏对应上盖。角色与摆件未随大船放大。主动请求一次工程编译；新增配表经定向导入解决Editor旧TextAsset缓存，未再次编译、未启动Editor或进入Play。

已经进入过的沉船会缓存旧布局，需要重新开始一次远征再进入。默认大地图种子仍为20260921、遗址坐标仍为(14,-24)。新10把武器已交付源、FBX、Prefab、图标和背景，但没有为其额外创建战斗数值或掉落配置。


## 帆面尺寸调整

高桅模型已改为约41.2米高，帆面52.8米宽、23.3米高，基座保持原尺寸；最低帆缘离主甲板8米。只更新该模型、资源基准高度和预览，未改变导航或剖切规则。

[放大后的整船效果](Previews/sail-enlarged-overview.png) / [帆面近景](Previews/sail-enlarged-close.png) / [导入尺寸与净空记录](Integration/sail_resize_validation.json)。
