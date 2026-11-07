# 营地建设与生产
关键词：Camp、后备、编组、换人、休养、队伍装备、营地装备、坐骑槽、宠物槽、火把槽、3D营地、Additive、固定机位、建筑入口、配方合成、装备制作、双网格仓库、建设、生产、订单、材料、补给、等待。

## 文档目录
正文：入口与生命周期 / 建设与事务 / 仓储与生产 / 存档与验证；关键入口：数据、规则、配置、UI、检查。

## 正文

- “队伍编组”只在营地开放，出战保留 1–4 人、后备最多 6 人；允许单人转入/转出和满编时原子交换。`AdventureData.party` 与原 `PartyCount/GetPartyAt` 仍只表示出战；`PartyRoster.Count/At/Find` 表示全部成员。后备保留原角色、装备、经历与经济账户，主角免薪身份不随出战顺序改变。招募优先补出战，满4人后转后备，两边都满才拒绝；后备不部署进区域或战斗。
- 后备按 `CampRosterTable` 和实际游戏分钟休养：每游戏日恢复可恢复血量上限的25%、每个非永久伤残部位减少20点创伤，剧情伤势倒计时按2倍速度推进。零碎时间累计保存在C#状态；永久伤残不修复、疾病沿原规则处理，已死亡成员不复活。换人前先结算时钟，读档和同分钟刷新不重复恢复；食物、工资规则见[经济](Economy.md)。
- 编组保存于角色/远征 v43/44 的 `roster`，`actors` 包含出战在前、后备在后的所有成员；记录出战数、主角ID、休养时间和小数进度。旧档全部成员保持出战、后备为空，从存档当前分钟开始；准备阶段拒绝零出战、超过4出战/6后备、重复/陌生角色和非法休养进度。

- 营地主界面“队伍装备”进入坐骑、宠物、火把三个独立槽。`CampLoadoutData` 保存动物主人/实例引用与一支火炬实物；已驯服动物仍由原队员持有，生命、亲密度、骑乘/独立随行模式不复制或切换。同一动物不能占两个队伍槽；坐骑要求物种 `rideable`，动物死亡或离队失去归属后清除对应槽。
- `CampLoadoutTable` 配队伍收益：首版坐骑使陆路实际行军速度 ×1.25，宠物使大地图可见半径 +2，队伍火把在 18:00–次日06:00 提供真实跟随点光。坐骑不加快世界时钟、不改变水路或跟随护送商队的速度；宠物卸下后保留已探索记忆。火把沿用 TorchTable 的光色/强度/9米范围，无燃料消耗，不揭开迷雾，T 开关沿用已有叙事状态。
- 火把装备事务优先从仓库移出一支，再取背包；槽中实物不计入仓库/背包，不能被重复消费。卸下先检查背包整笔容量，满包保持槽位与库存不变。局部地图允许背包或队伍槽里的火炬提供原有照明；只有装入槽位才提供大地图夜间照明。操作沿用营地开放状态和 Revision 校验。
- 角色/远征 v33/v34 保存 `camp.loadout`；旧版本缺字段迁移为三个空槽，不自动占用动物或火炬。准备阶段拒绝重复动物、失效归属与未知火炬配置，提交仍使用原动物实例重连流程。界面入口和动物预览引用通过原生 `install_loadout.cs` 保存，完整营地生成器也保留此入口。

- 营地“锻造”页复用同一界面、仓库与成本事务，对原武器执行锻造/重铸及事迹进阶；与创建新装备的生产订单独立。首版范围、器灵和保存见[装备锻造与随身器灵](EquipmentForging.md)。

