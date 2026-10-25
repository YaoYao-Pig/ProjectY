# UI 美术换皮与资源绑定

关键词：UI 换皮、背景、切图、九宫格、自适应、内边距、preferredHeight、ArtSkin、GuildMatte、CollageMatte、皮革、拼贴、哑光、奖励图标、3D 预览保护。

## 文档目录

正文：职责与范围 / 绑定和显示 / 原生同步与验证；关键入口：资源 / 工具 / 记录。

## 正文

- 标题、叙事正文和数值的字体分工及原生同步见[UI字体规则](UITypography.md)；重建美术或布局后需按该文档恢复明确的字体角色。

- `GuildMatte` 用于 Inventory、CharacterGrowth；`CollageMatte` 用于 MissionJournal、Dialogue、StoryEvent。它们编辑自原08/09图集，保留铜扣/缝线/撕纸/叠层造型，移除烘焙高光和脏纹理；各16张切片。早期 `GuildClean/CollageClean` 为被替换的极简版本，不作为当前风格源。
- `ArtSkin` 只处理 Image/Sprite、字体/颜色、视觉内边距和 Button 过渡，不设置 `interactable`、不提交命令、不改变选项/学习/物品/任务规则。08深皮革按钮与09蓝Tab使用浅字；09任务纸面仅在 MissionJournal 内调整富文本色，不修改共享装备展示。节点圆环仅换Sprite，保留原状态查询、选中缩放与实际技能图标。
- CharacterGrowth、MissionJournal、DialogueEntry、StoryChoice 的根 LuaReference `Skin` 引用共享 `Palette.prefab` 的 LuaReference。它按17个美术角色引用切图（含复用）和6个颜色，运行时只读取，不实例化子节点；字段由 `ArtSkin.Read` 定义。缺资源直接报错。
- MissionJournal 另有 `RewardSkin`，引用6种奖励图标与纸卡/标记条共8张Sprite。原 MissionReward.SetData 仍产生原名称/金额/备注；父面板随后应用美术，非物品奖励替换G/EXP/+占位，已有物品图片保留。`ArtSkin.ApplyReward` 按列宽调用 TMP `GetPreferredValues` 分别排布三段文字并返回卡高；面板的 `RewardsLayout` 显式绑定原 GridLayoutGroup，按最长卡设本批行高。共享 MissionReward 的 `Background/Badge` 绑定不强制其他消费者换皮。
- MissionJournal 仅对自己创建的 NarrativeEntry/TabButton 实例应用皮肤与自适应显示；共享 TabButton 新增 `Sizing`、NarrativeEntry 新增 `Layout/Sizing` 绑定，默认保持中性。`ArtSkin.FitTab` 按文字 preferredWidth 留出边帽，`FitEntry` 用原生布局控制文本高度；不改商店、营地、GM 等消费者的全局样式。装备详情继续使用原富文本及深底。
- DialogueEntry、StoryChoice 显式绑定 `Layout`（VerticalLayoutGroup）和 `Sizing`（LayoutElement），以换行后的 preferredHeight、内边距和最小高度排版，不按字符串长度推算高度。Title/Body 不设固定 preferredHeight，装饰节点忽略布局；父列表控制子项高度且不强制撑高。JournalSkill 使用原生 VerticalLayoutGroup，CharacterGrowth 的技能说明列表按 preferredHeight 排版。九宫格只保护图片边角，文字安全区必须单独设置。
- Dialogue 首次 OnShow 在宿主激活面板之前执行；新发言将滚动请求留到首个可见 Tick，原生布局稳定后再 ScrollToEnd，避免卡片增高后最新发言被视口裁掉。事件标题的红色印刷图形完整留在九宫格左侧固定区，不进入中央拉伸区。
- Inventory 的 `Frame/Equipment/CharacterPreview` 和 CharacterGrowth 的 `Page/Hero/Portrait` 保留原 RectTransform、RawImage、InventoryCharacterView 字段、挂点、八槽引线与绑定；可更换已有二维槽位 Image 的美术，但不能重建预览层级。对话左侧继续是原世界相机，禁止用效果图覆盖。
- 同步顺序为 `apply_matte_complete.cs` → `apply_adaptive_layout.cs`：前者原生导入/保存并修正边界、布局PPU和报酬资源；后者保存十个面板/控件的内边距、原生布局及显式引用，运行于已有空闲 Editor 的 MCP execute_code，不是新增项目 C# 编译。Inventory 槽名只改 Text 对齐/字号，不改预览区域任何 RectTransform；全流程不重建3D、不触发全量Refresh。旧UI生成工具可能重置美术，使用后需重同步并导出对应View hints；旧 `apply_skin.cs` 仅保留历史。
- 图片使用500 PPU与控件0.4倍率配套，避免Image的ILayoutElement最小尺寸撑大文本卡片。按钮纵向完整保留端帽，印刷角花避免进入拉伸中心；最终边界以 `matte/native-import-settings.json` 为准，源manifest只是初步建议。不要只改一个倍率或独立重复执行旧的中间修正脚本。
- 定向验证在已有空闲 Editor 中读取 `render_preview.cs` 交给 MCP execute_code，创建独立 PreviewScene/FrameworkServices 并打开五个真实 Panel，拒绝游戏命令、比较显示前后资源值；不进入 Play、不读写玩家存档。对话验证截图左侧为中性视口，不涵盖世界人物与 Cinemachine 渲染。
- 预览脚本的 captureWidth/captureHeight/captureVariant 可选择输出尺寸与子目录；本轮覆盖1280×720、1024×768，以及复制显示数据构造的长标题/奖励名称/选项。内置几何检查校验文本preferredHeight、卡片内边距、奖励文字相交和Tab宽度，截图仍需检查透明像素与装饰占用的视觉安全区。Inventory没有这些动态Widget，依靠原生截图与3D快照核验，不能用“0项通过”冒充文本几何覆盖。
- `capture_state.cs` 保存原生结构快照；`check_matte_preservation.cjs` 保留原绑定、本地化及组件，仅允许指定控件根追加本轮 VerticalLayoutGroup/LayoutElement，并记录二维 Rect 改动；两处3D字段、RawImage、所有子层级/Rect/组件仍完整严格比较。当前快照覆盖八个资源，不包含 TabButton、NarrativeEntry、JournalSkill；不要把八项报告称作十项布局的全部验证。每次新改动先保存新的基线，不将2026-10-25基线冒充将来项目状态。

