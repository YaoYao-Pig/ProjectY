using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using Debug = UnityEngine.Debug;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    public static class FrameworkTools
    {
        public const string DemoScene = "Assets/GameFramework/Samples/FrameworkDemo.unity";

        [MenuItem("Project Y/Config/Export Tables")]
        public static void ExportConfig()
        {
            var root = Directory.GetParent(Application.dataPath).FullName;
            var start = new ProcessStartInfo
            {
                FileName = Environment.GetEnvironmentVariable("PROJECT_Y_NODE") ?? "node",
                Arguments = "\"" + Path.Combine(root, "Tools/ConfigEditor/exporter.mjs") + "\"",
                WorkingDirectory = root,
                UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true
            };
            using (var process = Process.Start(start))
            {
                var output = process.StandardOutput.ReadToEndAsync();
                var error = process.StandardError.ReadToEndAsync();
                if (!process.WaitForExit(60000)) { process.Kill(); throw new BuildFailedException("Config export timed out."); }
                if (process.ExitCode != 0) throw new BuildFailedException(error.GetAwaiter().GetResult());
                Debug.Log(output.GetAwaiter().GetResult());
            }
            AssetDatabase.Refresh();
        }

        [MenuItem("Project Y/Config/Open Local Editor")]
        public static void OpenConfigEditor() => Application.OpenURL("http://127.0.0.1:4173");

        [MenuItem("Project Y/Demo/Create Missing Assets")]
        public static void CreateDemo()
        {
            PanelAssets.EnsureFolder(PanelConfig.PrefabRoot + "/Demo");
            Directory.CreateDirectory("Assets/GameFramework/Samples");
            MigrateDemoPrefab("Demo"); MigrateDemoPrefab("Info");
            if (!File.Exists(PanelConfig.PrefabRoot + "/Demo/DemoPanel.prefab")) CreateDemoPanel();
            if (!File.Exists(PanelConfig.PrefabRoot + "/Demo/InfoPanel.prefab")) CreateInfoPanel();
            EnsureDemoConfig();
            if (!File.Exists(DemoScene))
            {
                var previous = SceneManager.GetActiveScene();
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
                SceneManager.SetActiveScene(scene);
                try
                {
                    new GameObject("GameBootstrap").AddComponent<GameBootstrap>();
                    EditorSceneManager.SaveScene(scene, DemoScene);
                }
                finally { SceneManager.SetActiveScene(previous); EditorSceneManager.CloseScene(scene, true); }
            }
            AssetDatabase.SaveAssets(); AssetDatabase.Refresh();
            Debug.Log("Framework demo ready: " + DemoScene);
        }

        private static void MigrateDemoPrefab(string name)
        {
            var oldPath = "Assets/GameFramework/Resources/UI/" + name + "Panel.prefab";
            var path = PanelConfig.PrefabRoot + "/Demo/" + name + "Panel.prefab";
            if (!File.Exists(oldPath) || File.Exists(path)) return;
            var error = AssetDatabase.MoveAsset(oldPath, path);
            if (!string.IsNullOrEmpty(error)) throw new InvalidOperationException(error);
        }

        private static void EnsureDemoConfig()
        {
            var config = PanelAssets.LoadOrCreate();
            if (!config.Entries.Any(x => x.Name == "Demo")) PanelAssets.Save(new PanelDefinition { Name = "Demo", Module = "Demo", CloseOnBack = false, CloseOnSceneChange = false }, null);
            if (!config.Entries.Any(x => x.Name == "Info")) PanelAssets.Save(new PanelDefinition { Name = "Info", Module = "Demo", Layer = "Popup", Modal = true, Cache = false }, null);
            if (!config.Entries.Any(x => x.Name == "Stats")) PanelAssets.Save(new PanelDefinition { Name = "Stats", Module = "Demo", Kind = UIKind.Widget }, null);
            var stats = config.Get("Stats");
            if (!File.Exists(stats.PrefabPath))
            {
                var demo = AssetDatabase.LoadAssetAtPath<GameObject>(config.Get("Demo").PrefabPath);
                var source = demo.GetComponent<LuaReference>().GetReference("StatsWidget");
                var root = Object.Instantiate(source.gameObject); root.name = "StatsWidget";
                try { PrefabUtility.SaveAsPrefabAsset(root, stats.PrefabPath); }
                finally { Object.DestroyImmediate(root); }
            }
            EnsureDemoCanvasRoot(config.Get("Demo")); EnsureDemoCanvasRoot(config.Get("Info"));
            foreach (var entry in config.Entries.Where(x => x.Name == "Demo" || x.Name == "Info" || x.Name == "Stats")) PanelAssets.Generate(entry);
        }

        private static void EnsureDemoCanvasRoot(PanelDefinition entry)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(entry.PrefabPath);
            if (prefab.GetComponent<Image>() == null) return;
            // The original demo was a sized Image under a shared Canvas. Preserve that content geometry.
            var root = new GameObject(entry.PrefabName, typeof(RectTransform), typeof(LuaReference));
            try
            {
                var content = Object.Instantiate(prefab, root.transform, false); content.name = "Content";
                var view = content.GetComponent<LuaReference>();
                root.GetComponent<LuaReference>().SetEditorBindings(view.GetEditorBindings());
                foreach (var type in new[] { typeof(LuaPanel), typeof(GraphicRaycaster), typeof(CanvasScaler), typeof(Canvas), typeof(CanvasGroup), typeof(LuaReference) })
                {
                    var component = content.GetComponent(type);
                    if (component != null) Object.DestroyImmediate(component);
                }
                var rect = (RectTransform)content.transform;
                rect.anchorMin = rect.anchorMax = new Vector2(0.5f, 0.5f);
                rect.anchoredPosition = Vector2.zero;
                PanelAssets.ConfigureRoot(root, entry, false);
                var scaler = root.GetComponent<CanvasScaler>();
                scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
                scaler.referenceResolution = new Vector2(1280, 720); scaler.matchWidthOrHeight = 0.5f;
                entry.Prefab = PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
            }
            finally { Object.DestroyImmediate(root); }
        }

        [MenuItem("Project Y/Demo/Open Scene")]
        public static void OpenDemo()
        {
            CreateDemo();
            if (EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) EditorSceneManager.OpenScene(DemoScene);
        }

        private static GameObject Box(string name, Transform parent, Vector2 size, Vector2 position, Color color)
        {
            var obj = new GameObject(name, typeof(RectTransform), typeof(Image));
            if (parent != null) obj.transform.SetParent(parent, false);
            var rect = (RectTransform)obj.transform; rect.sizeDelta = size; rect.anchoredPosition = position;
            obj.GetComponent<Image>().color = color;
            return obj;
        }
        private static Text Label(string name, Transform parent, string text, Vector2 size, Vector2 position, int fontSize)
        {
            var obj = new GameObject(name, typeof(RectTransform), typeof(Text)); obj.transform.SetParent(parent, false);
            var rect = (RectTransform)obj.transform; rect.sizeDelta = size; rect.anchoredPosition = position;
            var label = obj.GetComponent<Text>(); label.text = text;
            label.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); label.fontSize = fontSize;
            label.alignment = TextAnchor.MiddleCenter; label.color = new Color(0.90f, 0.95f, 0.93f); label.raycastTarget = false;
            return label;
        }
        private static Button MakeButton(string name, Transform parent, string caption, Vector2 position, float width = 220)
        {
            var obj = Box(name, parent, new Vector2(width, 52), position, new Color(0.17f, 0.45f, 0.34f));
            var button = obj.AddComponent<Button>(); button.targetGraphic = obj.GetComponent<Image>();
            Label("Caption", obj.transform, caption, new Vector2(width, 52), Vector2.zero, 19);
            return button;
        }
        private static void CreateDemoPanel()
        {
            var root = Box("DemoPanel", null, new Vector2(1000, 610), Vector2.zero, new Color(0.065f, 0.13f, 0.11f));
            try
            {
                var view = root.AddComponent<LuaReference>();
                var title = Label("Title", root.transform, "PROJECT Y", new Vector2(900, 65), new Vector2(0, 208), 34);
                var description = Label("Description", root.transform, "", new Vector2(850, 85), new Vector2(0, 120), 21);
                var widget = Box("StatsWidget", root.transform, new Vector2(780, 84), new Vector2(0, 15), new Color(0.11f, 0.22f, 0.18f));
                var widgetRef = widget.AddComponent<LuaReference>();
                widgetRef.SetEditorBindings(new LuaReference.Entry("Stats", Label("Stats", widget.transform, "", new Vector2(760, 84), Vector2.zero, 28)));
                var reward = MakeButton("Reward", root.transform, "CLAIM REWARD", new Vector2(-255, -106));
                var level = MakeButton("LevelUp", root.transform, "LEVEL UP", new Vector2(0, -106));
                var info = MakeButton("Info", root.transform, "OPEN MODAL", new Vector2(255, -106));
                Label("Footer", root.transform, "LuaSystem  /  Panel + Widget  /  C# Data  /  Binary Config", new Vector2(920, 40), new Vector2(0, -226), 17);
                view.SetEditorBindings(new LuaReference.Entry("Title", title), new LuaReference.Entry("Description", description), new LuaReference.Entry("StatsWidget", widgetRef), new LuaReference.Entry("Reward", reward), new LuaReference.Entry("LevelUp", level), new LuaReference.Entry("Info", info));
                PrefabUtility.SaveAsPrefabAsset(root, PanelConfig.PrefabRoot + "/Demo/DemoPanel.prefab");
            }
            finally { Object.DestroyImmediate(root); }
        }
        private static void CreateInfoPanel()
        {
            var root = Box("InfoPanel", null, new Vector2(640, 350), Vector2.zero, new Color(0.13f, 0.23f, 0.19f));
            try
            {
                var view = root.AddComponent<LuaReference>();
                Label("Title", root.transform, "A LUA-CONTROLLED MODAL", new Vector2(610, 60), new Vector2(0, 105), 26);
                Label("Description", root.transform, "This panel blocks input to lower windows.\nClose it with the button or Escape.\nIts Lua listeners are released on close.", new Vector2(590, 110), new Vector2(0, 10), 19);
                view.SetEditorBindings(new LuaReference.Entry("Close", MakeButton("Close", root.transform, "CLOSE", new Vector2(0, -108))));
                PrefabUtility.SaveAsPrefabAsset(root, PanelConfig.PrefabRoot + "/Demo/InfoPanel.prefab");
            }
            finally { Object.DestroyImmediate(root); }
        }
    }

    public sealed class FrameworkBuildGate : BuildPlayerProcessor
    {
        public override void PrepareForBuild(BuildPlayerContext buildPlayerContext)
        {
            FrameworkTools.ExportConfig();
            PanelAssets.ValidateForBuild();
            if (!File.Exists("Assets/XLua/Gen/DelegatesGensBridge.cs"))
                throw new BuildFailedException("Run XLua > Generate Code before building (C# to Lua AOT bridges are required).");
            var root = LuaScriptPaths.RuntimeRoot;
            foreach (var file in LuaBuildFiles.Collect(root))
            {
                // Include original .lua sources directly in player data without creating duplicate Assets.
                var relative = file.Substring(root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar).Length + 1).Replace('\\', '/');
                buildPlayerContext.AddAdditionalPathToStreamingAssets(file, LuaScriptPaths.DirectoryName + "/" + relative);
            }
        }
    }
}
