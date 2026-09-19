# AI 工作入口

- Unity / Lua 开发、重构、评审和相关测试先读取并遵守 `$lua-code-style`：[项目 Skill](.agents/skills/lua-code-style/SKILL.md)。项目技能统一维护于 `.agents/skills/`；存在同名全局副本时以项目版本为准，约束不在文档复制。
- 文档中的验证命令仅说明可用检查，不代表已授权全量测试、启动 Editor / Play Mode 或反复编译；按上述 Skill 选择最小验证范围。
- 框架、业务、工具开发先读 [ForAI/INDEX.md](ForAI/INDEX.md)，再按关键词读取相关模块；无需预读所有文档。
- 实现或排错时按关键入口阅读相关代码，核实行为；上下文足够后停止扩读。文档负责定位，代码决定当前事实。
- 改动模块职责、契约、路径或验证方式时，同步相关 ForAI 文档；维护规则见 [ForAI/MAINTENANCE.md](ForAI/MAINTENANCE.md)。纯实现细节不必写文档。
- 可使用 `$forai-read` / `$forai-write`；没有这些技能时也遵循以上路由。
- 默认不扫描 `Library/`、`Temp/`、`Logs/`、`Tools/ConfigEditor/.cache/`、第三方源码和生成目录；仅在问题直接涉及它们时读取。
