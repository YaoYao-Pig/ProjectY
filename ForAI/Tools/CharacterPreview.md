# 角色工坊
关键词：角色网页、Character Lab、角色工坊、捏人、组合、随机、种子、4177、真实 Unity 资源、offset、握点编辑、自动保存。

## 文档目录
正文：使用 / 资源一致性 / 验证；关键入口：服务 / 前端 / 导出。

## 正文

- 默认地址 `http://127.0.0.1:4177`；工程根运行 `node Tools/WebServices/manage.mjs start character-preview`。已注册到[Web 服务管理](WebServices.md)，可通过 Editor 服务管理窗口启停和打开。
- 提供五族男女、三档体型、脸型、有效发型与颜色选择；支持锁定种族/性别随机、种子重现、转动/缩放、动作播放暂停/进度/速度、外观 JSON 查看、复制、下载与导入。龙人自动过滤会撞角的全包发型。
- Unity 菜单 `Project Y/角色/同步模块化角色资源` 更新资源目录、装备贴合与 PawnRig 绑定；`导出角色网页资源` 从实际 Mesh、材质、bind pose、动作采样和根偏移生成 `public/data/characters.json`。未持武时展示六类基础动作；11 个持武组合从实际 PawnView/Tick 与握点求解采样，提供持握待机、持械行走和武器动作。
- 试穿包含三种头饰、三种护甲、裤靴、披风/箭袋、九种武器及双持/剑盾组合，展示所选[动作模组](../Business/EquipmentMotion.md)和局部握点。挂点下的符文、弹匣和推进器也来自真实资源。头饰覆盖发型时保留选项，卸下恢复；试穿状态不写入角色外观 JSON 或游戏库存。
- “武器朝向与握点”默认编辑武器本身的旋转，按[持握专属旋转契约](../Business/EquipmentMotion.md)分别保存武器型号/模组/主副手；页面显示作用范围、继承/专属状态，“恢复模组默认朝向”删除该组合修正。选主握点或第二握点则编辑原有共享几何数据，可平移、旋转或输入 XYZ。开启后暂停，可聚焦和播放动作复查；拖拽结束或输入停顿后自动保存，不属于外观 JSON。
- `gripEditor.version=2` 导出 moduleId、itemId/gripId、已采样的 rotationOffset、刚体归属、Prefab 缩放、手掌挂点局部变换及双臂参数。网页从采样朝向移除旧修正，再应用当前组合修正，避免重复叠加；附件保留相对武器变换。旧资源包可继续预览，重新导出后才能编辑。骨架基于已解算的动作采样重算，双手共持的手臂扭转细节可能与 Unity 原始动画重新求解不同，最终姿势在 Unity 复查。
- `/api/grips` 从当前源表读取，PUT 只更新指定行的 main/off Position/Rotation；要求本机 Host/Origin、会话令牌、有限 Vector3 和版本一致，复用现有配置校验与原子写入。冲突/保存失败保留草稿并停止自动重试，重读会提示丢弃未保存草稿。仅数值变化不触发 Unity 编译。
- `/api/hold-adjustments` 的 PUT 按 weaponId/moduleId/hand 更新专属旋转，rotationOffset=null 删除该组合覆盖；复用同一保存队列、令牌与版本，版本包含握点/武器/模组/修正表。重复组合与非法向量拒绝保存；修改某组合不会改写几何握点或其他组合。
- “导出游戏配置”调用现有导表器生成游戏产物；游戏配置缓存无热重载，重新加载后生效。网页读取源表即可预览保存的握点，Unity 最终动作采样仍通过“导出角色网页资源”刷新。
- 资源包包含 29 个基础模块、42 个装备贴合网格和 42 个身体遮挡网格。武器等刚体逐帧记录实际挂点修正后的变换，不近似为固定绑手骨；骨骼和刚体都转换坐标，浏览器在采样之间插值。
- 网页用同一目录与 uint32 随机算法，使用 Unity 导出的固定种子结果校对；从 Unity 左手坐标转换到网页右手坐标时同步转换顶点、法线、bind pose、姿势，并反转三角形绕序。不能把 Blender 单独生成的几何替代这一导出链路。
- `public/` 可独立部署为静态站点，不依赖 Editor，也不访问 CDN；Three.js 0.180.0 模块和 MIT LICENSE 本地分发。光照由浏览器渲染，不承诺与 Unity 逐像素一致。待机展示台属于预览布景，播放动作时隐藏以避免遮住真实姿势。
- 导出包记录 Unity 来源依赖及 SHA-256。本地服务 `/api/source-status` 检测文件修改/缺失；网页提示重新同步导出。资源包不会随模型修改自动更新；独立部署时没有工程源文件，明确显示无法校对源工程。
- 服务只监听 loopback，检查 Host/Origin，生命周期复用统一宿主；握点保存/导出之外的资源接口只读。静态部署仍支持角色预览，但禁用配置编辑。资源包缺失不显示伪造模型，直接提示 Unity 导出入口。
- 外观 JSON 使用[角色定制契约](../Business/PawnCustomization.md)。返回 Unity 的 `从网页外观 JSON 创建预览 Prefab` 入口验证并创建独立预设；游戏的敌群池和[角色存档](../Business/CharacterSave.md)由业务配置与 Data 管理。
- 最小检查 `node --test Tools/CharacterPreview/tests/characters.test.mjs Tools/CharacterPreview/tests/grips.test.mjs` 覆盖资源、随机、来源、服务边界、临时工程写回/冲突/导表、缩放坐标、双臂骨长、附件归属和武器旋转隔离；要求新版导出包。Lua 解析用 `python Tools/Tests/run_lua.py Tools/Tests/equipment_motion.lua`。交互另用浏览器确认拖拽、组合切换和保存。

## 关键入口

- [使用说明](../../Tools/CharacterPreview/README.md) / [注册表](../../Tools/WebServices/services.json) / [服务](../../Tools/CharacterPreview/server.mjs)。
- [页面](../../Tools/CharacterPreview/public/index.html) / [预览与交互](../../Tools/CharacterPreview/public/app.mjs) / [随机规则](../../Tools/CharacterPreview/public/rules.mjs)。
- [握点编辑](../../Tools/CharacterPreview/public/grip-editor.mjs) / [握点求解](../../Tools/CharacterPreview/public/grip-math.mjs) / [配置读写](../../Tools/CharacterPreview/grip-store.mjs)。
- [Unity 导出](../../Assets/GameFramework/Editor/PawnCustomizationAssets.cs) / [资源包](../../Tools/CharacterPreview/public/data/characters.json) / [检查](../../Tools/CharacterPreview/tests/characters.test.mjs)。
