# 配置编辑器

关键词：网页、前端、增列、表头、目录、模块根节点、枚举、常量、总览、409。

## 文档目录

正文：运行与保存契约 / 修改与验证；关键入口：服务 / 页面 / 共享规则。

## 正文

- Node.js 20+，无 npm 依赖；工程根运行 `node Tools/ConfigEditor/server.mjs`，访问 `http://127.0.0.1:4173`。只服务本地配表工作流，不是游戏后端。
- JSON 表源、生成产物和数据约束属于 [配置管线](../Framework/Config.md)；服务复用 exporter 校验，网页与导出器共享 formula 模块。
- 保存修改源 JSON；导出生成二进制与 Lua schema。网页执行导出前先保存脏数据；保存成功不代表已导出。
- 表头为键名/类型/可编辑描述三行；键名打开列编辑，支持增删、改名、排序、默认值和共享枚举。改名迁移已有值，新增列填默认值；类型改变不会隐式转换已有数据。text 使用多行输入。
- 目录对应真实 `Config/Tables/` 子目录，支持新建、移动/重命名、删除空目录；表保存时可换目录。模块根节点是 Catalog 模块的可选 folder 绑定，取消绑定保留定义；移动目录自动更新绑定。
- 独立枚举/常量页面按模块管理；全局总览检索表、字段描述、枚举成员、常量值与 text 字段并定位。Catalog 整体保存，保留稳定模块 ID/显式枚举值。
- `GET /api/tables` 获取表与 revision；`PUT/DELETE /api/tables/:name` 保存/删除，按 revision 检测冲突（409），并校验全表引用。不能忽略冲突直接覆盖其他修改。
- `POST /api/validate` 校验，`POST /api/export` 导出。变更请求需会话 token，并保留 loopback、Host/Origin 检查；具体请求字段以服务路由为准。
- `PUT /api/catalog` 保存共享定义；`POST/DELETE /api/folders` 管理目录，`POST /api/folders/move` 移动；`POST /api/language/sync` 同步 Lua 默认文本。revision 覆盖表、路径、Catalog 和 Language.lua，外部变更同样触发 409。

验证：`node --test Tools/ConfigEditor/tests/config.test.mjs`；改网页后启动服务，检查编辑、保存、公式预览和导出。涉及格式或公式同时执行配置管线中的 Lua 检查。

## 关键入口

- [server.mjs](../../Tools/ConfigEditor/server.mjs)：`createEditorServer` 与 API 路由。
- [workspace.mjs](../../Tools/ConfigEditor/workspace.mjs)：递归扫描、路径校验、源文件写入；[definitions.mjs](../../Tools/ConfigEditor/definitions.mjs)：前后端共享定义、默认值和列变更。
- [app.js](../../Tools/ConfigEditor/public/app.js)：页面状态/请求；[index.html](../../Tools/ConfigEditor/public/index.html) / [styles.css](../../Tools/ConfigEditor/public/styles.css)：视图。
- [exporter.mjs](../../Tools/ConfigEditor/exporter.mjs) / [formula.mjs](../../Tools/ConfigEditor/formula.mjs)：共享规则；[config.test.mjs](../../Tools/ConfigEditor/tests/config.test.mjs)：工具链测试。