- `Adventure.camp` 是 `CampModel`，复用 Adventure 和 Narrative，不注册额外 System。营地只能在 `map` 阶段打开；普通出入区域和返回地图保留设施、物资及订单，显式新开局由 `AdventureData.Reset` 清空。UI 的临时打开状态不入档。
- `AdventureData` partial 内部的 `CampData` 是等级、仓库和订单的唯一权威状态；Lua 只校验配置、产生显示快照和路由操作。`CampData.For/Prepared` 提供反射入口；新增类型由 `Data/link.xml` 保留，不手改生成 Wrapper。
- `CampFacilityTable` 定义工作台、医务所和仓库；`CampUpgradeTable` 定义逐级 0→1→2 的费用。仓库零级即可存放 80 件，升级后 160/320 件。建设立即生效，费用从仓库优先扣除，再由背包补足，全部材料和金币满足后才提交。
- 仓库接受背包中的武器、防具、独立弹匣，以及材料、弹药、消耗品、符文与模组。12×10 独立网格保留 80/160/320 件容量，每件装备计1件；枪内弹匣随枪存取，不另占格。堆叠物整堆双向拖拽，空格建立独立堆，指针落到同类堆才合并；装备始终按独立实例占格。支持 R 旋转与右键取消，非法落点/满包/容量不足不改变任何一侧。
- 装备本体仍由 `EquipmentData` 唯一保存，仓库只记录原 `w/g/m + 实例ID` 的位置引用；不会重发、重抽或复制物品。`CampEquipmentKeys` 区分仓库存放，背包 Grid 不保留这些位置；耐久、词缀、配件、装填弹匣及 `legacy` 保持原实例。随身查询继续用 `IsCarriedWeapon/IsCarriedMagazine`，不能用实例总数代表背包数量；取回前不能远程穿戴或改装。
- `CampRecipeTable` 定义设施等级、材料、金币、生产分钟数和整组产物。投入只允许堆叠物；产物支持武器、防具和原有堆叠物，不支持弹匣。武器、防具通过现有装备生成入口创建独立实例，沿用品质词缀和初始耐久规则。当前 20 条配方覆盖三口径各三种弹药、铁剑、皮甲、四种工具、火炬、急救包、备战药剂、抗感染药及触媒适配器；物资来自现有搜刮和商店，共用仓库与背包。
- 每个生产设施同时保留一个订单，完成后仍占用设施，直到领取成功。订单按 `NarrativeData.Minutes` 判定完成；营地可显式等待 60/360/1440 游戏分钟，影响世界时钟和商店补货周期。等待不直接恢复全队血量或自动发放物品；推进时钟会触发后备休养。
- 所有动作带 `CampData.Revision` 拒绝重复旧点击。余额、材料、等级、订单、时钟上限与容量在提交前检查；领取先检查整组容量，武器、防具逐实例占格，满包保留整个订单且不发放部分产物。C# 数组参数使用普通 Lua 数组，不能直接传配置只读代理。
- `CampData` 的失败返回稳定语言键，空字符串表示成功；`CampModel` 在业务边界通过 Language 严格转换，未知键直接暴露。配方规则的费用、材料和设施要求同样使用语言模板，名称来自配置 `text` 字段。
- Camp Panel 已注册并改为建筑入口、制作/锻造详情和仓储叠层；`CampPresentation` 产生结构化显示快照，旧 `CampModel.Snapshot.rows` 留给兼容消费者。制作页左侧滚动配方、右侧真实模型/材料、底部订单与等待；锻造按原装备实例展示配件、事迹和成长操作，仍是即时事务。
- 独立 `CampPresentation.unity` 通过 Additive 加载，不替换 Adventure 主场景。`CampSceneView` 持有固定相机、透明 RT、主世界截图的分离模糊、建筑射线和只读队员副本；营地用层30，物品预览沿用层31。关闭/缓存重开清理相机目标、RT、展示角色与加载会话，世界状态仍归原模型。主场景输入由既有模态/暂停租约阻挡。
- `CampStage` 显式绑定四个建筑入口、三档模型与队员锚点；熔炉入口复用工作台等级，没有新增第四种设施。模型/场景/界面由 `CampAssets.Sync` 原生生成，再运行 `polish_scene.cs`、`polish_ui.cs`。建筑按钮底图使用 `CampFacilityTagGraphic` 原生矢量图形：切角、铜边、缝线、铆钉、底部指向及悬停/按下状态；仅更新标签可运行 `apply_tags.cs`。运行界面引用均保存到 LuaReference，不通过 Lua 层级搜索获取组件。
- Camp 的 `CloseOnBack=false`，Esc 由 `CampPanelView` 先取消拖拽、再经控制器返回营地/关闭；其他窗口的 Back 契约不变。缓存重开会重建 SceneView 会话；框架暂停租约只由这个 Panel 持有。
- 角色/远征 v31/v32 使用仓库 `gridVersion=2`，增加装备实例引用；v29/v30 的网格位置继续保留，早于v29的数量仓储仍确定性安置。`PrepareWarehouseSave` 联合校验背包与仓库：引用必须指向真实闲置装备、与 ItemId 匹配、不能同时出现在背包/穿戴/其他仓库格；装填弹匣不能独立再入库。结构、ID、网格和容量失败都在提交前拒绝。完整生命周期见[角色存档](CharacterSave.md)。
- 最小离线检查 `python -B Tools/Tests/camp_core.py`；[仓储数据检查](../../Tools/Tests/camp_warehouse_data.ps1) 使用已编译 DLL，覆盖独立堆、合并、旋转、非法落点、版本、容量及迁移。原生 UI 检查通过 [render_preview.cs](../../Tools/CampRework/render_preview.cs) 在现有闲置 Editor 执行真实控制器、Prefab、拖拽、暂停与临时存档；不进入 Play，不读取玩家档案。调用与美术顺序见[工具说明](../../Tools/CampRework/README.md)。
- 装备产物事务使用 [camp_crafting_data.ps1](../../Tools/Tests/camp_crafting_data.ps1) 的 `-AssemblyPath` 指向已编译项目 DLL；只创建独立 Data 对象，检查混合产物、满包保留订单、实例占格、品质与初始耐久、重复领取，不启动 Editor、不编译、不读写玩家存档。Lua 规则、源表内容与定向真实 Data 检查已通过；Play 界面尚未验收。

