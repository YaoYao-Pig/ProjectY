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
            public GridLayoutGroup SkillGrid, ItemGrid;
            public Text[] Labels;
            public ScrollRect LogScroll;
            public Text LogText, LogTitle;
            public Button LogOpen, LogClose;
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
        private bool logExpanded;
        private RectTransform logControls;
        private float rightInset;
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
            BindLogControls();
            if(layout.LogScroll==null || layout.LogText==null || layout.LogTitle==null || layout.LogOpen==null || layout.LogClose==null)
                throw new InvalidOperationException("战斗日志展开绑定缺失，请执行 Project Y/UI/同步战斗日志展开界面。");
            foreach (var label in layout.Labels) label.font = Font;
            ApplyLayout();
        }
        internal void SetLog(bool expanded,string compactText,string fullText,int count)
        {
            if(compactText==null || fullText==null || count<0)throw new ArgumentException("Invalid battle log projection.");
            bool changed=logExpanded!=expanded;
            bool follow=changed || !expanded || layout.LogScroll.verticalNormalizedPosition<=.02f;
            float offset=layout.LogScroll.content.anchoredPosition.y;
            logExpanded=expanded;
            layout.LogTitle.text=expanded?LuaLanguage.Format("BattleLogExpandedTitle",count):LuaLanguage.Get("BattleLogCollapsedTitle");
            layout.LogOpen.interactable=!expanded;layout.LogClose.gameObject.SetActive(expanded);
            layout.LogScroll.enabled=expanded;
            if(layout.LogScroll.verticalScrollbar!=null)layout.LogScroll.verticalScrollbar.gameObject.SetActive(expanded);
            if(changed)ApplyLayout();
            string next=expanded?fullText:compactText;
            if(!changed && layout.LogText.text==next)return;
            layout.LogText.text=next;
            layout.LogScroll.StopMovement();
            LayoutRebuilder.ForceRebuildLayoutImmediate(layout.Log);
            if(follow)layout.LogScroll.verticalNormalizedPosition=0;
            else
            {
                var content=layout.LogScroll.content;
                float maximum=Mathf.Max(0,content.rect.height-layout.LogScroll.viewport.rect.height);
                content.anchoredPosition=new Vector2(content.anchoredPosition.x,Mathf.Clamp(offset,0,maximum));
            }
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
        private void BindLogControls()
        {
            if(logControls!=null)return;
            var reference=GetComponent<LuaReference>();
            var auto=reference.GetButton("Auto").transform;
            var toggle=reference.GetButton("LogToggle").transform;
            if(auto.parent!=toggle.parent || auto.parent.parent!=layout.SafeArea)
                throw new InvalidOperationException("Battle log controls must share a container under SafeArea.");
            logControls=(RectTransform)auto.parent;
        }
        internal void SetRightInset(float value)
        {
            if(Mathf.Approximately(rightInset,value))return;
            rightInset=value;
            ApplyLayout();
        }
        public void ApplyLayout()
        {
            previousSize = layout.Root.rect.size; previousSafeArea = Screen.safeArea;
            var screen = new Vector2(Mathf.Max(1, Screen.width), Mathf.Max(1, Screen.height));
            layout.SafeArea.anchorMin = previousSafeArea.min / screen;
            layout.SafeArea.anchorMax = previousSafeArea.max / screen;
            layout.SafeArea.offsetMin = Vector2.zero;
            layout.SafeArea.offsetMax = new Vector2(-rightInset,0);
            LayoutContent(layout.SafeArea.rect.size);
        }
        private void LayoutContent(Vector2 size)
        {
            BindLogControls();
            // Keep authored button/text proportions on short or narrow windows. All
            // occupied bounds below use the same logical coordinates and scale.
            float scale=Mathf.Min(1,size.x/640,size.y/600);
            if(scale<=0)return; // Canvas can have zero dimensions before its first layout.
            float width=size.x/scale,height=size.y/scale;
            var deckWidth=Mathf.Min(550,width-224);
            PlaceScaled(layout.Deck,18,18,deckWidth,242,scale);
            PlaceScaled(layout.Header,18,height-80,190,62,scale);
            var turnWidth=Mathf.Min(540,width-246);
            PlaceScaled(layout.Turns,228,height-98,turnWidth,76,scale);
            layout.Party.gameObject.SetActive(false);
            Place(layout.Skills,Vector2.zero,14,132,deckWidth-28,98);
            layout.SkillGrid.constraintCount=4;layout.SkillGrid.cellSize=new Vector2((deckWidth-46)/4,72);
            layout.Items.gameObject.SetActive(true);
            Place(layout.Items,Vector2.zero,14,30,deckWidth-28,98);
            layout.ItemGrid.constraintCount=4;layout.ItemGrid.cellSize=new Vector2((deckWidth-46)/4,72);
            PlaceScaled(layout.Commands,deckWidth+32,18,142,140,scale);
            PlaceScaled(logControls,deckWidth+32,168,174,60,scale);
            Place(layout.Hint,Vector2.zero,14,6,deckWidth-28,22);
            float compactWidth=Mathf.Min(480,width-deckWidth-238);
            Compact=size.x<1050 || compactWidth<320;
            layout.Log.gameObject.SetActive(logExpanded || !Compact);
            if(logExpanded)
            {
                // The entire bottom control band and the initiative row stay usable.
                float logTop=Mathf.Min(layout.Header.anchoredPosition.y,layout.Turns.anchoredPosition.y)/scale-12;
                float logWidth=Mathf.Min(680,width-36),logHeight=Mathf.Min(440,logTop-272);
                PlaceScaled(layout.Log,width-logWidth-18,272,logWidth,logHeight,scale);
            }
            else if(!Compact)PlaceScaled(layout.Log,width-compactWidth-18,18,compactWidth,140,scale);
            PlaceScaled(layout.Tooltip,(width-400)/2,272,400,152,scale);
        }
        private static void PlaceScaled(RectTransform rect,float x,float y,float width,float height,float scale)
        {
            Place(rect,Vector2.zero,x*scale,y*scale,width,height);
            rect.localScale=Vector3.one*scale;
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
        [BlackList] public Layout EditorLayout => layout;
        [BlackList] public void SetEditorIcons(IconEntry[] value) => icons = value;
        // Deterministic preview uses the same layout function without changing the user's Game view.
        [BlackList] public void PreviewLayout(float width)
        {
            layout.SafeArea.anchorMin = Vector2.zero; layout.SafeArea.anchorMax = Vector2.one;
            layout.SafeArea.offsetMin = Vector2.zero;layout.SafeArea.offsetMax = new Vector2(-rightInset,0);
            LayoutContent(new Vector2(width-rightInset,layout.SafeArea.rect.height));
        }
#endif
    }
}
