"""Local Python client for the Unity Editor Lua console; standard library only."""
from __future__ import annotations

import json
import socket
import struct
import uuid
from pathlib import Path

PROTOCOL = 1
MAX_PACKET = 1024 * 1024
DEFAULT_TIMEOUT = 8.0


class ConsoleError(RuntimeError):
    pass


class OutcomeUnknown(ConsoleError):
    """A mutating request was sent but no reliable result arrived. Never auto-retry."""


def project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def read_connection(project: Path) -> dict:
    path = project.resolve() / "Library/LuaConsole/connection.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as error:
        raise ConsoleError("连接未开启：在 Unity 顶部菜单选择 Project Y > Lua Console > Open。") from error
    except (OSError, ValueError) as error:
        raise ConsoleError(f"无法读取 LuaConsole 连接文件：{error}") from error
    if not isinstance(data, dict) or data.get("protocol") != PROTOCOL or data.get("host") != "127.0.0.1":
        raise ConsoleError("连接协议或地址不匹配；仅支持本机 Unity Editor。")
    if not isinstance(data.get("project"), str) or Path(data["project"]).resolve() != project.resolve():
        raise ConsoleError("连接文件属于另一个工程。")
    if not isinstance(data.get("port"), int) or not 0 < data["port"] < 65536 or not data.get("token"):
        raise ConsoleError("连接文件缺少有效端口或凭据。")
    return data


def receive_exact(stream: socket.socket, count: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < count:
        part = stream.recv(count - len(chunks))
        if not part:
            raise EOFError("Unity 关闭了连接。")
        chunks.extend(part)
    return bytes(chunks)


def receive_packet(stream: socket.socket) -> dict:
    size = struct.unpack("!I", receive_exact(stream, 4))[0]
    if not 0 < size <= MAX_PACKET:
        raise ConsoleError("Unity 返回的数据包大小无效。")
    result = json.loads(receive_exact(stream, size).decode("utf-8"))
    if not isinstance(result, dict):
        raise ConsoleError("Unity 返回了无效响应。")
    return result


class Client:
    def __init__(self, project: Path | None = None, timeout: float = DEFAULT_TIMEOUT):
        self.project = (project or project_root()).resolve()
        if timeout <= 0:
            raise ValueError("timeout 必须大于 0。")
        self.timeout = timeout

    def request(self, operation: str, **fields) -> dict:
        connection = read_connection(self.project)
        request_id = uuid.uuid4().hex
        body = json.dumps({"protocol": PROTOCOL, "id": request_id, "token": connection["token"],
                           "operation": operation, **fields}, ensure_ascii=False).encode("utf-8")
        if len(body) > MAX_PACKET:
            raise ConsoleError("请求超过 1 MiB；请缩小脚本。")
        try:
            stream = socket.create_connection((connection["host"], connection["port"]), timeout=self.timeout)
        except OSError as error:
            raise ConsoleError("无法连接 Unity；请重新打开 Lua Console 菜单入口。") from error
        try:
            with stream:
                stream.sendall(struct.pack("!I", len(body)) + body)
                response = receive_packet(stream)
                if response.get("id") != request_id:
                    raise ConsoleError("响应 ID 与本次请求不匹配。")
                return response
        except (OSError, EOFError, ValueError, ConsoleError) as error:
            if operation != "status":
                raise OutcomeUnknown("执行结果未知：请求可能已修改运行时。请先检查状态，不要自动重发。") from error
            raise ConsoleError(f"Unity 状态请求失败：{error}") from error

    def status(self) -> dict:
        return self.request("status")

    def execute(self, code: str, chunk_name: str = "LuaConsole") -> dict:
        if not code.strip():
            raise ConsoleError("执行代码不能为空。")
        return self.request("execute", code=code, chunkName=chunk_name)
