using System;
using System.Collections.Generic;
using ProjectY.UI;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Persistent, editable skill-tooltip resources and LuaReference bindings.</summary>
    [InitializeOnLoad]
    public static class SkillTooltipAssets
    {
        public const string FontPath = "Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc.asset";
        private static readonly Color Ink = new Color(.075f, .105f, .12f);
        private static readonly Color Paper = new Color(.89f, .92f, .92f);
        private static readonly Color Gold = new Color(.87f, .74f, .48f);
        private static readonly Color Muted = new Color(.60f, .66f, .68f);

        static SkillTooltipAssets() => LuaViewHints.Register(typeof(SkillTooltipView), "CS.ProjectY.UI.SkillTooltipView");

        [MenuItem("Project Y/UI/同步技能说明卡")]
        public static void SyncBattleHUD()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode)
                throw new InvalidOperationException("请在 Edit Mode 同步技能说明卡。");
            var font = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(FontPath);
            if (font == null) throw new InvalidOperationException("Missing tooltip font: " + FontPath);
            var config = AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            var entry = config == null ? null : config.Entries.Find(row => row.Name == "BattleHUD");
            if (entry == null || entry.Prefab == null) throw new InvalidOperationException("请先创建 BattleHUD Prefab。");
            var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference = root.GetComponent<LuaReference>();
                var bindings = new List<LuaReference.Entry>(reference.GetEditorBindings());
                if (!bindings.Exists(row => row.Key == "SkillTip"))
                {
                    var parent = root.GetComponent<BattleHUDView>().EditorLayout.SafeArea;
                    bindings.Add(new LuaReference.Entry("SkillTip", Create(parent, font)));
                    reference.SetEditorBindings(bindings.ToArray());
                }
                if (!(reference.Get("SkillTip") is SkillTooltipView))
                    throw new InvalidOperationException("BattleHUD.SkillTip must bind a SkillTooltipView.");
                reference.ValidateBindings();
                PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
                LuaViewHints.Export(reference, entry.ViewType);
            }
            finally { PrefabUtility.UnloadPrefabContents(root); }
            Debug.Log("BattleHUD 技能说明卡已同步：TMP 术语链接、标签、参数、协同遮罩和滚动。旧目标预览绑定保留。");
        }

        /// <summary>Builds the same reusable card under another UI, e.g. the skill atlas.</summary>
        public static SkillTooltipView Create(Transform parent, TMP_FontAsset font)
        {
            if (!(parent is RectTransform bounds) || font == null)
                throw new ArgumentException("Tooltip requires a RectTransform parent and a TMP font asset.");
            if (!font.HasCharacter('_'))
                throw new InvalidOperationException("Tooltip font must include '_' for TMP underline rendering.");
            var root = Node("SkillTip", parent, 440, 500);
            Paint(root, Ink, true);
            var shadow = root.gameObject.AddComponent<Shadow>();
            shadow.effectColor = new Color(0, 0, 0, .65f); shadow.effectDistance = new Vector2(4, -5);
            var view = root.gameObject.AddComponent<SkillTooltipView>();
            EdgeLine(root, "TopRule", new Vector2(0, 1), new Vector2(1, 1), new Vector2(0, -2), Vector2.zero, Gold);
            EdgeLine(root, "BottomRule", Vector2.zero, new Vector2(1, 0), Vector2.zero, new Vector2(0, 1), new Color(.30f, .37f, .39f));
            EdgeLine(root, "LeftRule", Vector2.zero, new Vector2(0, 1), Vector2.zero, new Vector2(1, 0), new Color(.30f, .37f, .39f));
            EdgeLine(root, "RightRule", new Vector2(1, 0), Vector2.one, new Vector2(-1, 0), Vector2.zero, new Color(.30f, .37f, .39f));
            var title = Label("Title", root, font, 24, Gold); title.fontStyle = FontStyles.Bold; title.richText = false;
            var breadcrumb = Label("Breadcrumb", root, font, 12, Muted); breadcrumb.richText = false;
            breadcrumb.overflowMode = TextOverflowModes.Ellipsis; breadcrumb.enableWordWrapping = false;
            var backRect = Node("Back", root, 54, 25);
            var backImage = Paint(backRect, new Color(.18f, .24f, .26f), true);
            var back = backRect.gameObject.AddComponent<Button>(); back.targetGraphic = backImage;
            back.navigation = new Navigation { mode = Navigation.Mode.None };
            var backText = Label("Label", backRect, font, 12, Paper); backText.text = "‹ 返回";
            backText.alignment = TextAlignmentOptions.Center; Stretch(backText.rectTransform);
            var colors = back.colors; colors.highlightedColor = new Color(.76f, .90f, 1); colors.pressedColor = new Color(.55f, .74f, .84f);
            colors.selectedColor = Color.white; colors.fadeDuration = .1f; back.colors = colors;

            var scrollRoot = Node("Scroll", root, 404, 380);
            var scroll = scrollRoot.gameObject.AddComponent<ScrollRect>();
            scroll.horizontal = false; scroll.vertical = true; scroll.inertia = false;
            scroll.scrollSensitivity = 32; scroll.movementType = ScrollRect.MovementType.Clamped;
            var viewport = Node("Viewport", scrollRoot, 394, 380); Stretch(viewport, 0, 0, 10, 0);
            Paint(viewport, Color.clear, true); viewport.gameObject.AddComponent<RectMask2D>();
            var content = Node("Content", viewport, 394, 380);
            scroll.viewport = viewport; scroll.content = content;

            var barRoot = Node("Scrollbar", scrollRoot, 4, 380);
            barRoot.anchorMin = new Vector2(1, 0); barRoot.anchorMax = Vector2.one; barRoot.pivot = new Vector2(1, .5f);
            barRoot.offsetMin = new Vector2(-4, 0); barRoot.offsetMax = Vector2.zero;
            Paint(barRoot, new Color(.16f, .21f, .23f), true);
            var sliding = Node("SlidingArea", barRoot, 4, 380); Stretch(sliding);
            var handle = Node("Handle", sliding, 4, 100); Stretch(handle);
            var handleImage = Paint(handle, new Color(.44f, .57f, .61f), true);
            var scrollbar = barRoot.gameObject.AddComponent<Scrollbar>();
            scrollbar.direction = Scrollbar.Direction.BottomToTop; scrollbar.handleRect = handle; scrollbar.targetGraphic = handleImage;
            scrollbar.navigation = new Navigation { mode = Navigation.Mode.None };
            scroll.verticalScrollbar = scrollbar; scroll.verticalScrollbarVisibility = ScrollRect.ScrollbarVisibility.AutoHide;

            var tags = Node("Tags", content, 394, 26);
            var body = Label("Description", content, font, 16, Paper); body.raycastTarget = true; body.lineSpacing = 9;
            var statsTitle = Label("StatsTitle", content, font, 12, Muted); statsTitle.text = "技能参数"; statsTitle.characterSpacing = 8;
            var stats = Node("Stats", content, 394, 160);
            var synergyTitle = Label("SynergyTitle", content, font, 14, Gold); synergyTitle.text = "协同效应"; synergyTitle.fontStyle = FontStyles.Bold;
            var synergies = Node("Synergies", content, 394, 160);
            var footer = Label("Footer", root, font, 11, Muted); footer.enableWordWrapping = false;
            footer.overflowMode = TextOverflowModes.Ellipsis;

            var tag = Item("TagTemplate", tags, font);
            tag.Caption.fontSize = 13; tag.Caption.alignment = TextAlignmentOptions.Center; tag.Caption.richText = false;
            var stat = Item("StatTemplate", stats, font);
            stat.Caption.fontSize = 12; stat.Caption.color = Muted; stat.Caption.richText = true; stat.Caption.raycastTarget = true;
            stat.Value = Label("Value", stat.Rect, font, 15, Paper);
            stat.Value.fontStyle = FontStyles.Bold; stat.Value.alignment = TextAlignmentOptions.TopLeft; stat.Value.richText = false;
            var synergy = Item("SynergyTemplate", synergies, font);
            synergy.Caption.fontSize = 15; synergy.Caption.fontStyle = FontStyles.Bold; synergy.Caption.richText = false;
            synergy.Value = Label("State", synergy.Rect, font, 11, Muted); synergy.Value.alignment = TextAlignmentOptions.TopRight;
            synergy.Body = Label("Description", synergy.Rect, font, 14, Paper); synergy.Body.raycastTarget = true; synergy.Body.lineSpacing = 7;
            synergy.Mask = Node("UndiscoveredMask", synergy.Rect, 394, 72); Stretch(synergy.Mask);
            Paint(synergy.Mask, new Color(.12f, .16f, .18f), true);
            var question = Label("QuestionMark", synergy.Mask, font, 32, new Color(.44f, .55f, .60f));
            question.text = "?"; question.alignment = TextAlignmentOptions.Center; Box(question.rectTransform, 10, 8, 42, 48);
            var unknown = Label("Unknown", synergy.Mask, font, 14, Muted); unknown.text = "尚未发现";
            unknown.rectTransform.anchorMin = new Vector2(0, 1); unknown.rectTransform.anchorMax = Vector2.one;
            unknown.rectTransform.pivot = new Vector2(0, 1); unknown.rectTransform.anchoredPosition = new Vector2(62, -11);
            unknown.rectTransform.sizeDelta = new Vector2(-74, 23);
            var hint = Label("UnlockHint", synergy.Mask, font, 11, Muted); hint.text = "首次成功装配对应符文组合后解锁";
            hint.rectTransform.anchorMin = new Vector2(0, 1); hint.rectTransform.anchorMax = Vector2.one;
            hint.rectTransform.pivot = new Vector2(0, 1); hint.rectTransform.anchoredPosition = new Vector2(62, -37);
            hint.rectTransform.sizeDelta = new Vector2(-74, 28);

            view.SetEditorLayout(new SkillTooltipView.Layout {
                Root = root, Bounds = bounds, Title = title, Breadcrumb = breadcrumb, Back = back, Scroll = scroll,
                Tags = tags, Body = body, StatsTitle = statsTitle, Stats = stats, SynergyTitle = synergyTitle,
                Synergies = synergies, Footer = footer, TagTemplate = tag, StatTemplate = stat, SynergyTemplate = synergy
            });
            tag.gameObject.SetActive(false); stat.gameObject.SetActive(false); synergy.gameObject.SetActive(false);
            back.gameObject.SetActive(false); root.gameObject.SetActive(false);
            return view;
        }

        private static SkillTooltipItemView Item(string name, RectTransform parent, TMP_FontAsset font)
        {
            var rect = Node(name, parent, 394, 32);
            var row = rect.gameObject.AddComponent<SkillTooltipItemView>();
            row.Rect = rect; row.Background = Paint(rect, new Color(.14f, .18f, .20f), false);
            row.Caption = Label("Caption", rect, font, 14, Paper);
            return row;
        }

        private static RectTransform Node(string name, Transform parent, float width, float height)
        {
            var rect = (RectTransform)new GameObject(name, typeof(RectTransform)).transform;
            rect.SetParent(parent, false); Box(rect, 0, 0, width, height); return rect;
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
            var image = rect.gameObject.AddComponent<Image>(); image.color = color; image.raycastTarget = raycast; return image;
        }

        private static TMP_Text Label(string name, Transform parent, TMP_FontAsset font, int size, Color color)
        {
            var text = Node(name, parent, 394, 32).gameObject.AddComponent<TextMeshProUGUI>();
            text.font = font; text.fontSize = size; text.color = color; text.raycastTarget = false;
            text.richText = true; text.enableAutoSizing = false; text.enableWordWrapping = true;
            text.overflowMode = TextOverflowModes.Overflow; text.alignment = TextAlignmentOptions.TopLeft;
            return text;
        }

        private static void EdgeLine(RectTransform parent, string name, Vector2 min, Vector2 max, Vector2 offsetMin, Vector2 offsetMax, Color color)
        {
            var line = Node(name, parent, 1, 1); line.anchorMin = min; line.anchorMax = max;
            line.offsetMin = offsetMin; line.offsetMax = offsetMax; Paint(line, color, false);
        }
    }
}
