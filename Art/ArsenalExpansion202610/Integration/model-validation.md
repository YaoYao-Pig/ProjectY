# 新武器与配件模型交付

通过 Blender MCP 制作，Blender 5.2.2。前一轮 EquipmentExpansion202610 原始场景与展示场景保持完整；本轮使用独立 ArsenalExpansion202610_Source / WeaponsPreview / AttachmentsPreview。

- 20 把武器（601–620）：3 法杖、3 步枪、3 单手剑、3 大剑、3 巨剑、3 弓、2 工具武器。
- 20 个配件（701–720）：4 杖头、3 杖身、3 机械组件、2 触媒、4 导轨、4 刃夹。
- 40 个唯一几何 SHA-256，合计 17,940 三角面。每件具有不同结构和轮廓；未用重复几何换色充数。
- 40 个 FBX 共 1,200,032 bytes。模型原点为本地握点或装配接口，所有源对象位置/旋转为零，缩放为一，无父级/约束/Modifier/动画依赖。
- 逐件检查 1 个 UV 层、有限 UV、正面积面、平面法线，开放边与非流形边均为 0；三角面数、尺寸、材质和几何摘要详见 models.json。
- 材质全部采用现有 M_MapLP 纯色色板。无图片、程序节点、外部素材或透明材质依赖。palette.json 为本轮实际使用材质色值。
- 武器本体保留对应 baseWeaponId 的实际握持区域；models.json 包含基准 EquipmentGripTable 的主/副手位置和旋转，anchors.json 提供 32 个 Unity 本地挂点。
- 使用项目既有静态装备导出函数，仅旋转临时导出副本；Unity 必须使用 bakeAxisConversion=true，单位换算启用，Scale Factor=1。
- 2200×2900 武器总览和 2200×1850 配件总览已渲染并逐件目视检查，标注编号和分类。

交付文件：

- `../Source/ArsenalMasters.blend`：40 件可编辑 Mesh，保持装配原点。
- `../Source/WeaponsPreview.blend` / `../Source/AttachmentsPreview.blend`：可重渲染的独立展示场景。
- `../Staging/*.fbx`：本轮 40 件最终暂存模型。
- `../Previews/weapons-contact-sheet.png` / `../Previews/attachments-contact-sheet.png`：外观验收总览。
- `models.json`：逐件原生几何与导出报告。
- `anchors.json`：挂点坐标与接口约定；Unity 原生轴向检查后同步最终符号。

此子任务不写 Config、Lua/C# 或 Unity Assets，未启动 Editor/Play、编译或游戏测试。Unity 导入、材质映射、Prefab 挂点、图标及实际持握由主任务验证。
