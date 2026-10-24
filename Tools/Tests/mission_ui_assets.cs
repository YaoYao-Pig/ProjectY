// Run through Unity MCP execute_code in idle Edit Mode. Saves only the three mission UI assets and registry.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var font=UnityEditor.AssetDatabase.LoadAssetAtPath<TMPro.TMP_FontAsset>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc.asset");
var inventory=config.Get("Inventory").Prefab.GetComponent<ProjectY.UI.LuaReference>();
var inventoryView=inventory.Get("Inventory");
var catalog=new UnityEditor.SerializedObject(inventoryView).FindProperty("catalog").objectReferenceValue;
var ink=new Color(.055f,.083f,.076f,1);var paper=new Color(.91f,.92f,.87f,1);var gold=new Color(.9f,.76f,.47f,1);
System.Func<string,Transform,RectTransform> node=(name,parent)=>{var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);return r;};
System.Action<RectTransform,float,float,float,float> box=(r,x,y,w,h)=>{r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);};
System.Action<RectTransform> stretch=r=>{r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=r.offsetMax=Vector2.zero;};
System.Func<RectTransform,Color,bool,UnityEngine.UI.Image> paint=(r,color,hit)=>{var image=r.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=hit;return image;};
System.Action<GameObject,string,Component> bind=(root,key,target)=>{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    entries.RemoveAll(e=>e.Key==key);entries.Add(new ProjectY.UI.LuaReference.Entry(key,target));reference.SetEditorBindings(entries.ToArray());
};
System.Func<GameObject,string,Transform,int,ProjectY.UI.UITxt> label=(root,key,parent,size)=>{
    var r=node(key,parent);var text=r.gameObject.AddComponent<ProjectY.UI.UITxt>();text.font=font;text.fontSize=size;text.color=paper;
    text.richText=true;text.enableWordWrapping=true;text.raycastTarget=false;text.DefaultText="";text.overflowMode=TMPro.TextOverflowModes.Overflow;
    bind(root,key,text);return text;
};
System.Action<GameObject,RectTransform,UnityEngine.UI.ScrollRect> style=(root,page,scroll)=>{
    var view=root.GetComponent<ProjectY.UI.NarrativeView>()??root.AddComponent<ProjectY.UI.NarrativeView>();
    view.SetEditorBindings(page,scroll,root.GetComponentsInChildren<UnityEngine.UI.Text>(true),false);
    var so=new UnityEditor.SerializedObject(view);so.FindProperty("richFont").objectReferenceValue=font;
    var labels=root.GetComponentsInChildren<ProjectY.UI.UITxt>(true);var list=so.FindProperty("richLabels");list.arraySize=labels.Length;
    for(int i=0;i<labels.Length;i++)list.GetArrayElementAtIndex(i).objectReferenceValue=labels[i];so.ApplyModifiedPropertiesWithoutUndo();bind(root,"Style",view);
};
System.Func<RectTransform,UnityEngine.UI.GridLayoutGroup> grid=r=>{
    var g=r.gameObject.AddComponent<UnityEngine.UI.GridLayoutGroup>();g.cellSize=new Vector2(234,104);g.spacing=new Vector2(12,12);
    g.constraint=UnityEngine.UI.GridLayoutGroup.Constraint.FixedColumnCount;g.constraintCount=3;
    r.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>().verticalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;return g;
};
System.Action<GameObject,string,bool> save=(root,name,widget)=>{
    var definition=config.Entries.Find(e=>e.Name==name);
    if(definition==null){definition=new ProjectY.UI.PanelDefinition{Name=name,Module="Narrative",Kind=widget?ProjectY.UI.UIKind.Widget:ProjectY.UI.UIKind.Panel};config.Entries.Add(definition);}
    if(!widget){definition.Layer="Overlay";definition.Modal=true;definition.ModalDimAlpha=.72f;definition.PauseWorldOnOpen=true;definition.CloseOnBack=false;}
    root.GetComponent<ProjectY.UI.LuaReference>().ValidateBindings();ProjectY.Editor.LuaViewHints.Export(root.GetComponent<ProjectY.UI.LuaReference>(),definition.ViewType);
    definition.Prefab=UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,definition.PrefabPath);
};
ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.ItemIconView),"CS.ProjectY.UI.ItemIconView");
ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.NarrativeView),"CS.ProjectY.UI.NarrativeView");
var reward=new GameObject("MissionRewardWidget",typeof(RectTransform),typeof(ProjectY.UI.LuaReference),typeof(CanvasGroup));
try{
    var root=(RectTransform)reward.transform;box(root,0,0,234,104);bind(reward,"Root",root);paint(root,new Color(.115f,.18f,.16f,1),false);
    var accent=node("Accent",root);box(accent,0,0,3,104);bind(reward,"Accent",paint(accent,gold,false));
    var badge=node("Badge",root);box(badge,14,20,58,58);paint(badge,new Color(.065f,.115f,.13f,1),false);
    var icon=node("Icon",badge);box(icon,5,5,48,48);var image=paint(icon,Color.white,false);image.preserveAspect=true;bind(reward,"Icon",image);
    var source=reward.AddComponent<ProjectY.UI.ItemIconView>();var so=new UnityEditor.SerializedObject(source);so.FindProperty("catalog").objectReferenceValue=catalog;so.FindProperty("image").objectReferenceValue=image;so.ApplyModifiedPropertiesWithoutUndo();bind(reward,"ItemIcon",source);
    var glyph=label(reward,"Glyph",badge,20);stretch(glyph.rectTransform);glyph.alignment=TMPro.TextAlignmentOptions.Center;glyph.fontStyle=TMPro.FontStyles.Bold;glyph.DefaultText="EXP+";
    var name=label(reward,"Name",root,16);box(name.rectTransform,86,10,138,40);name.alignment=TMPro.TextAlignmentOptions.MidlineLeft;name.enableAutoSizing=true;name.fontSizeMin=12;name.fontSizeMax=16;name.overflowMode=TMPro.TextOverflowModes.Ellipsis;
    var amount=label(reward,"Amount",root,27);box(amount.rectTransform,86,48,138,31);amount.fontStyle=TMPro.FontStyles.Bold;
    var note=label(reward,"Note",root,12);box(note.rectTransform,86,82,138,17);note.color=new Color(.66f,.75f,.71f,1);
    style(reward,null,null);save(reward,"MissionReward",true);
}finally{UnityEngine.Object.DestroyImmediate(reward);}
var settlement=new GameObject("MissionSettlementPanel",typeof(RectTransform),typeof(ProjectY.UI.LuaReference),typeof(ProjectY.UI.LuaPanel));
try{
    var root=(RectTransform)settlement.transform;root.sizeDelta=new Vector2(1280,720);bind(settlement,"Root",root);
    var page=node("Page",root);page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.sizeDelta=new Vector2(820,640);paint(page,ink,true);
    var line=node("TopAccent",page);box(line,0,0,820,4);paint(line,gold,false);
    var title=label(settlement,"Title",page,32);box(title.rectTransform,30,29,760,44);title.alignment=TMPro.TextAlignmentOptions.Center;title.color=gold;
    var name=label(settlement,"MissionName",page,23);box(name.rectTransform,30,88,760,64);name.alignment=TMPro.TextAlignmentOptions.Center;
    var caption=label(settlement,"Caption",page,17);box(caption.rectTransform,30,159,760,32);caption.alignment=TMPro.TextAlignmentOptions.Center;caption.color=new Color(.63f,.84f,.72f,1);
    var scrollRect=node("Scroll",page);box(scrollRect,44,213,732,304);
    var viewport=node("Viewport",scrollRect);stretch(viewport);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();paint(viewport,new Color(0,0,0,0),true);
    var content=node("Rewards",viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=Vector2.zero;grid(content).childAlignment=TextAnchor.UpperCenter;bind(settlement,"Rewards",content);
    var scroll=scrollRect.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();scroll.viewport=viewport;scroll.content=content;scroll.horizontal=false;scroll.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;bind(settlement,"Scroll",scroll);
    var footer=label(settlement,"Footer",page,14);box(footer.rectTransform,30,530,760,24);footer.color=new Color(.64f,.72f,.67f,1);footer.alignment=TMPro.TextAlignmentOptions.Center;
    var buttonRect=node("Confirm",page);box(buttonRect,260,572,300,44);var plate=paint(buttonRect,new Color(.22f,.37f,.29f,1),true);
    var button=buttonRect.gameObject.AddComponent<UnityEngine.UI.Button>();button.targetGraphic=plate;button.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};bind(settlement,"Confirm",button);
    var captionButton=label(settlement,"ConfirmText",buttonRect,18);stretch(captionButton.rectTransform);captionButton.alignment=TMPro.TextAlignmentOptions.Center;
    style(settlement,page,scroll);save(settlement,"MissionSettlement",false);
}finally{UnityEngine.Object.DestroyImmediate(settlement);}
var journal=UnityEditor.PrefabUtility.LoadPrefabContents(config.Get("MissionJournal").PrefabPath);
try{
    var reference=journal.GetComponent<ProjectY.UI.LuaReference>();var content=(RectTransform)reference.Get("Content");
    var layout=content.GetComponent<UnityEngine.UI.VerticalLayoutGroup>();layout.spacing=16;layout.padding=new RectOffset(12,12,12,20);
    foreach(var key in new[]{"Objective","RewardTitle","Rewards"}){var old=content.Find(key);if(old!=null)UnityEngine.Object.DestroyImmediate(old.gameObject);}
    var objective=label(journal,"Objective",content,17);objective.overflowMode=TMPro.TextOverflowModes.Overflow;objective.lineSpacing=5;objective.transform.SetSiblingIndex(2);
    var heading=label(journal,"RewardTitle",content,19);heading.color=gold;heading.transform.SetSiblingIndex(3);
    var rewards=node("Rewards",content);grid(rewards);rewards.SetSiblingIndex(4);bind(journal,"Rewards",rewards);
    var title=reference.GetUITxt("DetailTitle");title.fontSize=27;title.lineSpacing=4;
    var description=reference.GetUITxt("Description");description.fontSize=17;description.lineSpacing=7;description.color=new Color(.81f,.85f,.80f,1);
    var page=(RectTransform)reference.GetText("Title").transform.parent;page.GetComponent<UnityEngine.UI.Image>().color=ink;
    foreach(var key in new[]{"PrimaryAction","PrimaryHint"}){var old=page.Find(key);if(old!=null)UnityEngine.Object.DestroyImmediate(old.gameObject);}
    var primary=node("PrimaryAction",page);box(primary,850,556,228,48);var primaryPlate=paint(primary,new Color(.20f,.36f,.27f,1),true);
    var primaryButton=primary.gameObject.AddComponent<UnityEngine.UI.Button>();primaryButton.targetGraphic=primaryPlate;primaryButton.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};bind(journal,"PrimaryAction",primaryButton);
    var primaryText=label(journal,"PrimaryText",primary,18);stretch(primaryText.rectTransform);primaryText.alignment=TMPro.TextAlignmentOptions.Center;
    var primaryHint=label(journal,"PrimaryHint",page,14);box(primaryHint.rectTransform,310,556,520,48);primaryHint.alignment=TMPro.TextAlignmentOptions.MidlineLeft;primaryHint.color=new Color(.67f,.78f,.71f,1);
    var detailScroll=(UnityEngine.UI.ScrollRect)reference.Get("Scroll");box((RectTransform)detailScroll.transform,298,104,780,436);
    var missions=(UnityEngine.UI.ScrollRect)reference.Get("MissionsScroll");missions.content.GetComponent<UnityEngine.UI.VerticalLayoutGroup>().spacing=10;
    style(journal,page,(UnityEngine.UI.ScrollRect)reference.Get("Scroll"));
    reference.ValidateBindings();ProjectY.Editor.LuaViewHints.Export(reference,"MissionJournalPanelView");UnityEditor.PrefabUtility.SaveAsPrefabAsset(journal,config.Get("MissionJournal").PrefabPath);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(journal);}
UnityEditor.EditorUtility.SetDirty(config);UnityEditor.AssetDatabase.SaveAssetIfDirty(config);
return "Saved MissionReward, MissionSettlement, MissionJournal and their explicit LuaReference bindings.";
