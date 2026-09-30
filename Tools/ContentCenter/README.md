# Project Y 内容编辑中心

入口为 <http://127.0.0.1:4181>。工程根执行 `node Tools/WebServices/manage.mjs start content-center`；Unity 的 `Project Y/Web 服务/服务管理` 也会自动列出。Node.js 20+，无需 npm 安装。编辑表和 MCP 可独立运行；真实模型、图标和持握采样需要当前工程已在 Unity Edit Mode 打开并完成编译。服务不会启动 Unity 或进入 Play。

## 编辑与保存

左侧按物品、人物、任务、技能特质和投放分组。引用字段按名称或 ID 选择，`↗` 进入关联记录；数组逐项编辑并保留顺序。关联规则在同一内容页的折叠表单里，例如武器规则、属性要求、几何握点。

修改先进入浏览器草稿，按工程身份保存本机恢复副本；可下载/导入 patch。“检查草稿”展示关联表修改；“保存并导出”依次执行：

1. 全批类型、引用、叙事及内容语义校验。
2. 按 workspace revision 保存 `Config/Tables/**/*.json`。
3. 使用原有导表器生成 Lua schema 与 Unity 二进制。
4. 请求已打开的 Unity 同步物品 Prefab、模型图标、资源目录和持握网页资源。

页面区分源表保存、配置导出、Unity 资源完成。后续失败不会谎报全部成功，也不偷偷回退已经保存的源表；修复后再次导出或“同步 Unity 资源”。游戏配置有缓存，**重新加载游戏配置后生效**，不热改正在进行的游戏或存档。

409 保留草稿。“重读 / 合并”自动合并非重叠的外部修改；同一行冲突展示原值、源表值和草稿，可下载 patch 后对照最新 revision 合并并导入。内容中心与 Narrative 共用写锁；通用表编辑器和外部程序不受该锁控制。单文件原子替换、异常时尽量回滚并保护外部修改，多文件与生成产物不保证断电原子事务。不要并发编辑同一批表。

## 从模型新建物品

1. 物品页“新建”，首先搜索选择 `Assets/` 内已有 FBX、OBJ、Prefab 等 Unity 能导入的资源；右侧展示实际 Unity 网格，可旋转/缩放。
2. 选择现有物品作为规则原型，填写名称。物品/资源/子类型记录一起生成草稿；武器握点、属性要求和改装挂点独立复制。
3. 调整技能、属性要求、伤害倍率、背包占格、图标角度等。不会连带修改规则原型。
4. “关联与投放”选择掉落池、已有商店/事件选项、任务完成奖励或初始背包；新增内容不自动塞进其他来源。
5. 保存并导出后，Unity 创建 `Assets/DynamicAsset/ContentCenter/Prefabs/Asset_<id>.prefab`，从模型渲染 `Icons/Item_<id>.png`，更新 EquipmentAssetCatalog。原始模型作为资源来源。
6. “模型与持握”打开角色工坊，复用真实模组、双手求解和武器朝向编辑。**嵌入工坊的握点进入内容中心草稿**；独立 4177 工坊保持原有自动保存。新武器首次持握预览需等 Unity 同步完成。

贴身防具（头、胸、腿、脚、背）还需要现有角色管线中的 GearFit 体型适配。已适配模型复用其源路径；全新未适配的衣甲会明确拒绝保存，不能仅有任意 3D 模型就保证穿戴贴合。普通刚体物品与武器走上述模型流程。

预览使用实际 Unity Mesh、局部变换和纯色材质；Web 光照与 Unity 图标渲染不同，不承诺像素一致。不用占位模型代替缺失资源。新鲜度检查模型、Prefab、材质与 `.meta`；Unity 的虚拟 Packages 路径按锁定版本解析到 PackageCache，不把包依赖误判为缺失。导出依赖摘要前保存材质导入升级结果。

## 特殊 NPC 与可招募角色

向导选择原型、城镇、设施和是否可招募，创建独立 CombatUnit、GrowthProfile、PawnTemplate、城镇外观、安置、全天日程和 CharacterLoadout 记录。随后编辑：

- 初始技能和属性归 CombatUnit；初始特质、天赋、潜力归 GrowthProfile。
- `CharacterLoadoutTable` 按 unitId 唯一定义主手、副手、防具和固定外观。角色工坊“应用到角色草稿”回填外观；留空沿用随机外观池。
- 任务线、对话、招募动作与条件、阵营、关系及日程。可招募标记不等于无条件入队，仍需实际任务/对话的 `recruit_npc` 动作。

