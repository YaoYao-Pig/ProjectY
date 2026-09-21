using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using UnityEditor;
using UnityEngine;
using Debug = UnityEngine.Debug;

namespace ProjectY.Editor
{
    /// <summary>调用工程统一服务管理器；菜单、旧工具入口与管理窗口共用同一状态。</summary>
    public static class WebServicesMenu
    {
        [Serializable]
        public sealed class ServiceInfo
        {
            public string id = null;
            public string name = null;
            public string url = null;
            public string status = null;
            public string message = null;
            public string log = null;
            public int port = 0;
            public int pid = 0;
            public bool managed = false;
        }

        [Serializable]
        public sealed class Result
        {
            public bool ok = false;
            public ServiceInfo[] services = null;
        }

        public static bool IsBusy { get; private set; }
        public static Result LastResult { get; private set; }
        public static string LastError { get; private set; }
        public static event Action Changed;

        [MenuItem("Project Y/Web 服务/启动全部", false, 10)]
        public static void StartAll() => Run("start");

        [MenuItem("Project Y/Web 服务/停止全部", false, 11)]
        public static void StopAll() => Run("stop");

        [MenuItem("Project Y/Web 服务/打开配置工作台", false, 30)]
        public static void OpenConfigEditor() => Run("start", "config-editor", true);

        [MenuItem("Project Y/Web 服务/打开地图实验室", false, 31)]
        public static void OpenMapPreview() => Run("start", "map-preview", true);

        [MenuItem("Project Y/Web 服务/启动全部", true)]
        [MenuItem("Project Y/Web 服务/停止全部", true)]
        [MenuItem("Project Y/Web 服务/打开配置工作台", true)]
        [MenuItem("Project Y/Web 服务/打开地图实验室", true)]
        public static bool CanRun() => !IsBusy;

        // 每次从注册表读取服务；新增注册项自动出现在窗口和全部操作中。
        public static async void Run(string action, string target = "all", bool open = false)
        {
            if (IsBusy) return;
            IsBusy = true; LastError = null; Changed?.Invoke();
            try
            {
                var result = await Execute(action, target);
                if (target == "all" || LastResult == null) LastResult = result;
                else
                {
                    // 单项操作之后获取完整状态，避免窗口丢失其他已注册服务。
                    LastResult = await Execute("status", "all");
                }
                foreach (var service in result.services)
                {
                    var message = service.name + "：" + service.message;
                    if (service.status == "error" || service.status == "conflict")
                    {
                        LastError = string.IsNullOrEmpty(LastError) ? message : LastError + "\n" + message;
                        Debug.LogError(message);
                    }
                    else if (action != "status") Debug.Log(message + (string.IsNullOrEmpty(service.url) ? "" : "\n" + service.url));
                }
                if (open && result.ok && result.services.Length == 1)
                {
                    var service = result.services[0];
                    if (service.status != "running" || !Uri.TryCreate(service.url, UriKind.Absolute, out var url)
                        || url.Scheme != "http" || url.Host != "127.0.0.1")
                        throw new InvalidOperationException("服务未返回有效的本机地址");
                    Application.OpenURL(service.url);
                }
            }
            catch (Exception error)
            {
                LastError = error.Message; Debug.LogError("Web 服务管理失败：" + error.Message);
            }
            finally { IsBusy = false; Changed?.Invoke(); }
        }

