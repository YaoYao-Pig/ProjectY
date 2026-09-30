using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Shared HUD layout and post-camera screen followers; Lua owns projections and commands.</summary>
    [LuaCallCSharp, DisallowMultipleComponent, DefaultExecutionOrder(1000)]
    public sealed class MainHudView : MonoBehaviour
    {
        [Serializable] public sealed class Layout
        {
            public RectTransform Root,Safe,Header,Navigation,NavigationScroll,NavigationContent,Journal,Party,Interaction,Hint,Common,Rail,Menu,Clock;
            public GridLayoutGroup PartyGrid,SkillGrid;
            public Canvas Canvas;
            public Text[] Labels;
        }
        [SerializeField] private Layout layout;
        [SerializeField] private BattleFeedbackSystem battleFeedback;
        internal BattleFeedbackSystem BattleFeedback => battleFeedback != null ? battleFeedback : throw new InvalidOperationException("MainHud battle feedback binding is missing.");
        private readonly List<UIFollower> followers=new List<UIFollower>();
        private Font font;
        private bool exploration=true,navigation=true;
        private Vector2 previousSize;
        private Rect previousSafe;
        private bool layoutDirty=true;
        private RectTransform characterSkills;
        public void SetCharacterSkillBar(RectTransform value) {characterSkills=value;layoutDirty=true;ApplyLayout();}
        public Font Font => font!=null?font:(font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","PingFang SC","Noto Sans CJK SC","Arial"},16));
        public float WorldLeftInset => exploration&&navigation?Mathf.Min(Screen.width*.45f,526*layout.Canvas.rootCanvas.scaleFactor):0;
        public void Prepare() {foreach(var text in layout.Labels) text.font=Font;ApplyLayout();}
        public void SetMode(bool explore,bool showNavigation)
        {
            layoutDirty|=exploration!=explore||navigation!=showNavigation;
            exploration=explore;navigation=showNavigation;layout.Navigation.gameObject.SetActive(explore&&showNavigation);ApplyLayout();
        }
        public void Track(UIFollower follower,Camera camera,Transform target)
        {if(!followers.Contains(follower)) followers.Add(follower);follower.Bind(camera,target,layout.Canvas);}
        public void TrackScreen(UIFollower follower,Vector2 point)
        {if(!followers.Contains(follower)) followers.Add(follower);follower.BindScreen(layout.Canvas,point);}
        public void Untrack(UIFollower follower) {followers.Remove(follower);follower.Clear();}
        public void SetHealth(Image fill,float fraction) {fill.rectTransform.anchorMax=new Vector2(Mathf.Clamp01(fraction),1);}
        public void ApplyLayout()
        {
            if(!layoutDirty&&previousSize==layout.Root.rect.size&&previousSafe==Screen.safeArea) return;
            previousSize=layout.Root.rect.size;previousSafe=Screen.safeArea;layoutDirty=false;
            var screen=new Vector2(Mathf.Max(1,Screen.width),Mathf.Max(1,Screen.height));
            layout.Safe.anchorMin=Screen.safeArea.min/screen;layout.Safe.anchorMax=Screen.safeArea.max/screen;layout.Safe.offsetMin=layout.Safe.offsetMax=Vector2.zero;
            layout.Common.anchorMin=layout.Safe.anchorMin;layout.Common.anchorMax=layout.Safe.anchorMax;
            layout.Common.offsetMin=layout.Common.offsetMax=Vector2.zero;
            var size=layout.Safe.rect.size;var w=Mathf.Max(480,size.x);var h=Mathf.Max(360,size.y);
            var narrow=w<1050;
            Place(layout.Header,0,1,224,-18,Mathf.Max(170,w-380),48);
            Place(layout.Party,0,1,18,-18,190,352);
            layout.Party.localScale=Vector3.one*Mathf.Clamp((h-194)/352,.45f,1);
            layout.PartyGrid.constraintCount=1;layout.PartyGrid.cellSize=new Vector2(190,82);
            Place(layout.Navigation,0,1,222,-82,294,Mathf.Max(90,h-246));
            layout.NavigationScroll.sizeDelta=new Vector2(270,Mathf.Max(42,h-300));
            if(characterSkills!=null)Place(characterSkills,0,0,18,18,narrow?Mathf.Max(420,w-158):550,138);
            if(characterSkills!=null)layout.SkillGrid.cellSize=new Vector2((characterSkills.sizeDelta.x-42)/4,70);
            Place(layout.Journal,1,0,-Mathf.Min(480,w-612)-18,18,Mathf.Min(480,w-612),138);
            layout.Journal.gameObject.SetActive(exploration&&!narrow);
            Place(layout.Interaction,.5f,0,-210,172,420,100);
            Place(layout.Hint,.5f,1,-Mathf.Min(560,w-400)/2,-76,Mathf.Min(560,w-400),42);
            Place(layout.Clock,1,1,-130,-18,112,112);
            Place(layout.Rail,1,1,-112,-150,94,300);
            Place(layout.Menu,1,1,-442,-148,314,Mathf.Min(410,h-172));
        }
        private static void Place(RectTransform r,float ax,float ay,float x,float y,float w,float h)
        {r.anchorMin=r.anchorMax=new Vector2(ax,ay);r.pivot=new Vector2(0,ay);r.anchoredPosition=new Vector2(x,y);r.sizeDelta=new Vector2(w,h);}
        private void LateUpdate() {ApplyLayout();UpdateFollowers();}
        public void UpdateFollowers()
        {
            foreach(var follower in followers)
            {
                if(follower!=null && follower.gameObject.activeInHierarchy) follower.Project();
            }
        }
        private void OnDestroy() {if(font!=null) {if(Application.isPlaying) Destroy(font);else DestroyImmediate(font);}}
#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(Layout value) {layout=value;}
#endif
    }
}
