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
            public RectTransform Root,Safe,Header,Navigation,NavigationScroll,NavigationContent,Journal,Party,Interaction,Hint;
            public GridLayoutGroup PartyGrid;
            public Canvas Canvas;
            public Text[] Labels;
        }
        [SerializeField] private Layout layout;
        private readonly List<UIFollower> followers=new List<UIFollower>();
        private Font font;
        private bool exploration=true,navigation=true;
        private Vector2 previousSize;
        private Rect previousSafe;
        private bool layoutDirty=true;
        private RectTransform characterSkills;
        public void SetCharacterSkillBar(RectTransform value) {characterSkills=value;layoutDirty=true;ApplyLayout();}
        public Font Font => font!=null?font:(font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","PingFang SC","Noto Sans CJK SC","Arial"},16));
        public float WorldLeftInset => exploration&&navigation?Mathf.Min(Screen.width*.42f,326*layout.Canvas.rootCanvas.scaleFactor):0;
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
            var size=layout.Safe.rect.size;var w=Mathf.Max(480,size.x);var h=Mathf.Max(360,size.y);
            Place(layout.Header,0,1,16,-16,w-32,66);
            var bottomReserve=characterSkills!=null?340:212;
            Place(layout.Navigation,0,1,16,-96,294,Mathf.Max(90,h-bottomReserve));
            layout.NavigationScroll.sizeDelta=new Vector2(270,Mathf.Max(42,h-bottomReserve-54));
            var compact=w<1050;var partyWidth=compact?360:712;
            Place(layout.Party,0,0,16,16,partyWidth,compact?118:56);
            if(characterSkills!=null)Place(characterSkills,0,0,16,compact?142:80,partyWidth,116);
            layout.PartyGrid.constraintCount=compact?2:4;
            Place(layout.Journal,1,0,-340,16,324,188);
            layout.Journal.gameObject.SetActive(exploration&&w>=900);
            Place(layout.Interaction,.5f,0,-210,characterSkills!=null?(compact?270:208):(compact?148:92),420,100);
            Place(layout.Hint,.5f,1,-Mathf.Min(720,w-360)/2,-88,Mathf.Min(720,w-360),42);
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
