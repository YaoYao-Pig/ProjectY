"""Call the configured Blender stdio MCP without requiring a client reload."""

import argparse
import asyncio
import base64
import json
import os
from pathlib import Path
import sys
import tomllib

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def run(args):
    config_path = Path(args.config).expanduser()
    config = tomllib.loads(config_path.read_text(encoding="utf-8-sig"))
    server = config["mcp_servers"]["blender"]
    if not server.get("enabled", True) or "command" not in server:
        raise ValueError("blender must be an enabled stdio MCP server")
    env = dict(os.environ)
    env.update(server.get("env", {}))
    params = StdioServerParameters(
        command=server["command"], args=server.get("args", []),
        env=env, cwd=server.get("cwd"),
    )
    async with stdio_client(params) as (reader, writer):
        async with ClientSession(reader, writer) as session:
            initialized = await session.initialize()
            if args.action == "tools":
                found = []
                cursor = None
                while True:
                    page = await session.list_tools(cursor=cursor)
                    found.extend(page.tools)
                    cursor = page.nextCursor
                    if not cursor:
                        break
                if args.name:
                    tool = next(t for t in found if t.name == args.name)
                    result = tool.model_dump(mode="json", exclude_none=True)
                else:
                    result = {"server": initialized.serverInfo.model_dump(),
                              "tools": [t.name for t in found]}
                print(json.dumps(result, ensure_ascii=False, indent=2))
                return 0

            arguments = {"user_prompt": args.prompt}
            if args.action == "scene":
                tool_name = "get_scene_info"
            elif args.action == "execute":
                tool_name = "execute_blender_code"
                arguments["code"] = Path(args.code_file).read_text(encoding="utf-8-sig")
            else:
                tool_name = "get_viewport_screenshot"
                arguments["max_size"] = args.max_size

            result = await session.call_tool(tool_name, arguments)
            failed = bool(result.isError)
            content = []
            for block in result.content:
                if block.type == "image":
                    if args.action != "screenshot":
                        raise ValueError("Unexpected image result")
                    suffix = {"image/png": ".png", "image/jpeg": ".jpg"}[block.mimeType]
                    folder = Path(args.output_dir).resolve()
                    folder.mkdir(parents=True, exist_ok=True)
                    path = folder / ("blender-viewport" + suffix)
                    # Avoid replacing any earlier preview.
                    index = 1
                    while path.exists():
                        path = folder / (f"blender-viewport-{index}" + suffix)
                        index += 1
                    path.write_bytes(base64.b64decode(block.data, validate=True))
                    content.append({"image": str(path), "mimeType": block.mimeType})
                else:
                    content.append(block.model_dump(mode="json", exclude_none=True))
                    if block.type == "text":
                        message = block.text.lstrip()
                        failed |= message.startswith(("Error", "Rejected by safe mode", "Failed"))
            print(json.dumps({"failed": failed, "content": content}, ensure_ascii=False, indent=2))
            return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    config_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
    parser.add_argument("--config", default=str(config_home / "config.toml"))
    parser.add_argument("--timeout", type=float, default=120)
    sub = parser.add_subparsers(dest="action", required=True)
    tools_parser = sub.add_parser("tools")
    tools_parser.add_argument("--name")
    for action in ("scene", "execute", "screenshot"):
        cmd = sub.add_parser(action)
        cmd.add_argument("--prompt", default="")
        if action == "execute":
            cmd.add_argument("--code-file", required=True)
        elif action == "screenshot":
            cmd.add_argument("--output-dir", required=True)
            cmd.add_argument("--max-size", type=int, default=1000)
    args = parser.parse_args()
    return asyncio.run(asyncio.wait_for(run(args), timeout=args.timeout))


if __name__ == "__main__":
    sys.exit(main())
