# 地形、水系与聚落生成 V5 · 可运行 Review

状态：已实现工程 Lua、正式源表和 Web 诊断；待效果 Review。2026-09-22。本次未操作 Unity 编译、Refresh 或 Play。

打开 [地图实验室](http://127.0.0.1:4175/)，种子 `20260921`，配方 `1,2,3,4,5,6,1,4,5,6`。当前样例有 9 座普通聚落、2 处偏远地牢、3 条主河、6 条支流与 1 处瀑布。修改配置工作台中的表并保存后，重新生成即可应用；Web 直接执行工程 ConfigSystem 和 Lua。

## Review 操作

1. 用自然地表、俯视和立体视角检查河流走向、宽窄、湖岸与聚落位置。关闭水面可看真实河床。
2. 点击地牢列表：查看道路网络为“独立地点，不接道路”，以及生成时中心的道路/聚落净距。
3. 选择“选址方案”，自动进入评分热力图；灰色表示水域、地貌、硬指标或最低分未通过，点击格子显示原因。高分候选仍须通过数量、间距、完整占地和入口试排，不保证生成。
4. 展开“选址结果与未生成原因”：查看各样式的实生成数、候选淘汰、占地失败与区域数量/尝试上限。
5. 选择“汇水与河道”，点击河格查看上游累计汇水和目标扩宽半径。半径是算法计划值，实际范围还受两岸地形和开挖预算约束。

热力图记录该样式开始选址时的评分；聚落详情记录其最终选定时的中心指标，两者因前面聚落落位可能不同。汇水权重、接近岸边代价都是生成预览指标，不是物理流量或队伍的正式寻路规则。

## 实际生成顺序

Region 地形与边界混合 → 自然盆地湖 → 全图排水与累计汇水 → 主河/支流与河宽 → 跨区瀑布及落水潭 → 普通聚落与街道 → 城际道路 → 偏远地牢 → 资源装饰、Border、只读快照。

地牢在道路之后生成，使用独立随机流；仅改变地牢规则不会改变前面的河网、普通聚落或道路。道路不会在地牢生成后继续铺设。

## 地牢如何配置

[MapTownTable](../Config/Tables/Map/MapTownTable.json) 的地牢样式引用现有地牢建筑/模型，并设置：

| 字段 | 当前值 | 作用 |
| --- | --- | --- |
| placementStage | AfterRoads | 在所有道路结束后放置 |
| connectRoad | false | 不作为城际道路端点，不进入道路网络 |
| generateStreets | false | 保留干燥相邻入口，不生成内部街道 |
| siteProfileIds | [401] | 使用“地牢·荒野遗址”方案 |

[MapSiteRuleTable](../Config/Tables/Map/MapSiteRuleTable.json) 中 profileId=401：roadDistance 的 hardRange=[8,48]，settlementDistance 的 hardRange=[12,48]。分别代表离所有道路/街道至少 8 格，离普通聚落实际建筑、中心和街道至少 12 格。48 是方案距离截断值，并非最远允许距离。

净距按直线六边形距离计算，不因地图缺格而被绕路距离放大；完整建筑占地与入口也必须满足净距。其他遗址间距由 MapTownTable.minSpacing 保证。没有符合条件的位置时少生成，不降低规则凑数。

内部保持 town/building 兼容输出，town.role 区分 settlement/remote。偏远地点 roadNetworkId 缺省、roadIds 为空；Web 已单列计数。Unity 渲染仍可复用现有布局与资产，本次未调整其统计文字或验证 Play 画面。

## 聚落选址算法

先按配置的硬区间过滤候选，再对每项指标作分段线性评分，求加权平均；低于 minScore 的候选淘汰。可用方案按 pickWeight 抽选，方案内按 score^scoreExponent 做确定性加权抽样，避免所有聚落都挤在唯一最高分位置。试排建筑和街道后才提交整座聚落；失败不留下残余占地。

海拔与局部可建设程度分别评价。城市已允许 Mountain/Snow 地貌；高山方案的硬海拔区间是 [6,40]，同时要求足够干燥缓坡格。普通方案不会禁止高处，只是偏好不同；平整的高处也可能被普通方案选中。

[MapSiteProfileTable](../Config/Tables/Map/MapSiteProfileTable.json) 当前方案：

| 样式 | 方案 ID | 方案抽选权重 |
| --- | --- | --- |
| 小村庄 | 101 近水缓坡 / 102 高原台地 | 80 / 20 |
| 大城市 | 201 河谷平地 / 202 高山盆地 | 90 / 10 |
| 城堡 | 301 河岸平原 / 302 高地据点 | 40 / 60 |
| 地牢 | 401 荒野遗址 | 100 |

权重影响可用方案之间的选择，不承诺地图中严格的数量比例。默认采样半径 3 格、距离截断 48；candidateBudget 限制每方案进入试排的候选数，样式 siteAttempts 限制每 Region 试排次数，maxCount/maxPerRegion 均为数量上限。

可调指标如下。规则支持 hardRange（空数组关闭）、严格递增 scoreXs、对应 0–1 的 scoreYs、weight；端点以外沿用端点分值，不执行自定义脚本。

| 指标 | 含义 |
| --- | --- |
| height | 绝对地面海拔 |
| slope | 与干燥邻格的最大高差 |
| roughness | 采样半径内高度标准差 |
| relativeHeight | 高于周围平均地面的程度 |
| buildableCells | 周围干燥且邻格高差不超过 accessMaxStep 的格数 |
| waterClearance | 到水域的六边形净距 |
| waterAccessDistance | 到可接近岸边的坡度加权路径代价 |
| riverJunctionDistance | 到实际中心线汇流点的六边形距离 |
| settlementDistance | 到普通聚落实际建筑、中心和街道的净距 |
| roadDistance | 到全部道路和街道的净距 |

取水评价只沿干地传播；岸边离水面高差须不超过 shoreAccessMaxDrop，路径邻格高差须不超过 accessMaxStep，路径每步代价为 1 + 高差 × accessSlopeCost。因此近在悬崖下的水源不会得到“方便取水”的高分。没有来源、超出距离上限或不可达时记为 distanceCap；界面明确提示这种截断含义。

评分负责偏好与中心硬限制，实际建筑仍受 MapTownTable.maxGroundDelta、半径、完整占地、建筑地貌、必需地标和入口条件约束。水域/道路/聚落净距硬限制还复核完整占地及入口。

## 水系算法与配置

[MapHydrologyProfileTable](../Config/Tables/Map/MapHydrologyProfileTable.json) 提供局部径流权重、开挖阻力、曲流偏好、河宽倍率、陡坡收窄系数、盆地蓄水概率与比例。[MapRegionTable](../Config/Tables/Map/MapRegionTable.json) 通过 hydrologyProfileId 引用，过渡带使用 TerrainBlend.regionWeights 插值；同地貌的不同 Region 配置也能采用不同水文方案。

1. **真实盆地**：从全部地图外缘进行 Priority-Flood，求最低溢出高度。填洼是分析用虚拟高度，不抬高地面。按盆地深度排序，在概率与数量预算内蓄水；水位取最低点至溢出口高度的一部分。仅连通且低于水位的地形变湿，保留岛屿、岩脊和天然缺口。超过 maxLakeCells 时降低水位。
2. **连续排水**：选少量间隔较远的低洼地图出口，建立全图无环下游关系。先最小化翻越高度，同高时比较路径长度、地形高差/开挖阻力与低频空间噪声代价。平地有更多曲流变化，陡坡更服从谷地；不会在 Region 边界重新开始一条河。
3. **汇水和主支流**：每格径流按局部配置及空间噪声加权，沿排水树反向累计。候选源头达到 minSourceRunoff 后，在长度、跨区数、源头间距、主支流数量上限内尝试；流入既有河段成为支流，流入湖泊或地图出口结束。单 Region 预览的跨区数限制按实际 Region 数取最小值。
4. **水位和河宽**：中心线先整条验证下坡水位、干岸、开挖预算，再写入。widthFlowXs/widthRadiusYs 定义汇水量到河宽的曲线；局部宽度倍率、坡度收窄、bankNoise 决定目标河岸。仅扩入高度与开挖预算允许的连通陆格；横断面检查通过后提交，陡峭峡谷可以仍只有一格宽。
5. **瀑布**：保留跨 Region 的真实直连水边、最小落差、配置概率与连通落水潭条件。不能在预算内形成湖泊时不生成瀑布；不保证每个种子都有。

[MapWaterNetworkTable](../Config/Tables/Map/MapWaterNetworkTable.json) 控制全局预算、源头阈值、噪声跨度、河宽曲线、最大扩宽半径、河岸开挖预算与湖泊上下限。当前最大额外扩宽半径 2 格、岸边开挖预算 1.1、自然湖上限 10 片；这都是可调整的初始参数。

启用全图水系时，Lake/River 策略只负责塑造初始盆地与河谷，旧策略的候选水面不参与最终水域划分。水系表为空时保留原有策略水体整理，作为明确的关闭模式。

仍采用六边形地面与离散水位；本版没有连续曲面、侵蚀仿真、动态水流或通行/桥梁规则。当前湖泊以部分蓄水盆地为主，没有单独的“满湖溢流河口”配置与玩法语义。

## 实现与验证入口

- [MapSiteSelection.lua](../Lua/Game/Map/MapSiteSelection.lua)：指标、距离场、曲线评分及完整占地净距。
- [MapInfrastructure.lua](../Lua/Game/Map/MapInfrastructure.lua)：分阶段选址、试排、道路与偏远地点。
- [MapHydrology.lua](../Lua/Game/Map/MapHydrology.lua)：盆地、排水、汇水、河宽和瀑布。
- [map_siting_hydrology.lua](../Tools/Tests/map_siting_hydrology.lua)：高山平台、悬崖取水、配置净距、岛屿湖盆、坡度收窄与真实偏远地点。
- [preview.lua](../Tools/MapPreview/preview.lua)：序列化诊断；前端不复制算法。

设计参考：[Priority-Flood 原论文](https://rbarnes.org/sci/2014_barnes_depressions_published.pdf)。工程使用其优先扩展和虚拟填洼思路，实际生成策略及美术约束以上述代码与配表为准。
