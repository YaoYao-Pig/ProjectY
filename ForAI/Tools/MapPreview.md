# 地图预览工具

关键词：Web、地图预览、Map Lab、地图实验室、Editor 菜单、柱体、城镇、建筑预览、道路、种子、算法调试、xLua、Python、4175。

## 文档目录

正文：启动与操作 / 工程一致性与边界 / 验证；关键入口：服务 / 运行时 / 视图。

## 正文

- Unity 菜单 `Project Y/地图/打开地图实验室` 与 `Project Y/Web 服务/打开地图实验室` 自动启动或复用当前工程服务，在默认浏览器打开。`Project Y/Web 服务/` 可统一启停注册服务或打开管理窗口；具体生命周期、等待时限与旧版迁移见 [Web 服务管理](WebServices.md)。
- 也可在工程根运行 `node Tools/MapPreview/launch.mjs`，获得就绪地址；直接前台运行仍用 `node Tools/MapPreview/server.mjs`。默认访问 `http://127.0.0.1:4175`。需要 Node 20+、64 位 Python 和工程中的 Windows x64 xLua DLL，无需 npm 安装或 Play。`PROJECT_Y_PYTHON` 可指定 Python 可执行文件，`MAP_PREVIEW_PORT` 可覆盖端口。
- 原启动器委托统一 Web 服务管理器，宿主通过 `/api/web-services/health` 检查工程与实例身份；原 `/api/health` 保留工具身份查询。端口冲突会明确报错，同工程已知旧版仍可打开但需先手动关闭一次再升级。`MAP_PREVIEW_ROOT` 保留为直接启动命令的工程目录参数。
- 初次打开按当前配表 ID 循环构建至少 8 个实例的混合配方（当前 `1,2,3,4,5,6,1,2`）。输入 uint32 种子与逗号分隔的 Region 配置 ID（也接受 JSON 数组），点击生成；可追加配置或点击“填入混合地貌配方”。配置工作台链接指向 4173；使用 Editor“启动全部”可同时准备两个服务。
- 拖动平移、滚轮缩放、适应画布；支持自然地表、Region、高度、地貌与边界过渡强度着色。自然颜色使用 Lua 根据地貌配置和混合权重计算的 groundColor，水面使用真实水位/深度；关闭水面可查看湖床/河床。旋转、俯视角与高度放大仅改变显示。点击实际绘制的地面、水面或侧面，查看真实坐标、原始/最终高度、混合比例、水体/水深、Region、邻居及候选。
- 城市地块、建筑细节、森林/地貌装饰与道路可分别开关；关闭建筑细节后仍能从分散的着色地块识别城市。自然地表模式使用 Lua town.groundColor 标记实际建筑占地，保留地块间的自然地面；其他着色模式遵循当前诊断颜色。列表按钮定位并放大到城镇中心，点击建筑或其地块可查样式、占地、地基和尺寸。道路沿实际地面绘制；概览显示城镇、建筑、街道、道路与分离网络。
- 每栋建筑的多格占地按真实邻接合并为一个连续地基顶面，只画外沿与外侧壁，内部不显示格线；平台高度使用 Lua baseHeight，不改写原始地形。关闭“城市地块”可恢复原格地形。点击平台任意部位统一选中建筑中心并高亮整块；屋顶/墙体仍用配置尺寸绘制，属于可关闭的占位细节。
- 导出 JSON 包含格子、邻接、Region、Border、连通水体、地貌权重、towns/buildings/roads/roadNetworks、assets/decorations/rivers/waterfalls、种子、配方、算法版本和源码/配表哈希；保存图片导出当前地图画布。索引从 1 开始，`regions[].buildings` 保留原有候选配置含义，顶层 `buildings` 才是生成的占地布局。复现历史算法仍需保留对应工程源码及配表版本，哈希不是源码存档。
- 河网面板统计主河、支流及瀑布，可点击瀑布定位下游湖泊；窄窗口向下滚动可访问检查面板。树木和建筑轮廓读取 MapAssetTable 的预览形状与颜色；只表示算法占位，实际 FBX 以 Unity 为准。样例 seed=20260921、配方 `1,2,3,4,5,6,1,4,5,6` 覆盖森林、冰雪和瀑布。
- 每次生成捕获 `Config/Tables`、Catalog 与项目 Lua 源文件，用**现有 exporter** 在临时目录导出，再通过**项目 xLua DLL** 执行 `ConfigSystem → MapSystem → MapGenerator`。所有 require 使用此次快照中的 Lua 与 Generated schema，`ReadConfig` 读取此次导出的同格式二进制；源码/表变化下一次生成即生效，不使用过期的工程 Generated 文件。
- Lua 预览适配器仅序列化现有查询结果，邻接来自 HexGrid/Map 查询；前端仅将返回的世界坐标、高度与邻接绘制为 Canvas 正交柱体。这里的临时几何不依赖美术模型，不另实现生成算法，也不替代 Unity 的实际渲染、碰撞或性能验证。[地图业务契约](../Business/Map.md) 保持唯一来源。
- 预览不改写工程源表或 Unity 导表产物；临时快照在成功或失败后清理，每个请求使用全新 Lua 状态。Python/xLua 宿主复用于 Lua 测试入口。接口仅监听 loopback，验证 Host/Origin 与会话 token；同时最多一个生成任务，运行超时 30 秒、输出上限 64 MiB。错误展示 Lua 栈，保留并标明上次成功的画布。
- 工具读取磁盘上**已保存**的文件；配置网页尚未保存的草稿不参与生成。点击“刷新配置”更新选择器与参数摘要，点击“生成地图”始终读取最新磁盘数据。当前采用 Canvas 软件绘制，大地图的视图帧率不代表游戏运行性能。

最小检查：`node --test Tools/MapPreview/tests/launch.test.mjs Tools/MapPreview/tests/preview.test.mjs` 验证启动/复用/端口冲突、真实链路、可复现、源码/配表变化、错误恢复及不改写资源；`python -B Tools/Tests/run_lua.py Tools/Tests/map.lua` 验证共享宿主与地图回归。网页行为修改再检查生成、选择、视角/颜色切换、错误反馈及导出；Editor 入口变更遵循项目 C# 编译约束，不自动启动 Unity 或进入 Play。

## 关键入口

- [MapPreviewMenu.cs](../../Assets/GameFramework/Editor/MapPreviewMenu.cs)：旧 Editor 菜单的转发入口；[launch.mjs](../../Tools/MapPreview/launch.mjs)：兼容原启动命令，委托统一管理器。
- [server.mjs](../../Tools/MapPreview/server.mjs)：快照、复用导出器、worker 和本地 HTTP；[worker.py](../../Tools/MapPreview/worker.py)：单请求 Lua 执行。
- [runtime.py](../../Tools/LuaRuntime/runtime.py)：通用 xLua DLL 宿主；[run_lua.py](../../Tools/Tests/run_lua.py)：原测试命令入口。
- [preview.lua](../../Tools/MapPreview/preview.lua) / [json.lua](../../Tools/MapPreview/json.lua)：项目系统启动与只读序列化。
- [app.js](../../Tools/MapPreview/public/app.js) / [renderer.js](../../Tools/MapPreview/public/renderer.js)：工具交互与柱体绘制；[index.html](../../Tools/MapPreview/public/index.html) / [styles.css](../../Tools/MapPreview/public/styles.css)：页面。
- [preview.test.mjs](../../Tools/MapPreview/tests/preview.test.mjs)：工具集成检查；[launch.test.mjs](../../Tools/MapPreview/tests/launch.test.mjs)：启动器检查。
