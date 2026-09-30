using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>首次生成可编辑资源；重复执行只同步图片和绑定提示，不覆盖手工布局。</summary>
    [InitializeOnLoad]
    public static class StoryGrowthAssets
    {
        private static readonly Color Ink = new Color(.065f,.10f,.09f,.98f);
        private static readonly Color Card = new Color(.14f,.19f,.17f);
        private static readonly Color Paper = new Color(.90f,.86f,.75f);
        private static readonly Color Gold = new Color(.82f,.69f,.43f);
        private static readonly Color Muted = new Color(.64f,.69f,.60f);
        [Serializable] private sealed class Events { public EventArt[] rows; }
        [Serializable] private sealed class EventArt { public string illustration; }
        static StoryGrowthAssets() { LuaViewHints.Register(typeof(StoryGrowthView), "CS.ProjectY.UI.StoryGrowthView"); }
        [MenuItem("Project Y/UI/创建事件与养成 UI")]
        public static void Create()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请在 Edit Mode 生成事件与养成 UI。");
            var arts = new List<StoryGrowthView.ArtEntry>();
            foreach (var path in JsonUtility.FromJson<Events>(File.ReadAllText("Config/Tables/Adventure/AdventureEventTable.json")).rows.Select(row=>row.illustration).Where(path=>!string.IsNullOrEmpty(path)).Distinct())
            {
                AssetDatabase.ImportAsset(path);
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                if (importer == null) throw new InvalidOperationException("Missing illustration texture: " + path);
                if (importer.textureType != TextureImporterType.Sprite) { importer.textureType = TextureImporterType.Sprite; importer.spriteImportMode = SpriteImportMode.Single; importer.mipmapEnabled = false; importer.SaveAndReimport(); }
                arts.Add(new StoryGrowthView.ArtEntry { Path = path, Sprite = AssetDatabase.LoadAssetAtPath<Sprite>(path) });
            }
            Entry("StoryChoice", UIKind.Widget, BuildChoice, arts);
            Entry("GrowthRow", UIKind.Widget, BuildRow, arts);
            Entry("TraitTag", UIKind.Widget, BuildTag, arts);
            Entry("TalentNode", UIKind.Widget, BuildNode, arts);
            Entry("TalentEdge", UIKind.Widget, BuildEdge, arts);
            Entry("StoryEvent", UIKind.Panel, BuildEvent, arts);
            Entry("CharacterGrowth", UIKind.Panel, BuildGrowth, arts);
            Entry("AdventureJournal", UIKind.Panel, BuildJournal, arts);
            CharacterJournalAssets.SyncGlyphs();
            AssetDatabase.SaveAssets();
            Debug.Log("Story and growth prefabs ready; existing layouts preserved.");
        }
        private static void Entry(string name, UIKind kind, Action<GameObject> build, List<StoryGrowthView.ArtEntry> arts)
        {
            var modal = kind == UIKind.Panel && name != "AdventureJournal";
            var entry = PanelAssets.LoadOrCreate().Entries.Find(row=>row.Name==name);
            if (entry == null) entry = PanelAssets.Save(new PanelDefinition { Name=name, Module="Adventure", Kind=kind,
                Layer=modal?"Popup":"Main", Modal=modal, Cache=true, CloseOnBack=name=="CharacterGrowth", PauseWorldOnOpen=modal },null);
            PanelAssets.Generate(entry);
            var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                if (root.transform.childCount == 0) build(root);
                var view = root.GetComponent<StoryGrowthView>();
                if (view != null)
                {
                    var bindings = root.GetComponent<LuaReference>().GetEditorBindings();
                    var page = bindings.FirstOrDefault(value=>value.Key=="Page").Target as RectTransform;
                    view.SetEditorBindings(root.GetComponentsInChildren<Text>(true),arts.ToArray(),page);
                }
                root.GetComponent<LuaReference>().ValidateBindings();
                PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                LuaViewHints.Export(root.GetComponent<LuaReference>(),entry.ViewType);
            }
            finally { PrefabUtility.UnloadPrefabContents(root); }
        }
        private static RectTransform Node(string name, Transform parent, float x, float y, float w, float h)
        {
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform; rect.SetParent(parent,false);
            rect.anchorMin=rect.anchorMax=new Vector2(0,1);rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(w,h);return rect;
        }
        private static void Stretch(RectTransform rect, float inset=0)
        {rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;rect.offsetMin=new Vector2(inset,inset);rect.offsetMax=new Vector2(-inset,-inset);}
        private static Image Paint(RectTransform rect, Color color, bool raycast=false)
        {var image=rect.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=raycast;return image;}
        private static Text Text(string name, Transform parent, string value, float x,float y,float w,float h,int size=17,Color? color=null)
        {
            var rect=Node(name,parent,x,y,w,h);var text=rect.gameObject.AddComponent<Text>();
            text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");text.fontSize=size;text.color=color??Paper;text.text=value;
            text.raycastTarget=false;text.alignment=TextAnchor.MiddleLeft;text.supportRichText=false;text.verticalOverflow=VerticalWrapMode.Truncate;return text;
        }
        private static Button Button(string name,Transform parent,string caption,float x,float y,float w,float h,out Text label)
        {
            var rect=Node(name,parent,x,y,w,h);var image=Paint(rect,Card,true);var button=rect.gameObject.AddComponent<Button>();
            button.targetGraphic=image;button.navigation=new Navigation {mode=Navigation.Mode.None};
            label=Text("Label",rect,caption,10,2,w-20,h-4,16);label.alignment=TextAnchor.MiddleCenter;
            return button;
        }
        private static void Bind(GameObject root,string key,Component value)
        {
            var reference=root.GetComponent<LuaReference>();var all=new List<LuaReference.Entry>(reference.GetEditorBindings());
            all.Add(new LuaReference.Entry(key,value));reference.SetEditorBindings(all.ToArray());
        }
        private static void Control(GameObject root,string key,Transform parent,string caption,float x,float y,float w,float h)
        {var button=Button(key,parent,caption,x,y,w,h,out var text);Bind(root,key,button);Bind(root,key+"Text",text);}
        private static RectTransform Scroll(GameObject root,string key,Transform parent,float x,float y,float w,float h,bool graph=false)
        {
            var rect=Node(key+"Scroll",parent,x,y,w,h);Paint(rect,new Color(.08f,.13f,.115f),true);
            var viewport=Node("Viewport",rect,0,0,w,h);Stretch(viewport);viewport.gameObject.AddComponent<RectMask2D>();
            var content=Node(key,viewport,0,0,graph?780:w,graph?480:0);
            if (!graph)
            {
                var layout=content.gameObject.AddComponent<VerticalLayoutGroup>();layout.spacing=8;layout.padding=new RectOffset(8,8,8,8);
                layout.childControlWidth=true;layout.childControlHeight=false;layout.childForceExpandWidth=true;layout.childForceExpandHeight=false;
                content.gameObject.AddComponent<ContentSizeFitter>().verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            }
            var scroll=rect.gameObject.AddComponent<ScrollRect>();scroll.viewport=viewport;scroll.content=content;scroll.horizontal=graph;scroll.vertical=true;
            scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=24;Bind(root,key,content);Bind(root,key+"Scroll",scroll);return content;
        }
        private static RectTransform Page(GameObject root,string title)
        {
            var veil=Node("Veil",root.transform,0,0,1280,720);Stretch(veil);Paint(veil,new Color(.015f,.025f,.02f,.84f),true);
            var page=Node("Page",root.transform,0,0,1200,664);page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.anchoredPosition=Vector2.zero;Paint(page,Ink,true);
            var rule=Node("GoldRule",page,26,14,1148,2);Paint(rule,Gold);
            Bind(root,"Page",page);Bind(root,"Style",root.AddComponent<StoryGrowthView>());
            Bind(root,"Title",Text("Title",page,title,28,27,890,43,27,Gold));
            Bind(root,"Hint",Text("Hint",page,"",28,626,1030,25,14,Muted));
            return page;
        }
        private static void BuildChoice(GameObject root)
        {
            var rect=(RectTransform)root.transform;rect.sizeDelta=new Vector2(440,100);Paint(rect,Card,true);
            var button=root.AddComponent<Button>();button.targetGraphic=root.GetComponent<Image>();button.navigation=new Navigation{mode=Navigation.Mode.None};
            Bind(root,"Button",button);Bind(root,"Title",Text("Title",rect,"做出选择",16,9,405,29,18,Gold));
            Bind(root,"Body",Text("Body",rect,"条件与后果",16,41,405,51,14,Muted));
        }
        private static void BuildRow(GameObject root)
        {
            var rect=(RectTransform)root.transform;rect.sizeDelta=new Vector2(340,86);var image=Paint(rect,Card,true);
            var button=root.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};
            var title=Text("Title",rect,"",12,6,316,25,17,Gold);var body=Text("Body",rect,"",12,35,316,44,14,Muted);
            title.rectTransform.anchorMax=new Vector2(1,1);title.rectTransform.sizeDelta=new Vector2(-24,25);
            body.rectTransform.anchorMax=new Vector2(1,1);body.rectTransform.sizeDelta=new Vector2(-24,44);
            Bind(root,"Button",button);Bind(root,"Title",title);Bind(root,"Body",body);Bind(root,"Background",image);
        }
        private static void BuildTag(GameObject root)
        {
            BuildRow(root);root.name="TraitTagWidget";
            var badge=Node("Accent",root.transform,0,0,3,86);Bind(root,"Accent",Paint(badge,Gold));
        }
        private static void BuildNode(GameObject root)
        {
            var rect=(RectTransform)root.transform;rect.sizeDelta=new Vector2(122,66);var image=Paint(rect,Card,true);
            var button=root.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};
            var title=Text("Title",rect,"被动天赋",5,7,112,26,15,Paper);title.alignment=TextAnchor.MiddleCenter;
            var rank=Text("Rank",rect,"0 / 1",5,35,112,22,13,Gold);rank.alignment=TextAnchor.MiddleCenter;
            Bind(root,"Button",button);Bind(root,"Title",title);Bind(root,"Rank",rank);Bind(root,"Background",image);
        }
        private static void BuildEdge(GameObject root)
        {
            var rect=(RectTransform)root.transform;Bind(root,"Line",Paint(rect,Muted));
            var arrow=Text("Arrow",rect,"▶",0,0,16,20,14,Gold);arrow.rectTransform.anchorMin=arrow.rectTransform.anchorMax=new Vector2(.6f,.5f);arrow.rectTransform.pivot=new Vector2(.5f,.5f);
            Bind(root,"Arrow",arrow);
        }
        private static void BuildEvent(GameObject root)
        {
            var page=Page(root,"旅途中的一页");
            var image=Paint(Node("Illustration",page,28,91,680,453),Color.white);image.preserveAspect=true;Bind(root,"Illustration",image);
            Bind(root,"Caption",Text("Caption",page,"",28,555,680,55,15,Muted));
            Bind(root,"Description",Text("Description",page,"有人向你伸出手。",735,92,433,158,19,Paper));
            Scroll(root,"Choices",page,724,263,450,310);
            Control(root,"Continue",page,"继续旅程",916,584,250,38);
        }
        private static void BuildGrowth(GameObject root)
        {
            var page=Page(root,"同行者 · 旅人手记");
            Control(root,"Close",page,"关闭  [Esc]",1042,30,130,36);
            for(var i=1;i<=4;i++) Control(root,"Party"+i,page,"同行者 "+i,28+(i-1)*212,82,202,42);
            Bind(root,"Summary",Text("Summary",page,"等级 · 生命 · 可用点数",28,135,1140,26,16,Muted));
            Control(root,"OverviewTab",page,"01  总览",28,176,172,37);Control(root,"SkillsTab",page,"02  技能与天赋",210,176,190,37);Control(root,"HistoryTab",page,"03  经历",410,176,172,37);
            var overview=Node("Overview",page,28,230,1144,384);Bind(root,"Overview",overview);
            Text("AttributesTitle",overview,"属性 · 点击条目投入属性点",0,0,650,30,18,Gold);
            var attributes=Scroll(root,"Attributes",overview,0,40,660,342);
            UnityEngine.Object.DestroyImmediate(attributes.GetComponent<VerticalLayoutGroup>());
            var attributeGrid=attributes.gameObject.AddComponent<GridLayoutGroup>();attributeGrid.constraint=GridLayoutGroup.Constraint.FixedColumnCount;
            attributeGrid.constraintCount=3;attributeGrid.cellSize=new Vector2(209,86);attributeGrid.spacing=new Vector2(8,8);attributeGrid.padding=new RectOffset(8,8,8,8);
            Text("TraitsTitle",overview,"留下来的印记",690,0,440,30,18,Gold);
            var traits=Scroll(root,"Traits",overview,690,40,454,342);
            UnityEngine.Object.DestroyImmediate(traits.GetComponent<VerticalLayoutGroup>());
            var traitGrid=traits.gameObject.AddComponent<GridLayoutGroup>();traitGrid.constraint=GridLayoutGroup.Constraint.FixedColumnCount;
            traitGrid.constraintCount=2;traitGrid.cellSize=new Vector2(215,86);traitGrid.spacing=new Vector2(8,8);traitGrid.padding=new RectOffset(8,8,8,8);
            var skills=Node("Skills",page,28,228,1144,384);Bind(root,"Skills",skills);
            Control(root,"PreviousTree",skills,"‹",0,0,35,32);Control(root,"NextTree",skills,"›",700,0,35,32);
            Bind(root,"TreeTitle",Text("TreeTitle",skills,"被动天赋",46,0,640,32,18,Gold));
            Scroll(root,"Graph",skills,0,41,750,300,true);
            Bind(root,"TalentDetail",Text("TalentDetail",skills,"选择节点查看详情",0,346,574,38,13,Muted));
            Control(root,"Invest",skills,"投入天赋点",584,345,165,39);
            Bind(root,"SkillTitle",Text("SkillTitle",skills,"主动技能",776,0,368,32,18,Gold));
            Scroll(root,"SkillRows",skills,776,41,368,343);
            var history=Node("History",page,28,228,1144,384);Bind(root,"History",history);
            Bind(root,"HistorySummary",Text("HistorySummary",history,"每一次选择，都留下痕迹。",0,0,820,32,18,Gold));
            Control(root,"PreviousHistory",history,"上一页",920,0,100,32);Control(root,"NextHistory",history,"下一页",1032,0,100,32);
            Scroll(root,"HistoryRows",history,0,42,1144,342);
        }
        private static void BuildJournal(GameObject root)
        {
            var dock=Node("Journal",root.transform,0,0,360,244);dock.anchorMin=dock.anchorMax=new Vector2(1,0);dock.pivot=new Vector2(1,0);dock.anchoredPosition=new Vector2(-20,20);Paint(dock,Ink,true);
            Text("Heading",dock,"旅途见闻",16,10,150,28,18,Gold);Control(root,"Growth",dock,"同行者  [C]",206,9,138,30);
            Scroll(root,"Logs",dock,8,46,344,188);Bind(root,"Style",root.AddComponent<StoryGrowthView>());
        }
    }
}
