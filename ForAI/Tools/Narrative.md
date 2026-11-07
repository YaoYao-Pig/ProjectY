# 叙事工坊与 Agent 工具
关键词：Mission 编辑器、Web、叙事关系图、任务编辑、NPC、对话编辑、Agent、CLI、批量修改、影响分析、4179。

## 文档目录
正文：运行 / 编辑与校验 / Agent 使用 / 验证；关键入口：服务 / 规则 / 页面 / 技能。

## 正文

- `SpecialEventTable` 已纳入叙事批量工具，连接事件选择、专属区域、盟军槽位与招募身份；语义和生命周期见 [特殊事件](../Business/SpecialEvents.md)。

- 使用现有 Web 服务管理器：`node Tools/WebServices/manage.mjs start narrative`，访问 `http://127.0.0.1:4179`。Unity Web 服务管理窗口自动列出“叙事工坊”。Node 无额外 npm 依赖，仅监听 loopback，写入需会话 token 和同源校验。
- 左侧搜索任务、阶段、条件、动作、NPC、阵营、日程和对话；中间切换属性编辑／关系图，右侧常驻叙事预览。属性、图、引用与间接影响都读取合并后的草稿。引用数组可增删、上下调整顺序，保留 `choiceIds/actionIds` 的配置顺序。故事总览折叠条件/动作，当前关联展开两层引用，支持缩放/平移/点击。
- Mission／Quest 预览显示任务手记、接取条件、各阶段激活／达成条件、完成动作和关联对白；阶段按 ID 排列，不伪称固定线性流程。条件树保留 all/any/not 与配置失败原因；通用 always/never 不用于串联无关对白。对话、节点、选项和插话定位所属对白，显示前文来源、角色卡片、条件、动作、后文和结束／开战出口。分支阅读支持历史、退一步、回到编辑节点和从头阅读；草稿改变或删除跳转时重新核对路径。编辑条件／动作时保留故事上下文。所有预览均不求值存档条件、不执行动作、不模拟战斗；不会隐藏未满足条件的分支。
- 页面编辑保留在本地草稿，支持多表联改、新建/删除、下载 patch JSON；检查整组草稿后保存，保存并导出才更新游戏产物。刷新前提醒未保存修改。所有保存必须匹配 workspace revision，包含表源、位置、Catalog、Language.lua；409 时保留草稿并要求用户重新合并。
- `workspace.mjs` 是 Web/CLI 的共同读写入口；批量保存先完整校验，提交前复查 revision，使用写锁串行化叙事工具自身写入。单文件原子替换，捕获写入异常时回滚本次已写且未被外部改动的文件；多文件保存不是断电原子事务。通用配置编辑器/外部编辑器不受叙事锁控制，因此不要并发修改同一批源文件。
- `rules.mjs` 接入通用 exporter 的 validateTables，通用配置工作台、导表、Web 与 CLI 使用一致的叙事规则：Condition 环/深度/参数、引用目标、奖励动作限制、对话所有权/可达性、NPC 数值范围/安置/日程/设施。完成状态前置环给警告；任意自定义 Condition 给出需执行对应 Lua 校验的提示，不伪称静态证明其语义正确。
- 关系图包含表字段引用、条件/动作的动态目标引用，以及 flag 读者到同键写入动作的依赖。`impact` 按反向引用遍历，返回更改某实体可能影响的全部节点。它不是剧情可达性证明，仍需核对实际条件与玩法。
- `DialogueInterjectionTable` 纳入工坊与内容中心的任务分类；预览展示自动/主动发言、Condition、缘由和可点击接续节点。图及可达性检查包含插话跳转，禁止自动插话跳转及跨 Dialogue 跳转；actor 条件只允许插话上下文，特质/属性/事件历史引用均参与校验与影响分析。运行语义见[任务对话与 NPC](../Business/Narrative.md)。
- `party_attribute` 显式投影到 GrowthAttributeTable，并校验属性 ID、正阈值及空 key/state；`grant_experience` 校验全队目标和正数量。三线剧情的可达性与奖励原子预检由 [narrative_campaign_core.lua](../../Tools/Tests/narrative_campaign_core.lua) 执行真实 Lua 流转验证，不能用关系图无环代替路线验证。
- [内容中心](ContentCenter.md)复用同一批量保存实现；写锁位于 `Tools/ConfigEditor/.cache/write.lock`，两者相互串行。Narrative 的默认可编辑白名单保持为叙事表，内容中心显式传入源表列表。
- Agent 命令统一为 `node Tools/Narrative/cli.mjs <command>`：`list [table]`、`get <table> <id>`、`schema [table]`、`graph`、`impact <table:id>`、`snapshot`、`validate`、`review <patch.json>`、`patch <patch.json>`、`export <revision>`。成功输出 JSON，失败输出 error/status 并返回非零退出码；无需启动 Web 服务。
- Patch 为 `{revision,operations}`；支持 upsert 完整行和 delete ID，同一实体不得重复操作。仅允许叙事表，跨表改动放同组。review 返回 before/after 和诊断且不写盘；patch 不自动导出；export 必须传最新 revision。Agent 工作流见项目 [$mission-authoring](../../.agents/skills/mission-authoring/SKILL.md)。
- 定向测试 `node --test Tools/Narrative/tests/narrative.test.mjs` 使用 OS 临时配置副本，覆盖跨表批次、预检不写、悬空引用、409、条件环、日程断档、对话越界和 HTTP/CLI 一致性。运行时及 Unity 操作边界见[叙事业务](../Business/Narrative.md)。
- `node --test Tools/Narrative/tests/preview.test.mjs` 覆盖编辑对象定位、条件层级／坏引用、上下文、零跳转含义、路径循环及草稿变动、动作展示与模块静态路由。前端交互还需在浏览器验看实时更新、分支阅读、顺序编辑及响应式布局；不需要启动 Unity。

## 关键入口

- [server.mjs](../../Tools/Narrative/server.mjs) / [workspace.mjs](../../Tools/Narrative/workspace.mjs) / [rules.mjs](../../Tools/Narrative/rules.mjs) / [cli.mjs](../../Tools/Narrative/cli.mjs)。
- [页面](../../Tools/Narrative/public/index.html) / [交互与图](../../Tools/Narrative/public/app.js) / [样式](../../Tools/Narrative/public/styles.css) / [预览呈现](../../Tools/Narrative/public/preview.js) / [只读草稿投影](../../Tools/Narrative/public/preview-model.mjs)。
- [服务注册](../../Tools/WebServices/services.json) / [定向测试](../../Tools/Narrative/tests/narrative.test.mjs) / [Agent 技能](../../.agents/skills/mission-authoring/SKILL.md)。
