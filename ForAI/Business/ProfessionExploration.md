# 职业探索与礼式决斗

关键词：职业生活技能、野外萃取、酒馆采风、随军诊护、识咒、礼式决斗、循迹、日限、诅咒武器。

## 文档目录

正文：实体与事务 / 单挑 / 入口与验证。

## 正文

- `ProfessionExplorationTable` 以真实技能 ID 声明用途、距离、耗时、物资和幅度。`AdventureSystem` 创建模块后向 `CharacterSkills` 注册独立 handler；技能拥有、使用阶段、当前触媒仍走同一入口。角色 UI 不持有第二份玩法状态。
- 萃取查找当前可见、距离内且未采过的真实森林蕨类 prop；背包容量检查通过后才发放毒剂并登记实体已采。采风要求可用酒馆服务，选择实际存在、范围内且未到访／未记录的地点；每城每日一次。采集与消息身份按地点/实体记录在 `NarrativeData`，随现有存档保存。
- 诊护只缩短已有可恢复伤势的到期时间，每队员每日一次，消费真实急救包；不会生成不存在的恢复计划，不修复永久残肢。`ProfessionExplorationState` 在 C# 原子校验物资与伤势，再扣费和缩短到期；完成工作推进游戏时间。
- `ProfessionCurseTable` 定义血契仪刀首次装备时的真实持久虚弱状态。正常装配与初始装具均触发；独立 Buff 实例与武器实例绑定。识咒第一次揭示来源/解除方式，再次使用消费净咒药剂并登记该武器已净化。现有通用净化仍能清除减益，未新增无法净化的隐藏免疫。
- 循迹只记录可见野生动物的实际位置变化，保留前后格与观测分钟；接近观测点可取得有时效的方向线索。查询界面不推进时间、不记录足迹，不暴露世界上全部动物。
- 礼式决斗只在可用公会附近、地面层合法空地发起，一人对一名配置对手，队友与战宠不参战。沿用当前区域六边形、真实地形和未参与者占位，不挪动原 NPC。先检查全部条件再收取保证金；每城每日一次，胜利退还保证金并发配置奖励，失败或超时支付保证金；普通击杀掉落和升级奖励不参与。
- `ProfessionDuelState` 将本场扣血限制在约定认输线，并让 `CheckWinner` 优先判断单挑结果。伤势保持；结算归还原探索阶段与队形，清除临时对手装备和单挑状态。会话 Reset 清除单挑状态；战斗中不新增存档入口。

## 关键入口

- [ProfessionExploration.lua](../../Lua/Game/Adventure/ProfessionExploration.lua) / [ProfessionDuels.lua](../../Lua/Game/Adventure/ProfessionDuels.lua)：实体查询、事务、日限与结算。
- [诊护数据桥](../../Assets/GameFramework/Runtime/Data/ProfessionExplorationState.cs) / [单挑数据桥](../../Assets/GameFramework/Runtime/Data/ProfessionDuelState.cs)：权威伤势与会话状态。
- [探索配置](../../Config/Tables/Progression/ProfessionExplorationTable.json) / [诅咒配置](../../Config/Tables/Progression/ProfessionCurseTable.json) / [单挑配置](../../Config/Tables/Progression/ProfessionDuelTable.json)。
- [职业探索定向检查](../../Tools/Tests/profession_exploration.lua)：真实 Lua 与隔离状态适配器；原生数据需合批编译后的隔离检查，不自动授权 Editor／Play。
