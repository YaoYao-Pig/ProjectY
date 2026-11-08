# 施法点、组合法术与法术区域
关键词：法师、施法点、强化投入、爆裂火球、落石、水流、陨石、迷雾、泥沼、熔星、静心回路。

## 文档目录
正文：资源与消费 / 组合与区域 / 表现与验证；关键入口：规则 / 状态 / 配置。

## 正文

- [自创技能](CustomSkills.md)的法术修饰通过显式资源要求接入同一施法点事务；武器主体仍保留武器属性缩放与装备修正，自创组合不额外投入施法强化点。
- `CombatStats.spellcasting` 与 `Battle.spellcasting` 是同一规则对象；只有 `skillGroup=spell` 且 `catalystKind=arcane` 的技能使用施法点，兼职与装备授予的同类法术遵守同一契约。`SpellcastingState` 将点数、上限、回复、非战斗小数进度保存在角色 C# 状态及 `ActorSave.spellcasting`，旧档首次获得该能力时初始化；Lua 不维护资源镜像。
- 默认上限6、每次本人正式回合开始回复1；非战斗每10游戏分钟回复1。回复加成同时作用于回合量与非战斗速率；战斗时更新时钟但不按分钟回复，避免战后补算战斗时长。倒地不回复，满点不储存超额回复。换装／天赋增加上限不会立即补点，入战、切职和战后清理不回满。
- `SpellcastingBonusTable` 按已学天赋阶数与实际装备、未损坏物品计数。天赋302／303／304提供上限／回复；学者指环、潮汐／熔炉法杖等装备提供额外加成，装备详情显示来源。参数归三张源表，不写进 UI。
- `Battle:SetCastingBoost` 只调整当前角色的 C# 临时选择；`Battle:Skill` 返回 `castingCost/castingBoost/castingBoostLimit/castingRecipe`。消耗在完整预算和目标校验后由 `ProfessionCombat:Commit` 单次提交，拒绝零消耗，合法未命中照常消耗；提交后清除本技能额外投入。探索容器攻击使用同一预算／扣费。额外每点默认提高25%法术伤害，不增加 AP。
- 爆裂火球2301、落石2302、水流2303组合开放陨石2304、迷雾2305、泥沼2306；陨石与群星之火104再开放熔星2307。以当前可用技能集合做固定点展开，包含装备授予来源；不另花学习机会，失去必要来源时不能施放。图鉴显示组合来源与前置，不增加“纯血”身份限制。静心回路2308用2次要AP回复3点，冷却3回合，满点拒绝。
- 区域状态归 `BattleData.SpellFields`，支持地面层、完整角色占地、敌我共同受影响。陨石／熔星先完整准备范围效果再付费，施法者被自身爆炸击倒也不会取消已提交的其他目标结算。火焰和泥沼通行多耗1格距离；火焰进入或回合开始尝试点燃，泥沼施加迟缓，同一角色同一区域每轮只触发一次。
- 地表形态和范围统一读取 `CombatSkillTable.splashShape/splashRadius`，`SpellRecipeTable` 不再重复配置半径；现有四个地表法术保持原半径。初次伤害、持续区域接触／视线／通行、迷雾与火焰的实际交集、落点预览和粒子格子共用 `SkillShape`。C# 状态保存本次半径，形态由技能配置标识读取；快照的 `spellFields.cells` 供表现直接消费。
- 迷雾立即施加潮湿并熄灭与其重叠的整片燃烧区域；穿过或起止于迷雾的超过1格射线不可瞄准，引导法术也不绕过视线。保留相邻识别，双方对称。区域默认存续3轮、同种同中心刷新、战斗结束清空；不写入持久地图工事或战后存档。区域是危险／遮蔽地面，不是硬阻挡建筑。
- `CombatSnapshot` 和状态页投影当前／最大／回复点数；脚下绿色可用、灰色已耗，每弧12点，增加行数时让 Buff 弧外移。战斗栏±调整强化，技能 Tips 显示总消耗与配方；组件与绑定见[主 HUD](MainHud.md)、[战斗 HUD](BattleHUD.md)，持续区域及陨石网格见[特效](VisualEffects.md)。
- 2026-10-27：定向 Lua 规则、UI、职业与图鉴回归通过；集中主动触发1次 Unity 编译后，真实 C# 资源／存档、真实 Lua 战斗入口、21组点数 mesh／原生绑定及分阶段 VFX 检查通过。原生迁移保存了 CanvasRenderer 与 LuaReference，隔离预览确认点数换行和 Buff 间距；未进入 Play、未执行全量测试。配置与改动概览见[本轮说明](../../Docs/ProfessionDepthAndSpellcasting.md)。

## 关键入口

- [Spellcasting.lua](../../Lua/Game/Battle/Spellcasting.lua)：资源规则、配方展开、区域和投影；[SpellcastingState.cs](../../Assets/GameFramework/Runtime/Data/SpellcastingState.cs)：权威状态、时钟、存档与区域生命周期。
- [基础规则](../../Config/Tables/Progression/SpellcastingRuleTable.json) / [法术配方](../../Config/Tables/Progression/SpellRecipeTable.json) / [天赋装备加成](../../Config/Tables/Progression/SpellcastingBonusTable.json)。
- [离线规则检查](../../Tools/Tests/spellcasting_core.lua) / [UI交互检查](../../Tools/Tests/spellcasting_ui.lua)；用 `Tools/Tests/run_lua.py` 分别执行。
- [真实资源检查](../../Tools/Tests/spellcasting_state_editmode.cs) / [真实战斗入口](../../Tools/Tests/spellcasting_integration_editmode.cs) / [原生UI检查](../../Tools/Tests/spellcasting_ui_editmode.cs)：已有空闲 Editor 中经 Unity MCP `execute_code` 执行；不启动 Editor／Play。
- [UI迁移](../../Tools/UI/apply_spellcasting_ui.cs) / [点数预览](../../Tools/Tests/spellcasting_ui_preview.cs) / [特效预览](../../Tools/Tests/skill_visual_depth_preview.cs)：前者保存指定 Prefab，后两者只使用隔离 PreviewScene。
