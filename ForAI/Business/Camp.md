# 营地建设与生产
关键词：Camp、营地、配方合成、装备制作、工作台、医务所、仓库、建设、生产、订单、材料、补给、等待。

## 文档目录
正文：入口与生命周期 / 建设与事务 / 仓储与生产 / 存档与验证；关键入口：数据、规则、配置、UI、检查。

## 正文

- `Adventure.camp` 是 `CampModel`，复用 Adventure 和 Narrative，不注册额外 System。营地只能在 `map` 阶段打开；普通出入区域和返回地图保留设施、物资及订单，显式新开局由 `AdventureData.Reset` 清空。UI 的临时打开状态不入档。
- `AdventureData` partial 内部的 `CampData` 是等级、仓库和订单的唯一权威状态；Lua 只校验配置、产生显示快照和路由操作。`CampData.For/Prepared` 提供反射入口；新增类型由 `Data/link.xml` 保留，不手改生成 Wrapper。
- `CampFacilityTable` 定义工作台、医务所和仓库；`CampUpgradeTable` 定义逐级 0→1→2 的费用。仓库零级即可存放 80 件，升级后 160/320 件。建设立即生效，费用从仓库优先扣除，再由背包补足，全部材料和金币满足后才提交。
- 仓库只保存真实可堆叠的材料、弹药、消耗品、符文与模组，不接收武器、防具或弹匣实例。容量按物品总件数计算。界面中材料/弹药每次最多转移 10 件，药品/组件每次 1 件；存满或背包放不下时原物品保持不变。
- `CampRecipeTable` 定义设施等级、材料、金币、生产分钟数和整组产物。投入只允许堆叠物；产物支持武器、防具和原有堆叠物，不支持弹匣。武器、防具通过现有装备生成入口创建独立实例，沿用品质词缀和初始耐久规则。当前 20 条配方覆盖三口径各三种弹药、铁剑、皮甲、四种工具、火炬、急救包、备战药剂、抗感染药及触媒适配器；物资来自现有搜刮和商店，共用仓库与背包。
- 每个生产设施同时保留一个订单，完成后仍占用设施，直到领取成功。订单按 `NarrativeData.Minutes` 判定完成；营地可显式等待 60/360/1440 游戏分钟，影响世界时钟和商店补货周期。等待本身不治疗角色或自动发放物品。
- 所有动作带 `CampData.Revision` 拒绝重复旧点击。余额、材料、等级、订单、时钟上限与容量在提交前检查；领取先检查整组容量，武器、防具逐实例占格，满包保留整个订单且不发放部分产物。C# 数组参数使用普通 Lua 数组，不能直接传配置只读代理。
- `CampData` 的失败返回稳定语言键，空字符串表示成功；`CampModel` 在业务边界通过 Language 严格转换，未知键直接暴露。配方规则的费用、材料和设施要求同样使用语言模板，名称来自配置 `text` 字段。
- Camp Panel 复用 `NarrativeView`、`NarrativeEntry` 与原生 `LuaReference`，分建设、生产、仓库、等待四页。打开时使用框架暂停租约；关闭、Back 和缓存重开释放并重建临时会话。创建缺失资源的入口为 `NarrativeAssets.CreateCamp`，不覆盖已有编辑过的 Prefab。
- 2026-10-14 接入状态：控制器与规则已写入，`PanelConfig` 尚未注册 Camp，须通过 Unity MCP 执行上述资源同步再进行真实 UI 验收；独立主 HUD 入口已复用现有绑定。实际检查结果见[本轮验收](../../Docs/GameplayExpansionIteration.md)。
- 角色存档 v6 记录设施等级、仓储和订单起止游戏分钟；v1–5 显式迁移为空营地，零级仓库仍可用。C# 验证结构与重复记录，`CampRules:ValidateSaved` 核对当前设施/物品/配方、容量和订单时长；不兼容档案在提交前拒绝。完整保存生命周期见[角色存档](CharacterSave.md)。
- 最小离线检查 `python -B Tools/Tests/camp_core.py` 直接读取真实 JSON 源表，检查规则与 Lua 语法，无需导表。`camp_integration.lua` 使用真实 C# 状态与临时角色档案检查原子交易、91/92 商店购买、生产、区域往返和存档；`camp_ui_integration.lua` 检查实际面板点击与暂停释放。Unity 检查由获授权的现有 Editor 宿主集中执行，UI 宿主需提供 `CampFont`。
- 装备产物事务使用 [camp_crafting_data.ps1](../../Tools/Tests/camp_crafting_data.ps1) 的 `-AssemblyPath` 指向已编译项目 DLL；只创建独立 Data 对象，检查混合产物、满包保留订单、实例占格、品质与初始耐久、重复领取，不启动 Editor、不编译、不读写玩家存档。Lua 规则、源表内容与定向真实 Data 检查已通过；Play 界面尚未验收。

- 营地等待成功推进游戏时间后，立即调用 Narrative.TickBuffs 结算 [长效 Buff](GameEffects.md)，再刷新叙事；窗口暂停只阻止自动时钟，不吞掉显式等待产生的时间。

## 关键入口

- [CampData.cs](../../Assets/GameFramework/Runtime/Data/CampData.cs)：等级、存取、材料消费、生产领取及 CampSave DTO。
- [CampRules.lua](../../Lua/Game/Camp/CampRules.lua) / [CampModel.lua](../../Lua/Game/Camp/CampModel.lua)：配表契约、存档验证、命令与快照。
- [营地源表](../../Config/Tables/Camp/)：3 设施、6 升级、20 生产配方；使用项目配置导出管线。[crafting_ammo_content.py](../../Tools/Tests/crafting_ammo_content.py) 检查源表物品、配方、口径和掉落引用。
- [CampCtr.lua](../../Lua/UI/Panel/CampCtr.lua) / [NarrativeAssets.cs](../../Assets/GameFramework/Editor/NarrativeAssets.cs)：原生面板与缺失资源同步。
- [离线检查](../../Tools/Tests/camp_core.py) / [真实事务与存档](../../Tools/Tests/camp_integration.lua) / [真实 UI 检查](../../Tools/Tests/camp_ui_integration.lua)。
