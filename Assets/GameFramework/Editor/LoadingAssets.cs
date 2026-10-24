using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    public static class LoadingAssets
    {
        private static readonly Color Ink = new Color(.035f, .065f, .06f);
        private static readonly Color Gold = new Color(.84f, .72f, .44f);
        private static readonly Color Paper = new Color(.91f, .89f, .81f);

        [MenuItem("Project Y/UI/创建 Loading 界面")]
        public static void Create()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Loading 界面创建需要 Edit Mode。");
            var config = PanelAssets.LoadOrCreate();
            var entry = config.Entries.Find(value => value.Name == "Loading");
            if (entry == null) entry = PanelAssets.Save(new PanelDefinition {
                Name = "Loading", Module = "Common", Kind = UIKind.Panel, Layer = "Overlay",
                Modal = true, ModalDimAlpha = 0, Cache = true, CloseOnBack = false,
                PauseWorldOnOpen = true, CloseOnSceneChange = false }, null);
            if (entry.Prefab != null) { Debug.Log("Loading 界面已存在，保留手工布局。"); return; }
            Directory.CreateDirectory(Path.GetDirectoryName(entry.PrefabPath));
            var root = new GameObject(entry.PrefabName, typeof(RectTransform));
            try
            {
                PanelAssets.ConfigureRoot(root, entry, true);
                var bindings = new List<LuaReference.Entry>();
                var rootRect = (RectTransform)root.transform;
                Stretch(rootRect); Paint(rootRect, Ink, true);
                bindings.Add(new LuaReference.Entry("Root", rootRect));
                var page = Node("Content", rootRect);
                page.anchorMin = page.anchorMax = page.pivot = new Vector2(.5f, .5f);
                page.sizeDelta = new Vector2(880, 480);
                var emblem = Node("Compass", page); Place(emblem, 432, 38, 16, 16);
                emblem.localRotation = Quaternion.Euler(0, 0, 45); Paint(emblem, Gold);
                var line = Node("Rule", page); Place(line, 340, 81, 200, 1); Paint(line, new Color(.84f, .72f, .44f, .35f));
                var title = Label("Title", page, "创建世界", 36, Gold, 40, 104, 800, 56);
                title.alignment = TextAnchor.MiddleCenter; bindings.Add(new LuaReference.Entry("Title", title));
                bindings.Add(new LuaReference.Entry("Stage", Label("Stage", page, "准备出发", 18, Paper, 40, 212, 660, 30)));
                var percent = Label("Percent", page, "0%", 18, Gold, 720, 212, 120, 30);
                percent.alignment = TextAnchor.MiddleRight; bindings.Add(new LuaReference.Entry("Percent", percent));
                var track = Node("Progress", page); Place(track, 40, 258, 800, 8);
                Paint(track, new Color(.12f, .19f, .16f));
                var fill = Node("Fill", track); Stretch(fill); Paint(fill, Gold);
                var slider = track.gameObject.AddComponent<Slider>();
                slider.fillRect = fill; slider.minValue = 0; slider.maxValue = 1; slider.value = 0;
                slider.interactable = false; slider.transition = Selectable.Transition.None;
                slider.navigation = new Navigation { mode = Navigation.Mode.None };
                bindings.Add(new LuaReference.Entry("Progress", slider));
                var category = Label("TipCategory", page, "旅途建议", 15, Gold, 60, 328, 760, 30);
                category.alignment = TextAnchor.MiddleCenter; bindings.Add(new LuaReference.Entry("TipCategory", category));
                var tip = Label("Tip", page, "世界正在展开。", 20, Paper, 60, 370, 760, 82);
                tip.alignment = TextAnchor.UpperCenter; bindings.Add(new LuaReference.Entry("Tip", tip));
                var reference = root.GetComponent<LuaReference>();
                reference.SetEditorBindings(bindings.ToArray()); reference.ValidateBindings();
                entry.Prefab = PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
                LuaViewHints.Export(reference, entry.ViewType);
                EditorUtility.SetDirty(config); AssetDatabase.SaveAssets();
                Debug.Log("Loading Prefab、组件绑定与 PanelConfig 已保存。");
            }
            finally { UnityEngine.Object.DestroyImmediate(root); }
        }

        private static RectTransform Node(string name, Transform parent)
        {
            var rect = (RectTransform)new GameObject(name, typeof(RectTransform)).transform;
            rect.SetParent(parent, false); return rect;
        }
        private static void Stretch(RectTransform rect)
        { rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one; rect.offsetMin = rect.offsetMax = Vector2.zero; }
        private static void Place(RectTransform rect, float x, float y, float width, float height)
        {
            rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0, 1);
            rect.anchoredPosition = new Vector2(x, -y); rect.sizeDelta = new Vector2(width, height);
        }
        private static void Paint(RectTransform rect, Color color, bool raycast = false)
        { var image = rect.gameObject.AddComponent<Image>(); image.color = color; image.raycastTarget = raycast; }
        private static Text Label(string name, Transform parent, string value, int size, Color color, float x, float y, float width, float height)
        {
            var label = Node(name, parent).gameObject.AddComponent<Text>();
            label.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); label.text = value;
            label.fontSize = size; label.color = color; label.raycastTarget = false; label.supportRichText = false;
            label.horizontalOverflow = HorizontalWrapMode.Wrap; label.verticalOverflow = VerticalWrapMode.Truncate;
            Place(label.rectTransform, x, y, width, height); return label;
        }
    }
}
