# 内容编辑中心
关键词：一站式、Web、表编辑、可视化配表、武器、物品、特殊角色、NPC、MCP、模型选择、初始装备、4181。

## 文档目录
正文：入口与工作流 / 契约与接入 / 验证；关键入口：服务 / UI / Agent / Unity。

## 正文

- `node Tools/WebServices/manage.mjs start content-center`，默认 `http://127.0.0.1:4181`；注册到[统一 Web 管理](WebServices.md)。同服务的 `/character/` 复用[角色工坊](CharacterPreview.md)，无需启动 4177。
- 按物品、人物、任务、技能特质和投放分组，表单读取真实 schema；引用按名称选取、跳转，数组逐项编辑。“全部表与扩展”自动纳入新表，模块元数据仅负责分组和名称。
- 新物品先选工程模型、再选规则原型；生成物品/资源/子类型草稿，武器独立复制握点、属性要求、挂点。Unity 生成专用 Prefab、模型图标、EquipmentAssetCatalog 和新增武器持握采样。
- NPC 向导生成独立角色/成长/外观、安置与全天日程。CharacterLoadoutTable 按 unitId 唯一定义初始主副手、防具与固定外观；新开局和首次招募应用，读档不重发。技能归 CombatUnit、特质归 GrowthProfile；运行规则见[叙事业务](../Business/Narrative.md)。
- 投放显式选择掉落池、已有商店/事件选项、任务奖励或初始背包，不默认投放；任务关联和可招募标记本身不执行招募。
- 草稿按工程身份本机缓存，可下载/导入。保存并导出区分源表、二进制、Unity 资源三个结果。409 保留草稿；重读可合并非重叠变更。游戏配置无热重载，重新加载生效。
- Web/CLI/MCP 共用 workspace、authoring 和 exporter 校验。Patch 为 revision + operations（完整行 upsert / id delete），写锁与 Narrative 共用，外部编辑器不受锁控制；多文件保存/导出非断电原子事务。
- MCP 为 stdio：`node Tools/ContentCenter/mcp.mjs`。create_item/create_npc 只返回草稿，save 默认只写源表，exportConfig=true 才导出。配置、完整工具和扩展步骤见[使用说明](../../Tools/ContentCenter/README.md)。
- Unity 桥接只处理显式 preview/sync 队列，检查 Edit Mode 和源表摘要；不启动 Editor/Play，不执行任意代码。模型缓存校对真实依赖，Packages 虚拟路径解析到锁定版本缓存。已有武器同步挂点绑定，导出摘要前保存材质导入升级；失败或超时明确报告，不自动重试。
- 最小检查：`node --test Tools/ContentCenter/tests/content.test.mjs Tools/Narrative/tests/narrative.test.mjs`；`python Tools/Tests/run_lua.py Tools/Tests/content_loadout.lua`。浏览器另查新建、引用、预览；Editor 操作遵循项目 Skill。

## 关键入口

- [workspace.mjs](../../Tools/ContentCenter/workspace.mjs) / [authoring.mjs](../../Tools/ContentCenter/authoring.mjs) / [rules.mjs](../../Tools/ContentCenter/rules.mjs)：统一批次。
- [server.mjs](../../Tools/ContentCenter/server.mjs) / [app.mjs](../../Tools/ContentCenter/public/app.mjs) / [modules.mjs](../../Tools/ContentCenter/modules.mjs)：服务、表单、扩展分组。
- [mcp.mjs](../../Tools/ContentCenter/mcp.mjs) / [cli.mjs](../../Tools/ContentCenter/cli.mjs)：Agent 工具。
- [assets.mjs](../../Tools/ContentCenter/assets.mjs) / [ContentCenterBridge.cs](../../Assets/GameFramework/Editor/ContentCenterBridge.cs)：真实 Unity 导出。
- [InitialLoadout.lua](../../Lua/Game/Equipment/InitialLoadout.lua) / [CharacterLoadoutTable.json](../../Config/Tables/Adventure/CharacterLoadoutTable.json)：初始装备和固定外观。
