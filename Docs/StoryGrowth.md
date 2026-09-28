# 事件与角色养成

## 需求依据与参考范围

- [战斗总览](https://my.feishu.cn/wiki/XvPvw2sk2ih7BTkAonGcjmR7nlg)：一级/二级属性，按属性权重抽 2–3 个技能方向，属性高低影响技能层级，初始和经历获得的特质。
- [游戏玩法](https://my.feishu.cn/wiki/AjNMwkcNHisPnukqnESc78azn0b)：潜力通过特定事件释放，冒险中产生角色表达。
- [一些想法](https://my.feishu.cn/wiki/OHZhwsGudiXWfIkywDDcczNunfe)：永久特质、负面特质消除、事件解锁新树、记录共同经历。其他战斗/装备/时间/关系系统想法不属于本次实现。
- [GDC 2022：Getting Players Emotionally Invested in Procedural Characters in Wildermyth](https://www.gdcvault.com/play/1027924/Independent-Games-Summit-Session-Getting)：已查阅官方会话摘要，核心主题是让玩家与生成角色建立情感连接，避免违背角色性格和破坏信任；未声称完整观看视频或取得逐字稿。
- [Wildermyth Event Types](https://wildermyth.com/wiki/Event_Types) 与[官方创作教程](https://wildermyth.itch.io/wildermyth/devlog/91164/how-to-write-your-own-villain-for-wildermyth-part-1)：情境匹配事件、故事角色和结果，以及用短故事串起旅程。本项目据此将“事件选择→角色改变→可回顾经历”接成闭环；没有复制游戏剧情或美术。

## 使用

1. 在现有远征 Demo 中，按 **C** 或点击游戏内“同行者”打开养成页，按 Esc 关闭。切换四名队员查看各自状态。
2. 总览：左侧展示当前角色与成长进度；17 项属性默认完整可见，点击属性条目消费属性点。右侧点击紧凑的特质标签查看说明。
3. 技能：点天赋节点查看收益和条件，再点“投入”按钮。左右箭头切换天赋树，未开放树可预览。右侧点击学习候选选择一项，固有、装备、已研习技能同时可查。
4. 经历：保留个人成长和参与事件的快照，按最新在前排序，每页 8 条。序号是记录顺序，不是游戏日期。
5. 地图“石缝里的路标”自动结算并写入【发现】日志；“余烬中的援手”展示配图、正文和选项，接受帮助会移除傲慢、留下伤痕与同袍特质、解锁余烬守望并释放潜力。

常驻入口、地点、资金、队伍状态、操作提示和旅途日志现由 [MainHud](../ForAI/Business/MainHud.md) 统一管理。天赋选中圆环已改为围绕圆心缩放，普通／选中状态均保持与节点同心。

## 从游戏里实际获得内容

大地图侧栏按地下探险、城镇、旅途故事分组，地牢入口不再埋在地点列表末尾。

| 行为 | 当前结果 |
| --- | --- |
| 进入“地牢遗址 · 古代地下迷宫” | 游戏内提示旧营地补给箱的位置与搜刮操作 |
| 靠近入口补给箱后按 E | 获得散射符文、满弹匣、弹药、劈砍助推器；逐项写入【获得】日志 |
| 继续深入，距入口至少 6 格 | 自动触发“余烬中的援手”；选择结束后留在相同地图、相同位置 |
| 走到城镇铁匠服务台附近按 E | 30 金币购买助推器，20 金币购买散射或精准符文 |
| 走到商店服务台附近按 E | 8 金币购买 24 发弹药，12 金币购买满弹匣，或购买恢复补给 |
| 走到酒馆服务台附近按 E | 购买全队恢复补给 |
| 按 I → 武器工坊 | 助推器装在双手巨剑剑脊；散射/精准符文装在法杖对应挂点 |

上述触发使用 [ExplorationEventTable](../Config/Tables/Adventure/ExplorationEventTable.json)，购买物品与价格使用 [AdventureChoiceTable](../Config/Tables/Adventure/AdventureChoiceTable.json)。触发来源支持进入、探索距离、搜刮、战斗胜利和设施交互；按地点记录一次性触发，重新进入不会重领，城镇服务可重复购买。金币或背包空间不足时不扣费、不发物品。地牢搜刮物仍沿用既有掉落表。

城镇居民保留真实占位；短暂挡路时需等待或绕行。其余设施仍是介绍，并未实现制作、独立商店库存或任务系统。

## 默认 Demo 规则（均可配表）

| 项目 | 默认 |
| --- | --- |
| 初始点数 | 2 属性点、2 被动点 |
| 初始潜力 | 每个模板 2 点，锁住等待事件 |
| 每级奖励 | 2 属性点、1 被动点 |
| 经验 | 升到 2 级需 40，之后逐级 +20，当前等级上限 10 |
| 主动研习 | 2/4/6/8/10 级；每次抽 2–3 个不同方向，选 1 项 |
| 方向权重 | `max(1, value)`；排除没有可用技能的方向 |
| 层级权重 | `weight * (1 + value * tier / 20)`；二层示例门槛为属性 8 |
| 装备影响抽取 | 默认关闭；角色自身加点、特质、被动仍参与 |
| 天赋邻接 | 远行者之路：任一已亮邻居；余烬守望：全部有向前置 |
| 战胜遭遇 | 每名参战队员 50 经验；倒地队员若已参战也获得 |
| 简单事件 | 仅一个自动结果，无战斗；先检查条件，未满足不进入事件 |

经验可以累计跨级，学习机会排队；已经抽出的候选不会随换装、加点或重开 UI 重抽。候选不足时展示实际数量；没有可用技能时明确记录，消耗该次机会。

## 配置入口

全部养成表位于 [Config/Tables/Progression](../Config/Tables/Progression/)；字段带说明，沿用配置编辑器及导表流程。

- 树由 `TalentTreeTable`、`TalentNodeTable` 和 `TalentEdgeTable` 组成。`unlockRule` 支持 `adjacent_any` / `prerequisite_all`；图中坐标可自由布局，画布随节点范围扩展。
- 节点只引用 `PassiveSkillTable`，被动支持多属性加算和多阶；主动技能统一引用现有 `CombatSkillTable`，由 `ActiveSkillPoolTable` 按方向和范围组织。
- [事件表](../Config/Tables/Adventure/AdventureEventTable.json) 配 `presentation`、`illustration`、`actorAttribute`、`logKind`；主角按指定属性最高的存活队员选出，平手按队伍顺序，全部倒地时选首名以支持营地恢复。
- [选项表](../Config/Tables/Adventure/AdventureChoiceTable.json) 配特质条件、金币/侦察条件、授予和移除特质、解锁树、经验、潜力、受益者范围、物品及遭遇。`subject` 影响主角，`party` 影响全队；物品进入共享背包。选择必须属于当前事件，结算后拒绝重复提交。
- `StoryLogTemplateTable` 配标识、颜色与模板，支持 `{actor}`、`{companions}`、`{location}`、`{title}`、`{detail}`。事件正文和结果也可使用已提供的上下文占位符。普通故事日志只在游戏内显示。
- 配图采用直接 Sprite 引用。改图路径后，退出 Play，执行 `Project Y/UI/创建事件与养成 UI` 同步；已有 Prefab 内容保留，复杂事件缺图直接报错。

## 生命周期与当前范围

养成、日志及经历仍属于当前远征会话。开始新远征或关闭运行时会清空；本次没有引入存档。也未实现关系数值、退休继承、角色招募、动态长篇事件链、日历、洗点或通用被动触发器。角色特质、属性、天赋收益与主动技能已接入现有战斗系统。

## 原创配图

- 工具：内置 `image_gen`，保存于 [Wayfarers.png](../Assets/DynamicAsset/UI/Art/Story/Wayfarers.png)。
- 生成提示：原创奇幻冒险队伍在苔藓覆盖的废墟石门前围坐营火，森林小径和半毁石门；手绘故事书、剪纸桌游质感，清晰轮廓、暖赭光和低饱和松绿、墨线、层次景深；横向 3:2，无文字、界面、标志或水印，不复刻现有游戏素材。

验证入口与数据职责见 [ForAI 养成文档](../ForAI/Business/Progression.md)。

## 本次验证（2026-09-27）

- 原生 xLua：养成规则 5 项、远征核心 5 项、显示快照 5 项、远征生命周期 6 项、战斗 HUD 3 项、装备与技能查询 5 项通过。
- Unity Edit Mode：真实 C# 养成与故事状态 6 项、真实 Prefab 交互 5 项、战斗与事件回归 7 项通过。验证了技能候选不会因窗口重开而改变、点数消费、前置条件、特质改变、故事重复提交和模态暂停恢复。
- 已完成用户授权的收尾 C# 编译，Console 无错误或警告；未进入 Play，未做完整构建或全量测试。
- 已检查 [总览](Previews/StoryGrowth-overview.png)、[天赋与技能](Previews/StoryGrowth-skills.png)、[经历](Previews/StoryGrowth-history.png)、[复杂事件](Previews/StoryGrowth-event.png) 的实际 Prefab 预览。截图中的角色成长来自验证过程，不是新远征的初始状态。

### 反馈后的接入与界面修订

- 用户授权结束现有 Play；集中请求一次 C# 编译并通过，生成 xLua 绑定后由 Unity 自动编译生成代码，未重新进入 Play。
- 新增真实路径检查 4 项通过：生成入口、逐格走到宝箱并搜刮/安装、探索故事/原地恢复、走到铁匠交易/不足金币/重复提交。检查曾因独立宿主没有 UI 暂停查询、物品名称断言不符、未等待巡游居民而失败，修正检查夹具后通过；没有跳过移动或直接修改物品状态。
- 新版真实 Prefab 的 5 项交互、旧战斗/事件 7 项与地牢原地战斗 5 项回归通过；养成规则 5 项、显示快照 5 项、生命周期 6 项通过。地牢回归实际处理新增故事后继续战斗，覆盖胜利恢复、撤退与重进。没有全量测试或 Player 构建。
- 当前截图已更新为角色手记布局：真实模型预览、纸色界面、属性图标、特质标签、天赋圆形节点、选中状态及经历时间线。布局源为实际 Prefab；“重建角色手记布局”会恢复生成器的基础布局，常规同步不会覆盖手工排版。

### MainHud 与屏幕血条

- MainHud 已统一地点、资金、背包／手记入口、探索操作、队伍、附近交互、日志和嵌套战斗 HUD；[地图布局预览](Previews/MainHud-map.png)与[血条布局预览](Previews/MainHud-area.png)来自独立 PreviewScene，背景不是实际地牢。
- UIFollower 在 Screen Space Canvas 中跟随真实角色 Transform；默认血条 Widget 宽 184、血槽高 18，带姓名和血量数字，透视／正交缩放限制为 .85–1.18，不挡鼠标。旧二维棋盘使用同一 Widget 的屏幕点模式。
- MainHud 4 项真实 UI／数据交互、相机透视与正交投影、旋转、近裁面／背后隐藏、分割视口和最小宽度检查通过。天赋圆环在普通与选中缩放下的圆心误差均为 0；养成 UI 的 5 项回归及战斗 HUD 3 项基础检查通过。
- 初次编译通过；Widget 生成器重复添加 CanvasGroup 和截图工具未恢复 Overlay 两处收尾问题修正后，分别取得用户授权再编译。最终资源与验证通过；没有进入 Play 或执行完整构建。
- [动作设计](CharacterAnimationPlan.md)已核对免费来源与当前无蒙皮骨骼的事实，尚未导入动画或制作骨架。
- 用户随后自行进入 Play 的只读检查发现首帧场景通知会清理刚打开的 MainHud；已修正 UISystem 在 Open 前同步场景版本，并新增两项定向生命周期检查。修补当前会话前用户已退出 Play，因此源码修复在下一次 Play 加载；没有重启或重置用户远征。
- 后续显示规则：仅战斗显示头顶血条，探索／城镇／事件／结算不显示。战斗拉远时通过 CanvasGroup.alpha 淡出：正交尺寸默认 28→40，透视等效深度默认 35→50；阈值可在 HudHealthWidget 的 UIFollower 组件中调整，拉近恢复。底部队伍生命卡保留。
