# 叙事工坊与 Agent 工具
关键词：Mission 编辑器、Web、叙事关系图、任务编辑、NPC、对话编辑、Agent、CLI、批量修改、影响分析、4179。

## 文档目录
正文：运行 / 编辑与校验 / Agent 使用 / 验证；关键入口：服务 / 规则 / 页面 / 技能。

## 正文

- 使用现有 Web 服务管理器：`node Tools/WebServices/manage.mjs start narrative`，访问 `http://127.0.0.1:4179`。Unity Web 服务管理窗口自动列出“叙事工坊”。Node 无额外 npm 依赖，仅监听 loopback，写入需会话 token 和同源校验。
- 左侧搜索任务、阶段、条件、动作、NPC、阵营、日程和对话；中间故事总览折叠条件/动作的中间节点，当前关联视图展开两层引用，支持缩放/平移/点击；右侧表单编辑、引用与影响分析、对话文本分支预览。预览只展示分支，不模拟战斗或执行奖励。
- 页面编辑保留在本地草稿，支持多表联改、新建/删除、下载 patch JSON；检查整组草稿后保存，保存并导出才更新游戏产物。刷新前提醒未保存修改。所有保存必须匹配 workspace revision，包含表源、位置、Catalog、Language.lua；409 时保留草稿并要求用户重新合并。
- `workspace.mjs` 是 Web/CLI 的共同读写入口；批量保存先完整校验，提交前复查 revision，使用写锁串行化叙事工具自身写入。单文件原子替换，捕获写入异常时回滚本次已写且未被外部改动的文件；多文件保存不是断电原子事务。通用配置编辑器/外部编辑器不受叙事锁控制，因此不要并发修改同一批源文件。
- `rules.mjs` 接入通用 exporter 的 validateTables，通用配置工作台、导表、Web 与 CLI 使用一致的叙事规则：Condition 环/深度/参数、引用目标、奖励动作限制、对话所有权/可达性、NPC 数值范围/安置/日程/设施。完成状态前置环给警告；任意自定义 Condition 给出需执行对应 Lua 校验的提示，不伪称静态证明其语义正确。
- 关系图包含表字段引用、条件/动作的动态目标引用，以及 flag 读者到同键写入动作的依赖。`impact` 按反向引用遍历，返回更改某实体可能影响的全部节点。它不是剧情可达性证明，仍需核对实际条件与玩法。
- [内容中心](ContentCenter.md)复用同一批量保存实现；写锁位于 `Tools/ConfigEditor/.cache/write.lock`，两者相互串行。Narrative 的默认可编辑白名单保持为叙事表，内容中心显式传入源表列表。
- Agent 命令统一为 `node Tools/Narrative/cli.mjs <command>`：`list [table]`、`get <table> <id>`、`schema [table]`、`graph`、`impact <table:id>`、`snapshot`、`validate`、`review <patch.json>`、`patch <patch.json>`、`export <revision>`。成功输出 JSON，失败输出 error/status 并返回非零退出码；无需启动 Web 服务。
- Patch 为 `{revision,operations}`；支持 upsert 完整行和 delete ID，同一实体不得重复操作。仅允许叙事表，跨表改动放同组。review 返回 before/after 和诊断且不写盘；patch 不自动导出；export 必须传最新 revision。Agent 工作流见项目 [$mission-authoring](../../.agents/skills/mission-authoring/SKILL.md)。
- 定向测试 `node --test Tools/Narrative/tests/narrative.test.mjs` 使用 OS 临时配置副本，覆盖跨表批次、预检不写、悬空引用、409、条件环、日程断档、对话越界和 HTTP/CLI 一致性。运行时及 Unity 操作边界见[叙事业务](../Business/Narrative.md)。

## 关键入口

- [server.mjs](../../Tools/Narrative/server.mjs) / [workspace.mjs](../../Tools/Narrative/workspace.mjs) / [rules.mjs](../../Tools/Narrative/rules.mjs) / [cli.mjs](../../Tools/Narrative/cli.mjs)。
- [页面](../../Tools/Narrative/public/index.html) / [交互与图](../../Tools/Narrative/public/app.js) / [样式](../../Tools/Narrative/public/styles.css)。
- [服务注册](../../Tools/WebServices/services.json) / [定向测试](../../Tools/Narrative/tests/narrative.test.mjs) / [Agent 技能](../../.agents/skills/mission-authoring/SKILL.md)。
