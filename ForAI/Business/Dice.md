# 实体检定骰子与优势判定
关键词：骰子、检定、优势判定、两次取最高、CheckRoll、投掷、D4、D6、D8、D10、D12、D20、DiceRoll、百分比。

## 文档目录
正文：资源 / 接入与结算 / 演出与生命周期 / 最小验证；关键入口：模型 / Lua / Unity。

## 正文

- 深色珐琅、金色面框与数字、蓝色角饰的实体骰子包含 D4/D6/D8/D10/D12/D20，以及百分比十位 D100（00–90）。D10 为 0–9；D4 读顶部顶点，三个相邻面使用同一顶点数字。源文件和制作脚本在 `Art/Dice`，显式导出的 FBX 在 `Assets/DynamicAsset/Dice/Models`；不直接导入 `.blend`。
- 已接入探索障碍、探索/世界接触驯服、事件概率效果，以及[动物交谈](Animals.md)的沟通检定（含战斗中交谈）。普通剧情属性门槛维持确定性查询，不自动改为掷骰；没有配置骰子的剧情不凭空添加 D20 检定。
- `DiceChecks.Percent` 只把已结算事实转换为展示请求，不抽取随机数。障碍沿用 1–100、`roll <= chance`；普通驯服与沟通沿用 0–99.99 与百分位阈值，增加两颗小数位 D10。附加效果通过元数据声明高值大于门槛成功。百分骰的 00+0 按请求约定读作 0 或 100；展示不改变概率、扣费与重复提交保护。
- `Game.CheckRoll.Resolve(threshold,precision,roll,sources)` 由业务传入自身随机流，`threshold` 是可成功的原始整数结果数量，精度为 1 或 100。无来源抽一次，有来源去重后仍只抽两次，将原始值转换为高值并取最大；相同值取第一项，不补投。返回 `rolls/selectedIndex/roll/threshold/chance/effectiveChance/advantageSources`，其中 `chance` 为单次概率。高地触发见[战斗](Battle.md)，沟通触发与消费见[动物](Animals.md)。
- `DiceChecks.Resolved` 将优势结算变成一个含两轮的请求，`DiceRollCtr` 每轮最多四颗骰子顺序播放；第一轮只显示掷值，第二轮展示两值并加粗最高值及最终成败。继续先播放下一轮，再处理其他判定；快速揭晓、缓存重开和日志均不重抽。`FromBattleEvent` 优先读取 `impact.check`；战斗命中通过日志展示两值，不因此额外弹出模态骰子窗。
- 普通检定显示 `DiceRequirement`；优势显示来源、单次高值门槛和实际成功率。要求、位数、结果、按钮与标题均走 [Language/LuaTxt](../Framework/Localization.md)，固定按钮由 Prefab 的语言绑定初始化。
- `AdventureEvents.CheckResolved` 发布探索结果；探索驯服发布到同一入口。`MainHudCtr` 在可见生命周期订阅它，并从已有 Battle.Changed 中仅收集非 battle 阶段的概率效果检定。`DiceRollCtr` 顺序展示同一次操作产生的多个请求，快速揭晓只结束当前演出，不重抽结果、不重做结算。
- `DiceRoll` 使用既有 UI 框架的 Overlay 模态窗口与世界暂停租约，不允许 Back 关闭；支持快速揭晓、结果后继续、缓存重开与换场景释放。UI 引用全部由保存的 LuaReference 获取。
- [GM 自由投骰](../Tools/GM.md) 使用 `kind='roll'` 的已抽取请求，包含 `dice/detail/reading`，不需要 `passed`，结果仅展示逐颗面值与合计。普通检定仍要求布尔 `passed` 并显示成功/失败；同一缓存窗口切换两种请求时恢复各自的结果字号。GM 使用独立随机序列，View 和快速揭晓均不能重抽。
- `DiceRollView` 以独立 PhysicsScene 预计算真实刚体轨迹，再用未缩放时间播放，带短拖尾、碰撞光环与结果光环。用多面体旋转对称性调整数字朝向，保持整个碰撞轮廓和轨迹不变，确保最终上方面值对应已结算结果；不是用物理重新决定业务成败。投掷最多六颗。
- 骰子从左侧同一出手区域紧凑释放，颗粒间有极短错拍，初始位形不重叠；共享向前抛出的速度，再由物理处理接触、弹跳和散开。最初 1.2 秒按物理时间播放，仅压缩后段落稳时间；镜头按接触桌面后的轨迹构图，不把出手点一起缩进画面。光环仅在碰撞或结果阶段显示。快速揭晓使用该次实际播放时长。
- 离屏相机使用项目 URP 预览 Renderer，通过透明 RawImage 叠加。相机、刚体、材质实例、RenderTexture 和临时物理场景均归 View；Hide/Dispose 释放。结果稳定后停止重复离屏渲染，尺寸变化时重建目标。
- `Project Y/UI/同步实体检定骰子` 通过 Unity API 导入模型、合并视觉网格、提取独立碰撞网格及面值标记，创建材质、Catalog 和可编辑 Panel；重跑保留已编辑 UI 布局。未来调整布局或绑定需通过 Unity API/MCP 保存，不手改 YAML。
- 最小验证：`python -B Tools/Tests/run_lua.py Tools/Tests/dice_checks.lua` 检查百分比边界与精度；`event_choice_effects.lua` 检查原事件结算。Unity 菜单 `Project Y/UI/验证实体检定骰子` 使用独立临时物理场景，检查模型旋转对称性、七种骰子面值、真实 xLua 调用、跳过/重开、资源释放和 Overlay 绑定，并输出 `Art/Dice/UnityPreview`。不进入 Play、不读写玩家存档。
- [完整窗口检查](../../Tools/Tests/dice_overlay.cs) 是 Unity MCP `execute_code` 片段，使用真实 UIHost、UISystem、Lua 控制器和按钮，检查暂停租约、Back 阻断、连续检定、快速揭晓、缓存重开与场景释放，同时输出最终 UI 合成图。Edit Mode 使用自带独立物理环境的 PreviewScene，运行时使用 LocalPhysicsMode.Physics3D 场景。
- [投掷定向检查](../../Tools/Tests/dice_throw_motion.cs) 覆盖单颗、百分比双骰、六种混合骰的紧凑出手、显著前移、初段物理时间和所有面值一致性；完整窗口检查输出两颗检定骰及六种混合骰各 60 帧，通过 [预览编码脚本](../../Art/Dice/Scripts/encode_preview.py) 生成 `DiceRoll.gif` 与 `DiceHandful.gif`。