## 关键入口

- [ArtSkin.lua](../../Lua/UI/ArtSkin.lua)：显式美术绑定和纯显示状态。
- [GuildMatte](../../Assets/DynamicAsset/UI/Skins/GuildMatte/) / [CollageMatte](../../Assets/DynamicAsset/UI/Skins/CollageMatte/)：当前切图和共享Palette；奖励资源位于CollageMatte/Rewards。
- [美术同步](../../Tools/UIRefresh/apply_matte_complete.cs) → [自适应同步](../../Tools/UIRefresh/apply_adaptive_layout.cs) / [结构快照](../../Tools/UIRefresh/capture_state.cs) / [保护检查](../../Tools/UIRefresh/check_matte_preservation.cjs)。
- [原生预览宿主](../../Tools/UIRefresh/render_preview.cs) / [五界面预览数据](../../Tools/UIRefresh/preview.lua)。
- [审查与源图](../../Art/UIRefresh/2026-10-25/matte/) / [结构检查](../../Art/UIRefresh/2026-10-25/matte/preservation-check.json) / [原生检查](../../Art/UIRefresh/2026-10-25/matte/native/checks.txt) / [实际导入边界](../../Art/UIRefresh/2026-10-25/matte/native-import-settings.json)。
- 固定/动态文案仍遵循[本地化](../Framework/Localization.md)，界面生命周期仍遵循[UI](../Framework/UI.md)。
