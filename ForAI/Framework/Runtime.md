# Lua 运行时

关键词：启动、LuaSystem、依赖、Tick、require、Lua 文件、构建、xLua、退出。

## 文档目录

正文：加载与生命周期 / 修改与验证；关键入口：C# 宿主 / Lua 注册 / 构建。

## 正文

- `GameBootstrap` 持有唯一常驻 `LuaEnv`，注入 `Services`，加载 `Main`；Unity 帧、暂停、返回和退出事件转给 Lua。
- `Main` 返回现有注册器供工具查询；Editor 主线程注入、Python 入口与执行限制见 [LuaConsole](../Tools/LuaConsole.md)。其 LuaFunction 缓存随 ReleaseCallbacks 释放。
- C# 可通过 `GameBootstrap.CallModule` 调用返回函数的 Lua 模块，复用现有 LuaEnv 与 require 缓存；调用方必须在当前调用内释放返回的 LuaTable/LuaFunction。它使用既有 `LuaFunction.Call`，不新增委托桥接；[地图运行测试](../Tools/MapRuntimePreview.md) 使用此入口读取一次性的显示快照。
- 游戏 Lua 源码位于工程根 `Lua/`，使用原生 `.lua`。`require('Game.Systems')` → `Lua/Game/Systems.lua`；自定义 loader 读字节、去 UTF-8 BOM，保留真实调试路径。配表结构、Manifest 和 Catalog 位于 `Lua/_Gen`，通过 `_Gen.*` 模块加载并随源码一起打包。第三方 xLua 内部资源不属于此迁移范围。
- 编辑器直接读根 `Lua/`；构建先导表，再把源文件加入成品 `StreamingAssets/Lua/`。不维护 `Assets/StreamingAssets/Lua` 副本；UI/Types 的编辑器提示不进入构建。模块路径使用标识符，构建拒绝额外点号和大小写冲突。
- 当前磁盘 loader 面向 Windows；Android/WebGL 的 URI 路径需另行实现异步预加载，不能直接沿用。
- 常驻 System 继承 `Core.LuaSystem`，在 `Game.Systems` 注册依赖。注册器按依赖排序：全部 `OnInit` → 全部 `OnStart`；运行中派发 `Tick/FixedTick/LateTick/OnPause`，逆序 `OnShutdown`。当前顺序为 Config → Localization → PlayerModel → Map → MapArea → Battle → AdventureEvents → Adventure → UI；[Map](../Business/Map.md) 与 [MapArea](../Business/MapArea.md) 仅依赖 Config，按需生成布局；[战斗](../Business/Battle.md)和[远征事件](../Business/Adventure.md)启动只加载配置，显式 Start 才创建玩法会话。
- 缺依赖、循环依赖使启动失败并回收已进入初始化的实例；运行回调报错仅禁用该 System，依赖它的系统不会自动停用。
- 退出先解除 C#→Lua 回调、监听和 UI 引用，再 Dispose LuaEnv。保留 `ReleaseCallbacks` 的独立栈帧与 `NoInlining`，避免 Mono 临时委托引用阻止关闭。

修改与验证：新 System 补注册和依赖；新增 C# 服务经 `FrameworkServices` 暴露。更改跨语言 API/委托后检查 `XLuaBindings`，执行 **XLua → Generate Code**，不手改 `Assets/XLua/Gen/`。Lua 逻辑用 `python Tools/Tests/run_lua.py`；桥接/生命周期用 Unity **Project Y → Tests → Run Integration Checks**；加载和构建变更还需验证实际 Player。历史结果见索引中的验证记录。

## 关键入口

- [GameBootstrap.cs](../../Assets/GameFramework/Runtime/Lua/GameBootstrap.cs)：`Awake / ReleaseCallbacks / Shutdown`；[FrameworkServices.cs](../../Assets/GameFramework/Runtime/Lua/FrameworkServices.cs)：服务边界。
- [LuaFileLoader.cs](../../Assets/GameFramework/Runtime/Lua/LuaFileLoader.cs)：`Load`；[LuaScriptPaths.cs](../../Assets/GameFramework/Runtime/Lua/LuaScriptPaths.cs)：`RuntimeRoot`。
- [Main.lua](../../Lua/Main.lua)：宿主回调；[LuaSystem.lua](../../Lua/Core/LuaSystem.lua)：生命周期基类；[SystemRegistry.lua](../../Lua/Core/SystemRegistry.lua)：`Register / Start / Dispatch / Shutdown`。
- [Systems.lua](../../Lua/Game/Systems.lua)：业务注册入口；[FrameworkTools.cs](../../Assets/GameFramework/Editor/FrameworkTools.cs)：`FrameworkBuildGate.PrepareForBuild`；[LuaBuildFiles.cs](../../Assets/GameFramework/Editor/LuaBuildFiles.cs)：构建文件校验。
- [XLuaBindings.cs](../../Assets/GameFramework/Editor/XLuaBindings.cs)：桥接声明；[FrameworkValidation.cs](../../Assets/GameFramework/Editor/FrameworkValidation.cs)：Unity 集成检查。
