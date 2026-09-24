using System;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Presentation only: safe-area layout, font and serialized icon assets. Combat stays in BattleSystem.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class BattleHUDView : MonoBehaviour
    {
        [Serializable]
        public sealed class Layout
        {
            public RectTransform Root, SafeArea, Header, Turns, Party, Deck, Actor, Skills, Items, Commands, Hint, Log, Tooltip;
            public GridLayoutGroup SkillGrid, ItemGrid, TurnGrid;
            public Text[] Labels;
        }
        [Serializable]
        public struct IconEntry
        {
            public int Id;
            public string Path;
            public Sprite Sprite;
        }
        [SerializeField] private Layout layout;
        [SerializeField] private IconEntry[] icons = Array.Empty<IconEntry>();
        [SerializeField] private Font preferredFont;
        private Font fallbackFont;
        private Vector2 previousSize;
        private Rect previousSafeArea;
        public bool Compact { get; private set; }
        public Font Font
        {
            get
            {
                if (preferredFont != null) return preferredFont;
                if (fallbackFont == null) fallbackFont = Font.CreateDynamicFontFromOSFont(
                    new[] { "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Arial" }, 16);
                return fallbackFont;
            }
        }
        public void Prepare()
        {
            foreach (var label in layout.Labels) label.font = Font;
            ApplyLayout();
        }
        public void SetIcon(Image target, int id, string configuredPath)
        {
            foreach (var icon in icons)
            {
                if (icon.Id != id) continue;
                if (icon.Path != configuredPath || (icon.Path != "" && icon.Sprite == null))
                    throw new InvalidOperationException("Battle icon binding differs from config: " + id + ". Run Project Y/UI/同步战斗图标引用.");
                target.sprite = icon.Sprite;
                target.enabled = icon.Sprite != null;
                return;
            }
            throw new InvalidOperationException("Missing serialized battle icon: " + id);
        }
        public void SetHealth(Image image, float value)
        {
            image.rectTransform.anchorMax = new Vector2(Mathf.Clamp01(value), 1);
        }
        private void LateUpdate()
        {
            if (layout != null && (previousSize != layout.Root.rect.size || previousSafeArea != Screen.safeArea)) ApplyLayout();
        }
        public void ApplyLayout()
        {
            previousSize = layout.Root.rect.size; previousSafeArea = Screen.safeArea;
            var screen = new Vector2(Mathf.Max(1, Screen.width), Mathf.Max(1, Screen.height));
            layout.SafeArea.anchorMin = previousSafeArea.min / screen;
            layout.SafeArea.anchorMax = previousSafeArea.max / screen;
            layout.SafeArea.offsetMin = layout.SafeArea.offsetMax = Vector2.zero;
            LayoutContent(previousSize.x * previousSafeArea.width / screen.x);
        }
        private void LayoutContent(float width)
        {
            Compact = width < 1120;
            var narrow = width < 900;
            var deckWidth = Mathf.Min(1232, width - 32);
            var deckHeight = narrow ? 372 : Compact ? 228 : 172;
            Place(layout.Deck, new Vector2(.5f, 0), -deckWidth / 2, 16, deckWidth, deckHeight);
            Place(layout.Header, new Vector2(0, 1), 16, -84, 180, 68);
            Place(layout.Party, new Vector2(0, 1), 16, -388, Compact ? 154 : 180, 286);
            var turnWidth = Mathf.Min(680, width - 414);
            Place(layout.Turns, new Vector2(.5f, 1), -turnWidth / 2 + 12, -78, turnWidth, 60);
            layout.TurnGrid.cellSize = new Vector2((turnWidth - 7 * 6) / 8, 60);
            Place(layout.Actor, Vector2.zero, 16, 16, 190, deckHeight - 32);
            const float commandsWidth = 142;
            var contentWidth = deckWidth - 190 - commandsWidth - 66;
            var itemWidth = Compact ? 116 : 184;
            var skillWidth = contentWidth - itemWidth - 20;
            Place(layout.Skills, Vector2.zero, 220, 38, skillWidth, deckHeight - 54);
            Place(layout.Items, Vector2.zero, 220 + skillWidth + 20, 38, itemWidth, deckHeight - 54);
            Place(layout.Commands, Vector2.zero, deckWidth - commandsWidth - 16, 16, commandsWidth, deckHeight - 32);
            var columns = Compact ? 4 : 8;
            layout.SkillGrid.constraintCount = columns;
            layout.SkillGrid.cellSize = new Vector2((skillWidth - (columns - 1) * 6) / columns, Compact ? 70 : 82);
            layout.ItemGrid.constraintCount = Compact ? 2 : 4;
            layout.ItemGrid.cellSize = new Vector2((itemWidth - (Compact ? 1 : 3) * 6) / (Compact ? 2 : 4), Compact ? 70 : 82);
            Place(layout.Hint, Vector2.zero, 220, 12, contentWidth, 20);
            Place(layout.Log, new Vector2(1, 0), -352, deckHeight + 30, 336, 144);
            Place(layout.Tooltip, new Vector2(.5f, 0), -190, deckHeight + 30, 380, 148);
            if (narrow)
            {
                Place(layout.Actor, Vector2.zero, 16, 214, 190, 142);
                Place(layout.Commands, Vector2.zero, deckWidth - commandsWidth - 16, 234, commandsWidth, 122);
                skillWidth = deckWidth - 168;
                Place(layout.Skills, Vector2.zero, 16, 38, skillWidth, 174);
                Place(layout.Items, Vector2.zero, deckWidth - 132, 38, 116, 174);
                layout.SkillGrid.cellSize = new Vector2((skillWidth - 18) / 4, 70);
                layout.ItemGrid.cellSize = new Vector2(55, 70);
                Place(layout.Hint, Vector2.zero, 16, 12, deckWidth - 32, 20);
                turnWidth = width - 32;
                Place(layout.Turns, new Vector2(.5f, 1), -turnWidth / 2, -158, turnWidth, 60);
                layout.TurnGrid.cellSize = new Vector2((turnWidth - 42) / 8, 60);
                Place(layout.Party, new Vector2(0, 1), 16, -456, 154, 286);
            }
        }
        private static void Place(RectTransform rect, Vector2 anchor, float x, float y, float width, float height)
        {
            rect.anchorMin = rect.anchorMax = anchor; rect.pivot = Vector2.zero;
            rect.anchoredPosition = new Vector2(x, y); rect.sizeDelta = new Vector2(width, height);
        }
        public int ReadShortcut()
        {
            if (!Application.isPlaying) return 0;
            for (var i = 0; i < 8; i++) if (Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1 + i))) return i + 1;
            if (Input.GetKeyDown(KeyCode.Return)) return 9;
            if (Input.GetKeyDown(KeyCode.Escape)) return 10;
            return 0;
        }
        private void OnDestroy()
        {
            if (fallbackFont == null) return;
            if (Application.isPlaying) Destroy(fallbackFont); else DestroyImmediate(fallbackFont);
        }
#if UNITY_EDITOR
        [BlackList] public void SetEditorLayout(Layout value) => layout = value;
        [BlackList] public void SetEditorIcons(IconEntry[] value) => icons = value;
        // Deterministic preview uses the same layout function without changing the user's Game view.
        [BlackList] public void PreviewLayout(float width)
        {
            layout.SafeArea.anchorMin = Vector2.zero; layout.SafeArea.anchorMax = Vector2.one;
            layout.SafeArea.offsetMin = layout.SafeArea.offsetMax = Vector2.zero;
            LayoutContent(width);
        }
#endif
    }
}