初始装备在新开局或首次招募时创建真实库存实例并装备，读档不重发。招募预检合并初始装备与同批奖励，背包不足保持待领取；双手武器/副手冲突和重复防具槽位拒绝保存。固定外观用于特殊 NPC 以及招募后的角色。现有任务手记、NPC 交互、奖励和掉落系统读取同一套表。

## CLI 与 MCP

CLI 无需 Web，第三参数为 UTF-8 JSON **参数文件**，避免 shell 转义：

```powershell
node Tools/ContentCenter/cli.mjs schema
node Tools/ContentCenter/cli.mjs validate
node Tools/ContentCenter/cli.mjs review path/to/arguments.json
node Tools/ContentCenter/cli.mjs save path/to/arguments.json
```

save 参数格式（ID/内容只是格式示例，不自动写入）：

```json
{
  "patch": {
    "revision": "从 schema/get/list 读取的最新 revision",
    "operations": [{"op":"upsert","table":"CombatTraitTable","row":{"id":900,"name":"示例","description":"力量增加","attribute":"strength","amount":1}}]
  },
  "exportConfig": true
}
```

upsert 是完整行；delete 使用 `{op:"delete",table,id}`。同一实体一批只能一个操作；关联新增/删除一起提交。create_item/create_npc 返回多表草稿，**不写盘**。

MCP 为标准 JSON-RPC/stdio，客户端配置示例（修改为实际绝对路径）：

```json
{
  "mcpServers": {
    "project-y-content": {
      "command": "node",
      "args": ["D:/Program/Unity/Project Y/Tools/ContentCenter/mcp.mjs"]
    }
  }
}
```

工具：`content_schema/list/get/validate/impact/assets/create_item/create_npc/review/save/export/asset_job/job`。list 支持 query/offset/limit（最多 500）。推荐 schema→get→impact→review→save；save 默认只写源表，exportConfig=true 才导出。检查 sourceSaved、exported、assetError 和 job 结果，不把“已入队”当完成。不会自动修改用户的 MCP 客户端配置。

协议依据 [MCP stdio](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) 和 [tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)，stdout 只写协议消息。

HTTP：GET `/api/workspace`、`/api/assets`、`/api/preview?path=...`、`/api/impact?key=Table:id`、`/api/job?id=...`；POST `/api/review`、`/api/save`、`/api/export`、`/api/preview`、`/api/sync`。写入需要同源、JSON 和 workspace 返回的 `X-Content-Token`。服务只绑定 loopback；`/character/` 同服务内挂载角色工坊，无需另外启动 4177。

## 新机制接入

1. 定义源表字段、中文 description、类型、Catalog 枚举和 ref。新表自动进入“全部表与扩展”，Web/CLI/MCP 无需新增 CRUD。
2. [modules.mjs](modules.mjs) 登记常用分组和短名称；表单从 schema 读字段，不复制字段全集。
3. 动态引用需要补充关系图与前端目标映射。跨字段约束放 [rules.mjs](rules.mjs)，由原有 exporter 一起调用，保持各入口一致。
4. 多表创建逻辑放 [authoring.mjs](authoring.mjs)，返回 `{operations,selection}`，UI 和 Agent 复用。实际系统要读取新字段，单独增加表不会自动产生玩法。
5. 资源生成归 [ContentCenterBridge.cs](../../Assets/GameFramework/Editor/ContentCenterBridge.cs)，只处理 preview/sync 白名单作业，不执行网页传来的任意代码。只在当前 Edit Mode 执行，检查源表摘要；两分钟未开始的任务过期，失败不自动重试。
6. 增加定向测试，同步所属 ForAI 和 INDEX。复杂专用控件只用于 schema 无法表达的编辑流程。

临时预览、心跳和作业在被 Git 忽略的 `.cache/`；工程模型和源表为权威数据。

图标 PNG 与角色预览 JSON 使用临时文件原子替换，避免覆盖 Unity 已映射的 PNG 或让浏览器读到未写完的包；物品 Sprite 的 `.meta`/GUID 保留。

## 最小检查

```powershell
node --test Tools/ContentCenter/tests/content.test.mjs Tools/Narrative/tests/narrative.test.mjs
python Tools/Tests/run_lua.py Tools/Tests/content_loadout.lua
```

Node 使用临时配置副本；原生 xLua 检查初始装备、手槽约束与招募预检。浏览器另查新建、引用、模型和持握回填。此文档不授权全量测试、Play、启动新 Editor 或反复编译。