- 营地等待成功推进游戏时间后，立即调用 Narrative.TickBuffs，统一结算[市场、投资和午夜食物/工资](Economy.md)，再结算 [长效 Buff](GameEffects.md)，再刷新叙事；窗口暂停只阻止自动时钟，不吞掉显式等待产生的时间。

## 关键入口

- [编组与休养权威状态](../../Assets/GameFramework/Runtime/Data/PartyRoster.cs) / [营地编组模型](../../Lua/Game/Camp/CampRoster.lua) / [休养配置](../../Config/Tables/Camp/CampRosterTable.json)。[原生入口安装](../../Tools/CampRework/install_roster.cs)保存按钮与语言绑定，完整 `CampPanelAssets` 同样保留入口。
- [原生编组/UI/经济/存档检查](../../Tools/CampRework/roster_preview.lua)使用 `render_preview.cs`，设 `previewScript` 为此脚本、`captureVariant="roster"`；[边界与旧档/小数进度检查](../../Tools/Tests/party_roster_data.cs)和[真实招募检查](../../Tools/Tests/party_roster_recruit.lua)定向执行。2026-10-31已通过，使用独立Data、PreviewScene和OS临时存档，未进入Play。预览在[编组面板](../../Art/CampPresentation/Previews/roster/roster-members.png)。

- [队伍装备状态与事务](../../Assets/GameFramework/Runtime/Data/CampLoadoutData.cs) / [规则和显示](../../Lua/Game/Camp/CampLoadout.lua) / [收益配置](../../Config/Tables/Camp/CampLoadoutTable.json)。
- [队伍装备资源安装](../../Tools/CampRework/install_loadout.cs) / [原生界面检查](../../Tools/CampRework/loadout_preview.lua) / [独立数据检查](../../Tools/Tests/camp_loadout_data.ps1)。数据检查使用已编译 DLL；原生预览复用 render_preview.cs 并选择 loadout_preview.lua，不进入 Play、不访问玩家存档。

- [CampData.cs](../../Assets/GameFramework/Runtime/Data/CampData.cs)：等级、存取、材料消费、生产领取及 CampSave DTO。
- [CampWarehouseData.cs](../../Assets/GameFramework/Runtime/Data/CampWarehouseData.cs)：网格、稳定堆与原子存取；`CampWarehouseBridge` 通过反射桥接新接口，避免修改旧生成 Wrapper。
- [装备仓储检查](../../Tools/Tests/camp_equipment_storage.ps1)：武器、防具、弹匣、实例身份、耐久、配件、成长/器灵、保存/提交和重复归属拒绝；使用已编译 DLL，不编译、不访问玩家存档。
- [CampRules.lua](../../Lua/Game/Camp/CampRules.lua) / [CampModel.lua](../../Lua/Game/Camp/CampModel.lua)：配表契约、存档验证、命令与快照。
- [营地源表](../../Config/Tables/Camp/)：3 设施、6 升级、20 生产配方；使用项目配置导出管线。[crafting_ammo_content.py](../../Tools/Tests/crafting_ammo_content.py) 检查源表物品、配方、口径和掉落引用。
- [CampCtr.lua](../../Lua/UI/Panel/CampCtr.lua) / [CampPresentation.lua](../../Lua/Game/Camp/CampPresentation.lua)：交互与显示快照；[CampAssets.cs](../../Assets/GameFramework/Editor/CampAssets.cs) / [CampPanelAssets.cs](../../Assets/GameFramework/Editor/CampPanelAssets.cs)：原生资源同步。
- [CampSceneView.cs](../../Assets/GameFramework/Runtime/UI/CampSceneView.cs) / [CampPanelView.cs](../../Assets/GameFramework/Runtime/UI/CampPanelView.cs)：场景与 UI 表现；[交付与预览](../../Docs/CampSceneUIImplementation.md)。
- [离线检查](../../Tools/Tests/camp_core.py) / [真实事务与存档](../../Tools/Tests/camp_integration.lua) / [真实 UI 检查](../../Tools/Tests/camp_ui_integration.lua)。
