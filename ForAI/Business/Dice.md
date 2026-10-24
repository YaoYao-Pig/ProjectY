# 实体检定骰子
关键词：骰子、检定、投掷、D4、D6、D8、D10、D12、D20、DiceRoll、百分比。

## 文档目录
正文：资源 / 接入与结算 / 演出与生命周期 / 最小验证；关键入口：模型 / Lua / Unity。

## 正文

- 深色珐琅、金色面框与数字、蓝色角饰的实体骰子包含 D4/D6/D8/D10/D12/D20，以及百分比十位 D100（00–90）。D10 为 0–9；D4 读顶部顶点，三个相邻面使用同一顶点数字。源文件和制作脚本在 `Art/Dice`，显式导出的 FBX 在 `Assets/DynamicAsset/Dice/Models`；不直接导入 `.blend`。
- 本轮仅接入非战斗检定：探索障碍的非必然成功尝试、探索驯服、事件概率效果。普通剧情属性门槛维持确定性查询，不自动改为掷骰；没有配置骰子的剧情不凭空添加 D20 检定。
- `DiceChecks.Percent` 只把已结算事实转换为展示请求，不抽取随机数。障碍沿用 1–100、`roll <= chance`，00+0 读作 100；事件效果沿用 0–99、`roll < chance`，00+0 读作 0；驯服沿用 0–99.99 与百分位阈值，增加两颗小数位 D10。停稳后标签标明每颗的位数。保留结算概率、随机流、扣费与重复提交保护。
- 玩家界面只显示 `DiceRequirement` 的“要求：%s”，不附加算法/读法解释。要求、位数、检定结果、按钮与检定标题前缀均走 [Language/LuaTxt](../Framework/Localization.md)，固定按钮由 Prefab 的语言绑定初始化。
- `AdventureEvents.CheckResolved` 发布探索结果；探索驯服发布到同一入口。`MainHudCtr` 在可见生命周期订阅它，并从已有 Battle.Changed 中仅收集非 battle 阶段的概率效果检定。`DiceRollCtr` 顺序展示同一次操作产生的多个请求，快速揭晓只结束当前演出，不重抽结果、不重做结算。
- `DiceRoll` 使用既有 UI 框架的 Overlay 模态窗口与世界暂停租约，不允许 Back 关闭；支持快速揭晓、结果后继续、缓存重开与换场景释放。UI 引用全部由保存的 LuaReference 获取。
- `DiceRollView` 以独立 PhysicsScene 预计算真实刚体轨迹，再用未缩放时间播放，带短拖尾、碰撞光环与结果光环。用多面体旋转对称性调整数字朝向，保持整个碰撞轮廓和轨迹不变，确保最终上方面值对应已结算结果；不是用物理重新决定业务成败。投掷最多六颗。
- 离屏相机使用项目 URP 预览 Renderer，通过透明 RawImage 叠加。相机、刚体、材质实例、RenderTexture 和临时物理场景均归 View；Hide/Dispose 释放。结果稳定后停止重复离屏渲染，尺寸变化时重建目标。
- `Project Y/UI/同步实体检定骰子` 通过 Unity API 导入模型、合并视觉网格、提取独立碰撞网格及面值标记，创建材质、Catalog 和可编辑 Panel；重跑保留已编辑 UI 布局。未来调整布局或绑定需通过 Unity API/MCP 保存，不手改 YAML。
- 最小验证：`python -B Tools/Tests/run_lua.py Tools/Tests/dice_checks.lua` 检查百分比边界与精度；`event_choice_effects.lua` 检查原事件结算。Unity 菜单 `Project Y/UI/验证实体检定骰子` 使用独立临时物理场景，检查模型旋转对称性、七种骰子面值、真实 xLua 调用、跳过/重开、资源释放和 Overlay 绑定，并输出 `Art/Dice/UnityPreview`。不进入 Play、不读写玩家存档。
- [完整窗口检查](../../Tools/Tests/dice_overlay.cs) 是 Unity MCP `execute_code` 片段，使用真实 UIHost、UISystem、Lua 控制器和按钮，检查暂停租约、Back 阻断、连续检定、快速揭晓、缓存重开与场景释放，同时输出最终 UI 合成图。Edit Mode 使用自带独立物理环境的 PreviewScene，运行时使用 LocalPhysicsMode.Physics3D 场景。

## 关键入口

- [模型制作](../../Art/Dice/Scripts/build_dice.py) / [源文件](../../Art/Dice/DiceSet.blend) / [灯光展示](../../Art/Dice/Scripts/showcase.py)。
- [DiceChecks.lua](../../Lua/Game/Presentation/DiceChecks.lua) / [DiceRollCtr.lua](../../Lua/UI/Panel/DiceRollCtr.lua) / [MainHudCtr.lua](../../Lua/UI/Panel/MainHudCtr.lua)。
- [DiceRollView.cs](../../Assets/GameFramework/Runtime/UI/DiceRollView.cs) / [DiceCatalog.cs](../../Assets/GameFramework/Runtime/UI/DiceCatalog.cs) / [DiceAura.shader](../../Assets/GameFramework/Resources/DiceAura.shader)。
- [资源同步](../../Assets/GameFramework/Editor/DiceAssets.cs) / [独立验证](../../Assets/GameFramework/Editor/DiceValidation.cs) / [Lua 检查](../../Tools/Tests/dice_checks.lua)。
