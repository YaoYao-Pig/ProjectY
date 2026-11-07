using System;
using System.Collections.Generic;
using ProjectY.UI;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Incremental course-detail authoring; existing controls and authored placement stay intact.</summary>
    [InitializeOnLoad]
    public static class GrowthSkillDetailAssets
    {
        private static readonly Color Ink = new Color(.22f, .25f, .21f, 1);
        private static readonly Color Muted = new Color(.43f, .44f, .36f, 1);
        private static readonly Color Paper = new Color(.97f, .95f, .88f, .55f);
        private static readonly Color RequirementPaper = new Color(.91f, .92f, .84f, .82f);
        private static readonly Color Green = new Color(50 / 255f, 115 / 255f, 79 / 255f, 1);
        private static readonly Color Red = new Color(171 / 255f, 77 / 255f, 60 / 255f, 1);

        static GrowthSkillDetailAssets() => LuaViewHints.Register(typeof(GrowthSkillDetailView), "CS.ProjectY.UI.GrowthSkillDetailView");

        [MenuItem("Project Y/UI/同步职业课程详情")]
        public static void Sync()
        {
            RequireIdleEditor();
            var config = AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            if (config == null) throw new InvalidOperationException("Missing PanelConfig for course details.");
            var entry = config.Get("CharacterGrowth");
            if (entry == null || entry.Prefab == null) throw new InvalidOperationException("Create CharacterGrowth before its course details.");
            var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            bool dirty = scene.isDirty;
            var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                Apply(root);
                var reference = root.GetComponent<LuaReference>();
                reference.ValidateBindings();
                PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
                LuaViewHints.Export(reference, entry.ViewType);
            }
            finally { PrefabUtility.UnloadPrefabContents(root); }
            if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != scene || scene.isDirty != dirty)
                throw new InvalidOperationException("Course-detail synchronization changed the active scene.");
            Debug.Log("CharacterGrowth course detail saved; existing layout and bindings preserved.");
        }

        public static void Apply(GameObject root)
        {
            RequireIdleEditor();
            if (root == null) throw new ArgumentNullException(nameof(root));
            var reference = root.GetComponent<LuaReference>();
            if (reference == null) throw new InvalidOperationException("CharacterGrowth requires its LuaReference.");
            var entries = new List<LuaReference.Entry>(reference.GetEditorBindings());
            int existingIndex = entries.FindIndex(entry => entry.Key == "CourseDetail");
            if (existingIndex >= 0)
            {
                var existing = entries[existingIndex];
                if (!(existing.Target is GrowthSkillDetailView existingView))
                    throw new InvalidOperationException("CharacterGrowth.CourseDetail must bind GrowthSkillDetailView.");
                Validate(existingView);
                return;
            }
            var parent = reference.Get("Skills") as RectTransform;
            if (parent == null) throw new InvalidOperationException("CharacterGrowth.Skills must bind its RectTransform.");
            if (parent.Find("CourseDetail") != null)
                throw new InvalidOperationException("An unbound CourseDetail node already exists; repair its binding before migration.");
            var font = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(SkillTooltipAssets.FontPath);
            if (font == null || !font.HasCharacter('_'))
                throw new InvalidOperationException("Course detail needs the existing Noto Sans CJK TMP font with underline/strikethrough support.");
            var detail = Create(parent, font);
            entries.Add(new LuaReference.Entry("CourseDetail", detail));
            reference.SetEditorBindings(entries.ToArray());
            reference.ValidateBindings();
            EditorUtility.SetDirty(reference);
        }

        private static void RequireIdleEditor()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling)
                throw new InvalidOperationException("Course detail authoring requires idle Edit Mode.");
        }

        private static void Validate(GrowthSkillDetailView view)
        {
            var layout = view.EditorLayout;
            if (layout == null || layout.Root == null || layout.Tags == null || layout.Conditions == null ||
                layout.Body == null || layout.Heading == null || layout.Status == null || layout.Equipment == null ||
                layout.Scroll == null || layout.Scroll.viewport == null || layout.Scroll.content == null ||
                layout.Scroll.verticalScrollbar == null || layout.TagTemplate == null || layout.ConditionTemplate == null ||
                layout.TagTemplate.Rect == null || layout.TagTemplate.Caption == null || layout.TagTemplate.Background == null ||
                layout.ConditionTemplate.Rect == null || layout.ConditionTemplate.Caption == null ||
                layout.ConditionTemplate.Background == null || layout.ConditionTemplate.Mask == null)
                throw new InvalidOperationException("Existing CourseDetail has missing serialized bindings; refusing to overwrite authored content.");
        }

        private static GrowthSkillDetailView Create(RectTransform parent, TMP_FontAsset font)
        {
            var root = Node("CourseDetail", parent, 267, 176);
            Box(root, 607, 37, 267, 176);
            Paint(root, Paper, true);
            var view = root.gameObject.AddComponent<GrowthSkillDetailView>();
            var scrollRoot = Node("Scroll", root, 267, 176); Stretch(scrollRoot);
            var scroll = scrollRoot.gameObject.AddComponent<ScrollRect>();
            scroll.horizontal = false; scroll.vertical = true; scroll.inertia = false;
            scroll.scrollSensitivity = 26; scroll.movementType = ScrollRect.MovementType.Clamped;
            var viewport = Node("Viewport", scrollRoot, 258, 176); Stretch(viewport, 0, 0, 9, 0);
            Paint(viewport, Color.clear, true); viewport.gameObject.AddComponent<RectMask2D>();
            var content = Node("Content", viewport, 258, 176);
            scroll.viewport = viewport; scroll.content = content;
            var scrollbarRect = Node("Scrollbar", scrollRoot, 4, 176);
            scrollbarRect.anchorMin = new Vector2(1, 0); scrollbarRect.anchorMax = Vector2.one;
            scrollbarRect.pivot = new Vector2(1, .5f); scrollbarRect.offsetMin = new Vector2(-4, 1); scrollbarRect.offsetMax = new Vector2(0, -1);
            Paint(scrollbarRect, new Color(.67f, .66f, .56f, .22f), true);
            var sliding = Node("SlidingArea", scrollbarRect, 4, 176); Stretch(sliding);
            var handle = Node("Handle", sliding, 4, 70); Stretch(handle);
            var handleImage = Paint(handle, new Color(.43f, .49f, .37f, .85f), true);
            var scrollbar = scrollbarRect.gameObject.AddComponent<Scrollbar>();
            scrollbar.direction = Scrollbar.Direction.BottomToTop; scrollbar.handleRect = handle; scrollbar.targetGraphic = handleImage;
            scrollbar.navigation = new Navigation { mode = Navigation.Mode.None };
            scroll.verticalScrollbar = scrollbar; scroll.verticalScrollbarVisibility = ScrollRect.ScrollbarVisibility.AutoHide;

            var tags = Node("Tags", content, 242, 22);
            var body = Label("Description", content, font, 13, Ink); body.lineSpacing = 3;
            var equipment = Label("Equipment", content, font, 12, Muted); equipment.lineSpacing = 2;
            var conditions = Node("UnlockRequirements", content, 242, 80); Paint(conditions, RequirementPaper, false);
            var heading = Label("Heading", conditions, font, 12, Ink); heading.fontStyle = FontStyles.Bold;
            var status = Label("Status", conditions, font, 12, Muted);

            var tagRect = Node("TagTemplate", tags, 60, 21);
            var tag = tagRect.gameObject.AddComponent<SkillTooltipItemView>();
            tag.Rect = tagRect; tag.Background = Paint(tagRect, new Color(.29f, .43f, .34f, 1), false);
            tag.Caption = Label("Caption", tagRect, font, 11, Color.white);
            tag.Caption.alignment = TextAlignmentOptions.Center; tag.Caption.richText = false;

            var conditionRect = Node("ConditionTemplate", conditions, 226, 24);
            var condition = conditionRect.gameObject.AddComponent<SkillTooltipItemView>(); condition.Rect = conditionRect;
            var box = Node("Checkbox", conditionRect, 15, 15); Box(box, 0, 3, 15, 15);
            condition.Background = Paint(box, Red, false);
            var interior = Node("Interior", box, 11, 11); Stretch(interior, 1.5f, 1.5f, 1.5f, 1.5f);
            Paint(interior, new Color(.94f, .94f, .88f, 1), false);
            var mark = Node("Checkmark", box, 15, 15); Stretch(mark); condition.Mask = mark;
            Stroke(mark, "ShortStroke", new Vector2(3.2f, -7.9f), new Vector2(6.2f, -10.8f));
            Stroke(mark, "LongStroke", new Vector2(6.2f, -10.8f), new Vector2(12.3f, -4.1f));
            condition.Caption = Label("Caption", conditionRect, font, 12, Red); condition.Caption.lineSpacing = 2;
            mark.gameObject.SetActive(false);

            view.SetEditorLayout(new GrowthSkillDetailView.Layout {
                Root = root, Scroll = scroll, Tags = tags, Body = body, Equipment = equipment,
                Conditions = conditions, Heading = heading, Status = status, TagTemplate = tag, ConditionTemplate = condition
            });
            tag.gameObject.SetActive(false); condition.gameObject.SetActive(false); root.gameObject.SetActive(false);
            Validate(view);
            return view;
        }

        private static void Stroke(RectTransform parent, string name, Vector2 from, Vector2 to)
        {
            var delta = to - from;
            var rect = Node(name, parent, delta.magnitude, 1.8f);
            rect.pivot = new Vector2(0, .5f); rect.anchoredPosition = from;
            rect.localRotation = Quaternion.Euler(0, 0, Mathf.Atan2(delta.y, delta.x) * Mathf.Rad2Deg);
            Paint(rect, Green, false);
        }

        private static RectTransform Node(string name, Transform parent, float width, float height)
        {
            var rect = (RectTransform)new GameObject(name, typeof(RectTransform)).transform;
            rect.SetParent(parent, false); rect.gameObject.layer = 5;
            Box(rect, 0, 0, width, height); return rect;
        }

        private static void Box(RectTransform rect, float x, float y, float width, float height)
        {
            rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0, 1);
            rect.anchoredPosition = new Vector2(x, -y); rect.sizeDelta = new Vector2(width, height);
        }

        private static void Stretch(RectTransform rect, float left = 0, float bottom = 0, float right = 0, float top = 0)
        {
            rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one;
            rect.offsetMin = new Vector2(left, bottom); rect.offsetMax = new Vector2(-right, -top);
        }

        private static Image Paint(RectTransform rect, Color color, bool raycast)
        {
            if (rect.GetComponent<CanvasRenderer>() == null) rect.gameObject.AddComponent<CanvasRenderer>();
            var image = rect.gameObject.AddComponent<Image>(); image.color = color; image.raycastTarget = raycast; return image;
        }

        private static TMP_Text Label(string name, Transform parent, TMP_FontAsset font, int size, Color color)
        {
            var rect = Node(name, parent, 242, 24);
            rect.gameObject.AddComponent<CanvasRenderer>();
            var text = rect.gameObject.AddComponent<TextMeshProUGUI>();
            text.font = font; text.fontSize = size; text.color = color; text.text = ""; text.raycastTarget = false;
            text.richText = true; text.enableAutoSizing = false; text.enableWordWrapping = true;
            text.overflowMode = TextOverflowModes.Overflow; text.alignment = TextAlignmentOptions.TopLeft;
            return text;
        }
    }
}
