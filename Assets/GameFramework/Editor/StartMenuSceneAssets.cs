using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    public static class StartMenuSceneAssets
    {
        public const string Root="Assets/DynamicAsset/MainMenu";
        private static readonly Color Gold=new Color(.88f,.75f,.50f),Paper=new Color(.92f,.87f,.75f),Ink=new Color(.12f,.17f,.135f,.97f);
        private static List<LuaReference.Entry> bindings;
        private static List<LuaReference.LocalizedText> texts;
        private static RectTransform Node(string name,Transform parent){var t=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;t.SetParent(parent,false);return t;}
        private static void Place(RectTransform t,float x,float y,float w,float h){t.anchorMin=t.anchorMax=t.pivot=new Vector2(0,1);t.anchoredPosition=new Vector2(x,-y);t.sizeDelta=new Vector2(w,h);t.localScale=Vector3.one;}
        private static void Fill(RectTransform t){t.anchorMin=Vector2.zero;t.anchorMax=Vector2.one;t.pivot=new Vector2(.5f,.5f);t.offsetMin=t.offsetMax=Vector2.zero;t.localScale=Vector3.one;}
        private static Image Paint(RectTransform r,Color color,bool raycast=false){var image=r.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=raycast;return image;}
        private static void Bind(string key,Component value){bindings.RemoveAll(x=>x.Key==key);bindings.Add(new LuaReference.Entry(key,value));}
        private static T Ref<T>(string key) where T:Component=> (T)bindings.Single(x=>x.Key==key).Target;
        private static Text Label(string name,Transform parent,string key,int size=18,TextAnchor alignment=TextAnchor.MiddleLeft)
        {
            var text=Node(name,parent).gameObject.AddComponent<Text>();text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");text.fontSize=size;text.color=Paper;text.alignment=alignment;text.raycastTarget=false;text.supportRichText=false;text.horizontalOverflow=HorizontalWrapMode.Wrap;text.verticalOverflow=VerticalWrapMode.Truncate;
            if(!string.IsNullOrEmpty(key)){text.text=LuaLanguage.Get(key);texts.Add(new LuaReference.LocalizedText(text,key));}return text;
        }
        private static void Localize(Text text,string key){texts.RemoveAll(x=>x.Target==text);text.text=LuaLanguage.Get(key);texts.Add(new LuaReference.LocalizedText(text,key));}
        private static Button Button(string name,Transform parent,string key,float x,float y,float w,float h,bool primary=false)
        {
            var t=Node(name,parent);Place(t,x,y,w,h);var image=Paint(t,primary?new Color(.75f,.63f,.40f):new Color(.22f,.28f,.23f),true);var b=t.gameObject.AddComponent<Button>();b.targetGraphic=image;b.navigation=new Navigation{mode=Navigation.Mode.Automatic};
            var text=Label("Label",t,key,19,TextAnchor.MiddleCenter);Fill(text.rectTransform);text.color=primary?new Color(.12f,.17f,.12f):Paper;Bind(name,b);Bind(name+"Text",text);return b;
        }
        private static Material Material(string name,string color,string shader="Universal Render Pipeline/Lit")
        {
            string path=Root+"/Materials/"+name+".mat";var m=AssetDatabase.LoadAssetAtPath<Material>(path);
            if(m==null){var found=Shader.Find(shader);if(found==null)throw new InvalidOperationException("Missing shader "+shader);m=new Material(found);ColorUtility.TryParseHtmlString(color,out var c);m.SetColor("_BaseColor",c);if(m.HasProperty("_Smoothness"))m.SetFloat("_Smoothness",0);AssetDatabase.CreateAsset(m,path);}return m;
        }
        private static GameObject Cube(Transform parent,string name,Vector3 p,Vector3 scale,Material material)
        {var g=GameObject.CreatePrimitive(PrimitiveType.Cube);g.name=name;g.transform.SetParent(parent,false);g.transform.localPosition=p;g.transform.localScale=scale;Object.DestroyImmediate(g.GetComponent<Collider>());g.GetComponent<Renderer>().sharedMaterial=material;return g;}
        private static GameObject Model(Transform parent,string path,Vector3 p,float scale=1)
        {var source=AssetDatabase.LoadAssetAtPath<GameObject>(path);if(source==null)throw new InvalidOperationException("Missing model: "+path);var g=(GameObject)PrefabUtility.InstantiatePrefab(source);g.transform.SetParent(parent,false);g.transform.localPosition=p;g.transform.localScale=Vector3.one*scale;return g;}
        private static StartMenuStage BuildStage()
        {
            var root=new GameObject("MainMenuStage");
            try
            {
                var stage=root.AddComponent<StartMenuStage>();var wood=Material("Menu_Wood","#69523a");var rim=Material("Menu_Rim","#8b704b");var ground=Material("Menu_Ground","#92967a");
                var importer=(ModelImporter)AssetImporter.GetAtPath(Root+"/Models/Signpost_Menu.fbx");if(importer==null)throw new InvalidOperationException("Menu sign FBX is not imported.");
                importer.bakeAxisConversion=true;importer.importAnimation=false;importer.isReadable=false;importer.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;
                var palette=new Dictionary<string,string>{{"Menu_Wood","#69523a"},{"Menu_Plank","#8b6a43"},{"Menu_Edge","#463b2d"},{"Menu_Iron","#333c35"},{"Menu_Rope","#b29c6e"}};
                foreach(var item in palette)importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material),item.Key),Material(item.Key,item.Value));importer.SaveAndReimport();
                var post=Model(root.transform,Root+"/Models/Signpost_Menu.fbx",new Vector3(4.25f,-.18f,1.6f));
                var anchors=new Transform[5];float[] ys={4.55f,3.72f,2.9f,2.1f,1.34f},xs={.3f,-.1f,.21f,.17f,-.08f},angles={-.045f,.065f,-.065f,.035f,.07f};
                for(int i=0;i<5;i++){anchors[i]=new GameObject("SignAnchor"+i).transform;anchors[i].SetParent(post.transform,false);anchors[i].localPosition=new Vector3(xs[i],ys[i],.34f);anchors[i].localRotation=Quaternion.Euler(0,0,angles[i]*Mathf.Rad2Deg);}
                Cube(root.transform,"Ground",new Vector3(4,-.55f,0),new Vector3(90,.3f,90),ground);
                var table=new GameObject("MapTable").transform;table.SetParent(root.transform,false);table.localPosition=new Vector3(-2.3f,.3f,-.5f);table.localRotation=Quaternion.Euler(0,-8,0);
                Cube(table,"Plinth",Vector3.zero,new Vector3(8.65f,.32f,6.1f),wood);Cube(table,"Rim",new Vector3(0,.2f,0),new Vector3(8.42f,.1f,5.86f),rim);
                foreach(float x in new[]{-3.5f,3.5f})foreach(float z in new[]{-2.2f,2.2f})Cube(table,"Leg",new Vector3(x,-.42f,z),new Vector3(.28f,.8f,.28f),wood);
                var map=new GameObject("MapRoot").transform;map.SetParent(table,false);map.localPosition=new Vector3(0,.28f,0);
                const string models="Assets/DynamicAsset/MapLowPoly/Models/";
                var tree=AssetDatabase.LoadAssetAtPath<GameObject>(models+"Tree_Conifer.fbx");var house=AssetDatabase.LoadAssetAtPath<GameObject>(models+"Building_House.fbx");var castle=AssetDatabase.LoadAssetAtPath<GameObject>(models+"Building_Castle.fbx");
                if(tree==null||house==null||castle==null)throw new InvalidOperationException("Map landmark models are missing.");
                for(int i=0;i<25;i++)Model(root.transform,models+"Tree_Conifer.fbx",new Vector3(-22+i*1.9f,-.4f,-14-Mathf.Sin(i*2.7f)*4),1.1f+Mathf.Abs(Mathf.Sin(i))*.935f);
                var cameraObject=new GameObject("MenuCamera");cameraObject.transform.SetParent(root.transform,false);var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.63f,.68f,.59f);camera.nearClipPlane=.1f;camera.farClipPlane=120;camera.allowHDR=false;
                var miniObject=new GameObject("MapCamera");miniObject.transform.SetParent(table,false);miniObject.transform.localPosition=new Vector3(0,7,9);miniObject.transform.LookAt(table.TransformPoint(new Vector3(0,.45f,0)));var mini=miniObject.AddComponent<Camera>();mini.enabled=false;mini.clearFlags=CameraClearFlags.SolidColor;mini.backgroundColor=new Color(.15f,.23f,.20f);mini.orthographic=true;mini.orthographicSize=3.5f;mini.aspect=16f/9;mini.nearClipPlane=.1f;mini.farClipPlane=80;mini.allowHDR=false;
                var lightObject=new GameObject("MenuSun");lightObject.transform.SetParent(root.transform,false);lightObject.transform.localRotation=Quaternion.Euler(48,-35,0);var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.color=new Color(1,.89f,.70f);light.intensity=1.2f;light.shadows=LightShadows.Soft;light.cullingMask=1<<30;
                foreach(var node in root.GetComponentsInChildren<Transform>(true))node.gameObject.layer=30;
                stage.Bind(camera,mini,post.transform,map,anchors,tree,house,castle,Material("Menu_Terrain","#ffffff","ProjectY/MenuTerrain"));stage.Pose(0,0,16f/9);
                return PrefabUtility.SaveAsPrefabAsset(root,Root+"/MainMenuStage.prefab").GetComponent<StartMenuStage>();
            }
            finally{Object.DestroyImmediate(root);}
        }
        private static void BuildSaveEntry(PanelConfig config)
        {
            if(config.Entries.Any(x=>x.Name=="CampaignSaveEntry"))return;
            var entry=new PanelDefinition{Name="CampaignSaveEntry",Module="Adventure",Kind=UIKind.Widget};
            var source=config.Get("NarrativeEntry");var root=PrefabUtility.LoadPrefabContents(source.PrefabPath);
            try
            {
                root.name=entry.PrefabName;var reference=root.GetComponent<LuaReference>();bindings=new List<LuaReference.Entry>(reference.GetEditorBindings());texts=new List<LuaReference.LocalizedText>(reference.GetEditorLocalizations());
                var layout=Ref<VerticalLayoutGroup>("Layout");layout.padding.right=100;Ref<LayoutElement>("Sizing").minHeight=110;
                var b=Button("Delete",root.transform,"MenuDelete",0,0,76,32);var rect=(RectTransform)b.transform;rect.anchorMin=rect.anchorMax=new Vector2(1,1);rect.pivot=new Vector2(1,1);rect.anchoredPosition=new Vector2(-12,-12);b.gameObject.AddComponent<LayoutElement>().ignoreLayout=true;
                b.GetComponent<Image>().color=new Color(.32f,.23f,.18f);reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(texts.ToArray());reference.ValidateBindings();
                entry.Prefab=PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);config.Entries.Add(entry);LuaViewHints.Export(reference,entry.ViewType);
            }
            finally{PrefabUtility.UnloadPrefabContents(root);}
        }
        private static Slider Slider(string name,Transform parent,string key,float y)
        {
            var label=Label(name+"Label",parent,key,17);Place(label.rectTransform,0,y,460,25);
            var t=Node(name,parent);Place(t,0,y+32,460,20);Paint(t,new Color(.08f,.12f,.09f),true);var fill=Node("Fill",t);Fill(fill);var fillImage=Paint(fill,Gold);
            var handle=Node("Handle",t);handle.sizeDelta=new Vector2(16,28);var image=Paint(handle,Paper,true);var slider=t.gameObject.AddComponent<Slider>();slider.fillRect=fill;slider.handleRect=handle;slider.targetGraphic=image;slider.minValue=0;slider.maxValue=1;Bind(name,slider);return slider;
        }
        [MenuItem("Project Y/远征/安装场景式开始菜单")]
        public static void Install()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode||EditorApplication.isCompiling)throw new InvalidOperationException("Menu installation requires idle Edit Mode.");
            Directory.CreateDirectory(Root+"/Materials");var config=AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);var entry=config.Get("StartMenu");
            if(entry.Prefab.GetComponent<StartMenuView>()!=null)throw new InvalidOperationException("Scene menu is already installed; edit its saved prefab instead of resetting it.");
            Directory.CreateDirectory("Art/MainMenu/Original");if(!File.Exists("Art/MainMenu/Original/StartMenuPanel.prefab"))File.Copy(entry.PrefabPath,"Art/MainMenu/Original/StartMenuPanel.prefab",false);
            var stage=BuildStage();BuildSaveEntry(config);var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference=root.GetComponent<LuaReference>();bindings=new List<LuaReference.Entry>(reference.GetEditorBindings());texts=new List<LuaReference.LocalizedText>(reference.GetEditorLocalizations());
                var oldStyle=Ref<NarrativeView>("Style");var page=(RectTransform)Ref<Text>("Title").transform.parent;Fill(page);page.GetComponent<Image>().color=new Color(Ink.r,Ink.g,Ink.b,.94f);var frame=page.gameObject.AddComponent<CanvasGroup>();
                var home=Ref<RectTransform>("HomePage");home.SetParent(root.transform,false);Fill(home);var homeGroup=home.gameObject.AddComponent<CanvasGroup>();home.Find("HomeHint").gameObject.SetActive(false);
                var image=Node("Scene",root.transform).gameObject.AddComponent<RawImage>();Fill(image.rectTransform);image.raycastTarget=true;image.transform.SetAsFirstSibling();
                var brand=Label("Brand",home,"MenuBrand",42);Place(brand.rectTransform,48,35,460,56);brand.color=Gold;
                var strap=Label("Strapline",home,"MenuStrapline",17);Place(strap.rectTransform,50,94,510,30);
                var previewTitle=Label("PreviewTitle",home,"MenuUnnamedWorld",28,TextAnchor.MiddleRight);previewTitle.rectTransform.anchorMin=previewTitle.rectTransform.anchorMax=new Vector2(1,0);previewTitle.rectTransform.pivot=Vector2.one;previewTitle.rectTransform.anchoredPosition=new Vector2(-64,83);previewTitle.rectTransform.sizeDelta=new Vector2(650,48);
                var previewCaption=Label("PreviewCaption",home,"MenuDefaultPreview",15,TextAnchor.MiddleRight);previewCaption.rectTransform.anchorMin=previewCaption.rectTransform.anchorMax=new Vector2(1,0);previewCaption.rectTransform.pivot=Vector2.one;previewCaption.rectTransform.anchoredPosition=new Vector2(-64,49);previewCaption.rectTransform.sizeDelta=new Vector2(850,28);
                var signs=new List<RectTransform>();
                foreach(var pair in new[]{new[]{"Start","MenuStart"},new[]{"Load","MenuLoad"},new[]{"Settings","MenuSettings"},new[]{"About","MenuAbout"},new[]{"Quit","MenuQuit"}})
                {
                    Button b;if(pair[0]=="Start"||pair[0]=="Load"){b=Ref<Button>(pair[0]);Localize(b.GetComponentInChildren<Text>(true),pair[1]);}else b=Button(pair[0],home,pair[1],0,0,250,50);
                    b.transform.SetParent(home,false);var text=b.GetComponentInChildren<Text>(true);text.fontSize=29;text.color=new Color(.96f,.85f,.63f);b.targetGraphic=text;b.GetComponent<Image>().color=Color.clear;
                    var c=b.colors;c.normalColor=Color.white;c.highlightedColor=new Color(1.2f,1.1f,.78f);c.selectedColor=c.highlightedColor;c.pressedColor=new Color(.8f,.72f,.5f);b.colors=c;
                    var shadow=text.gameObject.GetComponent<Shadow>()??text.gameObject.AddComponent<Shadow>();shadow.effectColor=new Color(.1f,.08f,.04f,.8f);shadow.effectDistance=new Vector2(1,-2);signs.Add((RectTransform)b.transform);
                }
                var fresh=Ref<RectTransform>("NewPage");var load=Ref<RectTransform>("LoadPage");
                foreach(var t in new[]{fresh,load}){t.anchorMin=t.anchorMax=new Vector2(.5f,.5f);t.pivot=new Vector2(.5f,.5f);t.anchoredPosition=new Vector2(0,-40);t.sizeDelta=new Vector2(1100,500);t.localScale=Vector3.one;}
                var freshGroup=fresh.gameObject.AddComponent<CanvasGroup>();var loadGroup=load.gameObject.AddComponent<CanvasGroup>();
                var title=Ref<Text>("Title");title.alignment=TextAnchor.MiddleCenter;title.rectTransform.anchorMin=title.rectTransform.anchorMax=new Vector2(.5f,1);title.rectTransform.pivot=new Vector2(.5f,1);title.rectTransform.anchoredPosition=new Vector2(0,-35);title.rectTransform.sizeDelta=new Vector2(900,48);
                var caption=Ref<Text>("Caption");caption.alignment=TextAnchor.MiddleCenter;caption.rectTransform.anchorMin=caption.rectTransform.anchorMax=new Vector2(.5f,1);caption.rectTransform.pivot=new Vector2(.5f,1);caption.rectTransform.anchoredPosition=new Vector2(0,-86);caption.rectTransform.sizeDelta=new Vector2(1000,30);
                Place((RectTransform)Ref<Button>("Back").transform,36,30,165,42);Localize(Ref<Button>("Back").GetComponentInChildren<Text>(true),"MenuBack");
                var resume=Ref<Button>("Resume");resume.transform.SetParent(root.transform,false);var resumeRect=(RectTransform)resume.transform;resumeRect.anchorMin=resumeRect.anchorMax=new Vector2(0,0);resumeRect.pivot=Vector2.zero;resumeRect.anchoredPosition=new Vector2(38,22);resumeRect.sizeDelta=new Vector2(175,42);resume.transform.SetAsLastSibling();
                var hint=Ref<Text>("Hint");hint.transform.SetParent(root.transform,false);hint.rectTransform.anchorMin=hint.rectTransform.anchorMax=new Vector2(.5f,0);hint.rectTransform.pivot=new Vector2(.5f,0);hint.rectTransform.anchoredPosition=new Vector2(0,15);hint.rectTransform.sizeDelta=new Vector2(800,38);hint.alignment=TextAnchor.MiddleCenter;
                var worldName=Ref<InputField>("WorldName");worldName.characterLimit=32;Place(worldName.GetComponent<RectTransform>(),0,27,350,42);Place((RectTransform)fresh.Find("WorldNameLabel"),0,0,350,24);
                Place((RectTransform)fresh.Find("SeedLabel"),380,0,320,24);Place((RectTransform)Ref<InputField>("Seed").transform,380,27,215,42);Place((RectTransform)Ref<Button>("RandomSeed").transform,605,27,95,42);
                Place((RectTransform)fresh.Find("SizeLabel"),730,0,370,24);Place((RectTransform)Ref<Dropdown>("Size").transform,730,27,370,42);Place((RectTransform)Ref<Dropdown>("Size").transform.Find("Arrow"),332,5,28,30);
                Place(Ref<Text>("OriginsTitle").rectTransform,0,90,330,28);Place((RectTransform)Ref<ScrollRect>("OriginsScroll").transform,0,124,330,315);
                Place((RectTransform)Ref<ScrollRect>("StartDetailScroll").transform,355,90,745,349);Place((RectTransform)Ref<Button>("Create").transform,750,455,350,45);
                Place((RectTransform)Ref<ScrollRect>("SaveScroll").transform,0,0,510,480);Place(Ref<Text>("Empty").rectTransform,80,90,940,230);
                var map=Node("SelectedMap",load).gameObject.AddComponent<RawImage>();Place(map.rectTransform,550,0,550,245);map.raycastTarget=false;Bind("SelectedMap",map);
                var saveTitle=Label("SelectedTitle",load,"MenuSelectWorld",27);Place(saveTitle.rectTransform,550,265,550,44);Bind("SelectedTitle",saveTitle);
                var saveInfo=Label("SelectedInfo",load,"",17);Place(saveInfo.rectTransform,550,316,550,96);Bind("SelectedInfo",saveInfo);
                Button("LoadSelected",load,"MenuContinue",550,435,550,45,true);
                var dialog=Node("Dialog",root.transform);Fill(dialog);Paint(dialog,new Color(.035f,.07f,.045f,.78f),true);Bind("Dialog",dialog);
                var card=Node("Card",dialog);card.anchorMin=card.anchorMax=card.pivot=new Vector2(.5f,.5f);card.sizeDelta=new Vector2(560,480);Paint(card,Ink,true);
                var dialogTitle=Label("Title",card,"MenuSettings",29);Place(dialogTitle.rectTransform,40,25,480,48);Bind("DialogTitle",dialogTitle);
                var dialogText=Label("Body",card,"",21);Place(dialogText.rectTransform,40,95,480,240);Bind("DialogText",dialogText);
                var settings=Node("SettingsContent",card);Place(settings,50,95,460,280);Bind("SettingsContent",settings);
                Slider("MasterVolume",settings,"MenuMasterVolume",0);Slider("MusicVolume",settings,"MenuMusicVolume",70);Slider("EffectsVolume",settings,"MenuEffectsVolume",140);
                var toggleRect=Node("ReducedMotion",settings);Place(toggleRect,0,226,460,42);var checkRect=Node("Check",toggleRect);Place(checkRect,0,7,26,26);Paint(checkRect,new Color(.08f,.12f,.09f),true);var mark=Node("Mark",checkRect);Fill(mark);var check=Paint(mark,Gold);var toggle=toggleRect.gameObject.AddComponent<Toggle>();toggle.targetGraphic=checkRect.GetComponent<Image>();toggle.graphic=check;Bind("ReducedMotion",toggle);var reducedLabel=Label("Label",toggleRect,"MenuReducedMotion",18);Place(reducedLabel.rectTransform,42,0,418,42);
                Button("DialogCancel",card,"MenuCancel",40,400,180,44);Button("DialogConfirm",card,"MenuConfirm",300,400,220,44,true);dialog.gameObject.SetActive(false);
                Object.DestroyImmediate(oldStyle);var view=root.AddComponent<StartMenuView>();Bind("Style",view);view.Bind(stage,image,map,Shader.Find("ProjectY/UI/MenuTransition"),homeGroup,frame,freshGroup,loadGroup,signs.ToArray(),root.GetComponentsInChildren<Text>(true),previewTitle,previewCaption);
                reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(texts.Where(x=>x.Target!=null).ToArray());reference.ValidateBindings();entry.ModalDimAlpha=0;
                PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Register(typeof(StartMenuView),"CS.ProjectY.UI.StartMenuView");LuaViewHints.Export(reference,entry.ViewType);
            }
            finally{PrefabUtility.UnloadPrefabContents(root);}
            EditorUtility.SetDirty(config);AssetDatabase.SaveAssets();Debug.Log("Scene menu, save deletion controls and localized bindings installed.");
        }
    }
}
