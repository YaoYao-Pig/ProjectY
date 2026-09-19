using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using UnityEditor;
using UnityEngine;
using Debug = UnityEngine.Debug;

namespace ProjectY.Editor
{
    /// <summary>Editor-only transport. Socket I/O stays on a worker; Lua always runs on Editor update.</summary>
    [InitializeOnLoad]
    public static class LuaConsoleBridge
    {
        private const string EnabledKey = "ProjectY.LuaConsole.Enabled";
        private const string PythonKey = "ProjectY.LuaConsole.Python";
        private const int MaxPacket = 1024 * 1024;
        private static readonly string ProjectRoot = Directory.GetParent(Application.dataPath).FullName;
        private static readonly string ConnectionPath = Path.Combine(ProjectRoot, "Library/LuaConsole/connection.json");
        private static readonly ConcurrentQueue<Pending> Queue = new ConcurrentQueue<Pending>();
        private static TcpListener listener;
        private static CancellationTokenSource cancellation;
        private static Task worker;
        private static string token;
        private static int generation;

        [Serializable]
        private sealed class Connection
        {
            public int protocol = 1;
            public string host = "127.0.0.1";
            public int port;
            public string token;
            public string project;
            public int pid;
        }
        [Serializable]
        private sealed class Request
        {
            public int protocol;
            public string id;
            public string token;
            public string operation;
            public string code;
            public string chunkName;
        }
        [Serializable]
        private sealed class Response
        {
            public string id;
            public bool ok;
            public bool ready;
            public bool playing;
            public bool paused;
            public int session;
            public string output = "";
            public string result = "";
            public string error = "";
            public long elapsedMs;
        }
        private sealed class Pending
        {
            public string Json;
            public int Generation;
            public readonly TaskCompletionSource<string> Completion = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
            // 0 queued, 1 started, 2 expired. An expired queued command must never run later.
            private int state;
            public bool TryBegin() => Interlocked.CompareExchange(ref state, 1, 0) == 0;
            public void Expire() => Interlocked.CompareExchange(ref state, 2, 0);
        }

        static LuaConsoleBridge()
        {
            EditorApplication.update += Pump;
            EditorApplication.playModeStateChanged += _ => Interlocked.Increment(ref generation);
            AssemblyReloadEvents.beforeAssemblyReload += Stop;
            EditorApplication.quitting += Stop;
            if (SessionState.GetBool(EnabledKey, false)) EditorApplication.delayCall += Start;
        }

        [MenuItem("Project Y/Lua Console/Open")]
        public static void Open()
        {
            SessionState.SetBool(EnabledKey, true);
            Start();
            var python = Environment.GetEnvironmentVariable("PROJECT_Y_PYTHON") ?? EditorPrefs.GetString(PythonKey, "python");
            var script = Path.Combine(ProjectRoot, "Tools/LuaConsole/console.py");
            Process.Start(new ProcessStartInfo
            {
                FileName = python,
                Arguments = "\"" + script + "\" --project \"" + ProjectRoot + "\" gui",
                WorkingDirectory = ProjectRoot,
                UseShellExecute = false,
                CreateNoWindow = true
            })?.Dispose();
        }

        [MenuItem("Project Y/Lua Console/Start Connection (CLI)")]
        public static void StartConnection()
        {
            SessionState.SetBool(EnabledKey, true); Start();
            Debug.Log("LuaConsole connection ready. Enter Play Mode manually, then use Tools/LuaConsole/console.py.");
        }

        [MenuItem("Project Y/Lua Console/Stop Connection")]
        public static void StopConnection() { SessionState.SetBool(EnabledKey, false); Stop(); }

        [MenuItem("Project Y/Lua Console/Select Python Executable")]
        public static void SelectPython()
        {
            var path = EditorUtility.OpenFilePanel("Select Python 3 (with tkinter)", "", "exe");
            if (!string.IsNullOrEmpty(path)) EditorPrefs.SetString(PythonKey, path);
        }

        private static void Start()
        {
            if (listener != null) return;
            token = Guid.NewGuid().ToString("N");
            cancellation = new CancellationTokenSource();
            listener = new TcpListener(IPAddress.Loopback, 0);
            try
            {
                listener.Start(4);
                var connection = new Connection { port = ((IPEndPoint)listener.LocalEndpoint).Port,
                    token = token, project = ProjectRoot, pid = Process.GetCurrentProcess().Id };
                Directory.CreateDirectory(Path.GetDirectoryName(ConnectionPath));
                var temporary = ConnectionPath + ".tmp";
                File.WriteAllText(temporary, JsonUtility.ToJson(connection), new UTF8Encoding(false));
                if (File.Exists(ConnectionPath)) File.Replace(temporary, ConnectionPath, null);
                else File.Move(temporary, ConnectionPath);
                var server = listener; var stopping = cancellation.Token;
                worker = Task.Run(() => Serve(server, stopping));
            }
            catch { Stop(); throw; }
        }

