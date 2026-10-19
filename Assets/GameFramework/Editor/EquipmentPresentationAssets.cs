using System;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Persist equipment typography and scrollable details on existing panels.</summary>
    public static class EquipmentPresentationAssets
    {
        [MenuItem("Project Y/装备/同步品质与装备详情样式")]
        public static void Sync()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("装备详情同步需要 Edit Mode。");
            var config = PanelAssets.LoadOrCreate();
            foreach (var name in new[] { "Inventory", "Loot", "EquipmentWorkbench", "EquipmentRow" })
            {
                var entry = config.Entries.Find(row => row.Name == name) ?? throw new InvalidOperationException("缺少界面：" + name);
                var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
                try
                {
                    Apply(name, root);
                    root.GetComponent<LuaReference>().ValidateBindings();
                    PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
                }
                finally { PrefabUtility.UnloadPrefabContents(root); }
            }
            AssetDatabase.SaveAssets();
            Debug.Log("Equipment quality colors and scrollable detail typography saved on all four prefabs.");
        }
        private static void Box(RectTransform rect, float x, float y, float width, float height)
        {
            rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0, 1);
            rect.anchoredPosition = new Vector2(x, -y); rect.sizeDelta = new Vector2(width, height);
        }
        private static RectTransform Node(string name, Transform parent)
        {
            var result = new GameObject(name, typeof(RectTransform)).GetComponent<RectTransform>();
            result.SetParent(parent, false); return result;
        }
        private static void Style(Text text, int size)
        {
            text.supportRichText = true; text.fontSize = size; text.resizeTextForBestFit = false;
            text.color = Color.white; text.lineSpacing = 1.16f; text.alignment = TextAnchor.UpperLeft;
            text.horizontalOverflow = HorizontalWrapMode.Wrap; text.verticalOverflow = VerticalWrapMode.Overflow;
        }
        private static void Details(Text text, RectTransform parent, float x, float y, float width, float height)
        {
            var viewport = parent.Find("ItemDetailsScroll") as RectTransform;
            ScrollRect scroll;
            if (viewport == null)
            {
                viewport = Node("ItemDetailsScroll", parent);
                var background = viewport.gameObject.AddComponent<Image>(); background.color = new Color(.065f, .083f, .105f, .7f);
                viewport.gameObject.AddComponent<RectMask2D>();
                scroll = viewport.gameObject.AddComponent<ScrollRect>();
                scroll.horizontal = false; scroll.vertical = true; scroll.inertia = false;
                scroll.movementType = ScrollRect.MovementType.Clamped; scroll.scrollSensitivity = 28;
            }
            else scroll = viewport.GetComponent<ScrollRect>() ?? throw new InvalidOperationException("详情容器缺少 ScrollRect。");
            Box(viewport, x, y, width, height);
            text.transform.SetParent(viewport, false); Style(text, 13);
            var content = text.rectTransform;
            content.anchorMin = new Vector2(0, 1); content.anchorMax = Vector2.one; content.pivot = new Vector2(0, 1);
            content.anchoredPosition = Vector2.zero; content.sizeDelta = new Vector2(-8, 0);
            var fitter = text.GetComponent<ContentSizeFitter>();
            if (fitter == null) fitter = text.gameObject.AddComponent<ContentSizeFitter>();
            fitter.horizontalFit = ContentSizeFitter.FitMode.Unconstrained; fitter.verticalFit = ContentSizeFitter.FitMode.PreferredSize;
            scroll.viewport = viewport; scroll.content = content;
        }
        internal static void Apply(string name, GameObject root)
        {
            var reference = root.GetComponent<LuaReference>();
            if (name == "Inventory")
            {
                var title = reference.GetText("ItemName"); var parent = (RectTransform)title.transform.parent;
                Style(title, 21); Box(title.rectTransform, 18, 52, 242, 58);
                var heading = parent.Find("DetailHeading").GetComponent<Text>();
                heading.text = "装备详情  ·  滚轮查看"; heading.fontSize = 12; heading.color = new Color(.56f, .65f, .76f);
                Details(reference.GetText("ItemDetail"), parent, 18, 122, 242, 252);
                Box((RectTransform)reference.GetButton("Equip").transform, 18, 392, 116, 38);
                Box((RectTransform)reference.GetButton("Unequip").transform, 144, 392, 116, 38);
                Box((RectTransform)reference.GetButton("Rotate").transform, 18, 440, 242, 36);
                reference.GetText("EquipText").text = "穿戴装备"; reference.GetText("UnequipText").text = "卸下装备";
                reference.GetText("RotateText").text = "旋转 90°";
                foreach (var key in new[] { "EquipText", "UnequipText", "RotateText" })
                {
                    var label = reference.GetText(key); var rect = label.rectTransform;
                    rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one;
                    rect.offsetMin = new Vector2(5, 2); rect.offsetMax = new Vector2(-5, -2);
                }
            }
            else if (name == "Loot")
            {
                var title = reference.GetText("ItemName"); var parent = (RectTransform)title.transform.parent;
                Box((RectTransform)parent.Find("Viewport"), 18, 74, 480, 300);
                Box(reference.GetImage("SelectedIcon").rectTransform, 18, 390, 52, 52);
                Style(title, 20); Box(title.rectTransform, 84, 390, 414, 54);
                Details(reference.GetText("ItemDetail"), parent, 18, 454, 480, 142);
            }
            else if (name == "EquipmentWorkbench")
            {
                Style(reference.GetText("Title"), 23);
                Style(reference.GetText("Stats"), 13); Style(reference.GetText("Requirements"), 13);
                reference.GetText("Stats").transform.parent.Find("StatsTitle").GetComponent<Text>().text = "装备详情与技能";
            }
            else if (name == "EquipmentRow")
            {
                Style(reference.GetText("Title"), 14);
                reference.GetText("Title").verticalOverflow = VerticalWrapMode.Truncate;
            }
            var inventory = root.GetComponent<InventoryPanelView>();
            if (inventory != null)
            {
                inventory.EditorLayout.DragLabel.supportRichText = true;
                inventory.EditorLayout.Labels = root.GetComponentsInChildren<Text>(true);
                EditorUtility.SetDirty(inventory);
            }
        }
    }
}
