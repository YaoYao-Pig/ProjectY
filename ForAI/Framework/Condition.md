# 共享 Condition
关键词：Condition、条件、all、any、not、条件图、类型扩展、前置、后置。

## 文档目录
正文：职责 / 配置与扩展 / 验证；关键入口：求值器 / 系统 / 配表。

## 正文

- `Condition` 是依赖 Config 的常驻系统，统一读取 `ConditionTable`。条件只返回是否满足与失败原因，不保存业务进度，不执行任务流转、发奖、扣物品或对话跳转。
- `all` / `any` / `not` 用 `conditionIds` 组成有向无环图；叶子不能有子节点，组合不能为空，not 恰好一个子节点。使用 ID 1（always）表达无条件，ID 2（never）表达不开放；不存在“0 或缺省 ID 自动通过”的约定。
- 业务适配器依赖 `Condition`，在 `OnInit` 调用 `Register(kind, evaluate, validate)`。`evaluate(row, context)` 必须返回布尔值，可返回动态失败原因；`validate(row)` 校验目标表引用与参数。`targetId/key/value/state` 的含义归叶子类型定义，通用层不推断目标表。
- 注册器先完成所有 `OnInit`，Condition 再在 `OnStart` 校验全部配置和图。重复类型、保留组合类型、未知类型、失效引用、循环、重复子节点、非法参数以及超过 64 层的嵌套明确报错。注册新处理器会使既有校验失效；运行期不支持无校验扩展。
- `Check(id, context)` 的 context 是调用方提供的事实读取上下文；处理器保持只读。查询内短路并缓存共享子节点，查询之间不缓存业务结果。ALL 返回首个失败子条件的原因，ANY 全失败及 NOT 失败使用自身 reason。
- 通用层内置组合条件与 always/never；[叙事系统](../Business/Narrative.md) 注册任务/阶段状态、物品、击杀、事实、NPC、阵营与时段叶子，具体语义归业务适配器。
- 改表后执行 `node Tools/ConfigEditor/exporter.mjs`。最小检查 `python -B Tools/Tests/run_lua.py Tools/Tests/condition_core.lua` 覆盖嵌套、共享节点、实时事实、失败暴露以及真实导表读取，不启动 Editor 或 Play。

## 关键入口

- [ConditionEvaluator.lua](../../Lua/Game/Condition/ConditionEvaluator.lua)：`Register / Validate / Check`。
- [ConditionSystem.lua](../../Lua/Game/Condition/ConditionSystem.lua) / [注册入口](../../Lua/Game/Systems.lua)：生命周期与扩展入口。
- [ConditionTable.json](../../Config/Tables/Condition/ConditionTable.json) / [Catalog.json](../../Config/Catalog.json)：源配置；产物遵循[配置管线](Config.md)。
- [condition_core.lua](../../Tools/Tests/condition_core.lua)：定向检查。
