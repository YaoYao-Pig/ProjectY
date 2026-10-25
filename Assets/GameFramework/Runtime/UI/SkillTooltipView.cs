using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Reusable tooltip geometry and interaction; contains no skill or save-game rules.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class SkillTooltipView : MonoBehaviour, IPointerClickHandler, IPointerEnterHandler, IPointerExitHandler
    {
        [Serializable]
        public sealed class Layout
        {
            public RectTransform Root, Bounds, Tags, Stats, Synergies;
            public TMP_Text Title, Breadcrumb, Body, StatsTitle, SynergyTitle, Footer;
            public Button Back;
            public ScrollRect Scroll;
            public SkillTooltipItemView TagTemplate, StatTemplate, SynergyTemplate;
        }

        [SerializeField] private Layout layout;
        [SerializeField] private float preferredWidth = 440;
        [SerializeField] private float maximumHeight = 580;
        private readonly List<SkillTooltipItemView> tags = new List<SkillTooltipItemView>();
        private readonly List<SkillTooltipItemView> stats = new List<SkillTooltipItemView>();
        private readonly List<SkillTooltipItemView> synergies = new List<SkillTooltipItemView>();
        private readonly Queue<string> links = new Queue<string>();
        private readonly Vector3[] corners = new Vector3[4];
        private int tagCount, statCount, synergyCount;
        private RectTransform anchor;
        private bool bound, dirty, pointerInside;
        private PointerEventData pointer;
        private Vector2 previousBounds;
        private const float Inset = 18, Edge = 10, Gap = 0;
        private static readonly Color Muted = new Color(.60f, .66f, .68f);
        private static readonly Color Paper = new Color(.89f, .92f, .92f);
        private static readonly Color Active = new Color(.53f, .86f, .70f);

        public bool Visible => gameObject.activeInHierarchy;

        private void EnsureBindings()
        {
            if (bound) return;
            if (layout == null || layout.Root == null || layout.Bounds == null || layout.Title == null ||
                layout.Breadcrumb == null || layout.Body == null || layout.Tags == null || layout.Stats == null ||
                layout.Synergies == null || layout.StatsTitle == null || layout.SynergyTitle == null ||
                layout.Footer == null || layout.Back == null || layout.Scroll == null ||
                layout.Scroll.content == null || layout.Scroll.viewport == null || layout.Scroll.verticalScrollbar == null ||
                layout.TagTemplate == null || layout.StatTemplate == null || layout.SynergyTemplate == null)
                throw new InvalidOperationException("SkillTooltipView requires all serialized bindings. Run Project Y/UI/同步技能说明卡.");
            layout.Back.onClick.AddListener(QueueBack);
            bound = true;
        }

        public void Begin(string title, string body)
        {
            EnsureBindings();
            if (title == null || body == null) throw new ArgumentNullException(title == null ? nameof(title) : nameof(body));
            layout.Title.text = title;
            layout.Body.text = body;
            Deactivate(tags, tagCount); Deactivate(stats, statCount); Deactivate(synergies, synergyCount);
            tagCount = statCount = synergyCount = 0;
            links.Clear();
            SetNavigation(false, LuaLanguage.Get("SkillTooltipTitle"));
            dirty = true;
        }

        private static void Deactivate(List<SkillTooltipItemView> rows, int count)
        {
            for (int i = 0; i < count; i++) rows[i].gameObject.SetActive(false);
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
            if (string.IsNullOrEmpty(value) || !ColorUtility.TryParseHtmlString(value, out var result))
                throw new ArgumentException("Expected an HTML color: " + value);
            return result;
        }

        public void AddTag(string label, string foregroundHtml, string backgroundHtml)
        {
            EnsureBindings();
            var row = Next(tags, ref tagCount, layout.TagTemplate, layout.Tags);
            row.Caption.text = label;
            row.Caption.color = Html(foregroundHtml);
            row.Background.color = Html(backgroundHtml);
            dirty = true;
        }

        public void AddStat(string label, string value, string valueColorHtml)
        {
            EnsureBindings();
            var row = Next(stats, ref statCount, layout.StatTemplate, layout.Stats);
            row.Caption.text = label;
            row.Value.text = value;
            row.Value.color = Html(valueColorHtml);
            row.Background.color = statCount % 2 == 1 ? new Color(.14f, .18f, .20f) : new Color(.12f, .16f, .18f);
            dirty = true;
        }

        public void AddSynergy(string title, string description, bool discovered, bool active)
        {
            EnsureBindings();
            if (active && !discovered) throw new ArgumentException("An active synergy must already be discovered.");
            var row = Next(synergies, ref synergyCount, layout.SynergyTemplate, layout.Synergies);
            // Unknown rows never contain hidden effect text, even behind their visible question-mark mask.
            row.Caption.text = discovered ? title : "";
            row.Body.text = discovered ? description : "";
            row.Value.text = discovered ? LuaLanguage.Get(active ? "SkillSynergyActive" : "SkillSynergyDiscovered") : "";
            row.Value.color = active ? Active : Muted;
            row.Caption.color = active ? Active : Paper;
            row.Caption.gameObject.SetActive(discovered);
            row.Body.gameObject.SetActive(discovered);
            row.Value.gameObject.SetActive(discovered);
            row.Mask.gameObject.SetActive(!discovered);
            row.Background.color = active ? new Color(.13f, .22f, .21f) : new Color(.13f, .17f, .19f);
            dirty = true;
        }

        public void SetNavigation(bool backEnabled, string breadcrumb)
        {
            EnsureBindings();
            layout.Back.gameObject.SetActive(backEnabled);
            layout.Breadcrumb.text = breadcrumb ?? throw new ArgumentNullException(nameof(breadcrumb));
            dirty = true;
        }

        public void Show(RectTransform nextAnchor)
        {
            EnsureBindings();
            if (nextAnchor == null) throw new ArgumentNullException(nameof(nextAnchor));
            bool opening = !gameObject.activeSelf || anchor != nextAnchor;
            bool changed = dirty || previousBounds != layout.Bounds.rect.size;
            anchor = nextAnchor;
            gameObject.SetActive(true);
            layout.Root.SetAsLastSibling();
            if (changed) RebuildLayout();
            Position();
            if (opening || changed)
            {
                layout.Scroll.StopMovement();
                layout.Scroll.verticalNormalizedPosition = 1;
            }
        }

        public void Hide()
        {
            anchor = null;
            pointerInside = false;
            pointer = null;
            links.Clear();
            gameObject.SetActive(false);
        }

        public bool ContainsPointer()
        {
            if (pointerInside && pointer != null && !UIPointerState.HasCurrentHit(pointer, layout.Root))
            {
                pointerInside = false;
                pointer = null;
            }
            return Visible && pointerInside;
        }

        public bool KeepOpen() => KeepOpen(false);

        public bool KeepOpen(bool anchorHovered)
        {
            if (!Visible || anchor == null || !anchor.gameObject.activeInHierarchy) return false;
            // Card and anchor touch, so terminology remains reachable without a close delay.
            return ContainsPointer() || anchorHovered;
        }

        public void OnPointerEnter(PointerEventData data)
        {
            pointer = data;
            pointerInside = true;
        }

        public void OnPointerExit(PointerEventData data)
        {
            pointer = null;
            pointerInside = false;
        }

        public string TakeLink() => links.Count == 0 ? "" : links.Dequeue();
        private void QueueBack() => links.Enqueue("__back");

        public void OnPointerClick(PointerEventData data)
        {
            if (data.button == PointerEventData.InputButton.Left && !data.dragging)
                ClickAt(data.position, data.pressEventCamera);
        }

        /// <summary>Also usable by deterministic native UI checks without synthesizing an Input frame.</summary>
        public bool ClickAt(Vector2 screenPosition, Camera camera)
        {
            if (!Visible || !RectTransformUtility.RectangleContainsScreenPoint(layout.Scroll.viewport, screenPosition, camera)) return false;
            if (layout.Body.gameObject.activeInHierarchy && QueueLink(layout.Body, screenPosition, camera)) return true;
            for (int i = 0; i < statCount; i++)
                if (QueueLink(stats[i].Caption, screenPosition, camera)) return true;
            for (int i = 0; i < synergyCount; i++)
                if (synergies[i].Body.gameObject.activeInHierarchy && QueueLink(synergies[i].Body, screenPosition, camera)) return true;
            return false;
        }

        private bool QueueLink(TMP_Text text, Vector2 position, Camera camera)
        {
            int index = TMP_TextUtilities.FindIntersectingLink(text, position, camera);
            if (index < 0) return false;
            links.Enqueue(text.textInfo.linkInfo[index].GetLinkID());
            return true;
        }

        private void LateUpdate()
        {
            if (anchor == null) return;
            if (!anchor.gameObject.activeInHierarchy) { Hide(); return; }
            if (dirty || previousBounds != layout.Bounds.rect.size) RebuildLayout();
            Position();
        }

        private static void Box(RectTransform rect, float x, float y, float width, float height)
        {
            rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0, 1);
            rect.anchoredPosition = new Vector2(x, -y);
            rect.sizeDelta = new Vector2(width, height);
        }

        private static float TextHeight(TMP_Text text, float width) => Mathf.Ceil(text.GetPreferredValues(text.text, width, 0).y);

        public void RebuildLayout()
        {
            EnsureBindings();
            previousBounds = layout.Bounds.rect.size;
            float width = Mathf.Min(preferredWidth, Mathf.Max(120, previousBounds.x - Edge * 2));
            float available = width - Inset * 2 - 10;
            float titleHeight = Mathf.Max(32, TextHeight(layout.Title, width - Inset * 2));
            Box(layout.Title.rectTransform, Inset, 12, width - Inset * 2, titleHeight);
            float navY = titleHeight + 16;
            Box((RectTransform)layout.Back.transform, Inset, navY, 54, 25);
            bool hasBack = layout.Back.gameObject.activeSelf;
            Box(layout.Breadcrumb.rectTransform, Inset + (hasBack ? 64 : 0), navY,
                width - Inset * 2 - (hasBack ? 64 : 0), 25);
            float top = navY + 36;

            float y = 0, tagX = 0, tagY = 0;
            for (int i = 0; i < tagCount; i++)
            {
                var row = tags[i];
                float tagWidth = Mathf.Min(available, Mathf.Ceil(row.Caption.GetPreferredValues(row.Caption.text).x) + 20);
                if (tagX > 0 && tagX + tagWidth > available) { tagX = 0; tagY += 32; }
                Box(row.Rect, tagX, tagY, tagWidth, 26);
                Box(row.Caption.rectTransform, 10, 0, tagWidth - 20, 26);
                tagX += tagWidth + 6;
            }
            layout.Tags.gameObject.SetActive(tagCount > 0);
            float tagsHeight = tagCount > 0 ? tagY + 26 : 0;
            Box(layout.Tags, 0, y, available, tagsHeight);
            if (tagCount > 0) y += tagsHeight + 14;

            float bodyHeight = string.IsNullOrEmpty(layout.Body.text) ? 0 : TextHeight(layout.Body, available);
            layout.Body.gameObject.SetActive(bodyHeight > 0);
            Box(layout.Body.rectTransform, 0, y, available, bodyHeight);
            if (bodyHeight > 0) y += bodyHeight + 16;

            layout.StatsTitle.gameObject.SetActive(statCount > 0);
            layout.Stats.gameObject.SetActive(statCount > 0);
            if (statCount > 0)
            {
                Box(layout.StatsTitle.rectTransform, 0, y, available, 22); y += 29;
                float start = y;
                int columns = width >= 360 ? 2 : 1;
                float cellWidth = (available - (columns - 1) * 8) / columns;
                for (int i = 0; i < statCount; i += columns)
                {
                    float h = 46;
                    for (int column = 0; column < columns && i + column < statCount; column++)
                    {
                        var row = stats[i + column];
                        h = Mathf.Max(h, TextHeight(row.Caption, cellWidth - 20) + TextHeight(row.Value, cellWidth - 20) + 12);
                    }
                    for (int column = 0; column < columns && i + column < statCount; column++)
                    {
                        var row = stats[i + column];
                        float labelHeight = TextHeight(row.Caption, cellWidth - 20);
                        Box(row.Rect, column * (cellWidth + 8), y - start, cellWidth, h);
                        Box(row.Caption.rectTransform, 10, 5, cellWidth - 20, labelHeight);
                        Box(row.Value.rectTransform, 10, labelHeight + 7, cellWidth - 20, h - labelHeight - 12);
                    }
                    y += h + 6;
                }
                Box(layout.Stats, 0, start, available, y - start); y += 16;
            }

            layout.SynergyTitle.gameObject.SetActive(synergyCount > 0);
            layout.Synergies.gameObject.SetActive(synergyCount > 0);
            if (synergyCount > 0)
            {
                Box(layout.SynergyTitle.rectTransform, 0, y, available, 24); y += 31;
                float start = y;
                for (int i = 0; i < synergyCount; i++)
                {
                    var row = synergies[i];
                    float captionHeight = Mathf.Max(24, TextHeight(row.Caption, available - 92));
                    float descriptionHeight = TextHeight(row.Body, available - 24);
                    float h = row.Mask.gameObject.activeSelf ? 72 : captionHeight + descriptionHeight + 26;
                    Box(row.Rect, 0, y - start, available, h);
                    Box(row.Caption.rectTransform, 12, 10, available - 92, captionHeight);
                    Box(row.Value.rectTransform, available - 76, 10, 64, 24);
                    Box(row.Body.rectTransform, 12, captionHeight + 16, available - 24, descriptionHeight);
                    y += h + 8;
                }
                Box(layout.Synergies, 0, start, available, y - start);
            }

            float contentHeight = Mathf.Max(1, y);
            float maxHeight = Mathf.Max(120, Mathf.Min(maximumHeight, previousBounds.y - Edge * 2));
            float height = Mathf.Min(maxHeight, top + contentHeight + 38);
            layout.Root.sizeDelta = new Vector2(width, height);
            Box((RectTransform)layout.Scroll.transform, Inset, top, width - Inset * 2, Mathf.Max(10, height - top - 34));
            Box(layout.Scroll.content, 0, 0, available, contentHeight);
            Box(layout.Footer.rectTransform, Inset, height - 27, width - Inset * 2, 20);
            bool scrolling = contentHeight > layout.Scroll.viewport.rect.height + 1;
            layout.Scroll.verticalScrollbar.gameObject.SetActive(scrolling);
            layout.Footer.text = LuaLanguage.Get(scrolling ? "SkillTooltipScrollHint" : "SkillTooltipTermHint");
            dirty = false;
        }

        private void Position()
        {
            anchor.GetWorldCorners(corners);
            var lower = (Vector2)layout.Bounds.InverseTransformPoint(corners[0]);
            var upper = (Vector2)layout.Bounds.InverseTransformPoint(corners[2]);
            var bounds = layout.Bounds.rect;
            var size = layout.Root.rect.size;
            float x = lower.x, y = upper.y + Gap + size.y;
            // Prefer the space above a hotbar item; side placement keeps tall cards off their anchor.
            if (y > bounds.yMax - Edge)
            {
                x = upper.x + Gap;
                if (x + size.x > bounds.xMax - Edge) x = lower.x - size.x - Gap;
                y = upper.y;
            }
            x = Mathf.Clamp(x, bounds.xMin + Edge, Mathf.Max(bounds.xMin + Edge, bounds.xMax - size.x - Edge));
            y = Mathf.Clamp(y, Mathf.Min(bounds.yMax - Edge, bounds.yMin + size.y + Edge), bounds.yMax - Edge);
            layout.Root.localPosition = new Vector3(x, y, 0);
        }

        private void OnDisable() { anchor = null; pointerInside = false; pointer = null; links.Clear(); }
        private void OnDestroy() { if (bound && layout.Back != null) layout.Back.onClick.RemoveListener(QueueBack); }

#if UNITY_EDITOR
        [BlackList] public Layout EditorLayout => layout;
        [BlackList] public int EditorTagCount => tagCount;
        [BlackList] public int EditorStatCount => statCount;
        [BlackList] public int EditorSynergyCount => synergyCount;
        [BlackList] public SkillTooltipItemView EditorSynergy(int index) => synergies[index];
        [BlackList] public void SetEditorLayout(Layout value) => layout = value;
#endif
    }
}
