# 王城街区生成参考与适配

本次改善王城的城市布局。宫殿自身保留正式中庭和双翼对称，城门、桥、市场、住宅和花园分别选址；不对已有宫殿网格做随机扭曲。

## 参考资料

- [Parish & Müller, Procedural Modeling of Cities, SIGGRAPH 2001](https://people.eecs.berkeley.edu/~sequin/CS285/PAPERS/Parish_Muller01.pdf)：全局发展目标提出道路，局部约束检查地形和连接。这里适配为配置功能中心、分层图上的道路代价和地块合法性；没有复刻论文的 L-system。
- [van der Staaij 等, Believable Minecraft Settlements by Means of Decentralised Iterative Planning, 2023](https://arxiv.org/html/2309.10871v1)：先分析地形，再迭代更新规划蓝图，让路径和建筑相互影响。这里在每次落地完整住宅组团后更新道路距离，后续地块沿已有街网生长；没有引入论文的多代理运行系统。
- [UNESCO：爱丁堡旧城与新城](https://whc.unesco.org/en/list/728/)：山脊主街、侧巷和院落的组织。借鉴主街与支巷层级、目的地之间的分支联系；保留游戏要求的宽路，不照搬历史狭巷尺度。
- [UNESCO：克鲁姆洛夫历史中心](https://whc.unesco.org/en/list/617/)：城堡、坡地与河流共同构成城市布局。借鉴主导地标和地形之间的关系，王城中用高地宫苑、山腰市场、侧面御苑和低径石桥表达；不声称复制这座城市的平面。

## 实现选择

1. `MapAreaRoyalDistrictTable` 独立定义七个功能片区的中心、种子偏移、地块搜索上限和公共场地半径。
2. `RoyalTownTerrain` 用独立的左右城界控制点、台地主斜率和低频噪声改变外轮廓与等高线。每层单独安排阶梯/坡道，并保留与外边界之间的公共地带，避免把崖边切成不可达的小孤岛。
3. 必需地标、设施和中庭喷泉先落地。道路按距离选择连接目的地的树，再在真实分层导航图上用 Dijkstra 绕开建筑、悬崖，权衡坡度、低频代价与已有街道；补充有限的回路。
4. 住宅按临街距离、片区目标、邻近住宅和种子变化评分。优先成组沿街，朝向从配置候选中选择；每次放置都检查公共空间连通，再接支巷。
5. 花坛、树、凉亭和雕像在剩余合法地块中选择位置；可选景观失败记录于 `planningDiagnostics.skipped`。必需设施不允许静默跳过。挡墙/栏杆随等高线分段设置，并避开台阶、街口和建筑。
6. 主街铺装半径 1、支巷半径 0；扩宽按可通行邻接关系扩散，不跨崖或串到另一层。默认是 42 栋住宅、6 项设施、22 名 NPC；这是布局改进，不是完整人口与土地经济模拟。

## 验证入口

- `Tools/Tests/royal_planning.lua`：四个区域种子（含默认世界王城）、确定性、完整连通、道路层级、回路和门前空间。
- `Tools/Tests/royal_town.lua`：三种地貌、双向邻接、四人小队进宫/上桥/下桥/返回入口。
- `Tools/Tests/town_core.lua`：原四种普通城镇的基本回归。
- `Scripts/preview_organic.lua/.cs`：Unity Edit Mode 使用工程生成器、源表导出数据、真实快照和资产生成独立布局预览；只验收规划与表面采样，不把它当成远征交互或人工 3C 测试。

调参修改 `Config/Tables/MapArea` 源 JSON，再运行项目 exporter。`configure_organic.py` 仅记录初次迁移，不能重放覆盖后续人工调表。