        private static async Task<Result> Execute(string action, string target)
        {
            if (action != "start" && action != "stop" && action != "status") throw new ArgumentException("无效的 Web 服务操作");
            if (!Regex.IsMatch(target, "^[a-z][a-z0-9-]*$")) throw new ArgumentException("无效的 Web 服务 ID");
            var root = Directory.GetParent(Application.dataPath).FullName;
            var script = Path.Combine(root, "Tools/WebServices/manage.mjs");
            if (!File.Exists(script)) throw new FileNotFoundException("找不到 Web 服务管理器", script);
            // 不经过 shell、不弹出终端；支持含空格的工程目录和 PROJECT_Y_NODE。
            var start = new ProcessStartInfo
            {
                FileName = Environment.GetEnvironmentVariable("PROJECT_Y_NODE") ?? "node",
                Arguments = "\"" + script + "\" " + action + " " + target,
                WorkingDirectory = root, UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8,
            };
            using (var process = Process.Start(start))
            {
                if (process == null) throw new InvalidOperationException("无法启动 Node.js，请检查 PROJECT_Y_NODE 或 PATH");
                var output = process.StandardOutput.ReadToEndAsync();
                var errors = process.StandardError.ReadToEndAsync();
                // 服务停止可能等待已有生成完成；整个等待在后台执行，不阻塞 Editor。
                if (!await Task.Run(() => process.WaitForExit(45000)))
                {
                    process.Kill();
                    throw new TimeoutException("Web 服务管理超时；请刷新状态查看实际结果");
                }
                var stdout = await output; var stderr = await errors;
                if (string.IsNullOrWhiteSpace(stdout)) throw new InvalidOperationException(string.IsNullOrWhiteSpace(stderr) ? "Web 服务管理器没有返回结果" : stderr.Trim());
                var result = JsonUtility.FromJson<Result>(stdout);
                if (result == null || result.services == null) throw new InvalidOperationException("Web 服务管理器返回的数据无效");
                if (process.ExitCode != 0 && result.ok) throw new InvalidOperationException("Web 服务管理器异常退出：" + stderr.Trim());
                return result;
            }
        }
    }

    /// <summary>注册服务列表：状态、单项操作、统一启停与日志入口。</summary>
    public sealed class WebServicesWindow : EditorWindow
    {
        private Vector2 scroll;

        [MenuItem("Project Y/Web 服务/服务管理", false, 0)]
        public static void Open() => GetWindow<WebServicesWindow>("Web 服务");

        private void OnEnable()
        {
            minSize = new Vector2(460, 280);
            WebServicesMenu.Changed += Repaint;
            WebServicesMenu.Run("status");
        }

        private void OnDisable() => WebServicesMenu.Changed -= Repaint;

        private void OnGUI()
        {
            EditorGUILayout.LabelField("当前工程的 Web 服务", EditorStyles.boldLabel);
            EditorGUILayout.LabelField("注册表：Tools/WebServices/services.json", EditorStyles.miniLabel);
            using (new EditorGUI.DisabledScope(WebServicesMenu.IsBusy))
            {
                EditorGUILayout.BeginHorizontal();
                if (GUILayout.Button("启动全部")) WebServicesMenu.StartAll();
                if (GUILayout.Button("停止全部")) WebServicesMenu.StopAll();
                if (GUILayout.Button("刷新状态")) WebServicesMenu.Run("status");
                EditorGUILayout.EndHorizontal();
            }
            if (WebServicesMenu.IsBusy) EditorGUILayout.HelpBox("正在处理，请稍候…", MessageType.Info);
            if (!string.IsNullOrEmpty(WebServicesMenu.LastError)) EditorGUILayout.HelpBox(WebServicesMenu.LastError, MessageType.Error);
            // 停止不会丢弃已提交的保存；网页中未保存的草稿仍由页面持有。
            EditorGUILayout.HelpBox("服务独立于 Editor 运行；停止全部后网页暂时无法读写，重新启动即可恢复连接。", MessageType.None);
            scroll = EditorGUILayout.BeginScrollView(scroll);
            var result = WebServicesMenu.LastResult;
            if (result != null) foreach (var service in result.services)
            {
                EditorGUILayout.BeginVertical(EditorStyles.helpBox);
                EditorGUILayout.LabelField(service.name, EditorStyles.boldLabel);
                EditorGUILayout.SelectableLabel(service.url ?? "", EditorStyles.miniLabel, GUILayout.Height(18));
                EditorGUILayout.HelpBox(service.message ?? "", service.status == "error" || service.status == "conflict" ? MessageType.Error : MessageType.None);
                using (new EditorGUI.DisabledScope(WebServicesMenu.IsBusy))
                {
                    EditorGUILayout.BeginHorizontal();
                    if (GUILayout.Button("启动 / 打开")) WebServicesMenu.Run("start", service.id, true);
                    using (new EditorGUI.DisabledScope(service.status != "running" || !service.managed))
                        if (GUILayout.Button("停止")) WebServicesMenu.Run("stop", service.id);
                    using (new EditorGUI.DisabledScope(string.IsNullOrEmpty(service.log)))
                        if (GUILayout.Button("查看日志")) EditorUtility.RevealInFinder(service.log);
                    EditorGUILayout.EndHorizontal();
                }
                EditorGUILayout.EndVertical();
            }
            EditorGUILayout.EndScrollView();
        }
    }
}
