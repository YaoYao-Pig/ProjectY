# 叙事系统验证 · 2026-09-29

本次验证限于任务/对话/NPC/编辑工具及直接受影响的城镇和存档，不进入 Play，不执行 Player 构建或全量测试。

- `node --test Tools/Narrative/tests/narrative.test.mjs`：3 项通过。包含多表批次、预检不落盘、引用检查、旧 revision 冲突、条件循环、日程断档、对话跨界及 HTTP/CLI 共用规则。使用 OS 临时配置副本。
- `python -B Tools/Tests/run_lua.py Tools/Tests/condition_core.lua`：通过组合、共享 DAG、动态事实、处理器失败与实际导表生命周期检查。
- 14 个新增叙事 Lua 文件通过原生 xLua 语法加载检查。
- `python -B Tools/Tests/run_lua.py Tools/Tests/town_core.lua`：四城镇配方、种子/主题差异、分层桥路和四人通行检查通过。
- `ProjectY.Editor.NarrativeValidation.Run()`：真实 C# Data 与 Lua 的并行阶段、两条路线、激活击杀起点、单次奖励、满队暂缓、招募预检无副作用、招募入队、任务/好感/声望存档恢复、具名 NPC、道路日程、陈旧选择拒绝与对话生命周期通过。
- `ProjectY.Editor.NarrativeValidation.RunUI()`：真实 UGUI Prefab、LuaReference、选择按钮、对话历史、缓存重开、暂停释放、Cinemachine 双人构图和相机恢复通过；使用独立 PreviewScene，预览构图采用零时长切换进行确定性几何检查。真实场景内 .65 秒混合手感与遮挡仍待用户 Play 验收。
- `ProjectY.Editor.CharacterIntegrationValidation.Run()`：现有角色/背包保存读取、养成、外观、伤势、损坏与未知版本拒绝回归通过。仅使用临时存档。
- 浏览器实际走通任务描述编辑→草稿检查→保存并导出；对话文本预览沿选择跳转。页面会话保留为交付。
- 相关 ForAI 链接及 `mission-authoring` 技能格式检查通过。手写文件的 diff 空白检查通过；xLua 生成器原生输出包含空白行缩进，遵循项目规则未手改生成文件。

Unity 操作：主动请求编译 3 次（首次因新增包尚未解析失败，后两次用于已获授权的修复与预览验证）；Package Manager 安装 Cinemachine 2.10.7、XLua/Generate Code 另触发 Unity 自身编译/重载。最终 Console 错误为 0。UI 资源通过 Unity MCP 调用 NarrativeAssets 创建并保存，未手改 Prefab YAML。

过程修复：招募预检改用不写经历的 Growth.PrepareActor，正式入队后记录；存档 v2 显式保存 hasMount，兼容 Unity JSON 将无坐骑内联记录物化为全零对象；叙事 NPC 在布局冻结前通过生成扩展入口安置。

预览：

- [叙事工坊](Previews/Narrative-web.png)
- [对话 UI 与双人镜头](Previews/Narrative-dialogue.png)
- [任务与同行者](Previews/Narrative-missions.png)

使用与契约见 [叙事模块](../ForAI/Business/Narrative.md)、[编辑器与工具](../ForAI/Tools/Narrative.md)。

## 2026-09-30 · 对话输入死锁回归

- 用户实际进入对话后选项及关闭失效。原因是开启暂停世界的面板后又排入交谈动画，Demo 的动画门禁等待无法推进的 ActionBusy，连 dialogue_choose/dialogue_close 也被拦截。
- 修复为对话输入独立于世界动画门禁；已打开暂停对话时不排入新的交谈动作。原业务条件、节点版本与距离校验保留。
- [dialogue_pause_command.cs](../Tools/Tests/dialogue_pause_command.cs) 复制当前 AdventureDemo 的配置对象到独立 PreviewScene，初始化真实 GameBootstrap 和 Demo，经 GM 传送、正常 NPC 交互、实际 UGUI 按钮进入完整 C#→Lua 路径。验证世界暂停且角色保持真实 Busy 时仍能选择与关闭，并恢复暂停前时间倍率。最终执行通过，连同清理过程无新增 Error/Exception/Assert。
- 首轮验证发现预览退出沿用 Play 的延迟 Destroy，以及 SendMessage 调用特殊生命周期的 Editor 断言；已改为编辑态释放临时显示资源，并由测试显式调用独立副本生命周期。宿主仅在 Play 常驻，测试不替换用户正在运行的 LuaEnv。
- 本次共主动请求两次项目编译，第二次经用户单独确认用于预览清理收尾；未重新进入 Play。用户授权退出 Play 时 Editor 已停止，未额外结束其他会话。
