using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>经 Unity MCP 调用，创建可编辑 Prefab 和显式 LuaReference 绑定。</summary>
    public static class NarrativeAssets
    {
        private static readonly Color Ink=new Color(.06f,.085f,.075f,.97f),Paper=new Color(.91f,.88f,.80f),Gold=new Color(.83f,.71f,.48f);
        [MenuItem("Project Y/叙事/创建对话与任务 UI")]
        public static void Create()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Narrative UI requires Edit Mode.");
            LuaViewHints.Register(typeof(NarrativeView),"CS.ProjectY.UI.NarrativeView");
            Entry("NarrativeEntry",true,false);Entry("Dialogue",false,true);Entry("MissionJournal",false,false);
            AssetDatabase.SaveAssets();Debug.Log("Narrative prefabs, registry and LuaReference bindings saved.");
        }
        [MenuItem("Project Y/商店/同步商店界面")]
        public static void CreateShop()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Shop UI requires Edit Mode.");
            Entry("Shop",false,false,"Shop");AssetDatabase.SaveAssets();
        }
        private static void Entry(string name,bool widget,bool right,string module="Narrative")
        {
            var config=PanelAssets.LoadOrCreate();var entry=config.Entries.Find(e=>e.Name==name);
            if(entry==null)entry=PanelAssets.Save(new PanelDefinition{Name=name,Module=module,Kind=widget?UIKind.Widget:UIKind.Panel,
                Layer="Popup",Modal=!widget,ModalDimAlpha=right?0:.65f,Cache=true,CloseOnBack=true,PauseWorldOnOpen=!widget},null);
            if(entry.Prefab!=null)return; // 已存在的手工资源不重建。
            Directory.CreateDirectory(Path.GetDirectoryName(entry.PrefabPath));
            var root=new GameObject(entry.PrefabName,typeof(RectTransform),typeof(LuaReference));
            try
            {
                Bind(root,"Root",root.transform);
                if(widget)BuildRow(root);else{root.AddComponent<LuaPanel>();BuildPanel(root,right);}
                root.GetComponent<LuaReference>().ValidateBindings();
                entry.Prefab=PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);EditorUtility.SetDirty(config);
                LuaViewHints.Export(root.GetComponent<LuaReference>(),entry.ViewType);
            }
            finally{UnityEngine.Object.DestroyImmediate(root);}
        }
        private static void Bind(GameObject root,string key,Component value)
        {var reference=root.GetComponent<LuaReference>();var entries=new List<LuaReference.Entry>(reference.GetEditorBindings()){new LuaReference.Entry(key,value)};reference.SetEditorBindings(entries.ToArray());}
        private static RectTransform Node(string name,Transform parent)
        {var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);return r;}
        private static void Stretch(RectTransform r,float left=0,float bottom=0,float right=0,float top=0)
        {r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=new Vector2(left,bottom);r.offsetMax=new Vector2(-right,-top);}
        private static Image Paint(RectTransform r,Color color,bool raycast=true)
        {var image=r.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=raycast;return image;}
        private static Text Label(string name,Transform parent,int size,Color color)
        {
            var r=Node(name,parent);var text=r.gameObject.AddComponent<Text>();text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.fontSize=size;text.color=color;text.raycastTarget=false;text.supportRichText=false;text.horizontalOverflow=HorizontalWrapMode.Wrap;text.verticalOverflow=VerticalWrapMode.Overflow;
            return text;
        }
        private static void BuildRow(GameObject root)
        {
            var rect=(RectTransform)root.transform;rect.sizeDelta=new Vector2(390,100);
            var background=Paint(rect,new Color(.15f,.22f,.18f));var button=root.AddComponent<Button>();button.targetGraphic=background;button.navigation=new Navigation{mode=Navigation.Mode.None};
            var layout=root.AddComponent<VerticalLayoutGroup>();layout.padding=new RectOffset(14,14,12,12);layout.spacing=7;
            layout.childControlWidth=true;layout.childControlHeight=true;layout.childForceExpandWidth=true;layout.childForceExpandHeight=false;
            var title=Label("Title",rect,17,Gold);var body=Label("Body",rect,16,Paper);
            Bind(root,"Title",title);Bind(root,"Body",body);Bind(root,"Button",button);Bind(root,"Background",background);
        }
        private static void BuildPanel(GameObject root,bool right)
        {
            var page=Node("Page",root.transform);
            if(right){page.anchorMin=new Vector2(1,0);page.anchorMax=Vector2.one;page.pivot=new Vector2(1,.5f);page.sizeDelta=new Vector2(440,0);page.anchoredPosition=Vector2.zero;}
            else{page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.sizeDelta=new Vector2(900,670);}
            Paint(page,Ink);
            var title=Label("Title",page,25,Gold);title.rectTransform.anchorMin=new Vector2(0,1);title.rectTransform.anchorMax=Vector2.one;title.rectTransform.pivot=new Vector2(.5f,1);title.rectTransform.sizeDelta=new Vector2(-104,36);title.rectTransform.anchoredPosition=new Vector2(-28,-23);
            var caption=Label("Caption",page,13,new Color(.61f,.69f,.61f));caption.rectTransform.anchorMin=new Vector2(0,1);caption.rectTransform.anchorMax=Vector2.one;caption.rectTransform.pivot=new Vector2(.5f,1);caption.rectTransform.sizeDelta=new Vector2(-48,28);caption.rectTransform.anchoredPosition=new Vector2(0,-64);
            var closeRect=Node("Close",page);closeRect.anchorMin=closeRect.anchorMax=new Vector2(1,1);closeRect.pivot=Vector2.one;closeRect.anchoredPosition=new Vector2(-17,-22);closeRect.sizeDelta=new Vector2(48,32);
            var image=Paint(closeRect,new Color(.19f,.25f,.20f));var close=closeRect.gameObject.AddComponent<Button>();close.targetGraphic=image;
            var closeText=Label("Label",closeRect,16,Paper);Stretch(closeText.rectTransform);closeText.text="关闭";closeText.alignment=TextAnchor.MiddleCenter;
            var scrollRect=Node("Scroll",page);Stretch(scrollRect,14,52,14,104);Paint(scrollRect,new Color(0,0,0,.08f));
            var viewport=Node("Viewport",scrollRect);Stretch(viewport);viewport.gameObject.AddComponent<RectMask2D>();
            var content=Node("Content",viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=Vector2.zero;
            var layout=content.gameObject.AddComponent<VerticalLayoutGroup>();layout.spacing=12;layout.padding=new RectOffset(6,6,8,12);layout.childControlHeight=true;layout.childControlWidth=true;layout.childForceExpandHeight=false;
            content.gameObject.AddComponent<ContentSizeFitter>().verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            var scroll=scrollRect.gameObject.AddComponent<ScrollRect>();scroll.viewport=viewport;scroll.content=content;scroll.horizontal=false;scroll.vertical=true;scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=28;
            var hint=Label("Hint",page,12,new Color(.75f,.60f,.44f));hint.rectTransform.anchorMin=Vector2.zero;hint.rectTransform.anchorMax=new Vector2(1,0);hint.rectTransform.pivot=new Vector2(.5f,0);hint.rectTransform.sizeDelta=new Vector2(-48,34);hint.rectTransform.anchoredPosition=new Vector2(0,10);
            var style=root.AddComponent<NarrativeView>();style.SetEditorBindings(page,scroll,root.GetComponentsInChildren<Text>(true),right);
            Bind(root,"Title",title);Bind(root,"Caption",caption);Bind(root,"Close",close);Bind(root,"Content",content);Bind(root,"Scroll",scroll);Bind(root,"Hint",hint);Bind(root,"Style",style);
        }
    }
}
