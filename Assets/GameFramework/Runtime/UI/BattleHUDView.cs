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
            public RectTransform Root, SafeArea, Header, Turns, Party, Deck, Skills, Items, Commands, Hint, Log, Tooltip;
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
            Compact=width<1050;
            var deckWidth=Mathf.Min(550,width-190);
            Place(layout.Deck,Vector2.zero,18,18,deckWidth,140);
            Place(layout.Header,new Vector2(0,1),18,-80,190,62);
            var turnWidth=Mathf.Min(540,width-380);
            Place(layout.Turns,new Vector2(.5f,1),-turnWidth/2,-84,turnWidth,62);
            layout.TurnGrid.constraintCount=4;layout.TurnGrid.cellSize=new Vector2((turnWidth-24)/4,62);
            layout.Party.gameObject.SetActive(false);
            Place(layout.Skills,Vector2.zero,14,30,deckWidth-28,98);
            layout.SkillGrid.constraintCount=4;layout.SkillGrid.cellSize=new Vector2((deckWidth-46)/4,72);
            layout.Items.gameObject.SetActive(false);
            Place(layout.Commands,Vector2.zero,deckWidth+32,18,142,140);
            Place(layout.Hint,Vector2.zero,14,6,deckWidth-28,22);
            Place(layout.Log,new Vector2(1,0),-498,18,480,140);
            Place(layout.Tooltip,new Vector2(.5f,0),-200,174,400,152);
        }
        private static void Place(RectTransform rect, Vector2 anchor, float x, float y, float width, float height)
        {
            rect.anchorMin = rect.anchorMax = anchor; rect.pivot = Vector2.zero;
            rect.anchoredPosition = new Vector2(x, y); rect.sizeDelta = new Vector2(width, height);
        }
        public int ReadShortcut()
        {
            if (!Application.isPlaying) return 0;
            for (var i = 0; i < 4; i++) if (Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1 + i))) return i + 1;
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
