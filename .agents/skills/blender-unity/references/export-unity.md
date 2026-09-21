# 导出与 Unity 验收

## 静态 FBX

[export_static_fbx.py](../scripts/export_static_fbx.py) 在 Blender 内执行；接受明确对象名和绝对输出路径，不修改几何/变换，导出后恢复选择及活动对象。它要求 Object Mode、1 单位 = 1 米、可见且可选的 Mesh/Empty；拒绝现存输出（除非显式 `overwrite=True`）、负/零世界变换行列式和直接带动画/Armature modifier 的对象。父级、约束、Geometry Nodes 的依赖仍由调用者检查，不能仅凭这些前置校验断言是纯静态资产。

通过 `execute_blender_code` 调用的示例（路径和名字替换为本次已确认值）：

```python
import json
import runpy
exporter = runpy.run_path("D:/project/.agents/skills/blender-unity/scripts/export_static_fbx.py")
result = exporter["export_static_fbx"](
    ["Crate_Mesh"], "D:/staging/Crate.fbx"
)
print(json.dumps(result))
```

原生 MCP 传入 `code` 字符串；随附客户端用 `execute --code-file <片段文件>`。若用户开启了上游 safe mode，`runpy` 会被拒绝：按允许的模块把必要的 bpy 操作直接写入片段，文件存在性在宿主侧核对；不关闭或绕过 safe mode。

静态预设选择 `-Z Forward / Y Up`、`global_scale=1`、`apply_unit_scale=True`、`FBX_SCALE_UNITS`、选中对象导出、应用导出用 modifier、三角化、禁用动画/叶骨、外置贴图。来源：[Blender FBX API](https://docs.blender.org/api/current/bpy.ops.export_scene.html)。这些是起点，最终应核对 Unity 中的尺寸、方向和层级变换，不能承诺所有资源根节点都自动成为零旋转、单位缩放。

导出前还要检查：

- 对象世界尺寸和真实尺寸相符；原点符合落地、旋转或装配要求；法线/UV/材质槽存在且符合用途。
- 对导出副本应用需要的旋转/缩放，必要时烘焙约束和生成几何；有 shape key 或蒙皮时不要套静态预设。
- 使用贴图时显式复制/烘焙到最终 `Textures` 目录；`path_mode=RELATIVE` 不会替你打包、烘焙或重连所有图片。移动后核对 Unity 映射。
- 动画对象另选 Armature + Mesh，保留骨骼层级，明确导出哪些 Action/NLA、帧范围和采样率；通常关闭叶骨，不能无条件启用所有 Action/NLA。Humanoid/Generic 根据用户用途决定。

## Unity 侧

先读目标工程 `ProjectVersion.txt`、包清单、GraphicsSettings/QualitySettings 和已有资源约定。FBX 是这里默认交换格式；glTF 仅在工程已有受支持 importer 时使用。

| 检查 | 处理 |
| --- | --- |
| 项目/实例 | 多 Editor 时先列出并选择正确实例，核对项目路径；不要对默认实例盲写 |
| 文件路径 | `.blend` 留源资源目录；FBX 与贴图进已确认的 `Assets` 子目录，保存已有 `.meta` |
| 模型单位 | 开启/核对 Convert Units，先保持 Scale Factor 1；用已知米制尺寸比较 Renderer bounds，发现 100 倍误差后检查导出单位与 importer，避免双重补偿 |
| 朝向/原点 | 用有明确正面、非对称的对象核对 Unity +Y 向上及期望正面；对称立方体不能证明前后正确 |
| 法线/切线 | 保留需要的自定义法线；法线贴图要求正确 UV 和切线；无需 Read/Write 时保持关闭 |
| Rig/Animation | 静态模型禁用不需要的动画；角色按用途设 Generic/Humanoid 并检查 Avatar/clip |
| 颜色空间 | Base Color/发光颜色通常为 sRGB；金属度、粗糙度、AO 等数据贴图关闭 sRGB；法线贴图设 Normal map |
| Shader/通道 | Built-in、URP、HDRP 各用当前管线 Shader；粗糙度通常需转换 smoothness=1-roughness，通道打包以该 Shader 实际约定为准 |
| 材质 | 提取或创建独立 `.mat`，显式重映射；不要期待 Blender 节点图完整迁移。无贴图模型也要核对颜色和透明度 |
| Prefab | 用户需要时创建独立 Prefab，绑定 Mesh/Material/Collider；碰撞精度、LOD 和加载路径按需求决定 |

Unity 导入来源：[模型导入](https://docs.unity3d.com/2022.3/Documentation/Manual/ImportingModelFiles.html)、[Model 设置](https://docs.unity3d.com/2022.3/Documentation/Manual/FBXImporter-Model.html)、[Materials 设置](https://docs.unity3d.com/2022.3/Documentation/Manual/FBXImporter-Materials.html)。核对资源时采用目标工程版本的文档。

完成后获取 Unity 实际 importer/资源返回值及预览；如需验证大小，使用 Mesh/Renderer bounds，区分局部网格尺寸与世界包围盒。不要为了导入检查额外生成临时 C#、启动另一工程或进入 Play。工具不可用时只能报告文件准备完成，不能把 `.meta` 存在当成外观验收通过。
