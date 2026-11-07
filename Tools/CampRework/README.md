# 营地资源与定向检查

本目录服务[营地模块](../../ForAI/Business/Camp.md)。不自动启动 Editor、进入 Play 或全量构建。

## 资源制作与同步

1. Blender MCP 依次运行 `Blender/build_camp.py`、`Blender/build_dressing.py`、`Blender/build_review.py`。前者要求不存在同名制作场景；已有内容须先检查，只可替换本任务所有的对象。源 `.blend` 保留原点处可编辑资产与独立展示副本；源文件、暂存 FBX 和清单在 `Art/CampPresentation`，沿用项目 `/Art` 忽略规则。
2. 将暂存 FBX 复制到 `Assets/DynamicAsset/CampPresentation/Models`，保留已有 `.meta`。C# 修改按项目规范集中编译；资源更新不要求重复编译。
3. 通过 Unity MCP 调用 `ProjectY.Editor.CampAssets.Sync()`，再依次执行 `polish_scene.cs`、`polish_ui.cs`、`install_loadout.cs` 的方法体。最后一步按完整 PawnPartTable 显式绑定动物预览资源，并保留“队伍装备”入口；原角色预览的旧绑定可能未包含动物。基础生成和后续资源绑定共同组成完整安装；不要只运行基础生成后交付。
4. 同步会重建指定 Camp Prefab 和独立营地场景，首次面板备份保存在 `Art/CampPresentation/Integration/CampPanel.before.prefab`。不会保存或重建用户打开的 Adventure 主场景。

`CampAssets.Sync` 保存 LuaReference 与本地化绑定，`polish_ui.cs` 追加 Header 绑定、两侧网格锚点和配色，随后导出 View hints。不要手改 Prefab/场景 YAML。

建筑铭牌由 `CampFacilityTagGraphic` 绘制，保持字体和原按钮事件不变。`apply_tags.cs` 可单独更新四个现有按钮的底图与状态；不必重建整个场景或其他 UI。

## 最小检查

- `python -B Tools/Tests/camp_core.py`：配方、费用、单设施订单、时间规则及 Lua 语法。
- `node Tools/Tests/ui_localization_sources.mjs`：既有源码文案来源检查；原生绑定另在 Unity 检查。
- `pwsh -NoProfile -File Tools/Tests/camp_warehouse_data.ps1 -AssemblyPath Library/ScriptAssemblies/Assembly-CSharp.dll`：独立对象上的网格事务、版本、容量、旋转、迁移；不编译、不读取玩家存档。
- `camp_crafting_data.ps1` 同样使用已编译 DLL，覆盖混合产物、满包与重复领取。
- `camp_equipment_storage.ps1` 使用同一 DLL，覆盖装备实例/耐久/词缀/配件/弹药/器灵保留、目标格、保存与提交、重复背包/仓库归属拒绝。
- `camp_loadout_data.ps1` 使用同一 DLL，覆盖动物唯一引用、火把实物转移、满包保留、旧营地存档迁移、无效记录拒绝和实际行军时间。`torch_core.lua` 检查队伍火把的夜间与开关规则。
- `render_preview.cs` 的 `previewScript` 选择 `Tools/CampRework/loadout_preview.lua`、`captureVariant` 选择 `Loadout`，执行队伍装备的真实按钮/动物预览、即时视野、火把数量及临时存档检查。`torch_editmode.cs` 另验证局部和大地图点光的跟随、开关、实际像素与资源释放。
- 在已有闲置 Unity Editor 中，通过 MCP `execute_code` 执行 `render_preview.cs` 方法体。它加载营地场景，创建独立 PreviewScene/LuaEnv/FrameworkServices，在唯一临时目录保存测试档案，执行 `preview.lua`；最后恢复主场景、时间、随机状态、EventSystem 和文本服务。

原生检查预先创建正常的缓存 Panel 条目，绑定已加载场景后仍调用真实 `CampCtr` 的 Bind/OnShow/Action/OnHide 和 UISystem.Open/Close。此做法避开 Edit Mode 不支持的运行时异步加载，不替代 Play 中的 Additive 加载时序验收。截图中的主世界底图是隔离中性底景。

## 输出

- `Art/CampPresentation/Previews`：原生营地、制作、锻造和仓库截图，及实际验证文本。
- [实施记录](../../Docs/CampSceneUIImplementation.md)：当次完成范围与未验证部分。