        private static void Stop()
        {
            if (listener == null) return;
            cancellation.Cancel(); listener.Stop(); listener = null;
            while (Queue.TryDequeue(out var pending)) { pending.Expire(); pending.Completion.TrySetCanceled(); }
            worker = null; token = null;
            cancellation.Dispose(); cancellation = null;
            if (File.Exists(ConnectionPath)) File.Delete(ConnectionPath);
        }

        private static void Serve(TcpListener server, CancellationToken stopping)
        {
            while (!stopping.IsCancellationRequested)
            {
                TcpClient client;
                try { client = server.AcceptTcpClient(); }
                catch (SocketException) when (stopping.IsCancellationRequested) { return; }
                catch (ObjectDisposedException) when (stopping.IsCancellationRequested) { return; }
                using (client)
                using (stopping.Register(client.Close))
                {
                    try
                    {
                        var epoch = Volatile.Read(ref generation);
                        client.ReceiveTimeout = 3000; client.SendTimeout = 3000;
                        var stream = client.GetStream();
                        var prefix = ReadExact(stream, 4);
                        var size = (prefix[0] << 24) | (prefix[1] << 16) | (prefix[2] << 8) | prefix[3];
                        if (size <= 0 || size > MaxPacket) throw new InvalidDataException("Invalid console packet size.");
                        var pending = new Pending { Json = Encoding.UTF8.GetString(ReadExact(stream, size)), Generation = epoch };
                        Queue.Enqueue(pending);
                        try
                        {
                            if (!pending.Completion.Task.Wait(5000, stopping)) continue;
                            var bytes = Encoding.UTF8.GetBytes(pending.Completion.Task.Result);
                            var header = new[] { (byte)(bytes.Length >> 24), (byte)(bytes.Length >> 16), (byte)(bytes.Length >> 8), (byte)bytes.Length };
                            stream.Write(header, 0, header.Length); stream.Write(bytes, 0, bytes.Length);
                        }
                        finally { pending.Expire(); }
                    }
                    catch (IOException) { /* Disconnected or malformed client; no retry. */ }
                    catch (SocketException) { /* Client closed during shutdown. */ }
                    catch (OperationCanceledException) when (stopping.IsCancellationRequested) { return; }
                    catch (ObjectDisposedException) when (stopping.IsCancellationRequested) { return; }
                    catch (AggregateException) when (stopping.IsCancellationRequested) { return; }
                }
            }
        }

        private static byte[] ReadExact(Stream stream, int size)
        {
            var bytes = new byte[size]; var position = 0;
            while (position < size)
            {
                var count = stream.Read(bytes, position, size - position);
                if (count == 0) throw new EndOfStreamException();
                position += count;
            }
            return bytes;
        }

        private static void Pump()
        {
            if (worker != null && worker.IsFaulted)
            {
                var error = worker.Exception; Stop(); Debug.LogException(error); return;
            }
            if (!Queue.TryDequeue(out var pending) || !pending.TryBegin()) return;
            var response = new Response { playing = EditorApplication.isPlaying, paused = EditorApplication.isPaused,
                ready = EditorApplication.isPlaying && GameBootstrap.Instance != null && GameBootstrap.Instance.IsEditorConsoleReady,
                session = generation };
            var timer = Stopwatch.StartNew();
            try
            {
                var request = JsonUtility.FromJson<Request>(pending.Json);
                if (request == null) throw new InvalidDataException("Empty request.");
                response.id = request.id;
                if (request.protocol != 1 || request.token != token) throw new InvalidDataException("Console connection expired; reopen the menu entry.");
                if (pending.Generation != generation) throw new InvalidOperationException("Play session changed; command was not executed.");
                if (request.operation == "status") response.ok = true;
                else if (request.operation == "execute")
                {
                    if (!response.ready) throw new InvalidOperationException("Enter Play Mode with GameBootstrap before injecting Lua.");
                    if (string.IsNullOrWhiteSpace(request.code)) throw new ArgumentException("Code is empty.");
                    var runner = File.ReadAllText(Path.Combine(ProjectRoot, "Tools/LuaConsole/runtime.lua"));
                    var result = GameBootstrap.Instance.ExecuteEditorConsole(runner, request.code, request.chunkName ?? "LuaConsole");
                    response.ok = (bool)result[0]; response.output = (string)result[1];
                    response.result = (string)result[2]; response.error = (string)result[3];
                }
                else throw new ArgumentException("Unknown console operation: " + request.operation);
            }
            catch (Exception error) { response.ok = false; response.error = error.ToString(); }
            response.elapsedMs = timer.ElapsedMilliseconds;
            pending.Completion.TrySetResult(JsonUtility.ToJson(response));
        }
    }
}
