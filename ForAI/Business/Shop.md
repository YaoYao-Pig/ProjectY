# NPC 商店
关键词：商店、商人、商品模板、随机商品、独立概率、库存、售价、购买、补货、刷新天数。

## 文档目录

正文：配置与入口 / 库存与交易 / 存档与验证；关键入口：规则、状态、UI、测试。

## 正文

- `Game.Shop` 由 Adventure 持有；Lua 负责配表、交互与显示，`AdventureData` 内部的 `ShopData` 持有每位商人的权威库存和临时会话。通过 `ShopData.For/Prepared` 反射入口访问，新增类由 Data/link.xml 保留，无需手改生成 Wrapper。
- `ShopMerchantTable` 绑定商品模板：`npcIds` 指定特殊 NPC，或 `townNpcTemplateIds` 指定普通城镇居民模板，两者只能填写一种。`areaIds` 限定 MapArea 地点类型，空数组表示全部；同一 NPC 的匹配范围不能重叠。特殊 NPC 不自动继承其外观模板的商人身份。
- `ShopTemplateTable.refreshDays` 为补货间隔，从世界第 1 天零点起按游戏天数分段。`ShopEntryTable` 每条配置物品、独立上架百分比、命中后的库存整数范围及每件金币价；同模板不可重复配置同一物品。0% 不出现，100% 必出现，其他商品各自判定，允许整期为空。
- 世界种子、商人绑定、地点、NPC 和补货周期共同决定随机结果；同模板的不同商人独立库存。首次打开生成当前周期商品；到新周期后下次打开整批补货，不叠加旧库存。关闭重开、离开重进和购买失败都不重抽，也不补足已卖出的商品。
- 默认示例为 `MapAreaTownNpcTable #3` 杂货商，安置在商店设施；绑定模板 A，按天售卖随机弹药、材料、武器、防具和弹匣。靠近 NPC 按 E 打开；设施交互通过 `TownResidents.facilityId` 路由到同一商人和距离校验。未绑定商人的设施保留原事件服务。
- 特殊 NPC 保留剧情对话，配置为商人后在对话底部增加“查看商品”；无对白的商人直接进入商店。每次开店和购买都检查探索阶段、当前地点及实际 NPC 距离，不能隔层或远程交易。商店使用现有 UI 模态暂停，禁止开店时保存/读取角色；关闭及 Back 释放暂停和交互。
- 首版只支持玩家用金币购买，点击一件商品购买一件。界面显示单价、剩余库存、占格、余额和下次补货日期；售罄/钱不足/满包禁用按钮，服务端规则仍再次检查。使用会话 Revision 拒绝重复旧点击；所有可预期失败在扣款、入包和库存改变前检查。成功购买进入共享背包并写【获得】记录，弹匣沿物品配置初始化余弹。
- [角色存档](CharacterSave.md) v4 保存库存（包含售罄条目和空列表）及周期，加载时验证商品与模板配置；v1–v3 显式迁移为空商店库存。新远征清除库存。临时商店窗口不入档。
- 改源表后运行 `node Tools/ConfigEditor/exporter.mjs`；商店资源创建入口为 `NarrativeAssets.CreateShop`（`Project Y/商店/同步商店界面`），只创建缺失资源，不重建已编辑 Prefab。Shop Panel 复用 NarrativeView 与 NarrativeEntry，全部通过 LuaReference 绑定。
- 最小离线检查：`python -B Tools/Tests/run_lua.py Tools/Tests/shop_core.lua`。真实 C#、城镇、购买、存档与 UI 检查通过 Unity MCP 执行 `Tools/Tests/shop_editmode.cs`，使用独立 PreviewScene/LuaEnv 和 OS 临时存档，不进入 Play、不触碰玩家存档。宿主输出临时文件路径供清理。

## 关键入口

- [商店源表](../../Config/Tables/Shop/) / [ShopRules](../../Lua/Game/Shop/ShopRules.lua)：绑定、周期与随机上架。
- [ShopModel](../../Lua/Game/Shop/ShopModel.lua) / [ShopData](../../Assets/GameFramework/Runtime/Data/ShopData.cs)：交互、交易、权威库存和存档。
- [ShopCtr](../../Lua/UI/Panel/ShopCtr.lua) / [界面创建](../../Assets/GameFramework/Editor/NarrativeAssets.cs) / [UI 同步](../../Lua/UI/AdventureUIBridge.lua)。
- [离线检查](../../Tools/Tests/shop_core.lua) / [集成检查](../../Tools/Tests/shop_integration.lua) / [Edit Mode 宿主](../../Tools/Tests/shop_editmode.cs)。
