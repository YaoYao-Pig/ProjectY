---
name: mission-authoring
description: 在 Project Y 中通过叙事工具查询、创建和修改配置驱动的 Mission、Quest、Condition、对话、NPC、阵营与日程，检查网络引用和批量变更。用于 AI 任务内容开发；不用于通用 Lua 框架开发或擅自启动 Unity 验证。
---

# Mission 内容开发

先读项目 `ForAI/INDEX.md` 的叙事模块；修改 Lua/C# 时同时遵守项目 `lua-code-style`。用户已确认的业务规则沿用，不重复询问。

工程根下使用 `node Tools/Narrative/cli.mjs`，输出均为 JSON：

- `list [表名]`：精简实体目录与当前 revision。
- `get <表名> <id>`：单行完整内容和直接引用。
- `schema [表名]`：字段、描述、默认值和候选 nextId。nextId 只是当前快照建议，写入仍需 revision。
- `graph` / `impact <表名:id>`：叙事网络、反向依赖与间接影响。删改前先检查受影响内容。
- `validate`：当前源配置与叙事语义校验。
- `review <patch.json>`：校验整组变更并返回修改前后内容，不落盘。
- `patch <patch.json>`：按 revision 批量提交源配置。409 时重新读取并合并，不能只替换 revision 后重放旧内容。
- `export <revision>`：使用最新 revision 导出已保存配置。保存与导出是两个明确步骤。

Patch 结构为 `{ "revision": "读取到的版本", "operations": [...] }`。操作为 `{ "op": "upsert", "table": "MissionTable", "row": {完整字段} }` 或 `{ "op": "delete", "table": "MissionTable", "id": 123 }`。一个实体一次操作；跨表新增和连线放在同一组，避免中间引用失效。JSON 文件用 UTF-8 写入，勿把复杂 JSON 拼进 shell 参数。

Mission 是任务，Quest 是阶段。前置和完成通过 Condition 表达；all/any/not 可以组合，任务 category 不决定业务实现。条件只查询，副作用放在 NarrativeActionTable；完成奖励不能嵌套接取或领取其他任务，后继任务由条件响应。共享条件编辑会影响所有引用者，必须检查 impact。

NPC 使用稳定身份，不以城镇临时对象 ID 或名字作为叙事引用。对话节点可以循环，下一节点必须属于同一对话；日程必须连续覆盖 0–1440 分钟，目标设施必须存在于该 NPC 的城镇配方。

内容开发优先使用现有条件和动作。确需新类型时，同时实现运行时注册/参数检查、工具侧引用投影/校验及定向验证；不得仅添加未知 kind 后把静态校验警告当作完整支持。不要手改 `_Gen` 产物或 Prefab YAML。

最小交付：变更源配置、完成 `review → patch → export`、报告涉及实体及实际检查。纯内容修改不主动启动 Editor、Play、编译或全量测试。Web `叙事工坊` 与 CLI 使用同一批配置和规则，可用于用户复核。
