# 音乐与战斗音效
关键词：Audio、BGM、音乐、音效、击中、受击、淡入淡出、CC0、Wwise。

## 文档目录
正文：所有权 / 事件与时序 / 素材与验证；关键入口：服务 / 表现 / 素材。

## 正文

- 当前使用 Unity 原生 `AudioSource`，无 Wwise 依赖。`FrameworkServices` 内部持有 `GameAudioService`，由 `GameBootstrap` 初始化、按 unscaled delta 推进、应用暂停并在退出释放。没有新增 xLua 公共 API，也不新增场景组件绑定。
- 服务用两个 2D 音乐源循环播放并交叉淡化；重复选择同曲不会重启，中途反向切换从当前音量继续。16 个音效声源复用，每 cue 有冷却、并发上限、不连续重复的变体和小幅音高随机；只使用独立随机源。
- `AdventureAudio` 按显示阶段切换：菜单/非战斗为 exploration、部署与战斗为 battle；致死末击的待播队列完成后恢复探索。音效与棋子/特效使用相同 impactDelay、shot 间距和 presentation delta，慢动作及暂停不会让待播声提前；跳过表现、重建地图和销毁清理待播声。
- `AudioEvents.Record` 接收 `Battle:Emit` 的已结算事件，仅记录正数、非周期、非自身的直接伤害；同一次快照中相同 source/target/shot 去重，连发保留原 shot。队列上限128，DemoBridge 随快照一次性 Drain；共用 `VisualEffects.Clear` 的新战斗/重开/读档/关闭清理边界。战斗结束不清掉致死末击。
- 每条命中同时播放 hit（金属短响）和 hurt（柔和身体撞击），敌我相同；当前不按武器、种族或元素细分，也不包含挥空、脚步、对白或 UI 音效。2D旧棋盘使用零动画延迟。
- 战斗结束先推进末击、连发间隔及短尾音，再同步战利品/结果弹窗，避免弹窗暂停世界导致末击迟播；这一等待仅阻断表现期输入，不延后玩法结算或再次执行战斗规则。
- [catalog](../../Assets/GameFramework/Resources/Audio/catalog.json)维护资源路径、增益和并发。默认总音量/音乐/音效为 .8/.45/.8；`SetVolumes` 以 `ProjectY.Audio.Master/Music/Effects` 保存到 PlayerPrefs。本版提供服务接口，尚无玩家设置面板。
- 导入器对 Music 使用 Streaming/Vorbis、不预载，对 Effects 使用 DecompressOnLoad/PCM/单声道预载。素材只使用本批核实的 CC0 文件，作者/下载地址/hash/许可见 [来源记录](../../Art/Audio/README.md)。
- 最小事件检查：`python -B Tools/Tests/run_lua.py Tools/Tests/audio_events.lua`。Editor 后端检查为 [audio_editmode.cs](../../Tools/Tests/audio_editmode.cs)，仅在已打开的非 Play Editor 用 MCP `execute_code` 运行；不启动游戏、不发声，检查资源、切换、池容量、暂停与释放。游戏内响度、混音和循环听感须另行实机验收。

## 关键入口
- [GameAudioService](../../Assets/GameFramework/Runtime/Audio/GameAudioService.cs) / [GameAudioImport](../../Assets/GameFramework/Editor/GameAudioImport.cs)：播放及导入策略。
- [AudioEvents.lua](../../Lua/Game/Presentation/AudioEvents.lua) / [AdventureAudio](../../Assets/GameFramework/Samples/Adventure/AdventureAudio.cs)：结算筛选、快照桥与动画时序。
- [FrameworkServices](../../Assets/GameFramework/Runtime/Lua/FrameworkServices.cs) / [GameBootstrap](../../Assets/GameFramework/Runtime/Lua/GameBootstrap.cs)：所有权与生命周期。
