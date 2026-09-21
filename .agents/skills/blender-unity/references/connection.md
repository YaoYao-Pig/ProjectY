# MCP 接入与排查

## 两段连接

`Codex → stdio MCP 服务 → 本机 TCP → Blender 插件`

- 上游：[ahujasid/mcp-for-blender](https://github.com/ahujasid/mcp-for-blender)。当前发行名是 `mcp-for-blender`；`blender_mcp` 仍是 Python 模块名和安装后的插件文件名。
- Codex 配置采用 [官方 MCP 配置](https://developers.openai.com/codex/mcp/)；修改用户配置前备份，仅新增/更新对应 server，保留其他配置。
- 安装前查询 PyPI/仓库版本。本项目机器配置由 ForAI 工具入口记录，不在通用示例中固定某台机器路径。

## 安装方式

优先复用已安装的受支持 Python/uv。可以用 `uv venv --python <版本> <runtime>` 创建独立环境，再用 `uv pip install --python <runtime>/Scripts/python.exe mcp-for-blender==<已核实版本>` 安装。Codex 的 `command` 指向此环境下真实存在的 `mcp-for-blender.exe`；升级用明确版本，并同步插件。

也可按上游使用 `uvx --python <版本> mcp-for-blender==<版本>`；GUI 启动的客户端可能没有终端 PATH，配置 uvx 的绝对路径。Windows 使用参数数组直接执行，不套 `cmd /c` 或拼接 shell 命令。

```toml
[mcp_servers.blender]
command = 'C:/absolute/runtime/Scripts/mcp-for-blender.exe'
startup_timeout_sec = 30
tool_timeout_sec = 120

[mcp_servers.blender.env]
BLENDER_HOST = "127.0.0.1"
BLENDER_PORT = "9876"
DISABLE_TELEMETRY = "true"
```

1. 运行已安装的 `mcp-for-blender.exe install-addon --addons-dir <Blender用户scripts/addons目录>`。目录按实际 Blender 版本确定，不猜当前版本；安装器会处理旧文件备份。
2. 在 Preferences → Add-ons 启用 **MCP for Blender**。可在没有运行中 Blender 时用一次 `blender --background --python-exit-code 1 --python <启用脚本>` 调用 `addon_utils.enable("blender_mcp", default_set=True, persistent=True)`、关闭 `preferences.addons["blender_mcp"].preferences.telemetry_consent` 并 `bpy.ops.wm.save_userpref()`；不覆盖用户 startup.blend。
3. 正常启动 Blender 图形界面。已验证的 2.0.0 插件默认自动启动桥接，也可在 3D View 的 N 面板中连接。上游按钮仍可能显示 **Connect to Claude**，不影响 Codex 使用。
4. `--background` 只能做安装/离线转换，不能用于这个插件的常驻连接：它依赖 UI 事件循环处理命令。不得用额外死循环伪装成可用连接。
5. 服务端设置 `DISABLE_TELEMETRY=true`，插件偏好中取消 `Allow Telemetry`。不用供应商集成时保留关闭状态；仅监听回环地址，不开放局域网端口。

## 实际调用

当前会话尚未发现新配置的工具时，重新加载 MCP/重启客户端后再发现；不要为了验证而结束用户的活动任务。可先用 [mcp_client.py](../scripts/mcp_client.py) 在同一个已安装 `mcp` 的 Python 环境中完成标准 MCP 握手和调用：

```powershell
# $python 指向已安装 MCP 的运行时；$client 指向此 skill 的 scripts/mcp_client.py。
& $python $client tools
& $python $client tools --name execute_blender_code
& $python $client scene --prompt '用户本次请求'
& $python $client execute --code-file 'C:/work/build_asset.py' --prompt '用户本次请求'
& $python $client screenshot --output-dir 'C:/work/previews' --prompt '用户本次请求'
```

客户端只读取配置中的 `blender` stdio 服务，调用结束即关闭自己的服务进程；它不会安装、启动 Blender 或修改 Codex 配置。不要让多个客户端同时修改同一个 Blender 场景。截图返回图片后必须实际查看，不能仅凭文件存在判断外观。

## 定位失败

| 现象 | 下一步 |
| --- | --- |
| `codex mcp get blender` 有配置，但当前无工具 | 检查客户端是否重新加载配置；独立握手只能证明服务可用，不能证明当前任务已加载工具 |
| 服务启动失败 | 核对绝对可执行路径、依赖和 stderr；不要全量清 uv 缓存 |
| `Connection refused` | 检查 Blender 插件是否启用、图形进程和监听端口是否存在 |
| 端口有连接但调用超时 | 检查 Blender 是否被模态窗口或长渲染阻塞，且没有多个实例抢同一端口；先查已执行结果，再决定重试 |
| 返回文本 `Error ...` | 视为失败，读取完整错误；不要只看 MCP `isError` |
| 导出后朝向/缩放异常 | 用已知尺寸和有明确正面的模型验证 FBX + Unity importer 的组合，不叠加猜测性的 0.01/100 缩放 |
