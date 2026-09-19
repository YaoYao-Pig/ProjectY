"""Small tkinter front end. Networking never blocks Tk's UI thread."""
from __future__ import annotations

import queue
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, scrolledtext, ttk

from client import Client
from console import format_response


class ConsoleWindow:
    def __init__(self, window: tk.Tk, project: Path, timeout: float):
        self.window = window
        self.project = project.resolve()
        self.client = Client(self.project, timeout)
        self.responses = queue.Queue()
        self.busy = False
        self.ready = False
        window.title("LuaConsole · " + self.project.name)
        window.geometry("1000x760")
        window.minsize(760, 550)
        root = ttk.Frame(window, padding=12)
        root.pack(fill="both", expand=True)
        toolbar = ttk.Frame(root)
        toolbar.pack(fill="x")
        self.status = tk.StringVar(value="正在检查连接…")
        ttk.Label(toolbar, textvariable=self.status).pack(side="left")
        self.connect = ttk.Button(toolbar, text="检查连接", command=self.refresh)
        self.connect.pack(side="right")
        ttk.Label(root, text="Lua 片段  ·  Ctrl+Enter 执行  ·  全局赋值会保留到当前 Play 会话结束").pack(anchor="w", pady=(14, 6))
        self.code = scrolledtext.ScrolledText(root, wrap="none", undo=True, height=16, font=("Consolas", 11))
        self.code.pack(fill="both", expand=True)
        self.code.insert("1.0", "-- console.systems: 当前 SystemRegistry\n-- console.services: 当前 C# Services\nreturn console.systems.state\n")
        self.code.bind("<Control-Return>", self.execute)
        actions = ttk.Frame(root)
        actions.pack(fill="x", pady=8)
        ttk.Button(actions, text="载入 Lua 片段…", command=self.load_snippet).pack(side="left")
        self.run = ttk.Button(actions, text="执行 (Ctrl+Enter)", command=self.execute, state="disabled")
        self.run.pack(side="right")
        ttk.Label(root, text="输出 / 返回值 / 错误堆栈").pack(anchor="w")
        self.output = scrolledtext.ScrolledText(root, wrap="word", height=12, font=("Consolas", 10), state="disabled")
        self.output.pack(fill="both", expand=True, pady=(6, 0))
        ttk.Button(root, text="清空输出", command=self.clear_output).pack(anchor="e", pady=(6, 0))
        window.after(50, self.drain)
        self.refresh()

    def write_output(self, value: str):
        self.output.configure(state="normal")
        self.output.insert("end", value + "\n\n")
        self.output.see("end")
        self.output.configure(state="disabled")

    def clear_output(self):
        self.output.configure(state="normal")
        self.output.delete("1.0", "end")
        self.output.configure(state="disabled")

    def submit(self, operation, show_output: bool):
        if self.busy:
            return
        self.busy = True
        self.run.configure(state="disabled")
        self.connect.configure(state="disabled")
        self.status.set("等待 Unity 主线程…")

        def work():
            try:
                self.responses.put((operation(), None, show_output))
            except Exception as error:
                self.responses.put((None, str(error), True))

        threading.Thread(target=work, daemon=True).start()

    def refresh(self):
        self.submit(self.client.status, False)

    def execute(self, _event=None):
        if not self.busy and self.ready:
            code = self.code.get("1.0", "end-1c")
            if not code.strip():
                self.write_output("执行代码不能为空。")
                return "break"
            self.submit(lambda: self.client.execute(code), True)
        return "break"

    def drain(self):
        try:
            response, error, show_output = self.responses.get_nowait()
        except queue.Empty:
            pass
        else:
            self.busy = False
            self.connect.configure(state="normal")
            self.ready = error is None and response.get("ready", False)
            self.run.configure(state="normal" if self.ready else "disabled")
            if error:
                self.status.set("连接失败或结果未知；检查后再执行")
                self.write_output(error)
            else:
                self.status.set(("Play Mode · Lua 就绪" + (" · 游戏已暂停" if response["paused"] else "")) if self.ready else "已连接 · 等待手动进入 Play Mode")
                if show_output or not response["ok"]:
                    self.write_output(format_response(response))
        self.window.after(50, self.drain)

    def load_snippet(self):
        path = filedialog.askopenfilename(initialdir=self.project / "Lua", filetypes=[("Lua", "*.lua"), ("All", "*.*")])
        if not path:
            return
        try:
            source = Path(path).read_text(encoding="utf-8-sig")
        except (OSError, UnicodeError) as error:
            messagebox.showerror("读取失败", str(error))
            return
        self.code.delete("1.0", "end")
        self.code.insert("1.0", source)


def show(project: Path, timeout: float):
    window = tk.Tk()
    ConsoleWindow(window, project, timeout)
    window.mainloop()
