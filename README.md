# Project Y · Unity / xLua 游戏框架

Unity **2022.3.55f1c1**，首个验证目标为 **Windows x64**。xLua 已随工程引入并固定版本，生成的 C# 桥接代码也已包含。

AI 开发入口：[ForAI 短索引](ForAI/INDEX.md)。按关键词选择模块后再读必要代码；文档写法见 [维护约定](ForAI/MAINTENANCE.md)。

## 立即运行

1. Unity 打开 `Assets/GameFramework/Samples/FrameworkDemo.unity`，点击 Play。也可用菜单 **Project Y → Demo → Open Scene**。
2. **CLAIM REWARD**：读取二进制配置，在 Lua 求值奖励公式，再调用 C# `PlayerData.AddCoins`。Stats Widget 通过通知刷新。
3. **LEVEL UP**：修改 C# 等级，下一次奖励随公式变化。
4. **OPEN MODAL**：展示模态 Panel，屏蔽下层输入；按钮或 Escape 关闭并释放监听。

## 配表工作台

需要 **Node.js 20+**，无 npm 依赖。在工程根目录运行：

```powershell
node Tools/ConfigEditor/server.mjs
```

浏览器访问 <http://127.0.0.1:4173>。表头依次为键名、类型、描述；可直接添加/编辑/删除/排序列，编辑行数据和试算公式。**保存源文件** 后 **导出到 Unity**。网页工具只监听本机，不是游戏后端。

左侧目录对应实际表源文件夹，支持表移动与目录管理；模块根节点仅用于组织，取消绑定不会删除模块定义。枚举、常量有独立管理入口；**全局总览**可跨模块搜索并快速定位。共享枚举可选择 int/string 显式值，通过 `enumRef: "Demo.Rarity"` 复用。

```powershell
node Tools/ConfigEditor/exporter.mjs
```

也可以从 Unity 菜单 **Project Y → Config → Export Tables** 导出。Unity 找不到 Node 时，设置环境变量 `PROJECT_Y_NODE` 为 `node.exe` 的绝对路径并重启编辑器。

- 配置源：`Config/Tables/**/*.json`；共享模块/枚举/常量源：`Config/Catalog.json`。
- 二进制：`Assets/GameFramework/Resources/_Gen/Config/*.bytes`。
- Lua 结构：`Lua/_Gen/*.lua`，附 LuaLS 行类型注释。
- 导出清单：`Config/_Gen/export-manifest.json`；源表继续维护于 `Config/Tables/`。
- Lua 源码：工程根目录 `Lua/`，使用原生 `.lua` 文件，由自定义 `LuaFileLoader` 直接读取，不经过 Resources/TextAsset。

枚举/常量使用 `ConfigSystem:GetEnum("Demo", "Rarity")` / `GetConstant("Demo", "PreviewLimit")`，运行时为只读值。目录移动不改变表名或模块 ID。

## 默认文本与本地化

- 表字段 `text` 标记需要本地化；当前仍导出默认字符串。
- 在 [Language.lua](Lua/Language.lua) 的标记块中新增 `Confirm = "确认", -- 通用确认按钮`。`local Language = require('Language')` 后使用 `Language.Confirm`：优先 LuaTxt，缺失时回退到 Lua 文件。
- 导表或网页“同步 Language.lua”会新增 LuaTxt 缺失键、更新注释到 desc，保留已有 txt 覆盖；修改已有文本请同时维护 LuaTxt。LuaTxt / PrefabTxt 均为 `id, txt, desc`。
- Prefab 使用 **GameObject → UI → Project Y UITxt** 创建 TMP 派生组件，在 Inspector 配置文本 ID 和默认文本，运行时查 PrefabTxt；绑定 LuaReference 后可用 `self.view.Key` 获取它。

