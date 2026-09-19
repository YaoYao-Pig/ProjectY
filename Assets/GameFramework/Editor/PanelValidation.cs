using System;
using System.IO;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    public static class PanelValidation
    {
        [MenuItem("Project Y/Tests/Run Panel Checks")]
        public static void Run()
        {
            if (EditorApplication.isPlaying) throw new InvalidOperationException("Stop Play Mode before editor checks.");
            FrameworkTools.CreateDemo();
            var config = PanelAssets.LoadOrCreate();
            var testName = "PanelTest" + Guid.NewGuid().ToString("N");
            var initialScale = Time.timeScale;
            var originalInfoPause = config.Get("Info").PauseWorldOnOpen;
            GameObject hostObject = null;
            try
            {
                Throws(() => PanelAssets.Save(new PanelDefinition { Name = "../Bad" }, null));
                Throws(() => PanelAssets.Save(new PanelDefinition { Name = "end", Kind = UIKind.Widget }, null));
                Throws(() => PanelAssets.Save(new PanelDefinition { Name = "demo" }, null));
                var entry = PanelAssets.Save(new PanelDefinition { Name = testName, Module = testName, IsWorldUI = true,
                    SupportsHotSwitch = true, PauseWorldOnOpen = true, CloseOnSceneChange = true }, null);
                PanelAssets.Generate(entry);
                Check(entry.Prefab.GetComponent<LuaPanel>() != null && entry.Prefab.GetComponent<GraphicRaycaster>() != null, "Panel components missing.");
                Check(entry.Prefab.GetComponent<Canvas>().renderMode == RenderMode.WorldSpace, "World canvas generation failed.");
                var controller = PanelAssets.ControllerPath(entry);
                Check(File.ReadAllText(controller).Contains("UI.UIPanelCtrl"), "Wrong generated controller base.");
                File.AppendAllText(controller, "\n-- preserve custom implementation\n");
                var content = File.ReadAllText(controller);
                var contents = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
                try
                {
                    var button = new GameObject("Button", typeof(RectTransform), typeof(Image), typeof(Button));
                    button.transform.SetParent(contents.transform, false);
                    contents.GetComponent<LuaReference>().SetEditorBindings(new LuaReference.Entry("Confirm", button.GetComponent<Button>()));
                    PrefabUtility.SaveAsPrefabAsset(contents, entry.PrefabPath);
                }
                finally { PrefabUtility.UnloadPrefabContents(contents); }
                PanelAssets.Generate(entry);
                Check(File.ReadAllText(controller) == content, "Generation overwrote custom Lua code.");
                Check(entry.Prefab.GetComponent<LuaReference>().Get("Confirm") is Button, "Generation erased bindings.");
                var hints = Path.Combine(LuaScriptPaths.RuntimeRoot, "UI/Types/" + entry.ViewType + ".lua");
                Check(File.ReadAllText(hints).Contains("---@field Confirm CS.UnityEngine.UI.Button"), "Component hints missing.");
                Check(!LuaBuildFiles.Collect(LuaScriptPaths.RuntimeRoot).Any(file => Path.GetFullPath(file) == Path.GetFullPath(hints)), "Editor hints leaked into player inputs.");
                var guid = AssetDatabase.AssetPathToGUID(entry.PrefabPath);
                var oldPath = entry.PrefabPath;
                var draft = JsonUtility.FromJson<PanelDefinition>(JsonUtility.ToJson(entry)); draft.Module += "Moved";
                entry = PanelAssets.Save(draft, entry.Name);
                Check(!File.Exists(oldPath) && AssetDatabase.AssetPathToGUID(entry.PrefabPath) == guid, "Module move lost GUID.");
                Check(entry.SupportsHotSwitch && entry.PauseWorldOnOpen && entry.CloseOnSceneChange, "Panel flags not preserved.");
                hostObject = new GameObject("PanelValidationHost");
                var host = hostObject.AddComponent<UIHost>(); host.Initialize();
                config.Get("Info").PauseWorldOnOpen = true;
                Time.timeScale = 0.5f;
                var first = host.CreateView(testName); var second = host.CreateView("Info");
                var screenRoot = second.transform.parent.GetComponent<Canvas>();
                var worldRoot = first.transform.parent.GetComponent<Canvas>();
                Check(screenRoot != worldRoot && screenRoot.transform.parent == host.transform && worldRoot.transform.parent == host.transform,
                    "Screen and world UI must use separate host-owned roots.");
                Check(screenRoot.name == "UIRoot" && screenRoot.renderMode == RenderMode.ScreenSpaceOverlay && screenRoot.isRootCanvas,
                    "Screen root canvas missing.");
                Check(worldRoot.name == "WorldUIRoot" && worldRoot.renderMode == RenderMode.WorldSpace && worldRoot.isRootCanvas,
                    "World root canvas missing.");
                Check(!host.GetPanel(first).Canvas.isRootCanvas && !host.GetPanel(second).Canvas.isRootCanvas,
                    "Panels must be nested canvases.");
                var screenRect = (RectTransform)second.transform;
                Check(screenRect.anchorMin == Vector2.zero && screenRect.anchorMax == Vector2.one &&
                    screenRect.offsetMin == Vector2.zero && screenRect.offsetMax == Vector2.zero && screenRect.localScale == Vector3.one,
                    "Screen panel must stretch to UIRoot without applying a second scale.");
                Check(first.transform.localScale == entry.Prefab.transform.localScale && worldRoot.transform.localScale == Vector3.one &&
                    first.transform.localPosition == entry.Prefab.transform.localPosition && first.transform.localRotation == entry.Prefab.transform.localRotation &&
                    ((RectTransform)first.transform).sizeDelta == ((RectTransform)entry.Prefab.transform).sizeDelta,
                    "World root changed authored panel size or transform.");
                var rootScaler = screenRoot.GetComponent<CanvasScaler>();
                Check(rootScaler.uiScaleMode == CanvasScaler.ScaleMode.ScaleWithScreenSize && rootScaler.referenceResolution == new Vector2(1280, 720),
                    "Screen scaling must be owned by UIRoot.");
                Check(!host.IsWorldPaused, "Inactive panel paused the world.");
                host.SetVisible(first, true); host.SetVisible(first, true); host.SetVisible(second, true);
                Check(Time.timeScale == 0 && host.IsWorldPaused, "Open did not acquire pause.");
                Check(host.GetPanel(first).Canvas.renderMode == RenderMode.WorldSpace, "Runtime world canvas mismatch.");
                host.SetVisible(first, false);
                Check(Time.timeScale == 0, "Closing one panel released another panel's pause.");
                host.SetVisible(second, false);
                Check(Time.timeScale == 0.5f && !host.IsWorldPaused, "Prior time scale not restored.");
                host.SetVisible(first, true); host.DestroyView(first);
                Check(Time.timeScale == 0.5f, "Destroy leaked pause ownership.");
                var widget = host.CreateWidget("Stats", second.transform);
                Check(widget.Get("Stats") is Text, "Widget prefab binding failed.");
                host.DestroyWidget(widget);
                host.SetVisible(second, true); host.Shutdown();
                Check(Time.timeScale == 0.5f, "Shutdown leaked pause ownership.");
                Check(screenRoot == null && worldRoot == null, "Shutdown leaked UI roots.");
                host.Shutdown(); host.Initialize();
                var reopened = host.CreateView("Info");
                Check(reopened.transform.parent.name == "UIRoot", "Reinitialize did not recreate UI roots.");
                host.Shutdown();
                Debug.Log("PROJECT_Y_PANEL_PASS: generation, preserved bindings/controllers, EmmyLua, module move, screen/world roots, pause ownership and widget instantiation.");
            }
            finally
            {
                if (hostObject != null) Object.DestroyImmediate(hostObject);
                Time.timeScale = initialScale;
                config.Get("Info").PauseWorldOnOpen = originalInfoPause;
                config.Entries.RemoveAll(x => x.Name == testName);
                EditorUtility.SetDirty(config); AssetDatabase.SaveAssets();
                // Only assets/scripts created with this invocation's unique identifier are removed.
                AssetDatabase.DeleteAsset(PanelConfig.PrefabRoot + "/" + testName);
                AssetDatabase.DeleteAsset(PanelConfig.PrefabRoot + "/" + testName + "Moved");
                var lua = Path.Combine(LuaScriptPaths.RuntimeRoot, "UI/Panel/" + testName + "Ctr.lua");
                var hints = Path.Combine(LuaScriptPaths.RuntimeRoot, "UI/Types/" + testName + "PanelView.lua");
                if (File.Exists(lua)) File.Delete(lua);
                if (File.Exists(hints)) File.Delete(hints);
            }
        }
        private static void Check(bool success, string message) { if (!success) throw new InvalidOperationException(message); }
        private static void Throws(Action action)
        {
            try { action(); } catch (InvalidOperationException) { return; }
            throw new InvalidOperationException("Expected invalid configuration rejection.");
        }
    }
}
