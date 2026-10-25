# Loading
关键词：Loading、Loding、加载界面、进度条、创建世界、加载世界、读档、建议、骚话、随机文案。

## 文档目录
正文：接口与生命周期 / 创建和加载世界 / 文案与资源 / 验证；关键入口：系统 / 调用方 / 配置。

## 正文

- `LoadingSystem` 依赖 UI 与 Config，提供 `Begin(title,font) → token`、`Report(token,progress,stage)`、`Finish(token)`。同一时刻只有一个操作，token 防止旧操作关闭新界面；进度必须处于 0–1 且不倒退。调用方负责成功、失败及销毁时释放，系统 Shutdown 也会关闭界面。
- `Loading` 是 Common 模块的 Overlay 模态 Panel：阻断下层 UI、禁止 Back 关闭、暂停世界，跨场景保留。界面显示标题、阶段、百分比、进度条和随机提示；仅持有显示状态，业务 Data 仍归原系统。
- 开始菜单创建与选档加载均接入。`CampaignCreation` / `CampaignRestoration` 在 Lua 协程中准备独立世界，共用 `CampaignPreparation` 的状态门禁和推进契约。`MapGenerator.Generate/GenerateSeeded` 的可选 progress 回调允许在区域、地貌融合及生成阶段之间让出执行；同一入口传入回调不改变生成结果与随机序列。开场配方及旧档重建规则见[远征与角色存档](../Business/CharacterSave.md)。
- `AdventureRuntimeDemo` 每个 Update 推进一步，不依赖 timeScale。准备完成后读取渲染快照，并通过 `MapPreviewRenderer.BuildIncremental` 分批创建候选显示资源。候选就绪才提交队伍、世界和存档身份；读档不创建新槽、不重新发放开局物资。显示到 100% 后下一帧关闭。
- 读档的 `CharacterSave.Prepare` / `ExpeditionSave.Prepare` 在独立候选中校验队伍、地图、世界队伍与已探索区域，按地图检查点、队伍、区域让出执行；`CharacterSave.Commit` 才调用恢复事务。原同步 `CharacterSave.Read` 复用同一准备及提交入口。
- 准备或候选渲染失败时释放候选，创建返回新游戏页、读档返回选档页，并显示原因；原会话仍可继续。Data 提交后的异常禁止恢复旧显示；初始保存失败沿用“世界已创建但未保存”的提示和 F5 重试语义。宿主 Disable/Destroy 会释放正在进行的加载。
- 阶段进度表示实际工作检查点，权重不等于时间比例。文件解析、水文、基础设施、单个区域生成、布局冻结、Lua/C# 快照转换、提交后的区域显示和保存仍有同步子步骤；不保证逐帧耗时上限。
- 文案源为 `LoadingTipTable`，可配置启用、标签、正文和每条停留秒数。使用独立随机流，按未缩放时间轮换，相邻不重复；只有一条时重复该条，至少需一条启用文案。结束不等待文案时长。正文纯文本，不解析富文本。
- `Project Y/UI/创建 Loading 界面` 只创建缺失资源并导出绑定提示；已有 Prefab 保留手工布局。组件通过 LuaReference 显式绑定，沿用 1280×720 UIRoot 适配。
- 最小验证：`python Tools/Tests/run_lua.py Tools/Tests/loading.lua` 验证所有权、进度、轮换、准备失败；`python Tools/Tests/run_lua.py Tools/Tests/loading_map.lua` 使用真实配置比较 2,500 格地图同步/分帧的完整显示快照。原生检查见下方入口；命令不代表授权进入 Play。

## 关键入口

- [LoadingSystem.lua](../../Lua/UI/LoadingSystem.lua) / [LoadingBridge.lua](../../Lua/UI/LoadingBridge.lua) / [LoadingCtr.lua](../../Lua/UI/Panel/LoadingCtr.lua)：通用显示接口及控制器。
- [LoadingTipTable.json](../../Config/Tables/Adventure/LoadingTipTable.json)：文案源，修改后使用标准配置导出器。
- [CampaignCreation.lua](../../Lua/Game/Adventure/CampaignCreation.lua) / [CampaignLoadingBridge.lua](../../Lua/Game/Adventure/CampaignLoadingBridge.lua)：候选世界准备、提交与跨帧调用。
- [CampaignRestoration.lua](../../Lua/Game/Adventure/CampaignRestoration.lua) / [CampaignPreparation.lua](../../Lua/Game/Adventure/CampaignPreparation.lua)：读档候选与共用推进契约；[campaign_restoration.lua](../../Tools/Tests/campaign_restoration.lua) 验证失败、取消、token、提交和同步兼容。
- [CampaignLoading.cs](../../Assets/GameFramework/Samples/Adventure/CampaignLoading.cs) / [MapPreviewRenderer.cs](../../Assets/GameFramework/Samples/Map/MapPreviewRenderer.cs)：Update 驱动、候选资源所有权、渲染分批。
- [LoadingAssets.cs](../../Assets/GameFramework/Editor/LoadingAssets.cs)：Prefab 与 PanelConfig 创建入口。
- [loading_editmode.cs](../../Tools/Tests/loading_editmode.cs) / [loading_integration.lua](../../Tools/Tests/loading_integration.lua)：MCP execute_code 运行的定向 Edit Mode 检查，使用隔离 PreviewScene、真实 2,500 格候选地图/渲染与临时独立存档，覆盖具名创建、跨槽读档、局部区域恢复及名称保留，不进入 Play，不写玩家存档。
