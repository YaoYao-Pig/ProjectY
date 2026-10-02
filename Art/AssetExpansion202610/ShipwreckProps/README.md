# 沉船小物品：20件

原创低多边形船舱物品，真实米制、底部原点、零位移与单位缩放。Unity 朝向 +Z，使用既有静态 FBX 轴向导出契约；`bounds_unity` 已包含非对称部分。

- 可编辑来源：[ShipwreckProps.blend](Source/ShipwreckProps.blend)；独立 FBX：[Staging](Staging/)。
- 资源与放置契约：[manifest.json](manifest.json)；纯色哑光材质：[materials.json](materials.json)。
- 实际四视图：[Previews](Previews/)；总览：[collection_hero.jpg](Previews/collection_hero.jpg)；审核：[review.json](review.json)。
- 每件两份网络视觉参考及借鉴点随 manifest；原图仅用于研究，未作为模型贴图或几何挪用。参考档案：[References/references.json](References/references.json)。
- 风味文字为原创，文学意象参考《金银岛》的远航、船员补给与未完成归程：[Project Gutenberg](https://www.gutenberg.org/ebooks/120)。

小物品按真实尺寸放在桌面；绳结和滑轮也可落地。不得跟随船体整体放大。表面位置取 `bounds_unity.min.y=0`，桌面可加 0.004 米避免接触闪烁；道具不承担导航阻挡。

| ID | 模型 | 名称 | Unity 宽×高×深（米） | 表面 |
| --- | --- | --- | --- | --- |
| 830 | SWP_MarinerCompass | 暮潮航海罗盘 | 0.168 × 0.065 × 0.209 | table |
| 831 | SWP_FoldedSeaChart | 三折沿岸海图 | 0.420 × 0.020 × 0.300 | table |
| 832 | SWP_CaptainsLog | 皮封航海日志 | 0.226 × 0.106 × 0.300 | table |
| 833 | SWP_WatchHourglass | 值更木架沙漏 | 0.178 × 0.278 × 0.178 | table |
| 834 | SWP_BrassSpyglass | 皮握铜望远镜 | 0.470 × 0.114 × 0.114 | table |
| 835 | SWP_CabinLantern | 铁罩值夜船灯 | 0.200 × 0.412 × 0.200 | table |
| 836 | SWP_LeatherFlask | 皮套船员酒壶 | 0.192 × 0.272 × 0.111 | table |
| 837 | SWP_WoodenMug | 铁箍木杯 | 0.193 × 0.157 × 0.130 | table |
| 838 | SWP_CoarseBowl | 青边粗瓷碗 | 0.216 × 0.098 × 0.216 | table |
| 839 | SWP_WoodenPlate | 浅沿木餐盘 | 0.306 × 0.046 × 0.306 | table |
| 840 | SWP_CanvasRepairRoll | 束带修帆卷布 | 0.388 × 0.148 × 0.287 | table |
| 841 | SWP_SewingKit | 船匠针线木盒 | 0.235 × 0.203 × 0.217 | table |
| 842 | SWP_RopeKnot | 细缆盘结 | 0.247 × 0.034 × 0.255 | floor |
| 843 | SWP_WoodenPulley | 木颊双槽滑轮 | 0.170 × 0.138 × 0.178 | floor |
| 844 | SWP_IronNailBox | 船钉浅木盒 | 0.235 × 0.078 × 0.135 | table |
| 845 | SWP_WaxSealedLetter | 赤蜡封口信件 | 0.208 × 0.028 × 0.146 | table |
| 846 | SWP_DrawstringPurse | 抽绳零钱袋 | 0.162 × 0.185 × 0.150 | table |
| 847 | SWP_SpiceJar | 木盖香料小罐 | 0.130 × 0.200 × 0.132 | table |
| 848 | SWP_BandageParcel | 草药绑带医疗包 | 0.320 × 0.163 × 0.186 | table |
| 849 | SWP_BentWoodPipe | 弯柄旧木烟斗 | 0.345 × 0.096 × 0.084 | table |

本子任务完成 Blender 制作、导出及四视图核验；Unity 导入、独立材质/Prefab 与实际船舱摆放由主任务完成。没有启动 Editor、进入 Play 或执行项目编译。
