# 营地、关系、战利品与入口整理

更新：2026-10-14。承接[基础玩法迭代](GameplayFoundationIteration.md)和[差距清单](GameplayGapAudit.md)。本轮源码与数据层检查已经完成，原生资源同步及 Unity 端到端验收尚未完成；不能将此记录视为整批可玩验收通过。

## 接入内容

| 模块 | 本轮行为 | 当前边界 |
| --- | --- | --- |
| 技能图鉴异常 | `SkillAtlasTable.glyphCode` 独立于伤害熟练度；43 个技能都有显式图标，加载时检查代码有效性 | 准备技能、道具不再把空熟练度传给 `SetGlyph`；19 个已保存图标覆盖全部所需代码，无需新图标资源 |
| 营地入口 | 大地图原独立导航按钮改为“营地”；新建远征移入菜单，角色学习入口标为“角色养成” | 复用现有 `Restart/RestartText` 绑定；营地窗口本身仍待保存注册 |
| 学习界面 | “职业技能”和“被动天赋”分开展示；先选课程看详情，再点学习；图鉴定位入口角色职业，关闭返回原页 | 复用既有滚动框、按钮、文本和 viewport；控制器回归通过，实际排版待验收 |
| 营地 | 工作台、医务所、仓库逐级建设；4 个配方、定时生产、等待、堆叠物资存取 | 材料先用仓库，满包不丢产物；不包含完整出征失败损失、动态市场或武器防具锻造 |
| 关系与经历 | 正式战斗危急救援、共同胜利、关系阶段、移除傲慢／孤僻、有日期和双方的纪事 | 自疗、周期治疗、部署治疗不计救援；同场角色对去重；三次救援获得“守望者”，尚非实体勋章／玩家授勋 |
| 战利品 | 真实武器缴械、落地、双方拾取；敌人持真实装备；精准攻击保甲，伤害类型影响磨损 | 掉落保留实例状态；敌人可用拾到枪上的弹药，不能拿玩家背包备用弹匣 |
| 耐久维修 | 低于当前耐久上限的一半时永久减少初始上限5%，维修恢复至降低后的上限 | 最低上限20%；维修后重新启用阈值；金币／铁件不足不扣资源；维修按钮已通过现有 Unity 菜单保存绑定（2026-10-14 后续修复） |
| v6 存档 | 增加装备耐久、营地订单与仓储、关系／荣誉和完整纪事；过滤不属队伍的敌装与其弹匣 | v1–5 显式迁移新增数据；恢复所有状态后才发通知；本轮真实磁盘读写与旧档迁移仍待 Unity 验收 |

当前模块契约：[营地](../ForAI/Business/Camp.md)、[队员关系](../ForAI/Business/PartyStory.md)、[装备](../ForAI/Business/Equipment.md)、[角色存档](../ForAI/Business/CharacterSave.md)、[成长 UI](../ForAI/Business/Progression.md)。

## 已执行检查

- 配置导出：145 表、1644 行；本轮图标修改只改写 SkillAtlas 的 Lua schema 与二进制。
- `skill_atlas_core.lua`：完整目录与前置、未知图标拒绝、所有43个配置节点经过真实 Widget `SetData` 的图标选择逻辑；缺省熟练度的4种准备技能和2种道具专门覆盖。UI 组件以测试替身提供，此项不代表 Unity 绘制通过。
- `growth_navigation_core.lua`：6项控制器检查；真实导出配置，模拟视图。覆盖选中无消费、显式学习、条件不足、跨职业已学技能、资源路由与图鉴返回。
- `camp_core.py`、`social_source_check.py`（7项）、`equipment_salvage_core.py` 全部通过。
- `equipment_catalyst_core.lua` 7组和 `equipment_workbench_preview.lua` 28种组合通过；旧夹具已适配真实敌装与显式耐久边界。
- 使用现有 Unity 工程的源码清单和引用，离线编译运行时230文件及编辑器60文件，均0错误。输出留在独立临时目录，没有触发 Editor 编译、刷新或 Reload；报告见 [编译记录](Previews/GameplayFoundation/source-compile-20261014.json)。编译器另输出25／117条警告，不将“0错误”写成“无警告”。
- [真实托管数据检查](../Tools/Tests/gameplay_data_acceptance.ps1)直接加载本次编译程序集，不使用 Data 替身，不调用 Unity 原生方法：5组通过，覆盖营地失败原子性／旧点击、满包与重复领取、耐久阈值／维修、关系救援／结算去重，以及双方缴械后交叉拾取同一实例（符文、弹匣、余弹和耐久完整保留）。逐项结果与程序集哈希见 [Data 证据](Previews/GameplayFoundation/managed-data-acceptance.json)。

## 尚未完成的验收

首次验收时未提供 Unity MCP，LuaConsole 也未开启；当时发现 `PanelConfig.asset` 尚无 Camp，Inventory Prefab 尚无 `Repair/RepairText`。后续针对背包报错，已通过现有 Unity 的“同步耐久维修按钮”菜单保存两个绑定，核实组件类型与字体初始化列表，并让常规背包同步包含此步骤；未进入 Play，Camp 及完整流程仍按下列范围另行验收。

恢复 Unity MCP 后，在现有 Editor 中依次完成：

1. 确认编辑状态及编译结果；核实 xLua 桥接与新数据接口。不得在用户运行中的场景里直接迁移 Prefab。
2. 通过既有 `NarrativeAssets.CreateCamp()` 保存 Camp 配置／Prefab；维修按钮及 LuaReference 的 `EquipmentRepairAssets.Sync()` 已在后续修复中执行并保存。
3. 执行真实 `camp_integration.lua`、`social_integration.lua`、`equipment_salvage_integration.lua`、`gameplay_v6_save_integration.lua`，使用隔离存档，不碰玩家档案。
4. 验收 Camp、Inventory、CharacterGrowth、SkillAtlas 和 MainHud 实际窗口：独立入口、滚动排版、返回及暂停释放；更新过的 UI fixtures 是待运行入口。
5. 完成一条真实 Play 链路：营地备战 → 遭遇部署 → 缴械／拾取／救援 → 战后搜刮 → 营地生产／维修 → 保存读取，再处理实际画面与行为缺陷。

此限制遵循[项目开发 Skill](../.agents/skills/lua-code-style/SKILL.md)的“缺绑定时使用 Unity MCP 完成绑定、保存 prefab”，没有用运行时搜索或手改 Prefab YAML 代替。

## 下一批大项

本轮并未补齐所有设计笔记。仍需优先完成出征压力／撤离与失败损失、尸体和死亡后果、服役与退休传承、实体授勋。动态市场、天气星象、传言、多回合施法和完整职业内容继续保留在[差距清单](GameplayGapAudit.md)，不因本轮存在相邻基础而标成完成。