UGUI 1.0.0 与 TMP 3.0.7 源码已按 Unity 的 [嵌入包方式](https://docs.unity3d.com/Manual/upm-embed.html) 放入 `Packages`，TMP Essential Resources 已导入；字体仍需覆盖实际目标字符。统一各语言 i18n 导出、翻译管理及语言切换按本次约定留待后续。具体维护入口见 [本地化文档](ForAI/Framework/Localization.md)。

## Lua 目录与加载

```text
Lua/
  Main.lua
  Core/                 # LuaSystem、注册器、事件和生命周期
  UI/                   # UISystem、UIPanelCtrl、UIWidgetCtrl；Panel/、Widget/、Types/
  Game/                 # 业务 System
  Config/               # 二进制读表与公式解释器
  _Gen/                 # 导表生成的 Lua 结构、清单及 Catalog
```

`require('Game.Systems')` 映射到 `Lua/Game/Systems.lua`。编辑器直接读工程源码，改完后重新进入 Play 即可，无需等待 Unity 导入 Lua 文件。加载器保留真实文件路径供报错/调试使用，并处理 UTF-8 BOM。

构建回调自动将这些 `.lua` 源文件加入成品的 `StreamingAssets/Lua/`；桌面 Player 从该目录读取。项目中不需要维护 `Assets/StreamingAssets/Lua` 副本。只有 `.lua` 文件进入构建（排除编辑器提示 `UI/Types/`），模块路径必须使用字母/数字/下划线标识符，不能有大小写冲突或文件名中的额外点号。

## LuaConsole

Unity 顶部菜单 **Project Y → Lua Console → Open** 打开 Python 控制台；手动进入包含 GameBootstrap 的 Play Mode 后，点击“检查连接”即可执行 Lua。支持输出、返回值、错误堆栈，以及当前 LuaEnv 内的状态和函数修改。需要 Python 3.10+ / tkinter；找不到 Python 时使用同菜单的 **Select Python Executable**。

AI 可使用 `$unity-lua-console`，命令行入口为 `python -X utf8 Tools/LuaConsole/console.py status --json`。操作窗口编辑的是执行片段，执行不会自动保存源文件或重载模块。具体命令、生命周期和限制见 [LuaConsole](ForAI/Tools/LuaConsole.md)。

## 接入代码

新增常驻 System：继承 `Core.LuaSystem`，在 `Lua/Game/Systems.lua` 注册，并声明依赖。该入口集中调度 Init、Start、Tick、FixedTick、LateTick、Pause 和 Shutdown。

新增 UI：打开 **Project Y → UI → Panel Generator**，选择/新建配置，设置模块、层级、模态、缓存和四个标记，点击“保存并生成”。运行规则与扩展入口见 [UI 生成器文档](ForAI/Tools/PanelGenerator.md)。

- Prefab：`Assets/DynamicAsset/UI/Prefabs/<模块>/<名称>Panel.prefab` 或 `<名称>Widget.prefab`。
- Panel 控制器：`Lua/UI/Panel/<名称>Ctr.lua`，继承 `UIPanelCtrl`。
- Widget 控制器：`Lua/UI/Widget/<名称>.lua`，继承 `UIWidgetCtrl`；通过父控制器 `AddWidget` 或 `CreateWidget` 管理。
- LuaReference 绑定自定义 **Key + Component**，使用 `self.view.Confirm` 访问；Inspector 可选择组件类型、导出 EmmyLua 提示。
- PanelConfig 保存在 `Assets/DynamicAsset/UI/Resources/PanelConfig.asset`，运行时按其 Prefab 引用创建窗口；原 Lua PanelDefinitions 已迁移。
- WorldUI、打开时暂停世界、切场景关闭已接入；**支持热切仅保存标记**。重复生成保留已有 Lua 源码和绑定。
- 运行时创建独立的 **UIRoot**（屏幕 Canvas，统一缩放）和 **WorldUIRoot**（World Space Canvas）；Panel 按 IsWorldUI 自动挂到对应根节点。

可变业务数据写 C# Data，Lua ModelSystem 只转发命令和通知。

```lua
local row = self.context.systems:Get('Config'):GetTable('Rewards'):Get(1)
local amount = row.amount:Evaluate({ base = row.base, level = 3 })
```

C# 也可以查询同一份 Lua 配置：

```csharp
using (var row = ProjectY.GameBootstrap.Instance.GetConfigRow("Rewards", 1))
{
    var title = row.Get<string>("title");
    var baseAmount = row.Get<int>("base");
}
```

查询只在启动完成后、Unity 主线程上执行。不要长期持有返回的 `LuaTable`，必须在 LuaEnv 关闭前 Dispose。高频 C# 使用者之后可以添加专用导出器/强类型 DTO；第一版共享 Lua 配置，避免维护两份逻辑。

## 验证

```powershell
node --test Tools/ConfigEditor/tests/config.test.mjs
python Tools/Tests/run_lua.py
```

第二个命令需 Windows x64 Python，直接使用工程内 xLua 原生 DLL 运行 Lua 测试。Unity 菜单 **Project Y → Tests → Run Integration Checks** 在编辑模式执行真实 Unity Button / C# 数据 / xLua 交互与资源释放检查。**Run Panel Checks** 检查生成保留、模块移动、提示、WorldUI 和暂停计数。

修改 C# 暴露 API 或委托签名后，执行 **XLua → Generate Code**，等待编译，再运行集成检查。构建前会自动导表，检查 UI 配置/Prefab/控制器路径与 AOT 桥接代码。

完整设计、生命周期约定、二进制格式和扩展边界见 [架构说明](Docs/Architecture.md)。

## 当前边界

- UI 注册表与配置二进制使用同步 Resources；Prefab 通过注册表的直接引用进入构建；Lua 源码使用独立磁盘加载器。Android/WebGL 的 URI 型 StreamingAssets 需要异步预加载方案，不属于当前 Windows 版本。
- 数据目前驻内存，未实现单机存档；配置数据只读，存档应由 C# Data 的独立持久化层处理。
- 每个 Panel 定义同时一个实例；Widget 属于父控制器，不独立进入窗口栈。
- 未加入场景流转、音频、输入映射、热更新和联网模块。
- 已接入 Windows x64 原生插件；其他平台和 IL2CPP 真机包仍需对应原生库及构建验证。

xLua 接入依据 [官方 API 文档](https://github.com/Tencent/xLua/blob/59bf42685dbe36fe0e1678a6ba8597f859ef7ca3/Assets/XLua/Doc/XLua_API.md)，版本与许可见 `Assets/ThirdParty/XLua/UPSTREAM.md`。
