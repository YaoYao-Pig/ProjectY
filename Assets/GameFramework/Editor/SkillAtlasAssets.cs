using System;
using System.Collections.Generic;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>可编辑图谱 Prefab 与 LuaReference 绑定；日常同步保留已有布局。</summary>
    [InitializeOnLoad]
    public static class SkillAtlasAssets
    {
        private static readonly Color Paper=new Color(.91f,.87f,.77f),Ink=new Color(.20f,.25f,.22f),Gold=new Color(.55f,.39f,.20f),Muted=new Color(.42f,.43f,.36f);
        static SkillAtlasAssets(){LuaViewHints.Register(typeof(SkillAtlasView),"CS.ProjectY.UI.SkillAtlasView");}
        [MenuItem("Project Y/UI/创建技能图谱")]
        public static void Create()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("请在 Edit Mode 创建技能图谱。");
            Entry("SkillAtlasCategory",UIKind.Widget,BuildCategory);
            Entry("SkillAtlasNode",UIKind.Widget,BuildNode);
            Entry("SkillAtlasEdge",UIKind.Widget,BuildEdge);
            Entry("SkillAtlas",UIKind.Panel,BuildPanel);
            AddGrowthEntry();AssetDatabase.SaveAssets();Debug.Log("技能图谱已生成：两级分类、前置连线、Cell 跟随浮窗。");
        }
        private static void Entry(string name,UIKind kind,Action<GameObject> build)
        {
            var entry=PanelAssets.LoadOrCreate().Entries.Find(row=>row.Name==name);
            if(entry==null)entry=PanelAssets.Save(new PanelDefinition{Name=name,Module="Progression",Kind=kind,Layer="Popup",Modal=kind==UIKind.Panel,
                Cache=true,CloseOnBack=false,PauseWorldOnOpen=kind==UIKind.Panel,CloseOnSceneChange=true},null);
            PanelAssets.Generate(entry);var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                if(root.transform.childCount==0)build(root);
                if(kind==UIKind.Panel)
                {
                    var style=root.GetComponent<StoryGrowthView>();
                    style.SetJournalTheme(CharacterJournalAssets.CreateGlyphBindings());
                    var page=(RectTransform)root.GetComponent<LuaReference>().GetEditorBindings().Single(row=>row.Key=="Page").Target;
                    style.SetEditorBindings(root.GetComponentsInChildren<Text>(true),Array.Empty<StoryGrowthView.ArtEntry>(),page);
                }
                root.GetComponent<LuaReference>().ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                LuaViewHints.Export(root.GetComponent<LuaReference>(),entry.ViewType);
            }
            finally{PrefabUtility.UnloadPrefabContents(root);}
        }
        private static RectTransform Node(string name,Transform parent,float x,float y,float w,float h)
        {
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.SetParent(parent,false);
            rect.anchorMin=rect.anchorMax=new Vector2(0,1);rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(w,h);return rect;
        }
        private static void Stretch(RectTransform rect,float inset=0)
        {rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;rect.offsetMin=Vector2.one*inset;rect.offsetMax=-Vector2.one*inset;}
        private static Image Paint(RectTransform rect,Color color,bool hit=false)
        {var image=rect.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=hit;return image;}
        private static Text Label(Transform parent,string name,string value,float x,float y,float w,float h,int size=15,Color? color=null)
        {
            var text=Node(name,parent,x,y,w,h).gameObject.AddComponent<Text>();text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.text=value;text.fontSize=size;text.color=color??Ink;text.raycastTarget=false;text.supportRichText=false;text.alignment=TextAnchor.MiddleLeft;return text;
        }
        private static void Bind(GameObject root,string key,Component component)
        {var reference=root.GetComponent<LuaReference>();var all=new List<LuaReference.Entry>(reference.GetEditorBindings());all.Add(new LuaReference.Entry(key,component));reference.SetEditorBindings(all.ToArray());}
        private static Button Button(GameObject root,string key,Transform parent,string title,float x,float y,float w,float h)
        {
            var rect=Node(key,parent,x,y,w,h);var image=Paint(rect,new Color(.77f,.73f,.63f,.32f),true);var button=rect.gameObject.AddComponent<Button>();
            button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};
            var text=Label(rect,"Label",title,8,0,w-16,h,15);text.alignment=TextAnchor.MiddleCenter;
            Bind(root,key,button);Bind(root,key+"Text",text);return button;
        }
        private static ScrollRect Scroll(GameObject root,string key,Transform parent,float x,float y,float w,float h,bool layout)
        {
            var frame=Node(key+"Scroll",parent,x,y,w,h);Paint(frame,new Color(1,1,1,.015f),true);
            var viewport=Node("Viewport",frame,0,0,w,h);Stretch(viewport);viewport.gameObject.AddComponent<RectMask2D>();
            var content=Node(key,viewport,0,0,w,h);
            if(layout)
            {
                var group=content.gameObject.AddComponent<VerticalLayoutGroup>();group.spacing=6;group.padding=new RectOffset(4,4,4,4);
                group.childControlWidth=true;group.childControlHeight=false;group.childForceExpandWidth=true;group.childForceExpandHeight=false;
                content.gameObject.AddComponent<ContentSizeFitter>().verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            }
            var scroll=frame.gameObject.AddComponent<ScrollRect>();scroll.viewport=viewport;scroll.content=content;
            scroll.horizontal=!layout;scroll.vertical=true;scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=30;
            Bind(root,key,content);Bind(root,key+"Scroll",scroll);return scroll;
        }
        private static void BuildCategory(GameObject root)
        {
            var rect=(RectTransform)root.transform;rect.sizeDelta=new Vector2(180,54);var image=Paint(rect,Paper,true);
            var button=root.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};Bind(root,"Button",button);
            var title=Label(rect,"Title","",12,3,156,27,16);var detail=Label(rect,"Detail","",12,30,156,19,12,Muted);
            title.rectTransform.anchorMax=detail.rectTransform.anchorMax=new Vector2(1,1);
            title.rectTransform.sizeDelta=new Vector2(-24,27);detail.rectTransform.sizeDelta=new Vector2(-24,19);
            Bind(root,"Title",title);Bind(root,"Detail",detail);
        }
        private static void BuildNode(GameObject root)
        {
            var rect=(RectTransform)root.transform;rect.sizeDelta=new Vector2(146,108);Bind(root,"Border",Paint(rect,Gold,true));
            var bg=Paint(Node("Background",rect,2,2,142,104),Paper,true);Bind(root,"Background",bg);
            var button=root.AddComponent<Button>();button.targetGraphic=bg;button.navigation=new Navigation{mode=Navigation.Mode.None};Bind(root,"Button",button);
            var icon=Paint(Node("Icon",rect,49,9,48,48),Ink);icon.preserveAspect=true;Bind(root,"Icon",icon);
            var title=Label(rect,"Title","技能",4,62,138,23,16);title.alignment=TextAnchor.MiddleCenter;Bind(root,"Title",title);
            var state=Label(rect,"State","",4,86,138,17,11,Muted);state.alignment=TextAnchor.MiddleCenter;Bind(root,"State",state);
            Bind(root,"Group",root.GetComponent<CanvasGroup>());
        }
        private static void BuildEdge(GameObject root)
        {
            var rect=(RectTransform)root.transform;Bind(root,"Line",Paint(rect,Gold));Bind(root,"Group",root.GetComponent<CanvasGroup>());
            var arrow=Label(rect,"Arrow","▶",0,0,18,20,14,Gold);arrow.rectTransform.anchorMin=arrow.rectTransform.anchorMax=new Vector2(.68f,.5f);arrow.rectTransform.pivot=new Vector2(.5f,.5f);Bind(root,"Arrow",arrow);
        }
        private static void BuildPanel(GameObject root)
        {
            var veil=Node("Veil",root.transform,0,0,1280,720);Stretch(veil);Paint(veil,new Color(.07f,.10f,.09f,.88f),true);
            var page=Node("Page",root.transform,0,0,1200,664);page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.anchoredPosition=Vector2.zero;Paint(page,Paper,true);Bind(root,"Page",page);
            Bind(root,"Style",root.AddComponent<StoryGrowthView>());var geometry=root.AddComponent<SkillAtlasView>();Bind(root,"Geometry",geometry);
            Paint(Node("Rule",page,24,15,1152,2),Gold);
            Label(page,"Title","技 艺 图 谱",26,25,290,42,27);
            Label(page,"Subtitle","武艺与百工 · 自由研习，各有所长",26,66,450,22,13,Muted);
            Button(root,"Close",page,"关闭  Esc",1054,30,120,35);
            for(int i=1;i<=4;i++)Button(root,"Party"+i,page,"同行者",525+(i-1)*129,31,121,35);
            for(int i=1;i<=6;i++)Button(root,"Domain"+i,page,"领域",26+(i-1)*191,102,181,37);
            Paint(Node("Divider",page,218,159,1,451),new Color(.63f,.58f,.46f,.55f));
            Scroll(root,"Categories",page,22,168,188,438,true);
            Bind(root,"TreeTitle",Label(page,"TreeTitle","营造 / 筑障",239,154,450,30,18,Gold));
            var search=Node("Search",page,770,155,240,30);Paint(search,new Color(.98f,.95f,.87f),true);
            var input=search.gameObject.AddComponent<InputField>();var text=Label(search,"Text","",9,1,222,28,14);text.supportRichText=false;
            var placeholder=Label(search,"Placeholder","搜索全部技艺…",9,1,222,28,14,Muted);input.textComponent=text;input.placeholder=placeholder;input.lineType=InputField.LineType.SingleLine;input.characterLimit=60;Bind(root,"Search",input);
            Button(root,"SearchButton",page,"搜索",1018,155,70,30);Button(root,"ClearSearch",page,"清空",1096,155,76,30);
            var scroll=Scroll(root,"Graph",page,232,191,944,415,false);
            var dismiss=scroll.gameObject.AddComponent<Button>();dismiss.targetGraphic=scroll.GetComponent<Image>();dismiss.transition=Selectable.Transition.None;dismiss.navigation=new Navigation{mode=Navigation.Mode.None};Bind(root,"Dismiss",dismiss);
            var empty=Label(scroll.viewport,"Empty","此分类尚未收录技能",80,138,720,64,20,Muted);empty.alignment=TextAnchor.MiddleCenter;Bind(root,"Empty",empty);
            Label(page,"Legend","■ 已掌握 / 当前可用    □ 满足研习条件    ▧ 条件不足或特定途径",240,619,770,22,13,Muted);
            Label(page,"Hint","点击技能查看效果与前置 · 图谱用于浏览，不直接学习",26,645,1150,17,12,Muted);
            var popup=Node("Popup",page,0,0,316,464);Paint(popup,Gold,true);
            Paint(Node("Paper",popup,2,2,312,460),new Color(.98f,.95f,.86f),true);
            Bind(root,"TipTitle",Label(popup,"TipTitle","",18,12,236,30,20,Ink));Button(root,"TipClose",popup,"×",273,12,28,28);
            Bind(root,"TipPath",Label(popup,"TipPath","",18,43,280,22,12,Gold));
            var body=Scroll(root,"TipBody",popup,14,76,288,260,false);body.horizontal=false;
            var detail=Label(body.content,"TipDetail","",4,0,272,260,14);detail.alignment=TextAnchor.UpperLeft;Bind(root,"TipDetail",detail);
            Bind(root,"PrerequisiteTitle",Label(popup,"PrerequisiteTitle","",18,342,280,26,14,Gold));
            Scroll(root,"Prerequisites",popup,14,372,288,78,true);popup.gameObject.SetActive(false);
            geometry.Bind(page,scroll.viewport,popup,scroll);
            var results=Node("SearchResults",page,756,191,418,408);Paint(results,new Color(.97f,.93f,.83f),true);Bind(root,"SearchResults",results);
            Bind(root,"SearchSummary",Label(results,"SearchSummary","",15,9,388,27,15,Gold));Scroll(root,"Results",results,8,44,402,354,true);results.gameObject.SetActive(false);
        }
        private static void AddGrowthEntry()
        {
            var entry=PanelAssets.LoadOrCreate().Entries.Single(row=>row.Name=="CharacterGrowth");var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference=root.GetComponent<LuaReference>();var bindings=reference.GetEditorBindings();
                if(!bindings.Any(row=>row.Key=="Atlas"))
                {
                    var page=(RectTransform)bindings.Single(row=>row.Key=="Page").Target;
                    Button(root,"Atlas",page,"技艺图谱",914,27,118,32);
                    var style=root.GetComponent<StoryGrowthView>();
                    var serialized=new SerializedObject(style);var labels=serialized.FindProperty("labels");var texts=root.GetComponentsInChildren<Text>(true);
                    labels.arraySize=texts.Length;for(int i=0;i<texts.Length;i++)labels.GetArrayElementAtIndex(i).objectReferenceValue=texts[i];serialized.ApplyModifiedPropertiesWithoutUndo();
                }
                reference.ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
            }
            finally{PrefabUtility.UnloadPrefabContents(root);}
        }
    }
}
