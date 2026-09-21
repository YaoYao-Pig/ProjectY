# Editor Web 服务管理

关键词：Web 服务、注册表、一键启动、停止全部、服务管理、Editor 菜单、配表、地图、4173、4175。

## 文档目录

正文：菜单与命令 / 注册与生命周期 / 验证；关键入口：Editor / 管理器 / 宿主。

## 正文

- Unity 菜单 `Project Y/Web 服务/` 提供“启动全部”“停止全部”“服务管理”“打开配置工作台”“打开地图实验室”。管理窗口从注册表获取完整列表，可刷新状态、单独启动/打开、停止、查看日志。原 Config/Open Local Editor 与 地图/打开地图实验室 入口也复用统一管理器，打开前先确保服务就绪。
- 当前注册配置工作台（4173）与地图实验室（4175）。注册来源为 `Tools/WebServices/services.json`，字段为稳定 id、显示 name、工程内 module、HTTP 工厂 factory、默认 port 与 portEnvironment；新增注册项自动纳入全部操作和窗口，无需新增 C# 菜单。工厂接收 `{root}`，返回尚未 listen、含一个 request 处理器的 Node HTTP Server。
- 工程根执行 `node Tools/WebServices/manage.mjs start|stop|status all|服务ID`；JSON 输出逐项结果，批量中单项失败不阻止其他项。Editor 使用 `PROJECT_Y_NODE` 或 PATH 的 node，隐藏后台进程并异步等待最多 45 秒，不触发 Unity Refresh/Play。业务服务首次启动最多等待 10 秒，重复启动复用同工程实例。
- `host.mjs` 在原业务工厂外承接健康检查与停止。宿主只监听 127.0.0.1，核对 Host/Origin；身份包含工程真实路径摘要、服务 ID、随机实例 ID。当前用户临时目录 `project-y-web-services/` 保存停止令牌和实例记录，不输出令牌到菜单/命令行；日志为临时目录 `project-y-web-服务ID-*.log`。
- 停止先核对工程与实例，再携带本地记录中的令牌请求 `/api/web-services/stop`，停止接受新请求并等待已提交的保存/生成完成，最多等待 35 秒。只允许当前实例移除自己的记录；凭证缺失、其他工程、端口冲突或替换实例均不继续停止。不按端口或 node 进程名批量查杀，PID 仅供展示。
- 服务独立于 Editor 生命周期，关闭网页、Editor 或脚本重载后仍可由下次管理器识别。两项原 `server.mjs` 直接启动命令现在也进入统一宿主。`Tools/MapPreview/launch.mjs` 保留为兼容入口。修改监听端口需先停止旧端口实例，再改注册表或对应环境变量（配置服务 PORT、地图 MAP_PREVIEW_PORT）。
- 已在运行的旧版本不会随磁盘源码自动升级。可通过注册项可选 legacyHealth（path/tool/protocol）核对旧版本身份，保留打开能力；窗口明确显示旧版且禁用单项停止。首次手动关闭旧进程后从新菜单启动，即可纳入统一停止；不会把旧版伪报为受管服务。

最小验证：`node --test Tools/WebServices/tests/manage.test.mjs Tools/MapPreview/tests/launch.test.mjs` 使用临时端口覆盖注册启停、并发复用、鉴权、工程隔离、请求排空、批量部分失败及旧入口兼容。业务生成链路另按 [地图预览](MapPreview.md) 的定向检查执行。Editor 改动按项目 Skill 集中编译，不默认启动 Unity/Play。

## 关键入口

- [WebServicesMenu.cs](../../Assets/GameFramework/Editor/WebServicesMenu.cs)：统一菜单、异步调用与管理窗口。
- [services.json](../../Tools/WebServices/services.json) / [registry.mjs](../../Tools/WebServices/registry.mjs)：注册项与运行记录路径。
- [manage.mjs](../../Tools/WebServices/manage.mjs)：状态、启动、受控停止与命令行。
- [host.mjs](../../Tools/WebServices/host.mjs)：业务 HTTP 工厂宿主与生命周期接口。
- [manage.test.mjs](../../Tools/WebServices/tests/manage.test.mjs)：临时服务生命周期检查。
- [配置编辑器](ConfigEditor.md) / [地图预览工具](MapPreview.md)：各工具的业务职责。
