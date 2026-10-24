# 技能图标生成管线
关键词：技能图标、像素、低细节、生成配方、SkillIconRecipeTable、SkillIconStyleTable、BattleIconTable。

## 文档目录
正文：配置与归属 / 生成与发布 / 视觉验收；关键入口：表 / 工具 / Unity。

## 正文

- 风格归 `SkillIconStyleTable`，每个技能的画面主体归 `SkillIconRecipeTable`；均为正式配置表，可在内容中心“技能与特质”编辑。配方 `skillId` 关联真实技能，`id` 是发布后的稳定图标 ID，不能随排序重排。提示词是开发美术资料，不作为玩家文本。
- 运行时沿用 `CombatSkillTable.iconId → BattleIconTable.spritePath → BattleHUDView` 的序列化 Sprite。未生成的配方保留旧映射；发布后仅切换对应技能。技艺图谱、天赋与属性的字符符号属于独立入口，本管线不修改它们。
- `node Tools/SkillIcons/cli.mjs prepare --skill 1,2,3,4,5` 生成任务；`--all` 准备全部配方。任务保存完整提示词及配方摘要。每个任务调用一次内置 `image_gen`，要求透明背景；工具不会自己联网或读取 API 密钥。
- 查看生成图片并按下列标准验收后，执行 `node Tools/SkillIcons/cli.mjs publish --skill 1 --image <生成PNG的绝对路径> --job Art/SkillIcons/Jobs/10001.json --reviewed`。发布校验任务未过期、文件格式与资源归属，归档原图、保存版本、回填对应图标和技能配置；不手改 `.meta` 或 Prefab YAML。
- 原图在 `Art/SkillIcons/Sources/`，生成记录在 `Art/SkillIcons/manifest.json`，游戏资源在 `Assets/DynamicAsset/UI/Icons/Skills/`。重新生成使用新版本；相同配方与原图重复发布复用现有版本。配置、清单和资源应一起提交。
- 发布后先执行 `node Tools/ConfigEditor/exporter.mjs`，再在已有、空闲的 Unity Edit Mode 执行 `Project Y/UI/导入技能图标并同步引用`。菜单按风格导入 Single Sprite / Point / 无 mipmap / 无压缩，并调用现有 HUD 引用同步；不启动 Editor 或进入 Play。游戏配置无热重载。
- `node Tools/SkillIcons/cli.mjs status` 区分待生成与已发布；`validate` 校验已发布的配方、文件摘要和配置引用。配方变化需重做生成与视觉检查，不能仅更新摘要。文件校验不能自动证明图意正确或细节足够少。

视觉验收遵循[技能图标美术风格](../Business/SkillIconArt.md)，以已认可的首批五张为基准；检查实际 32/64 像素与深浅背景，保持单主体、大色块、最多一层阴影和低细节。图意与同类技能的轮廓差异属于人工验收，不能用文件格式或 hash 校验代替。

最小检查：`node --test Tools/SkillIcons/tests/*.test.mjs`、发布后 `validate`，以及 `python -B Tools/Tests/run_lua.py Tools/Tests/skill_icons.lua`，后者使用实际导出表独立验证图标加载。涉及 HUD 行为时再运行 `battle_hud_core.lua`。Unity 的[全目录检查](../../Tools/Tests/skill_icons_catalog_editmode.cs) 检查全部配方的导入设置、独立/嵌套 HUD 绑定，并分页渲染 96/64/32 px 与浅色背景预览；其中 `usePublished=false` 可先检查 `Art/SkillIcons/Candidates/<recipeId>.png`，`onlySkills` 可限制当批技能。[首批基准检查](../../Tools/Tests/skill_icons_editmode.cs) 继续保留五张认可图的预览；不默认运行完整战斗测试或构建。

## 关键入口

- [配方表](../../Config/Tables/Adventure/SkillIconRecipeTable.json) / [风格表](../../Config/Tables/Adventure/SkillIconStyleTable.json)：主体、统一风格与导入尺寸。
- [CLI](../../Tools/SkillIcons/cli.mjs)：准备、发布、状态及校验。
- [SkillIconAssets.cs](../../Assets/GameFramework/Editor/SkillIconAssets.cs)：`ImportPublished` 原生导入与引用同步。
- [战斗 HUD](../Business/BattleHUD.md)：运行时图标契约；[配置管线](../Framework/Config.md)：导表与加载。
