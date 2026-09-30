using System;
using System.Collections.Generic;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    [InitializeOnLoad]
    public static class MainHudAssets
    {
        private static readonly Color Ink=new Color(.055f,.075f,.068f,.95f),Card=new Color(.12f,.16f,.14f,.95f),Paper=new Color(.92f,.89f,.79f),Gold=new Color(.78f,.65f,.39f),Muted=new Color(.67f,.72f,.64f);
        [MenuItem("Project Y/UI/同步紧凑血条与跟随参数")]
        public static void SyncHealthFollower()
        {
            UXLayoutAssets.ApplyHeadHealth();
        }
        static MainHudAssets()
        {LuaViewHints.Register(typeof(MainHudView),"CS.ProjectY.UI.MainHudView");LuaViewHints.Register(typeof(UIFollower),"CS.ProjectY.UI.UIFollower");}
        [MenuItem("Project Y/UI/创建 MainHud 与跟随血条")]
        public static void Create()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("MainHud 资源需要 Edit Mode。");
            Save("HudRow",UIKind.Widget,BuildRow);Save("HudParty",UIKind.Widget,root=>BuildHealth(root,false));Save("HudHealth",UIKind.Widget,root=>BuildHealth(root,true));
            Save("MainHud",UIKind.Panel,Build);AssetDatabase.SaveAssets();Debug.Log("MainHud and screen-space followers ready; authored layouts preserved.");
        }
        private static void Save(string name,UIKind kind,Action<GameObject> build)
        {
            var entry=PanelAssets.LoadOrCreate().Entries.Find(e=>e.Name==name);
            if(entry==null) entry=PanelAssets.Save(new PanelDefinition {Name=name,Module="MainHud",Kind=kind,Layer="Main",Cache=true,Modal=false,CloseOnBack=false,PauseWorldOnOpen=false},null);
            PanelAssets.Generate(entry);var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                if(root.transform.childCount==0) build(root);
                var reference=root.GetComponent<LuaReference>();reference.ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
            }
            finally {PrefabUtility.UnloadPrefabContents(root);}
        }
        private static RectTransform Rect(string name,Transform parent,float x,float y,float w,float h)
        {
            var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);
            r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);return r;
        }
        private static void Stretch(RectTransform r)
        {r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.pivot=new Vector2(.5f,.5f);r.offsetMin=r.offsetMax=Vector2.zero;}
        private static Image Paint(RectTransform r,Color color,bool hit=false)
        {var image=r.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=hit;return image;}
        private static Text Label(string name,Transform parent,string value,float x,float y,float w,float h,int size=16,Color? color=null)
        {
            var text=Rect(name,parent,x,y,w,h).gameObject.AddComponent<Text>();text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.fontSize=size;text.text=value;text.color=color??Paper;text.alignment=TextAnchor.MiddleLeft;text.raycastTarget=false;text.supportRichText=false;return text;
        }
        private static void Bind(GameObject root,string key,Component value)
        {var reference=root.GetComponent<LuaReference>();var entries=reference.GetEditorBindings().ToList();entries.Add(new LuaReference.Entry(key,value));reference.SetEditorBindings(entries.ToArray());}
        private static Button Button(GameObject root,string key,Transform parent,string caption,float x,float y,float w,float h)
        {
            var rect=Rect(key,parent,x,y,w,h);var image=Paint(rect,Card,true);var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=image;
            button.navigation=new Navigation {mode=Navigation.Mode.None};var text=Label("Label",rect,caption,6,0,w-12,h,14);text.alignment=TextAnchor.MiddleCenter;
            Bind(root,key,button);Bind(root,key+"Text",text);return button;
        }
        private static RectTransform Scroll(GameObject root,string key,Transform parent,float x,float y,float w,float h)
        {
            var rect=Rect(key+"Scroll",parent,x,y,w,h);Paint(rect,new Color(0,0,0,.01f),true);
            var viewport=Rect("Viewport",rect,0,0,w,h);Stretch(viewport);viewport.gameObject.AddComponent<RectMask2D>();
            var content=Rect(key,viewport,0,0,w-8,0);var list=content.gameObject.AddComponent<VerticalLayoutGroup>();list.spacing=6;
            list.childControlWidth=true;list.childControlHeight=false;list.childForceExpandWidth=true;list.childForceExpandHeight=false;
            content.gameObject.AddComponent<ContentSizeFitter>().verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            var scroll=rect.gameObject.AddComponent<ScrollRect>();scroll.viewport=viewport;scroll.content=content;scroll.horizontal=false;scroll.vertical=true;scroll.scrollSensitivity=32;scroll.movementType=ScrollRect.MovementType.Clamped;
            var barRect=Rect("Scrollbar",rect,w-5,0,4,h);barRect.anchorMin=new Vector2(1,0);barRect.anchorMax=Vector2.one;barRect.offsetMin=new Vector2(-4,0);barRect.offsetMax=Vector2.zero;Paint(barRect,new Color(.2f,.25f,.21f));
            var handle=Rect("Handle",barRect,0,0,4,30);Stretch(handle);var handleImage=Paint(handle,Gold,true);
            var bar=barRect.gameObject.AddComponent<Scrollbar>();bar.direction=Scrollbar.Direction.BottomToTop;bar.handleRect=handle;bar.targetGraphic=handleImage;scroll.verticalScrollbar=bar;
            scroll.verticalScrollbarVisibility=ScrollRect.ScrollbarVisibility.AutoHide;Bind(root,key,content);Bind(root,key+"Scroll",scroll);return content;
        }
        private static void Build(GameObject root)
        {
            var canvas=root.GetComponent<Canvas>();
            Bind(root,"Group",root.GetComponent<CanvasGroup>());
            var health=Rect("HealthLayer",root.transform,0,0,1280,720);Stretch(health);Bind(root,"HealthLayer",health);
            var exploration=Rect("Exploration",root.transform,0,0,1280,720);Stretch(exploration);Bind(root,"Exploration",exploration);
            var safe=Rect("Safe",exploration,0,0,1280,720);Stretch(safe);
            var header=Rect("Header",safe,16,16,1248,66);Paint(header,Ink,true);
            var rule=Paint(Rect("GoldRule",header,0,0,1248,2),Gold).rectTransform;rule.anchorMax=new Vector2(1,1);rule.sizeDelta=new Vector2(0,2);
            Bind(root,"Location",Label("Location",header,"边境远征",18,9,360,26,22,Gold));Bind(root,"Subtitle",Label("Subtitle",header,"",18,37,460,22,13,Muted));
            var coins=Label("Coins",header,"",-570,15,116,34,16,Gold);coins.rectTransform.anchorMin=coins.rectTransform.anchorMax=new Vector2(1,1);Bind(root,"Coins",coins);
            var keys=new[]{"NavigationToggle","Inventory","Growth","Focus","Environment"};var captions=new[]{"地点 / 行动","背包  I","角色手记  C","全图  F","画面"};
            for(int i=0;i<keys.Length;i++) {var button=Button(root,keys[i],header,captions[i],-440+i*86,16,80,34);var rect=(RectTransform)button.transform;rect.anchorMin=rect.anchorMax=new Vector2(1,1);}
            var navigation=Rect("Navigation",safe,16,96,294,508);Paint(navigation,Ink,true);
            Bind(root,"NavigationTitle",Label("NavigationTitle",navigation,"目的地",14,12,266,27,17,Gold));
            var rows=Scroll(root,"NavigationRows",navigation,12,48,270,444);
            var footer=Rect("AreaActions",safe,0,0,640,34);footer.anchorMin=footer.anchorMax=new Vector2(.5f,1);footer.anchoredPosition=new Vector2(-190,-98);
            Button(root,"Leave",footer,"返回大地图",0,0,126,34);Button(root,"Stop",footer,"停止  Space",136,0,126,34);
            Button(root,"CameraMode",footer,"切换视角  V",272,0,126,34);Button(root,"Restart",footer,"新的远征",0,0,126,34);
            var party=Rect("PartyRows",safe,16,648,712,56);var grid=party.gameObject.AddComponent<GridLayoutGroup>();grid.constraint=GridLayoutGroup.Constraint.FixedColumnCount;grid.constraintCount=4;grid.cellSize=new Vector2(172,56);grid.spacing=new Vector2(8,6);Bind(root,"PartyRows",party);
            var journal=Rect("Journal",safe,924,516,324,188);Paint(journal,Ink,true);Label("JournalTitle",journal,"旅 途 见 闻",14,10,296,25,16,Gold);
            Bind(root,"Logs",Label("Logs",journal,"",14,44,296,132,13,Muted));
            var interaction=Rect("Interaction",safe,424,524,420,100);Paint(interaction,Ink,true);Bind(root,"Interaction",interaction);
            Bind(root,"InteractionTitle",Label("InteractionTitle",interaction,"",14,8,268,26,18,Gold));Bind(root,"InteractionBody",Label("InteractionBody",interaction,"",14,37,268,58,13,Muted));
            Button(root,"Interact",interaction,"交互  E",291,32,114,36);
            var hint=Label("Hint",safe,"",342,88,620,42,15,new Color(.95f,.64f,.45f));Bind(root,"Hint",hint);
            var battlePrefab=PanelAssets.LoadOrCreate().Get("BattleHUD").Prefab;
            if(battlePrefab==null) throw new InvalidOperationException("请先创建战斗 HUD。");
            var battle=(GameObject)PrefabUtility.InstantiatePrefab(battlePrefab,root.transform);battle.name="BattleContent";
            battle.GetComponent<LuaPanel>().enabled=false;var battleCanvas=battle.GetComponent<Canvas>();battleCanvas.overrideSorting=false;battle.GetComponent<CanvasScaler>().enabled=false;
            Stretch((RectTransform)battle.transform);battle.transform.localScale=Vector3.one;battle.transform.localRotation=Quaternion.identity;
            battle.SetActive(false);Bind(root,"BattleContent",battle.GetComponent<LuaReference>());
            var view=root.AddComponent<MainHudView>();
            view.SetEditorBindings(new MainHudView.Layout {Root=(RectTransform)root.transform,Safe=safe,Header=header,Navigation=navigation,NavigationScroll=(RectTransform)rows.parent.parent,
                NavigationContent=rows,Journal=journal,Party=party,PartyGrid=grid,Interaction=interaction,Hint=hint.rectTransform,Canvas=canvas,Labels=exploration.GetComponentsInChildren<Text>(true)});
            Bind(root,"HUD",view);Bind(root,"Style",view);
            BattleFeedbackAssets.SetupMain(root);
        }
        private static void BuildRow(GameObject root)
        {
            ((RectTransform)root.transform).sizeDelta=new Vector2(262,64);var image=Paint((RectTransform)root.transform,Card,true);
            var button=root.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};Bind(root,"Button",button);
            var title=Label("Title",root.transform,"",10,6,242,26,16,Paper);var body=Label("Body",root.transform,"",10,34,242,24,12,Muted);
            title.rectTransform.anchorMax=body.rectTransform.anchorMax=new Vector2(1,1);title.rectTransform.sizeDelta=new Vector2(-20,26);body.rectTransform.sizeDelta=new Vector2(-20,24);
            Bind(root,"Title",title);Bind(root,"Body",body);
        }
        private static void BuildHealth(GameObject root,bool follower)
        {
            var rect=(RectTransform)root.transform;rect.sizeDelta=new Vector2(follower?128:172,follower?36:56);
            Paint(rect,new Color(.045f,.06f,.05f,.95f));
            var name=Label("Name",rect,"同行者",follower?6:9,2,rect.sizeDelta.x-(follower?12:18),follower?18:23,follower?12:14,Paper);Bind(root,"Name",name);
            var track=Rect("Track",rect,follower?6:8,follower?21:30,rect.sizeDelta.x-(follower?12:16),follower?11:18);Paint(track,new Color(.17f,.20f,.17f));
            var fill=Rect("Health",track,0,0,track.sizeDelta.x,18);Stretch(fill);fill.anchorMax=Vector2.one;var image=Paint(fill,new Color(.38f,.74f,.53f));Bind(root,"Health",image);
            var hp=Label("HealthText",track,"46 / 46",0,0,track.sizeDelta.x,track.sizeDelta.y,follower?10:14,Color.white);hp.alignment=TextAnchor.MiddleCenter;
            var outline=hp.gameObject.AddComponent<Outline>();outline.effectColor=new Color(0,0,0,.8f);outline.effectDistance=new Vector2(1,-1);Bind(root,"HealthText",hp);
            if(follower)
            {
                rect.anchorMin=rect.anchorMax=new Vector2(.5f,.5f);rect.pivot=new Vector2(.5f,0);rect.anchoredPosition=Vector2.zero;
                var group=root.GetComponent<CanvasGroup>();group.blocksRaycasts=false;group.interactable=false;
                var follow=root.AddComponent<UIFollower>();follow.SetEditorBindings(rect,group);Bind(root,"Follower",follow);
            }
            BattleFeedbackAssets.SetupHealth(root);
        }
    }
}
