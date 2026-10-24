using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Creates the editable campaign menu once; every controller component is explicitly bound.</summary>
    public static class CampaignMenuAssets
    {
        private static readonly Color Ink=new Color(.055f,.08f,.075f,.99f);
        private static readonly Color Paper=new Color(.91f,.9f,.82f);
        private static readonly Color Gold=new Color(.88f,.75f,.50f);
        private static readonly Color Muted=new Color(.60f,.70f,.65f);

        [MenuItem("Project Y/远征/创建开始菜单")]
        public static void Create()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("开始菜单创建需要 Edit Mode。");
            NarrativeAssets.Create(); // Existing narrative prefabs are preserved by this tool.
            LuaViewHints.Register(typeof(NarrativeView),"CS.ProjectY.UI.NarrativeView");
            var config=PanelAssets.LoadOrCreate();var entry=config.Entries.Find(value=>value.Name=="StartMenu");
            if(entry==null)entry=PanelAssets.Save(new PanelDefinition {
                Name="StartMenu",Module="Adventure",Kind=UIKind.Panel,Layer="Popup",Modal=true,
                ModalDimAlpha=.82f,Cache=true,CloseOnBack=false,PauseWorldOnOpen=true},null);
            if(entry.Prefab!=null){Debug.Log("开始菜单已存在，保留手工布局。");return;}
            Directory.CreateDirectory(Path.GetDirectoryName(entry.PrefabPath));
            var root=new GameObject(entry.PrefabName,typeof(RectTransform),typeof(LuaReference),typeof(LuaPanel));
            try
            {
                Build(root);root.GetComponent<LuaReference>().ValidateBindings();
                entry.Prefab=PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);EditorUtility.SetDirty(config);
                LuaViewHints.Export(root.GetComponent<LuaReference>(),entry.ViewType);
                AssetDatabase.SaveAssets();Debug.Log("开始菜单、显式绑定与Panel注册已保存。");
            }
            finally {UnityEngine.Object.DestroyImmediate(root);}
        }

        private static RectTransform Node(string name,Transform parent)
        {var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.SetParent(parent,false);return rect;}
        private static void Place(RectTransform rect,float x,float y,float width,float height)
        {rect.anchorMin=rect.anchorMax=new Vector2(0,1);rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(width,height);}
        private static void Stretch(RectTransform rect,float left=0,float bottom=0,float right=0,float top=0)
        {rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;rect.offsetMin=new Vector2(left,bottom);rect.offsetMax=new Vector2(-right,-top);}
        private static Image Paint(RectTransform rect,Color color,bool raycast=true)
        {var image=rect.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=raycast;return image;}
        private static Text Label(string name,Transform parent,string value,int size,Color color)
        {
            var text=Node(name,parent).gameObject.AddComponent<Text>();text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.text=value;text.fontSize=size;text.color=color;text.raycastTarget=false;text.supportRichText=false;
            text.horizontalOverflow=HorizontalWrapMode.Wrap;text.verticalOverflow=VerticalWrapMode.Truncate;return text;
        }
        private static void Bind(GameObject root,string key,Component value)
        {
            var reference=root.GetComponent<LuaReference>();var bindings=new List<LuaReference.Entry>(reference.GetEditorBindings());
            bindings.Add(new LuaReference.Entry(key,value));reference.SetEditorBindings(bindings.ToArray());
        }
        private static Button MakeButton(string name,Transform parent,string label,float x,float y,float width,float height,bool primary=false)
        {
            var rect=Node(name,parent);Place(rect,x,y,width,height);
            var image=Paint(rect,primary?new Color(.26f,.36f,.28f):new Color(.12f,.19f,.16f));
            var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=image;
            button.navigation=new Navigation {mode=Navigation.Mode.None};
            var colors=button.colors;colors.highlightedColor=new Color(1.15f,1.15f,1.05f);colors.pressedColor=new Color(.75f,.84f,.75f);colors.disabledColor=new Color(.45f,.45f,.45f,.65f);button.colors=colors;
            var text=Label("Label",rect,label,primary?21:18,primary?Gold:Paper);Stretch(text.rectTransform,12,3,12,3);text.alignment=TextAnchor.MiddleCenter;
            return button;
        }
        private static InputField SeedField(Transform parent)
        {
            var rect=Node("Seed",parent);Place(rect,0,34,560,48);var background=Paint(rect,new Color(.035f,.055f,.045f));
            var text=Label("Text",rect,"",21,Paper);Stretch(text.rectTransform,14,4,14,4);text.alignment=TextAnchor.MiddleLeft;
            var placeholder=Label("Placeholder",rect,"0–4294967295",18,Muted);Stretch(placeholder.rectTransform,14,4,14,4);placeholder.alignment=TextAnchor.MiddleLeft;
            var field=rect.gameObject.AddComponent<InputField>();field.targetGraphic=background;field.textComponent=text;field.placeholder=placeholder;
            field.contentType=InputField.ContentType.IntegerNumber;field.lineType=InputField.LineType.SingleLine;field.characterLimit=10;
            field.navigation=new Navigation {mode=Navigation.Mode.None};return field;
        }
        private static Dropdown SizeField(Transform parent)
        {
            var rect=Node("WorldSize",parent);Place(rect,0,180,748,46);var image=Paint(rect,new Color(.105f,.17f,.135f));
            var caption=Label("Caption",rect,"",18,Paper);Stretch(caption.rectTransform,14,3,44,3);caption.alignment=TextAnchor.MiddleLeft;
            var arrow=Label("Arrow",rect,"▾",22,Gold);Place(arrow.rectTransform,707,7,28,30);arrow.alignment=TextAnchor.MiddleCenter;
            var template=Node("Template",rect);template.anchorMin=new Vector2(0,0);template.anchorMax=new Vector2(1,0);template.pivot=new Vector2(.5f,1);
            template.anchoredPosition=new Vector2(0,-3);template.sizeDelta=new Vector2(0,154);Paint(template,new Color(.08f,.13f,.105f));
            var viewport=Node("Viewport",template);Stretch(viewport,3,3,3,3);viewport.gameObject.AddComponent<RectMask2D>();
            var content=Node("Content",viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=new Vector2(0,36);
            var item=Node("Item",content);item.anchorMin=new Vector2(0,1);item.anchorMax=Vector2.one;item.pivot=new Vector2(.5f,1);item.sizeDelta=new Vector2(0,36);
            var itemImage=Paint(item,new Color(.15f,.23f,.18f));var toggle=item.gameObject.AddComponent<Toggle>();toggle.targetGraphic=itemImage;
            var check=Node("Checkmark",item);Place(check,8,12,12,12);toggle.graphic=Paint(check,Gold,false);
            var itemLabel=Label("Label",item,"",17,Paper);Stretch(itemLabel.rectTransform,30,3,12,3);itemLabel.alignment=TextAnchor.MiddleLeft;
            var scroller=template.gameObject.AddComponent<ScrollRect>();scroller.viewport=viewport;scroller.content=content;scroller.horizontal=false;scroller.vertical=true;scroller.movementType=ScrollRect.MovementType.Clamped;
            var dropdown=rect.gameObject.AddComponent<Dropdown>();dropdown.targetGraphic=image;dropdown.captionText=caption;dropdown.itemText=itemLabel;dropdown.template=template;
            dropdown.navigation=new Navigation {mode=Navigation.Mode.None};dropdown.options=new List<Dropdown.OptionData> {
                new Dropdown.OptionData("小型 · 2,500 格"),new Dropdown.OptionData("标准 · 10,000 格"),
                new Dropdown.OptionData("大型 · 30,000 格"),new Dropdown.OptionData("超大型 · 100,000 格")};
            dropdown.value=1;dropdown.RefreshShownValue();template.gameObject.SetActive(false);return dropdown;
        }
        private static void Build(GameObject root)
        {
            var rect=(RectTransform)root.transform;Stretch(rect);Bind(root,"Root",rect);
            var page=Node("Page",rect);page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.sizeDelta=new Vector2(820,640);Paint(page,Ink);
            var title=Label("Title",page,"远征",32,Gold);Place(title.rectTransform,36,26,748,46);Bind(root,"Title",title);
            var caption=Label("Caption",page,"选择一段旅程",15,Muted);Place(caption.rectTransform,36,82,748,34);Bind(root,"Caption",caption);
            var rule=Node("Rule",page);Place(rule,36,123,748,1);Paint(rule,new Color(.50f,.47f,.31f,.5f),false);
            var home=Node("HomePage",page);Place(home,36,142,748,370);Bind(root,"HomePage",home);
            Bind(root,"Start",MakeButton("Start",home,"开始游戏",164,55,420,64,true));
            Bind(root,"Load",MakeButton("Load",home,"加载游戏",164,145,420,64));
            var homeHint=Label("HomeHint",home,"每次新游戏创建独立存档\nF5 保存当前旅程",15,Muted);Place(homeHint.rectTransform,100,244,548,52);homeHint.alignment=TextAnchor.MiddleCenter;
            var fresh=Node("NewPage",page);Place(fresh,36,142,748,370);Bind(root,"NewPage",fresh);
            var seedLabel=Label("SeedLabel",fresh,"世界种子",16,Gold);Place(seedLabel.rectTransform,0,0,748,26);
            Bind(root,"Seed",SeedField(fresh));Bind(root,"RandomSeed",MakeButton("RandomSeed",fresh,"随机种子",578,34,170,48));
            var seedHint=Label("SeedHint",fresh,"输入 0–4294967295 的整数；相同种子和规模可重现世界布局。",14,Muted);Place(seedHint.rectTransform,0,94,748,42);
            var sizeLabel=Label("SizeLabel",fresh,"地图规模",16,Gold);Place(sizeLabel.rectTransform,0,148,748,26);
            Bind(root,"Size",SizeField(fresh));
            var sizeHint=Label("SizeHint",fresh,"较大的世界需要更长的生成与保存时间。",14,Muted);Place(sizeHint.rectTransform,0,237,748,34);
            Bind(root,"Create",MakeButton("Create",fresh,"创建世界并开始",214,292,320,54,true));fresh.gameObject.SetActive(false);
            var load=Node("LoadPage",page);Place(load,36,142,748,370);Bind(root,"LoadPage",load);
            var scrollRect=Node("SaveScroll",load);Stretch(scrollRect);Paint(scrollRect,new Color(0,0,0,.12f));
            var viewport=Node("Viewport",scrollRect);Stretch(viewport);viewport.gameObject.AddComponent<RectMask2D>();
            var content=Node("Content",viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=Vector2.zero;
            var layout=content.gameObject.AddComponent<VerticalLayoutGroup>();layout.padding=new RectOffset(4,4,4,8);layout.spacing=10;
            layout.childControlWidth=true;layout.childControlHeight=true;layout.childForceExpandWidth=true;layout.childForceExpandHeight=false;
            content.gameObject.AddComponent<ContentSizeFitter>().verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            var scroll=scrollRect.gameObject.AddComponent<ScrollRect>();scroll.viewport=viewport;scroll.content=content;scroll.horizontal=false;scroll.vertical=true;scroll.scrollSensitivity=30;scroll.movementType=ScrollRect.MovementType.Clamped;
            Bind(root,"SaveContent",content);Bind(root,"SaveScroll",scroll);
            var empty=Label("Empty",load,"还没有存档\n从“开始游戏”创建第一段旅程",19,Muted);Stretch(empty.rectTransform,30,80,30,80);empty.alignment=TextAnchor.MiddleCenter;Bind(root,"Empty",empty);
            load.gameObject.SetActive(false);
            var hint=Label("Hint",page,"",14,new Color(.93f,.65f,.48f));Place(hint.rectTransform,36,527,748,42);Bind(root,"Hint",hint);
            Bind(root,"Back",MakeButton("Back",page,"返回首页",36,582,140,40));
            Bind(root,"Resume",MakeButton("Resume",page,"返回游戏",628,582,156,40));
            var style=root.AddComponent<NarrativeView>();style.SetEditorBindings(page,scroll,root.GetComponentsInChildren<Text>(true),false);Bind(root,"Style",style);
        }
    }
}
