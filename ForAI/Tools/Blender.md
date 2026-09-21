# Blender 资源管线

关键词：Blender、MCP、建模、FBX、贴图、材质、Unity 导入、Prefab、skill。

## 文档目录

正文：职责 / 本机接入 / 项目约束 / 最小验证；关键入口：Skill 与辅助脚本。

## 正文

- 通过 [blender-unity Skill](../../.agents/skills/blender-unity/SKILL.md) 完成 Blender 调用、资源导出及 Unity 导入核对。通用操作和参数只维护在该 Skill，不在本文复制。
- 本机接入位于用户配置 `%USERPROFILE%/.codex/config.toml` 的 `mcp_servers.blender`；可执行文件在 `%USERPROFILE%/.codex/mcp/blender/venv/Scripts/mcp-for-blender.exe`，本次安装版本为 `mcp-for-blender==2.0.0`，Python 3.11。
- 当前 Blender 为 Steam 安装：`D:/Software/Steam/steamapps/common/Blender/blender.exe`（5.2.2 LTS）；插件位于 `%APPDATA%/Blender Foundation/Blender/5.2/scripts/addons/blender_mcp.py`，与 Python 包同源，协议版本 7。
- 本地桥接使用 `127.0.0.1:9876`。MCP 进程遥测和插件 Allow Telemetry 均关闭；插件已启用并保存用户偏好，正常图形启动时按插件默认行为自动连接。
- 机器配置、运行时和日志不随 Git 分发；新机器按 Skill 的连接参考安装，不能仅凭本文认为已接入。Codex 配置备份保存在同一本机 runtime 父目录。
- 项目 Unity 版本以 [ProjectVersion.txt](../../ProjectSettings/ProjectVersion.txt) 为准；当前为 2022.3.55f1c1，采用 Built-in 管线。Unity MCP 包版本以 [manifest.json](../../Packages/manifest.json) 为准，当前配置为 10.2.0。
- 大地图资源采用 `Art/MapLowPoly` 保留来源，`Assets/DynamicAsset/MapLowPoly` 保存 Unity 产物，几何与资源边界见 [地图模型资源](../Business/MapArt.md)。其他模块沿用各自目录，不由这套美术资源新增加载规则。
- 源 `.blend` 建议保留在 `Assets` 外，进入 Unity 的 FBX/贴图和后续材质/Prefab 沿用任务确认的目录。`.meta`/GUID 由 Unity 管理，既有资源更新保留引用。
- 最小验证分层：配置解析 → MCP tools/list → Blender 场景读取/截图 → 暂存目录 FBX 导出 → 目标 Unity 实例导入/预览。只报告实际完成的层级；后两步不互相替代。
- 不为 Skill/文档检查运行游戏测试；涉及 Editor、Play、编译或 LuaReference 时遵循 [项目开发规范](../../.agents/skills/lua-code-style/SKILL.md)。

## 关键入口

- [Skill](../../.agents/skills/blender-unity/SKILL.md)：连接、制作、导出、Unity 验收路由。
- [连接参考](../../.agents/skills/blender-unity/references/connection.md)：安装与故障定位。
- [MCP 客户端](../../.agents/skills/blender-unity/scripts/mcp_client.py)：在已安装 MCP 的 Python 中调用 stdio 服务。
- [静态 FBX 导出](../../.agents/skills/blender-unity/scripts/export_static_fbx.py)：`export_static_fbx`，在 Blender 内执行。
