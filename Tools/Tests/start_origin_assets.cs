// Targeted saved StartMenu upgrade through Unity MCP; no scene edits or runtime component search.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var entry=config.Get("StartMenu");var root=UnityEditor.PrefabUtility.LoadPrefabContents(entry.PrefabPath);
try{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();var fresh=(RectTransform)reference.Get("NewPage");
    var page=(RectTransform)fresh.parent;var font=UnityEditor.AssetDatabase.LoadAssetAtPath<TMPro.TMP_FontAsset>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc.asset");
    System.Action<RectTransform,float,float,float,float> box=(r,x,y,w,h)=>{r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);};
    System.Action<RectTransform,float,float,float,float> stretch=(r,l,b,right,t)=>{r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=new Vector2(l,b);r.offsetMax=new Vector2(-right,-t);};
    System.Func<string,Transform,RectTransform> node=(name,parent)=>{var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);return r;};
    System.Action<string,Component> bind=(key,target)=>{var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());bindings.RemoveAll(e=>e.Key==key);bindings.Add(new ProjectY.UI.LuaReference.Entry(key,target));reference.SetEditorBindings(bindings.ToArray());};
    System.Func<RectTransform,Color,bool,UnityEngine.UI.Image> paint=(r,color,hit)=>{var image=r.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=hit;return image;};
    System.Func<string,Transform,int,ProjectY.UI.UITxt> rich=(key,parent,size)=>{var text=node(key,parent).gameObject.AddComponent<ProjectY.UI.UITxt>();text.font=font;text.fontSize=size;text.color=new Color(.87f,.91f,.86f);text.richText=true;text.enableWordWrapping=true;text.raycastTarget=false;text.overflowMode=TMPro.TextOverflowModes.Overflow;text.DefaultText="";bind(key,text);return text;};
    System.Func<string,float,float,float,float,UnityEngine.UI.ScrollRect> scroll=(key,x,y,w,h)=>{
        var rect=node(key+"Scroll",fresh);box(rect,x,y,w,h);paint(rect,new Color(.025f,.05f,.04f,.45f),true);
        var viewport=node("Viewport",rect);stretch(viewport,0,0,12,0);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();
        var content=node(key,viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=Vector2.zero;
        var layout=content.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();layout.spacing=10;layout.padding=new RectOffset(4,4,8,14);layout.childControlWidth=layout.childControlHeight=true;layout.childForceExpandWidth=true;layout.childForceExpandHeight=false;
        content.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>().verticalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;
        var scroller=rect.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();scroller.viewport=viewport;scroller.content=content;scroller.horizontal=false;scroller.vertical=true;scroller.scrollSensitivity=30;scroller.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;
        var barRect=node("Scrollbar",rect);barRect.anchorMin=new Vector2(1,0);barRect.anchorMax=Vector2.one;barRect.pivot=new Vector2(1,.5f);barRect.sizeDelta=new Vector2(6,-4);barRect.anchoredPosition=new Vector2(-1,0);paint(barRect,new Color(.12f,.18f,.15f),true);
        var handle=node("Handle",barRect);stretch(handle,0,0,0,0);var handleImage=paint(handle,new Color(.43f,.53f,.45f),true);
        var bar=barRect.gameObject.AddComponent<UnityEngine.UI.Scrollbar>();bar.handleRect=handle;bar.targetGraphic=handleImage;bar.direction=UnityEngine.UI.Scrollbar.Direction.BottomToTop;scroller.verticalScrollbar=bar;scroller.verticalScrollbarVisibility=UnityEngine.UI.ScrollRect.ScrollbarVisibility.AutoHide;
        bind(key,content);bind(key+"Scroll",scroller);return scroller;
    };
    foreach(var key in new[]{"OriginsTitle","OriginsScroll","StartDetailScroll"}){var old=fresh.Find(key);if(old!=null)UnityEngine.Object.DestroyImmediate(old.gameObject);}
    box(fresh,36,142,1028,420);
    box((RectTransform)fresh.Find("SeedLabel"),0,0,390,24);box((RectTransform)reference.Get("Seed").transform,0,27,280,42);
    box((RectTransform)reference.Get("RandomSeed").transform,296,27,100,42);
    box((RectTransform)fresh.Find("SizeLabel"),420,0,608,24);box((RectTransform)reference.Get("Size").transform,420,27,608,42);
    box((RectTransform)reference.Get("Size").transform.Find("Arrow"),568,6,28,30);
    fresh.Find("SeedHint").gameObject.SetActive(false);fresh.Find("SizeHint").gameObject.SetActive(false);
    var originsLabel=node("OriginsTitle",fresh).gameObject.AddComponent<UnityEngine.UI.Text>();originsLabel.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");originsLabel.fontSize=16;originsLabel.color=new Color(.88f,.75f,.5f);originsLabel.raycastTarget=false;box(originsLabel.rectTransform,0,84,248,24);bind("OriginsTitle",originsLabel);
    scroll("Origins",0,115,248,287);var details=scroll("StartDetail",264,84,764,318);
    var title=rich("StartName",details.content,26);title.color=new Color(.9f,.77f,.5f);
    var description=rich("StartDescription",details.content,17);description.lineSpacing=5;
    var party=rich("StartParty",details.content,15);party.color=new Color(.62f,.79f,.70f);
    var kit=rich("StartKitTitle",details.content,18);kit.color=new Color(.9f,.77f,.5f);
    var items=node("StartItems",details.content);bind("StartItems",items);
    var grid=items.gameObject.AddComponent<UnityEngine.UI.GridLayoutGroup>();grid.cellSize=new Vector2(234,104);grid.spacing=new Vector2(12,12);grid.constraint=UnityEngine.UI.GridLayoutGroup.Constraint.FixedColumnCount;grid.constraintCount=3;
    items.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>().verticalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;
    box((RectTransform)reference.Get("Create").transform,708,414,320,48);bind("CreateText",reference.Get("Create").GetComponentInChildren<UnityEngine.UI.Text>(true));
    box(reference.GetText("Hint").rectTransform,36,551,680,28);
    var rule=(RectTransform)page.Find("Rule");rule.anchorMin=new Vector2(0,1);rule.anchorMax=Vector2.one;rule.pivot=new Vector2(.5f,1);rule.anchoredPosition=new Vector2(0,-123);rule.sizeDelta=new Vector2(-72,1);
    var style=root.GetComponent<ProjectY.UI.NarrativeView>();style.SetEditorBindings(page,(UnityEngine.UI.ScrollRect)reference.Get("SaveScroll"),root.GetComponentsInChildren<UnityEngine.UI.Text>(true),false);
    var so=new UnityEditor.SerializedObject(style);so.FindProperty("richFont").objectReferenceValue=font;var labels=root.GetComponentsInChildren<ProjectY.UI.UITxt>(true);var array=so.FindProperty("richLabels");array.arraySize=labels.Length;
    for(int i=0;i<labels.Length;i++)array.GetArrayElementAtIndex(i).objectReferenceValue=labels[i];so.ApplyModifiedPropertiesWithoutUndo();
    reference.ValidateBindings();ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.NarrativeView),"CS.ProjectY.UI.NarrativeView");ProjectY.Editor.LuaViewHints.Export(reference,"StartMenuPanelView");
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
ProjectY.Editor.EquipmentAssets.SyncItemIcons();
var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.EquipmentAssetCatalog>(ProjectY.Editor.EquipmentAssets.CatalogPath);UnityEditor.AssetDatabase.SaveAssetIfDirty(catalog);
return "Saved opening selector, scrollable background/loadout previews, explicit bindings and starter item icons.";
