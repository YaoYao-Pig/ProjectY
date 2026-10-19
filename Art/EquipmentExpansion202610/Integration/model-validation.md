# 配件模型交付与验收

2026-10-18 通过 Blender MCP 在现有 Blender 5.2.2 中完成。原有默认场景 Cube、Camera、Light 保留；作品使用独立 Source / Preview 场景，不修改用户原场景。

- 30 件独立配件，物品与资源 ID 501–530：杖首 10、杖身 8、巨剑机械件 8、剑触媒 4。
- 30 个唯一几何 SHA-256，合计 15,128 三角面，单件 140–1,324 三角面。不是同一模型换色。
- 每件模型具有平面法线、一个 UV 层和明确纯色材质槽；检查无零面积面、开放边或非流形边。
- 所有源 Mesh 无父级、无 modifier / constraint / animation，位置与旋转为零、缩放为一。原点为装配挂点，Blender 使用米制、Z 向上、-Y 朝前。
- 30 个独立 FBX 共 901,576 bytes。使用项目既有静态装备导出函数，导出副本绕 Blender Z 轴旋转 180°；Unity 必须启用 `bakeAxisConversion=true`，Scale Factor=1。
- 使用现有 EqBronze / EqIron / EqCyan / EqAmber / Timber / TimberLight / RockLight / Window 等色；新增 EqRuby=`c65352`、EqJade=`80ac64`、EqViolet=`9a81be`。色值见 palette.json 和 manifest.json，Blender 节点使用线性色值。
- 2400×2100 联络表已人工检查；504 风铃冠与 510 悬环冠补足连接梁后重新导出并更新预览。

交付入口：

- `../manifest.json`：设计、玩法建议、IDs、模型名和目标路径。
- `models.json`：每件模型的尺寸、面数、材质、几何 hash、导出设置与 FBX 路径。
- `../Source/EquipmentAttachments.blend`：30 件可编辑原点模型。
- `../Source/EquipmentAttachmentsPreview.blend`：带标题、编号和分类的展示场景。
- `../Previews/attachments-contact-sheet.png`：最终模型联络表。
- `../Staging/Equip_*.fbx`：30 件暂存 FBX。

本子任务仅执行模型作者、暂存导出和 Blender 外观验证。Unity 资产导入、材质映射、图标、配表与游戏装配检查由主任务完成；此报告不代表已通过运行时验证。
