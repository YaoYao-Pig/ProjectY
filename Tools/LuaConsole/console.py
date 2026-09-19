"""LuaConsole GUI / command line. Run --help for AI-friendly commands."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from client import Client, ConsoleError, OutcomeUnknown, project_root


def format_response(response: dict) -> str:
    if not response.get("ok"):
        return "\n".join(filter(None, [response.get("output"), "ERROR: " + response.get("error", "Unknown failure")]))
    if "ready" in response and not response.get("output") and not response.get("result"):
        return "执行完成 / Lua 运行时已就绪" if response["ready"] else "连接成功，请在 Unity 手动进入包含 GameBootstrap 的 Play Mode。"
    return "\n".join(filter(None, [response.get("output"), response.get("result")]))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="连接当前工程的 Unity Editor LuaEnv；不启动 Unity 或 Play Mode。")
    parser.add_argument("--project", type=Path, default=project_root(), help="Unity 工程根目录")
    parser.add_argument("--timeout", type=float, default=8.0, help="连接/响应超时秒数；超时不自动重试")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("gui", help="打开 Python 操作窗口")
    status = commands.add_parser("status", help="查询连接与 Play Mode 状态（只读）")
    status.add_argument("--json", action="store_true")
    execute = commands.add_parser("exec", help="在现有 LuaEnv 中执行 Lua 片段")
    source = execute.add_mutually_exclusive_group(required=True)
    source.add_argument("--code", help="单行 Lua 代码")
    source.add_argument("--file", type=Path, help="UTF-8 Lua 片段文件")
    source.add_argument("--stdin", action="store_true", help="从标准输入读取多行代码")
    execute.add_argument("--name", default="LuaConsole", help="错误堆栈中显示的 chunk 名")
    execute.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    if args.command == "gui":
        from gui import show
        show(args.project, args.timeout)
        return 0
    try:
        client = Client(args.project, args.timeout)
        if args.command == "status":
            response = client.status()
        else:
            if args.file:
                code = args.file.read_text(encoding="utf-8-sig")
            elif args.stdin:
                code = sys.stdin.read()
            else:
                code = args.code
            response = client.execute(code, "@" + str(args.file) if args.file else args.name)
        exit_code = 0 if response["ok"] else 1
    except (ConsoleError, OSError, ValueError) as error:
        response = {"ok": False, "error": str(error), "outcomeUnknown": isinstance(error, OutcomeUnknown)}
        exit_code = 2
    if args.json:
        print(json.dumps(response, ensure_ascii=False))
    else:
        print(format_response(response))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
