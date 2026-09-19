using System;
using System.IO;
using System.Linq;
using System.Text;
using ProjectY.UI;
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Generation implementation shared by the window, demo setup and build validation.</summary>
    public static class PanelAssets
    {
        public static PanelConfig LoadOrCreate()
        {
            var config = AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            if (config != null) return config;
            EnsureFolder(Path.GetDirectoryName(PanelConfig.AssetPath));
            config = ScriptableObject.CreateInstance<PanelConfig>();
            AssetDatabase.CreateAsset(config, PanelConfig.AssetPath);
            AssetDatabase.SaveAssets();
            return config;
        }

        public static void EnsureFolder(string path)
        {
            Directory.CreateDirectory(path);
            AssetDatabase.Refresh();
        }

        public static PanelDefinition Save(PanelDefinition draft, string originalName)
        {
            draft.Validate(false);
            var config = LoadOrCreate();
            var previous = config.Entries.FirstOrDefault(x => x.Name == originalName);
            if (previous != null && (previous.Name != draft.Name || previous.Kind != draft.Kind))
                throw new InvalidOperationException("Existing config names and kinds are stable; create a new entry instead.");
            if (config.Entries.Any(x => x != previous && string.Equals(x.Name, draft.Name, StringComparison.OrdinalIgnoreCase)))
                throw new InvalidOperationException("UI names must be globally unique, including case: " + draft.Name);
            if (config.Entries.Any(x => x != previous && string.Equals(x.Module, draft.Module, StringComparison.OrdinalIgnoreCase) && x.Module != draft.Module))
                throw new InvalidOperationException("Module capitalization must match the existing folder.");
            var next = JsonUtility.FromJson<PanelDefinition>(JsonUtility.ToJson(draft));
            next.Prefab = previous?.Prefab;
            if (next.Prefab != null)
            {
                var currentPath = AssetDatabase.GetAssetPath(next.Prefab);
                if (!currentPath.StartsWith(PanelConfig.PrefabRoot + "/", StringComparison.Ordinal))
                    throw new InvalidOperationException("UI prefab must live under " + PanelConfig.PrefabRoot);
                if (currentPath != next.PrefabPath)
                {
                    if (File.Exists(next.PrefabPath)) throw new InvalidOperationException("Destination prefab already exists: " + next.PrefabPath);
                    EnsureFolder(Path.GetDirectoryName(next.PrefabPath));
                    var error = AssetDatabase.MoveAsset(currentPath, next.PrefabPath);
                    if (!string.IsNullOrEmpty(error)) throw new InvalidOperationException(error);
                }
            }
            if (previous == null) config.Entries.Add(next); else config.Entries[config.Entries.IndexOf(previous)] = next;
            EditorUtility.SetDirty(config); AssetDatabase.SaveAssets();
            return next;
        }

        public static string ControllerPath(PanelDefinition entry) => Path.Combine(LuaScriptPaths.RuntimeRoot, entry.ControllerModule.Replace('.', '/') + ".lua");

        public static void Generate(PanelDefinition entry)
        {
            entry.Validate(false);
            EnsureFolder(Path.GetDirectoryName(entry.PrefabPath));
            var existing = AssetDatabase.LoadAssetAtPath<GameObject>(entry.PrefabPath);
            if (entry.Prefab != null && existing != entry.Prefab) throw new InvalidOperationException("Prefab reference/path mismatch.");
            GameObject root = existing != null ? PrefabUtility.LoadPrefabContents(entry.PrefabPath) : new GameObject(entry.PrefabName, typeof(RectTransform));
            try
            {
                ConfigureRoot(root, entry, existing == null);
                root.GetComponent<LuaReference>().ValidateBindings();
                entry.Prefab = PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
            }
            finally
            {
                if (existing != null) PrefabUtility.UnloadPrefabContents(root); else Object.DestroyImmediate(root);
            }
            WriteControllerIfMissing(entry);
            LuaViewHints.Export(entry.Prefab.GetComponent<LuaReference>(), entry.ViewType);
            var config = LoadOrCreate(); EditorUtility.SetDirty(config); AssetDatabase.SaveAssets();
        }

        public static void ConfigureRoot(GameObject root, PanelDefinition entry, bool fresh)
        {
            if (!(root.transform is RectTransform)) throw new InvalidOperationException("UI root requires RectTransform.");
            var view = root.GetComponent<LuaReference>();
            bool newReference = view == null;
            if (newReference) view = root.AddComponent<LuaReference>();
            if (root.GetComponent<CanvasGroup>() == null) root.AddComponent<CanvasGroup>();
            if (!entry.IsWidget)
            {
                var panel = root.GetComponent<LuaPanel>();
                if (panel == null) panel = root.AddComponent<LuaPanel>();
                var canvas = root.GetComponent<Canvas>();
                canvas.renderMode = entry.IsWorldUI ? RenderMode.WorldSpace : RenderMode.ScreenSpaceOverlay;
                var scaler = root.GetComponent<CanvasScaler>();
                if (fresh)
                {
                    scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
                    scaler.referenceResolution = new Vector2(1280, 720); scaler.matchWidthOrHeight = 0.5f;
                    var rect = (RectTransform)root.transform;
                    rect.sizeDelta = new Vector2(1280, 720);
                    if (entry.IsWorldUI) rect.localScale = Vector3.one * 0.01f;
                }
                if (fresh || newReference) view.SetEditorBindings(new LuaReference.Entry("Root", root.transform), new LuaReference.Entry("Canvas", canvas), new LuaReference.Entry("Panel", panel));
            }
            else if (fresh || newReference)
            {
                ((RectTransform)root.transform).sizeDelta = new Vector2(300, 160);
                view.SetEditorBindings(new LuaReference.Entry("Root", root.transform));
            }
        }

        private static void WriteControllerIfMissing(PanelDefinition entry)
        {
            var path = ControllerPath(entry);
            if (File.Exists(path)) return;
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            var name = entry.IsWidget ? entry.Name : entry.Name + "Ctr";
            var baseName = entry.IsWidget ? "UIWidgetCtrl" : "UIPanelCtrl";
            var source = "local Class = require('Core.Class')\nlocal Base = require('UI." + baseName + "')\n" +
                "---@class " + name + " : " + baseName + "\n---@field view " + entry.ViewType + "\n" +
                "local " + name + " = Class('" + name + "', Base)\n\n" +
                "function " + name + ":Bind()\n    -- Bind once: self:Listen(self.view.YourButton, function() ... end)\nend\n\n" +
                "function " + name + ":OnShow(args)\n    -- Use visibleScope for subscriptions that last only while visible.\nend\n\n" +
                "return " + name + "\n";
            File.WriteAllText(path, source, new UTF8Encoding(false));
        }

        [MenuItem("Project Y/UI/Export All View Hints")]
        public static void ExportAllHints()
        {
            var config = LoadOrCreate(); config.Validate(true);
            foreach (var entry in config.Entries) LuaViewHints.Export(entry.Prefab.GetComponent<LuaReference>(), entry.ViewType);
        }

        public static void ValidateForBuild()
        {
            var config = AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            if (config == null) throw new BuildFailedException("Generate PanelConfig before building.");
            config.Validate(true);
            foreach (var entry in config.Entries)
            {
                if (AssetDatabase.GetAssetPath(entry.Prefab) != entry.PrefabPath)
                    throw new BuildFailedException(entry.Name + ": prefab path differs from PanelConfig.");
                if (!File.Exists(ControllerPath(entry))) throw new BuildFailedException("Missing controller: " + ControllerPath(entry));
            }
        }
    }
}
