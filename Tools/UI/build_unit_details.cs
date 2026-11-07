// Unity MCP execute_code body. Run after the coordinated compile/config export.
// Only creates missing controls and updates bindings; existing saved control positions survive reruns.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var font=UnityEditor.AssetDatabase.LoadAssetAtPath<TMPro.TMP_FontAsset>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc.asset");
if(config==null||font==null)throw new System.InvalidOperationException("PanelConfig and NotoSansCJKsc are required");
var language=new System.Collections.Generic.Dictionary<string,string>();
foreach(var row in Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Localization/LuaTxt.json"))["rows"])
    language.Add((string)row["id"],(string)row["txt"]);
var manifestPath="Art/Localization/ui-text-bindings.json";
var manifest=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(manifestPath));
var ink=new Color(.055f,.083f,.076f,1);var panelColor=new Color(.085f,.135f,.115f,1);
var paper=new Color(.91f,.92f,.87f,1);var gold=new Color(.90f,.76f,.47f,1);var muted=new Color(.66f,.77f,.70f,1);
System.Action<RectTransform,float,float,float,float> box=(r,x,y,w,h)=>{
    r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);
};
System.Func<Transform,string,float,float,float,float,RectTransform> node=(parent,name,x,y,w,h)=>{
    var old=parent.Find(name);if(old!=null)return (RectTransform)old;
    var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);box(r,x,y,w,h);return r;
};
System.Action<RectTransform> stretch=r=>{r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=r.offsetMax=Vector2.zero;};
System.Func<RectTransform,Color,bool,UnityEngine.UI.Image> paint=(r,color,hit)=>{
    var image=r.GetComponent<UnityEngine.UI.Image>();if(image!=null)return image;
    image=r.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=hit;return image;
};
System.Action<GameObject,string,Component> bind=(root,key,value)=>{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var rows=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    rows.RemoveAll(e=>e.Key==key);rows.Add(new ProjectY.UI.LuaReference.Entry(key,value));reference.SetEditorBindings(rows.ToArray());
};
System.Func<GameObject,Transform,string,float,float,float,float,int,ProjectY.UI.UITxt> label=(root,parent,key,x,y,w,h,size)=>{
    var r=node(parent,key,x,y,w,h);var value=r.GetComponent<ProjectY.UI.UITxt>();
    if(value==null){value=r.gameObject.AddComponent<ProjectY.UI.UITxt>();value.font=font;value.fontSize=size;value.color=paper;
        value.richText=false;value.enableWordWrapping=true;value.raycastTarget=false;value.overflowMode=TMPro.TextOverflowModes.Overflow;value.DefaultText="";}
    bind(root,key,value);return value;
};
System.Action<GameObject,ProjectY.UI.UITxt,string> localize=(root,text,id)=>{
    if(!language.ContainsKey(id))throw new System.Exception("Export language key first: "+id);
    text.DefaultText=language[id];var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var rows=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
    rows.RemoveAll(e=>e.Target==text);rows.Add(new ProjectY.UI.LuaReference.LocalizedText(text,id));reference.SetEditorLocalizations(rows.ToArray());
};
System.Func<GameObject,Transform,string,string,float,float,float,float,UnityEngine.UI.Button> button=(root,parent,key,id,x,y,w,h)=>{
    var r=node(parent,key,x,y,w,h);var image=paint(r,new Color(.19f,.32f,.25f,1),true);
    var value=r.GetComponent<UnityEngine.UI.Button>();if(value==null){value=r.gameObject.AddComponent<UnityEngine.UI.Button>();value.targetGraphic=image;
        value.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};}
    bind(root,key,value);bool newText=r.Find(key+"Text")==null;
    var text=label(root,r,key+"Text",5,0,w-10,h,18);if(newText)text.alignment=TMPro.TextAlignmentOptions.Center;
    localize(root,text,id);return value;
};
System.Func<GameObject,Transform,string,string,float,float,float,float,bool,UnityEngine.UI.ScrollRect> scroll=(root,parent,key,contentKey,x,y,w,h,list)=>{
    var frame=node(parent,key,x,y,w,h);paint(frame,panelColor,true);
    var viewport=node(frame,"Viewport",8,8,w-28,h-16);if(viewport.GetComponent<UnityEngine.UI.RectMask2D>()==null)viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();
    bool newContent=viewport.Find(contentKey)==null;var content=node(viewport,contentKey,0,0,w-28,0);
    if(newContent){content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=Vector2.zero;}
    var fit=content.GetComponent<UnityEngine.UI.ContentSizeFitter>();if(fit==null){fit=content.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>();fit.verticalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;}
    if(list){
        var layout=content.GetComponent<UnityEngine.UI.VerticalLayoutGroup>();if(layout==null){layout=content.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();
            layout.spacing=8;layout.childAlignment=TextAnchor.UpperCenter;layout.childControlWidth=true;layout.childControlHeight=true;layout.childForceExpandWidth=true;layout.childForceExpandHeight=false;}
        bind(root,contentKey,content);
    }else{
        var text=content.GetComponent<ProjectY.UI.UITxt>();if(text==null){text=content.gameObject.AddComponent<ProjectY.UI.UITxt>();
            text.font=font;text.fontSize=18;text.color=paper;text.richText=false;text.raycastTarget=false;text.enableWordWrapping=true;
            text.overflowMode=TMPro.TextOverflowModes.Overflow;text.DefaultText="";text.lineSpacing=3;}
        bind(root,contentKey,text);
    }
    var value=frame.GetComponent<UnityEngine.UI.ScrollRect>();if(value==null){value=frame.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();
        value.horizontal=false;value.vertical=true;value.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;value.scrollSensitivity=34;}
    value.viewport=viewport;value.content=content;
    var track=node(frame,"Track",w-12,8,5,h-16);paint(track,new Color(.16f,.24f,.20f,1),true);
    bool newHandle=track.Find("Handle")==null;var handle=node(track,"Handle",0,0,5,60);if(newHandle)stretch(handle);
    var handleImage=paint(handle,gold,true);var bar=track.GetComponent<UnityEngine.UI.Scrollbar>();if(bar==null){bar=track.gameObject.AddComponent<UnityEngine.UI.Scrollbar>();bar.direction=UnityEngine.UI.Scrollbar.Direction.BottomToTop;}
    bar.handleRect=handle;bar.targetGraphic=handleImage;value.verticalScrollbar=bar;value.verticalScrollbarVisibility=UnityEngine.UI.ScrollRect.ScrollbarVisibility.AutoHide;
    bind(root,key,value);return value;
};
System.Action<GameObject,string> record=(root,path)=>{
    var old=new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>();foreach(var row in manifest)if((string)row["prefab"]==path)old.Add(row);
    foreach(var row in old)row.Remove();
    foreach(var entry in root.GetComponent<ProjectY.UI.LuaReference>().GetEditorLocalizations()){
        var parts=new System.Collections.Generic.List<string>();var target=entry.Target.transform;
        while(target!=root.transform){parts.Insert(0,target.name);target=target.parent;}
        manifest.Add(new Newtonsoft.Json.Linq.JObject{["prefab"]=path,["node"]=string.Join("/",parts.ToArray()),["type"]="UITxt",["text"]=((ProjectY.UI.UITxt)entry.Target).DefaultText,["id"]=entry.Id});
    }
};
System.Action<string,bool,System.Action<GameObject>> save=(name,widget,build)=>{
    var definition=System.Linq.Enumerable.FirstOrDefault(config.Entries,e=>e.Name==name);
    if(definition==null){definition=new ProjectY.UI.PanelDefinition{Name=name,Module="Adventure",Kind=widget?ProjectY.UI.UIKind.Widget:ProjectY.UI.UIKind.Panel,
        Layer="Popup",Modal=!widget,ModalDimAlpha=.68f,Cache=true,CloseOnBack=true,PauseWorldOnOpen=!widget,CloseOnSceneChange=true};config.Entries.Add(definition);}
    if(definition.IsWidget!=widget)throw new System.Exception("Existing UI kind differs: "+name);
    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(definition.PrefabPath);
    if(definition.Prefab!=null&&definition.Prefab!=prefab)throw new System.Exception("Existing UI prefab path differs: "+name);
    var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
    var root=prefab!=null?UnityEditor.PrefabUtility.LoadPrefabContents(definition.PrefabPath):new GameObject(definition.PrefabName,typeof(RectTransform));
    if(prefab==null)UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    try{
        ProjectY.Editor.PanelAssets.ConfigureRoot(root,definition,prefab==null);build(root);
        var reference=root.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
        definition.Prefab=UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,definition.PrefabPath);definition.Validate(true);
        ProjectY.Editor.LuaViewHints.Export(reference,definition.ViewType);record(root,definition.PrefabPath);
    }finally{if(prefab!=null)UnityEditor.PrefabUtility.UnloadPrefabContents(root);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
};
var folder=ProjectY.UI.PanelConfig.PrefabRoot+"/Adventure";
if(!UnityEditor.AssetDatabase.IsValidFolder(folder))UnityEditor.AssetDatabase.CreateFolder(ProjectY.UI.PanelConfig.PrefabRoot,"Adventure");
ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.NarrativeView),"CS.ProjectY.UI.NarrativeView");
save("InspectionTarget",true,root=>{
    var rect=(RectTransform)root.transform;
    if(root.transform.childCount==0)box(rect,0,0,234,66);
    var background=paint(rect,new Color(.11f,.18f,.145f,1),true);
    var value=root.GetComponent<UnityEngine.UI.Button>();if(value==null){value=root.AddComponent<UnityEngine.UI.Button>();value.targetGraphic=background;value.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};}
    bind(root,"Button",value);
    var element=root.GetComponent<UnityEngine.UI.LayoutElement>();if(element==null){element=root.AddComponent<UnityEngine.UI.LayoutElement>();element.minHeight=66;}
    var vertical=root.GetComponent<UnityEngine.UI.VerticalLayoutGroup>();if(vertical==null){vertical=root.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();
        vertical.padding=new RectOffset(14,10,6,6);vertical.spacing=2;vertical.childControlWidth=true;vertical.childControlHeight=true;
        vertical.childForceExpandWidth=true;vertical.childForceExpandHeight=false;}
    var selected=node(rect,"Selected",0,0,4,66);paint(selected,gold,false);bind(root,"Selected",selected);
    var selectedLayout=selected.GetComponent<UnityEngine.UI.LayoutElement>();if(selectedLayout==null)selectedLayout=selected.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();selectedLayout.ignoreLayout=true;
    label(root,rect,"Title",14,5,208,28,19);
    var detail=label(root,rect,"Body",14,35,208,23,16);detail.color=muted;
});
save("UnitDetails",false,root=>{
    bool newPage=root.transform.Find("Page")==null;var page=node(root.transform,"Page",0,0,1100,640);
    if(newPage){page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.anchoredPosition=Vector2.zero;}
    paint(page,ink,true);bind(root,"Page",page);paint(node(page,"TopAccent",0,0,1100,4),gold,false);
    var title=label(root,page,"Title",28,14,850,46,30);title.color=gold;localize(root,title,"InspectionTitle");
    var subtitle=label(root,page,"Subtitle",30,62,1042,26,16);subtitle.color=muted;localize(root,subtitle,"InspectionSubtitle");
    button(root,page,"Close","InspectionClose",988,20,84,36);
    localize(root,label(root,page,"TargetTitle",28,102,254,30,19),"InspectionTargets");
    var targetScroll=scroll(root,page,"TargetScroll","TargetRows",28,138,254,474,true);
    var name=label(root,page,"TargetName",310,98,570,40,25);name.color=gold;
    name.rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal,570);
    button(root,page,"Talk","PeopleDialogueTalk",900,98,172,40);
    localize(root,label(root,page,"AttributeTitle",310,143,350,30,19),"InspectionAttributes");
    localize(root,label(root,page,"TraitTitle",680,143,392,30,19),"InspectionTraits");
    scroll(root,page,"AttributeScroll","Attributes",310,177,350,285,false);
    scroll(root,page,"TraitScroll","Traits",680,177,392,285,false);
    label(root,page,"ObserverLabel",310,481,486,28,19);
    button(root,page,"PreviousObserver","InspectionPreviousObserver",842,478,108,34);
    button(root,page,"NextObserver","InspectionNextObserver",964,478,108,34);
    var cost=label(root,page,"Cost",310,516,762,28,17);cost.color=muted;
    label(root,page,"Result",310,547,762,28,17);
    var reason=label(root,page,"Reason",310,579,566,38,16);reason.color=muted;
    button(root,page,"Observe","InspectionObserve",900,575,172,42);
    var style=root.GetComponent<ProjectY.UI.NarrativeView>();if(style==null)style=root.AddComponent<ProjectY.UI.NarrativeView>();
    style.SetEditorBindings(page,targetScroll,root.GetComponentsInChildren<UnityEngine.UI.Text>(true),false);
    var so=new UnityEditor.SerializedObject(style);so.FindProperty("richFont").objectReferenceValue=font;
    var labels=root.GetComponentsInChildren<ProjectY.UI.UITxt>(true);var list=so.FindProperty("richLabels");list.arraySize=labels.Length;
    for(int i=0;i<labels.Length;i++)list.GetArrayElementAtIndex(i).objectReferenceValue=labels[i];so.ApplyModifiedPropertiesWithoutUndo();bind(root,"Style",style);
});
UnityEditor.EditorUtility.SetDirty(config);UnityEditor.AssetDatabase.SaveAssetIfDirty(config);
System.IO.File.WriteAllText(manifestPath,manifest.ToString(Newtonsoft.Json.Formatting.Indented)+"\n",new System.Text.UTF8Encoding(false));
return "Saved UnitDetails and InspectionTarget prefabs, explicit bindings, View hints, localization manifest and registry. Existing control layout was preserved.";
