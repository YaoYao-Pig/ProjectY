# 角色工坊

在工程根运行 `node Tools/WebServices/manage.mjs start character-preview`，打开 `http://127.0.0.1:4177`。
Unity 的「Project Y / Web 服务 / 服务管理」也能启动、打开和停止角色工坊。

网页读取 `public/data/characters.json`，由 Unity 菜单「Project Y / 角色 / 导出角色网页资源」生成。
先执行「同步模块化角色资源」更新 Blender FBX 对应的 Unity 网格、材质、目录与 PawnRig 绑定。
网页的种族、模块与配色目录来自 Unity 的 PawnCustomizationCatalog；随机算法用 Unity 导出的固定种子样本校对。

可以切换五族男女、三档体型、两种脸型、发型和颜色，选择动作、暂停与拖动时间轴，按种子随机或导入/导出外观 JSON。
回到 Unity，使用「从网页外观 JSON 创建预览 Prefab」。运行时把同一描述传入 `PawnAppearanceData.Customization`；Lua 快照可传 `customizationJson`。
角色与敌人共用装配组件；敌群种族池已经由 CharacterAppearancePoolTable 驱动，角色与背包在游戏 HUD 手动保存/读取，网页不会刷新一次就重新随机游戏角色。

网页显示实际 Unity Mesh、材质颜色、蒙皮与 Animator 采样，使用 Three.js 渲染，光照与 Unity 不保证逐像素一致。
未持武时展示六类 Humanoid 动作；装备试穿包含 42 个贴合网格、身体覆盖、九种武器及双持/剑盾，11 组实际待机/行走/攻击由 Unity 的装配与握点求解导出。刚体逐帧记录实际挂点变换，含符文、弹匣与推进器。
装备试穿只影响预览，外观 JSON 不修改游戏库存。模组与握点编辑入口为 `Config/Tables/Equipment/EquipmentMotionModuleTable.json`、`EquipmentMotionMatchTable.json`、`EquipmentGripTable.json`，改后导表并从 Unity 重新导出。握点向量也支持下面的可视化编辑。
当前弓为基础持握和射击，未制作专用拉弦片段与弓弦变形；当前枪资源是步枪，其他枪型可通过 gunClass 扩展。没有尾翼、表情骨骼或滑杆自由形变。
体型改变轮廓，关节位置和四肢长度固定；第一批五族身高一致。

`public/` 可作为独立静态网站目录使用，不依赖 Unity Editor。复制后无法检查源工程的更新；本机 Node 服务通过来源 SHA-256 提示过期资源。
Three.js 固定为 0.180.0，本地分发模块、OrbitControls、[TransformControls](https://github.com/mrdoob/three.js/blob/r180/examples/jsm/controls/TransformControls.js) 和 MIT LICENSE；无需运行时访问 CDN。

## 可视化调整武器握点

1. 在“装备试穿”选择武器组合，勾选“开启可视化编辑”。旧资源包缺少编辑数据时，先在 Unity 执行“导出角色网页资源”。
2. 默认目标是“武器朝向”。拖旋转圆环或输入 XYZ 度数，直接调整武器本身，页面明确显示“武器型号 · 持握模组 · 主/副手”。例如铁剑的单手、剑盾、双持朝向各自保存；双持主副手也彼此独立。“恢复模组默认朝向”会删除当前组合覆盖。
3. 选择“主握点”或“第二握点”可编辑共享几何握点：位置是武器本地坐标（米），旋转是手掌握点朝向（Unity 欧拉角、度）。这些修改影响所有使用该 gripId 的组合；它与武器朝向修正分开管理。金色球标记主握点，蓝色球标记第二握点；“聚焦握点”放大手部。编辑会暂停，可播放待机/移动/攻击或拖时间轴查看。
4. 拖拽松手或输入停顿约 650ms 后自动保存。武器朝向存到 `EquipmentHoldAdjustmentTable.json`，组合键为 `(weaponId,moduleId,hand)`；几何握点存到 `EquipmentGripTable.json`。保存失败保留草稿；外部修改导致 409 时须重读配置，不覆盖外部更改。几何握点的恢复按钮会将该行四个向量恢复为本次读取时的值并保存。
5. 点击“导出游戏配置”沿用现有导表器；重新加载游戏配置后生效。编辑会影响所有引用同一握点 ID 的武器/角色，不只当前预览。重新导出 Unity 网页资源可更新基准动作采样和来源状态。

静态部署仅提供预览，写回需从本机 4177 服务访问；无需进入 Play。武器旋转叠加到各动作的基准朝向，不使用相机角度、不改动作源文件；待机、移动、攻击及附件都应用修正。网页在 20Hz 采样之间插值，双臂从已解算姿势再求解可能有手臂扭转差异，最终复杂动作应在 Unity 复查。

最小验证：`node --test Tools/CharacterPreview/tests/characters.test.mjs Tools/CharacterPreview/tests/grips.test.mjs`。保存测试只写临时工程；握点预览集成测试需要带 `gripEditor.version=2` 的 Unity 导出资源。模组、武器/手别隔离及默认继承：`python Tools/Tests/run_lua.py Tools/Tests/equipment_motion.lua`。
Unity Edit Mode 菜单「验证模块化角色与网页蒙皮」检查实际 Avatar、60 套脸/体型组合、180 个动作采样与 CPU 蒙皮公式，并保存五族男女截图。
`验证全部装备适配` 另覆盖五族的 660 套真实持武组合、19,800 个动作采样和 360 套旧模板装配；`验证武器局部握点微调` 包含非零偏移、旋转与缩放步枪。新资产/新动画仍需复查。
