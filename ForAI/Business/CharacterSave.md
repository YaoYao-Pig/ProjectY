# 角色与共享背包存档
关键词：角色存档、保存队伍、读取队伍、磁盘保存、外观持久化、CharacterSave。

## 文档目录
正文：范围 / 提交流程 / 验证；关键入口：状态 / 服务 / Lua / HUD。

## 正文

- 探索 HUD 的菜单提供“保存队伍”和“读取队伍 · 重新开始地图”。只允许 map/area 阶段；这是手动存档，重开后点击读取。开始新远征不覆盖磁盘上的队伍档案。
- 单槽路径为 `Application.persistentDataPath/Characters/party-v1.json`。保存四人以内的角色 ID/模板、完整外观、HP/MaxHP、特质、等级经验、属性/天赋投入、已学技能、待选队列及养成 RNG；另保存金币/玩家等级、武器与配件、弹匣余弹、防具所有权、堆叠数量和背包布局。
- 不保存地图探索、地点访问、事件、战斗、移动路径或故事日志。读取时使用存档种子重新生成地图，再替换队伍和库存；新地图敌群重新生成，角色保留受伤/倒地状态。
- 文档版本现为 3，保存角色/坐骑的持续 GameEffect 实例与时长、周期、层数、数值快照；版本 1/2 明确迁移为空效果列表。同一文件还保存[叙事状态](Narrative.md)：任务/阶段状态、击杀计数与激活起点、事实、NPC 好感/招募、阵营声望和游戏时钟；临时对话不保存，对话中禁止读写。版本 1 明确迁移为新叙事初始状态；其他未知版本拒绝。
- 可变状态仍归 C# Data。`CharacterSaveState` 是这些 Data 的内部序列化实现，不能在 Lua 另存一套角色/库存。恢复时保留 `EquipmentData` 对象身份，避免系统缓存指向旧库存。
- 保存先在内存验证，再写入同目录临时文件并 Flush，以 Replace/Move 提交；已有档案保留 `.bak`。文件上限 1 MiB。读取先准备独立角色和库存，检查版本、数值、重复 ID、装备所有权、背包占格和外观，再由 Lua 核对当前配置与动作模组；全部通过才重建地图并提交。
- 损坏文件、未知版本、失效配置或背包重叠都明确报错，保持当前队伍；不会静默生成默认角色或自动把不兼容存档当作有效数据。当前支持版本 1/2→3 的显式兼容。
- 定向检查 `Project Y/角色/验证外观生成与角色存档` 使用 OS 临时文件和独立 Edit Mode LuaEnv，覆盖保存/覆盖、外观与伤势、升级/属性/天赋/技能/候选/RNG、背包、敌人重进稳定、HUD 入口、损坏与未知版本拒绝；不触碰用户存档。

## 关键入口

- [保存服务](../../Assets/GameFramework/Runtime/Data/CharacterSaveService.cs) / [Data 序列化](../../Assets/GameFramework/Runtime/Data/CharacterSaveState.cs)。
- [配置校验与读写命令](../../Lua/Game/Adventure/CharacterSave.lua) / [HUD](../../Lua/Game/Adventure/MainHudModel.lua) / [桥接](../../Lua/Game/Adventure/DemoBridge.lua)。
- [Editor 验证](../../Assets/GameFramework/Editor/CharacterIntegrationValidation.cs) / [真实集成检查](../../Tools/Tests/character_integration.lua)。