## 关键入口

- [模型制作](../../Art/Dice/Scripts/build_dice.py) / [源文件](../../Art/Dice/DiceSet.blend) / [灯光展示](../../Art/Dice/Scripts/showcase.py)。
- [DiceChecks.lua](../../Lua/Game/Presentation/DiceChecks.lua) / [DiceRollCtr.lua](../../Lua/UI/Panel/DiceRollCtr.lua) / [MainHudCtr.lua](../../Lua/UI/Panel/MainHudCtr.lua)。
- [共享结算](../../Lua/Game/CheckRoll.lua) / [优势核心检查](../../Tools/Tests/advantage_checks.lua) / [两轮演出检查](../../Tools/Tests/dice_checks.lua)：离线覆盖精度、阈值、概率、次数、跳过与重播；真实 UI 布局仍需 Unity 验收。
- [DiceRollView.cs](../../Assets/GameFramework/Runtime/UI/DiceRollView.cs) / [DiceCatalog.cs](../../Assets/GameFramework/Runtime/UI/DiceCatalog.cs) / [DiceAura.shader](../../Assets/GameFramework/Resources/DiceAura.shader)。
- [资源同步](../../Assets/GameFramework/Editor/DiceAssets.cs) / [独立验证](../../Assets/GameFramework/Editor/DiceValidation.cs) / [Lua 检查](../../Tools/Tests/dice_checks.lua)。
