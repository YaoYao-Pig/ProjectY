using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Scrollable course detail presentation. Lua owns tags, requirements and eligibility.</summary>
    [DisallowMultipleComponent]
    public sealed class GrowthSkillDetailView : MonoBehaviour
    {
        [Serializable]
        public sealed class Layout
        {
            public RectTransform Root, Tags, Conditions;
            public ScrollRect Scroll;
            public TMP_Text Body, Heading, Status, Equipment;
            public SkillTooltipItemView TagTemplate, ConditionTemplate;
        }

        [SerializeField] private Layout layout;
        private readonly List<SkillTooltipItemView> tags = new List<SkillTooltipItemView>();
        private readonly List<SkillTooltipItemView> conditions = new List<SkillTooltipItemView>();
        private int tagCount, conditionCount;
        private bool bound, resetScroll;
        private Vector2 previousSize;
        private const float Padding = 8, Gap = 7;
        private static readonly Color Met = new Color(50 / 255f, 115 / 255f, 79 / 255f, 1);
        private static readonly Color Unmet = new Color(171 / 255f, 77 / 255f, 60 / 255f, 1);

        private void EnsureBindings()
        {
            if (bound) return;
            if (layout == null || layout.Root == null || layout.Tags == null || layout.Conditions == null ||
                layout.Body == null || layout.Heading == null || layout.Status == null || layout.Equipment == null ||
                layout.Scroll == null || layout.Scroll.viewport == null || layout.Scroll.content == null ||
                layout.Scroll.verticalScrollbar == null || layout.TagTemplate == null || layout.ConditionTemplate == null ||
                layout.TagTemplate.Rect == null || layout.TagTemplate.Caption == null || layout.TagTemplate.Background == null ||
                layout.ConditionTemplate.Rect == null || layout.ConditionTemplate.Caption == null ||
                layout.ConditionTemplate.Background == null || layout.ConditionTemplate.Mask == null)
                throw new InvalidOperationException("Growth skill detail needs its serialized layout and templates. Run GrowthSkillDetailAssets.Sync.");
            bound = true;
        }

        internal void Begin(string body, string heading, string statusText, string equipmentText, bool reset)
        {
            EnsureBindings();
            layout.Body.text = body ?? throw new ArgumentNullException(nameof(body));
            layout.Heading.text = heading ?? throw new ArgumentNullException(nameof(heading));
            layout.Status.text = statusText ?? throw new ArgumentNullException(nameof(statusText));
            layout.Equipment.text = equipmentText ?? throw new ArgumentNullException(nameof(equipmentText));
            for (int i = 0; i < tagCount; i++) tags[i].gameObject.SetActive(false);
            for (int i = 0; i < conditionCount; i++) conditions[i].gameObject.SetActive(false);
            tagCount = conditionCount = 0;
            resetScroll = reset;
        }

        private static SkillTooltipItemView Next(List<SkillTooltipItemView> pool, ref int count,
            SkillTooltipItemView template, RectTransform parent)
        {
            if (count == pool.Count) pool.Add(Instantiate(template, parent, false));
            var row = pool[count++];
            row.gameObject.SetActive(true);
            return row;
        }

        private static Color Html(string value)
        {
            if (string.IsNullOrEmpty(value) || !ColorUtility.TryParseHtmlString(value[0] == '#' ? value : "#" + value, out var tint))
                throw new ArgumentException("Expected a hexadecimal detail color: " + value);
            return tint;
        }

        internal void AddTag(string label, string foregroundHex, string backgroundHex)
        {
            EnsureBindings();
            if (label == null) throw new ArgumentNullException(nameof(label));
            var row = Next(tags, ref tagCount, layout.TagTemplate, layout.Tags);
            row.Caption.text = label;
            row.Caption.color = Html(foregroundHex);
            row.Background.color = Html(backgroundHex);
        }

        internal void AddCondition(string text, bool met)
        {
            EnsureBindings();
            if (text == null) throw new ArgumentNullException(nameof(text));
            var row = Next(conditions, ref conditionCount, layout.ConditionTemplate, layout.Conditions);
            text = text.Replace("<", "＜").Replace(">", "＞");
            row.Caption.text = met ? "<s>" + text + "</s>" : text;
            row.Caption.color = met ? Met : Unmet;
            row.Background.color = met ? Met : Unmet;
            row.Mask.gameObject.SetActive(met);
        }

        internal void End()
        {
            EnsureBindings();
            RebuildLayout(resetScroll);
            resetScroll = false;
        }

        private static void Box(RectTransform rect, float x, float y, float width, float height)
        {
            rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0, 1);
            rect.anchoredPosition = new Vector2(x, -y);
            rect.sizeDelta = new Vector2(width, height);
        }

        private static float TextHeight(TMP_Text text, float width)
            => string.IsNullOrEmpty(text.text) ? 0 : Mathf.Ceil(text.GetPreferredValues(text.text, width, 0).y);

        private static float PlaceText(TMP_Text text, float x, float y, float width)
        {
            float height = TextHeight(text, width);
            text.gameObject.SetActive(height > 0);
            Box(text.rectTransform, x, y, width, height);
            return height > 0 ? height + Gap : 0;
        }

        private void RebuildLayout(bool reset)
        {
            previousSize = layout.Root.rect.size;
            float savedOffset = reset ? 0 : layout.Scroll.content.anchoredPosition.y;
            float contentWidth = Mathf.Max(80, layout.Scroll.viewport.rect.width);
            float width = contentWidth - Padding * 2;
            float y = Padding, x = 0, lineY = 0, lineHeight = 0;
            for (int i = 0; i < tagCount; i++)
            {
                var row = tags[i];
                float tagWidth = Mathf.Min(width, Mathf.Ceil(row.Caption.GetPreferredValues(row.Caption.text).x) + 16);
                float tagHeight = Mathf.Max(21, TextHeight(row.Caption, Mathf.Max(1, tagWidth - 16)) + 6);
                if (x > 0 && x + tagWidth > width) { x = 0; lineY += lineHeight + 4; lineHeight = 0; }
                Box(row.Rect, x, lineY, tagWidth, tagHeight);
                Box(row.Caption.rectTransform, 8, 3, tagWidth - 16, tagHeight - 6);
                lineHeight = Mathf.Max(lineHeight, tagHeight);
                x += tagWidth + 5;
            }
            float tagsHeight = tagCount > 0 ? lineY + lineHeight : 0;
            layout.Tags.gameObject.SetActive(tagCount > 0);
            Box(layout.Tags, Padding, y, width, tagsHeight);
            if (tagsHeight > 0) y += tagsHeight + Gap;
            y += PlaceText(layout.Body, Padding, y, width);
            y += PlaceText(layout.Equipment, Padding, y, width);

            bool showConditions = conditionCount > 0 || layout.Heading.text.Length > 0 || layout.Status.text.Length > 0;
            layout.Conditions.gameObject.SetActive(showConditions);
            if (showConditions)
            {
                float innerWidth = width - Padding * 2;
                float conditionY = Padding;
                conditionY += PlaceText(layout.Heading, Padding, conditionY, innerWidth);
                for (int i = 0; i < conditionCount; i++)
                {
                    var row = conditions[i];
                    float labelHeight = TextHeight(row.Caption, innerWidth - 25);
                    float rowHeight = Mathf.Max(22, labelHeight + 4);
                    Box(row.Rect, Padding, conditionY, innerWidth, rowHeight);
                    Box(row.Background.rectTransform, 0, 3, 15, 15);
                    Box(row.Caption.rectTransform, 25, 0, innerWidth - 25, labelHeight);
                    conditionY += rowHeight + 6;
                }
                conditionY += PlaceText(layout.Status, Padding, conditionY, innerWidth);
                float height = Mathf.Max(Padding * 2, conditionY + Padding - Gap);
                Box(layout.Conditions, Padding, y, width, height);
                y += height + Gap;
            }
            float contentHeight = Mathf.Max(layout.Scroll.viewport.rect.height, y + Padding - Gap);
            Box(layout.Scroll.content, 0, 0, contentWidth, contentHeight);
            layout.Scroll.StopMovement();
            float maximumOffset = Mathf.Max(0, contentHeight - layout.Scroll.viewport.rect.height);
            layout.Scroll.content.anchoredPosition = new Vector2(0, Mathf.Clamp(savedOffset, 0, maximumOffset));
            layout.Scroll.verticalScrollbar.gameObject.SetActive(maximumOffset > .5f);
        }

        private void LateUpdate()
        {
            if (bound && previousSize != layout.Root.rect.size) RebuildLayout(false);
        }

#if UNITY_EDITOR
        public Layout EditorLayout => layout;
        public int EditorTagCount => tagCount;
        public int EditorConditionCount => conditionCount;
        public SkillTooltipItemView EditorTag(int index) => tags[index];
        public SkillTooltipItemView EditorCondition(int index) => conditions[index];
        public void SetEditorLayout(Layout value) { layout = value; bound = false; }
#endif
    }

    /// <summary>Reflection bridge; caller supplies localized text and controls the root visibility.</summary>
    public static class GrowthSkillDetailPresentation
    {
        public static void Begin(GrowthSkillDetailView view, string body, string heading, string statusText, string equipmentText, bool resetScroll)
            => view.Begin(body, heading, statusText, equipmentText, resetScroll);
        public static void AddTag(GrowthSkillDetailView view, string label, string foregroundHex, string backgroundHex)
            => view.AddTag(label, foregroundHex, backgroundHex);
        public static void AddCondition(GrowthSkillDetailView view, string text, bool met) => view.AddCondition(text, met);
        public static void End(GrowthSkillDetailView view) => view.End();
    }
}
