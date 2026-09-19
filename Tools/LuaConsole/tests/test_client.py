import json
import contextlib
import io
import socket
import struct
import sys
import tempfile
import threading
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from client import Client, ConsoleError, OutcomeUnknown, read_connection, receive_packet
from console import main


class ClientTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.project = Path(self.temporary.name)
        self.manifest = self.project / "Library/LuaConsole/connection.json"
        self.manifest.parent.mkdir(parents=True)

    def tearDown(self):
        self.temporary.cleanup()

    def server(self, respond):
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        self.manifest.write_text(json.dumps({"protocol": 1, "host": "127.0.0.1", "port": listener.getsockname()[1],
                                             "token": "fixture", "project": str(self.project)}), encoding="utf-8")
        self.calls = []
        self.server_errors = []

        def work():
            try:
                with listener, listener.accept()[0] as connection:
                    request = receive_packet(connection)
                    self.calls.append(request)
                    response = respond(request)
                    if response is not None:
                        payload = json.dumps(response, ensure_ascii=False).encode("utf-8")
                        framed = struct.pack("!I", len(payload)) + payload
                        for offset in range(0, len(framed), 3):
                            connection.sendall(framed[offset:offset + 3])
            except Exception as error:
                self.server_errors.append(error)

        thread = threading.Thread(target=work, daemon=True)
        thread.start()
        self.addCleanup(listener.close)
        return thread

    def finish(self, thread):
        thread.join(2)
        self.assertFalse(thread.is_alive())
        self.assertEqual(self.server_errors, [])

    def test_fragmented_unicode_request_and_response(self):
        thread = self.server(lambda request: {"id": request["id"], "ok": True, "ready": True, "result": "确认"})
        result = Client(self.project).execute('return "确认"')
        self.finish(thread)
        self.assertEqual(result["result"], "确认")
        self.assertEqual(self.calls[0]["code"], 'return "确认"')
        self.assertEqual(self.calls[0]["token"], "fixture")

    def test_disconnect_after_mutation_is_unknown_and_never_retried(self):
        thread = self.server(lambda request: None)
        with self.assertRaises(OutcomeUnknown):
            Client(self.project).execute("SomeState = 1")
        self.finish(thread)
        self.assertEqual(len(self.calls), 1)

    def test_mismatched_response_id_is_unknown(self):
        thread = self.server(lambda request: {"id": "wrong", "ok": True})
        with self.assertRaises(OutcomeUnknown):
            Client(self.project).execute("return 1")
        self.finish(thread)

    def test_missing_or_remote_manifest_rejected(self):
        with self.assertRaises(ConsoleError):
            read_connection(self.project)
        self.manifest.write_text(json.dumps({"protocol": 1, "host": "8.8.8.8"}), encoding="utf-8")
        with self.assertRaises(ConsoleError):
            read_connection(self.project)

    def test_execution_error_returned_without_retry(self):
        thread = self.server(lambda request: {"id": request["id"], "ok": False, "error": "fixture traceback"})
        response = Client(self.project).execute('error("fixture")')
        self.finish(thread)
        self.assertFalse(response["ok"])
        self.assertEqual(len(self.calls), 1)

    def test_cli_reports_failed_execution_as_json_with_nonzero_exit(self):
        thread = self.server(lambda request: {"id": request["id"], "ok": False, "error": "fixture traceback"})
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            exit_code = main(["--project", str(self.project), "exec", "--code", "error('fixture')", "--json"])
        self.finish(thread)
        self.assertEqual(exit_code, 1)
        self.assertFalse(json.loads(output.getvalue())["ok"])


if __name__ == "__main__":
    unittest.main()
