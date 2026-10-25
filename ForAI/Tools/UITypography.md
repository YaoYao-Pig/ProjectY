# UI 字体规则

关键词：字体、Typography、思源宋体、霞鹜文楷、Noto Sans、中文、英文、数字、TMP、字重、字体授权。

## 文档目录

正文：角色与排版 / 资源与授权 / 原生绑定与刷新 / 验证；关键入口：字体 / 清单 / 同步与检查。

## 正文

### 角色与排版

| 文字用途 | 字体 | 排版规则 |
| --- | --- | --- |
| 面板、章节、任务标题，角色名和装备详情名称 | 思源宋体 SC SemiBold | 大标题参考24–32，次级标题18–23；使用真实SemiBold，不额外叠加伪粗体。紧凑图谱节点和HUD标题仍用黑体。 |
| 对话正文、事件描述、任务短文、身世描述、完整句子的对话与事件选项 | 霞鹜文楷 Regular | 正文参考17–20；长段落保留换行及自适应高度。选择项的费用、条件、数值说明继续使用黑体。 |
| 属性、技能数据、奖励金额、列表状态、按钮短标签、小字和战斗数字 | 现有Noto Sans CJK SC／原有黑体通道 | 信息密集区以辨认速度为先；不因组件名含Title就换宋体，也不把整段数值说明换为文楷。 |

- 以上字号是现有Canvas逻辑尺寸下的新界面建议，不是全局强制倍率。本次保留已有字号、颜色、行距、锚点、内边距与自适应布局；英文与数字随所属文字角色使用同一字体。
- 同屏最多使用以上三种角色；朱雀仿宋暂不接入。不要用逐字缩小、截断正文或压缩行距消除溢出，应先检查实际字体的preferredHeight、容器宽度与装饰安全区。
- 中英文、大小写、数字和常用标点均需检查；字体不等于完整Unicode覆盖。特殊符号应单独检查，不能假设备用字体一定有字。

### 资源与授权

- 思源宋体 `SourceHanSerifSC-SemiBold.otf` 为上游2.003；霞鹜文楷 `LXGWWenKai-Regular.ttf` 为1.530，均保留上游原版字体。来源、SHA-256和许可证记录于字体目录的 `Typography-NOTICE.txt`，随游戏分发时保留各自版权声明及OFL全文。
- 两个同名字体 `.asset` 是原生生成的TMP动态SDF资源：64采样、6padding、2048×2048、多图集，引用源字体，备用字体为现有 `NotoSansCJKsc.asset`；源字体不能从构建依赖中移除。UGUI Text使用原始Font，TMP/UITxt使用TMP_FontAsset，不能混用。
- 原有Noto及OS黑体回退通道没有全局改写。尤其Inventory/EquipmentWorkbench的动态小字仍按各自View.Font机制取字，不应把本轮称为全项目黑体统一。

### 原生绑定与刷新

- `roles.json` 是本轮18个Prefab、41处静态字体绑定的明确清单；按语义和实际路径维护，不靠名称模糊匹配全量替换。没有列出的控件保持原字体行为。
- `apply_typography.cs` 通过Unity原生API保存Prefab，只修改清单文字的Font、TMP材质及伪粗体状态，并从现有 `labels`、`richLabels`、`layout.Labels` 字体覆盖列表移除这些控件。列表承担统一字体赋值，布局和LuaReference绑定不依赖移除操作；脚本校验其余序列化字段、层级和绑定完全一致后才保存。
- 动态角色：DialogueEntry保存说话者宋体，交互选项改用自身Body的文楷，复用回普通发言时恢复；StoryChoice在GrowthRow赋值后恢复已绑定文楷，Body保留费用/条件黑体；MissionJournal只为其任务正文行应用Description的文楷，通用NarrativeEntry的正文仍保持黑体，以免影响商店、存档元数据等消费者。
- UI生成器、UX迁移或美术重建可能恢复统一字体列表。重建后先按[美术换皮](UIArtSkins.md)同步布局，再运行字体同步；新控件需增加明确角色，并检查Prepare、SetData和对象池复用是否覆盖字体。仅更新文字内容不应重设字体。
- 文案内容、语言键、配置text字段遵循[本地化约束](../Framework/Localization.md)；字体调整不能替代本地化绑定，不在样式代码复制剧情文字。

### 验证

- 在已有空闲Editor中，通过MCP execute_code依次执行字体资源创建和字体同步；只定向导入字体，不Refresh全工程，不要求新增项目C#或生成xLua桥接。不得自动启动Editor、切换Play或触发编译。
- `verify_typography.cs` 在独立PreviewScene中检查18个Prefab、重复Prepare后的字体、绑定及原生字样；`verify_widgets.lua` 调用真实DialogueEntry/StoryChoice控制器检查交互切换和复用。实际结果记录于本轮[验证记录](../../Art/UITypography/2026-10-25/validation.json)，脚本存在不等于已经通过。
- 完整游戏界面预览沿用UIRefresh入口；它会启动独立游戏模型，因此现有地图/配置错误也可能阻断。应报告阻断和实际覆盖，不能用字体静态检查冒充完整界面联调。

## 关键入口

- [字体与许可](../../Assets/DynamicAsset/UI/Fonts/) / [来源记录](../../Assets/DynamicAsset/UI/Fonts/Typography-NOTICE.txt)。
- [角色清单](../../Tools/UITypography/roles.json) / [创建TMP资源](../../Tools/UITypography/create_font_assets.cs) / [原生字体同步](../../Tools/UITypography/apply_typography.cs)。
- [原生检查](../../Tools/UITypography/verify_typography.cs) / [动态控件检查](../../Tools/UITypography/verify_widgets.lua) / [字符覆盖](../../Art/UITypography/2026-10-25/coverage.json) / [实际迁移](../../Art/UITypography/2026-10-25/application.json)。
