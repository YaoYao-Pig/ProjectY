using System;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>图文资源、字体与几何显示；养成和故事规则由 Lua 负责。</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class StoryGrowthView : MonoBehaviour
    {
        [Serializable] public struct ArtEntry { public string Path; public Sprite Sprite; }
        [SerializeField] private ArtEntry[] illustrations = Array.Empty<ArtEntry>();
        [SerializeField] private Text[] labels = Array.Empty<Text>();
        [SerializeField] private Font preferredFont;
        [SerializeField] private RectTransform fittedPage;
        [SerializeField] private bool journalTheme;
        [Serializable] public struct GlyphEntry { public string Code; public Sprite Sprite; }
        [SerializeField] private GlyphEntry[] glyphs = Array.Empty<GlyphEntry>();
        private Font fallbackFont;
        public Font Font
        {
            get
            {
                if (preferredFont != null) return preferredFont;
                if (fallbackFont == null) fallbackFont = Font.CreateDynamicFontFromOSFont(new[] { "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Arial" }, 18);
                return fallbackFont;
            }
        }
        public void Prepare() { foreach (var label in labels) label.font = Font; FitPage(); }
        private void LateUpdate() { FitPage(); }
        private void FitPage()
        {
            if (fittedPage == null) return;
            var rect = ((RectTransform)transform).rect;
            var scale = Mathf.Min(1, Mathf.Min((rect.width - 28) / 1200, (rect.height - 28) / 664));
            fittedPage.localScale = Vector3.one * Mathf.Max(.1f, scale);
        }
        public void SetArt(Image target, string path)
        {
            if (path == "") { target.enabled = false; return; }
            foreach (var art in illustrations)
                if (art.Path == path)
                {
                    if (art.Sprite == null) throw new InvalidOperationException("Missing story Sprite: " + path);
                    target.sprite = art.Sprite; target.enabled = true; return;
                }
            throw new InvalidOperationException("Story art not bound: " + path + ". Run Project Y/UI/创建事件与养成 UI.");
        }
        public void PlaceNode(RectTransform rect, float x, float y)
        {
            rect.anchorMin = rect.anchorMax = new Vector2(0, 1); rect.pivot = new Vector2(.5f, .7142857f);
            rect.anchoredPosition = new Vector2(x, -y);
        }
        public void SetLine(Image image, float x1, float y1, float x2, float y2, bool active)
        {
            var rect = image.rectTransform; var delta = new Vector2(x2 - x1, y1 - y2);
            rect.anchorMin = rect.anchorMax = new Vector2(0, 1); rect.pivot = new Vector2(0, .5f);
            rect.anchoredPosition = new Vector2(x1, -y1); rect.sizeDelta = new Vector2(delta.magnitude, active ? 3 : 2);
            rect.localEulerAngles = new Vector3(0, 0, Mathf.Atan2(delta.y, delta.x) * Mathf.Rad2Deg);
            image.color = active ? new Color(.53f,.38f,.19f) : new Color(.64f,.60f,.51f,.55f);
        }
        public void Tint(Image image, string html)
        {
            if (!ColorUtility.TryParseHtmlString("#" + html, out var color)) throw new ArgumentException("Invalid story color.");
            image.color = color;
        }
        public void Highlight(Button button, bool selected)
        {
            button.targetGraphic.color = journalTheme
                ? (selected ? new Color(.20f,.29f,.25f) : new Color(.77f,.73f,.63f,.32f))
                : (selected ? new Color(.34f,.39f,.28f) : new Color(.14f,.19f,.17f));
        }
        public void SetGlyph(Image image, string code)
        {
            foreach(var glyph in glyphs) if(glyph.Code==code)
            {
                if(glyph.Sprite==null)throw new InvalidOperationException("Missing journal Sprite: "+code);
                image.sprite=glyph.Sprite;return;
            }
            throw new InvalidOperationException("Missing journal glyph: "+code);
        }
        private void OnDestroy() { if(fallbackFont!=null){if(Application.isPlaying)Destroy(fallbackFont);else DestroyImmediate(fallbackFont);} }
#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(Text[] text, ArtEntry[] art, RectTransform page)
        { labels = text; illustrations = art; fittedPage = page; }
        [BlackList] public void SetJournalTheme(GlyphEntry[] icons) { journalTheme=true;glyphs=icons; }
#endif
    }
}
