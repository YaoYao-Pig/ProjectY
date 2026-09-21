---
name: blender-unity
description: 通过 ahujasid/mcp-for-blender 调用 Blender 建模、检查和导出 FBX，并在 Unity 中导入模型、贴图、材质及 Prefab；也用于接入或排查 Blender MCP。不用于普通 Unity/Lua 业务修改。
---

# Blender → Unity

将用户的资源需求落实为可检查的 Blender 源文件和 Unity 资源。先读取项目 AGENTS、ForAI 索引及命中的资源文档；项目中的机器配置和现状见 [Blender 工具入口](../../../ForAI/Tools/Blender.md)。涉及 Unity 修改时遵循 [lua-code-style](../lua-code-style/SKILL.md)。

## 接入与调用

1. 先发现当前可调用的 Blender/Unity MCP 工具及其参数。配置存在、MCP 握手成功、Blender 插件实际响应是三个不同状态，分别验证。
2. 安装、客户端未加载工具或连接报错时，读取 [connection.md](references/connection.md)。正常工作优先直接使用 MCP 工具；尚未加载工具时可用随附客户端，仍通过 MCP 协议调用，不能绕过审批或服务器的安全模式。
3. 先调用 `get_scene_info`，必要时 `get_object_info`、`get_viewport_screenshot`；用短小的 `execute_blender_code` 完成单个可检查步骤。`user_prompt` 按实际 schema 填写；需要用户原始意图时不要发送无关上下文。
4. Python 片段用 `print` 输出对象名、数量、尺寸、文件路径等验收信息。MCP 的 `isError=false` 不保证操作成功：这个服务可能把异常作为以 `Error ...` 开头的文本返回。
5. Blender 版本间节点接口会变化。先用 `describe_node_type` / Python RNA 查询实际属性，不凭记忆猜节点插槽或枚举。写入请求超时后先查询场景/文件状态，不盲目重放；长任务拆成有明确结束信号的步骤。

## 制作资源

- 从用户指令和已有资源约定确定用途、真实尺寸、朝向、原点、风格、面数、贴图及动画需求。影响最终资源但仍不清楚的要求先澄清；普通命名和操作细节自行处理。
- 读取现有场景和保存路径。更改已有作品前保存经授权的源文件或独立副本；不清空整场景、不覆盖无关对象。新资源使用明确的 Collection 和稳定名称，更新时只操作自己负责的对象。
- 可编辑 `.blend` 放在项目认可的源资源目录，默认建议位于 `Assets` 外；交付 Unity 使用显式导出的 FBX 和独立贴图。不要把直接复制 `.blend` 当成稳定导入管线。
- 静态模型明确单位（通常 1 单位 = 1 米）、落地点/旋转轴心和正面；检查负缩放、法线、UV、材质槽、三角面数。变换应用在明确的导出副本上进行，不能批量改变已绑定骨骼或动画的对象。
- Blender 程序材质、Geometry Nodes、约束不会自动变成 Unity 等效效果。按需求烘焙贴图、实现网格或烘焙动画，并保留可编辑源文件。
- 外部素材下载或付费生成服务仅在任务需要且已授权时启用；不为了本地建模开启全部供应商集成。

## 导出与 Unity 导入

导出参数、选区恢复和材质细节见 [export-unity.md](references/export-unity.md)。

1. 先把 FBX/贴图导出到 `Assets` 外的暂存目录；核对文件非空、目标对象和尺寸。静态物件与角色骨骼采用不同配置，不把示例参数当作万能预设。
2. 查明目标 Unity 工程和资源目录；多 Editor 实例时明确选中目标实例并核对项目路径。只按实际工具 schema 操作，不猜 Unity MCP 工具参数。
3. 导入已有文件时保留 `.meta`/GUID；不手写 Prefab、材质或 importer YAML。把整批最终资源写入目标 `Assets` 路径后，优先等待 Editor 自动导入；如需手动导入，使用已有的定向资源导入能力，避免每个文件全局 Refresh。
4. 核对 ModelImporter 的单位、轴向、法线、切线、Rig/Animation、材质映射；贴图按用途设置颜色空间、Normal map 类型及透明度。材质使用项目当前渲染管线支持的 Shader。
5. 用户要求 Prefab 时，用 Unity MCP 保存独立 Prefab 并显式绑定 Mesh/Material；需要 LuaReference 时遵循项目绑定规范。不要直接编辑 FBX 生成的只读 Model Prefab 内部结构。
6. 检查 Unity 中的包围盒、正面、原点、材质和引用，用 Scene/Inspector 截图或实际工具返回值作为证据。一次最小资源检查足够；启动 Unity、进入 Play、编译及扩大测试范围仍遵循项目约束。

## 完成判据

报告 `.blend`、FBX、贴图、材质/Prefab 的实际路径及已验证项目。区分“文件已复制”“Unity 已完成导入”“场景/Prefab 已核对”。缺少 Unity MCP 或 Editor 未打开时，继续完成可独立进行的制作/导出并明确剩余步骤，不能宣称导入验证完成。
