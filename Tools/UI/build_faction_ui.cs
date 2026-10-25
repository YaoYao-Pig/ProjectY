// Unity MCP execute_code method body. Saves only this feature's prefabs/registry/bindings.
// Uses existing components; no project compilation, global Refresh or Play transition.
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
if(config==null)throw new System.Exception("PanelConfig required");
var texts=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Localization/LuaTxt.json"));
var language=new System.Collections.Generic.Dictionary<string,string>();
foreach(var token in texts["rows"])language.Add((string)token["id"],(string)token["txt"]);
var manifest=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText("Art/Localization/ui-text-bindings.json"));
var paper=new Color(.94f,.91f,.83f);var ink=new Color(.16f,.23f,.20f);var muted=new Color(.42f,.45f,.39f);
var gold=new Color(.65f,.48f,.25f);var cream=new Color(.97f,.95f,.88f);
var allied=new Color(.22f,.48f,.36f);var neutral=new Color(.51f,.43f,.29f);var hostile=new Color(.69f,.29f,.26f);
System.Func<Transform,string,float,float,float,float,RectTransform> node=(parent,name,x,y,w,h)=>{
    var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);
    r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);return r;
};
System.Func<RectTransform,Color,bool,UnityEngine.UI.Image> paint=(r,color,hit)=>{
    var image=r.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=hit;return image;
};
System.Action<GameObject,string,Component> bind=(root,key,target)=>{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();var list=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    list.RemoveAll(e=>e.Key==key);list.Add(new ProjectY.UI.LuaReference.Entry(key,target));reference.SetEditorBindings(list.ToArray());
};
System.Func<GameObject,Transform,string,float,float,float,float,int,Color,UnityEngine.UI.Text> label=(root,parent,key,x,y,w,h,size,color)=>{
    var text=node(parent,key,x,y,w,h).gameObject.AddComponent<UnityEngine.UI.Text>();text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
    text.fontSize=size;text.color=color;text.raycastTarget=false;text.supportRichText=false;text.alignment=TextAnchor.MiddleLeft;bind(root,key,text);return text;
};
System.Action<GameObject,UnityEngine.UI.Text,string> localize=(root,text,id)=>{
    text.text=language[id];var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var list=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
    list.RemoveAll(e=>e.Target==text);list.Add(new ProjectY.UI.LuaReference.LocalizedText(text,id));reference.SetEditorLocalizations(list.ToArray());
};
System.Func<GameObject,Transform,string,string,float,float,float,UnityEngine.UI.Button> button=(root,parent,key,id,x,y,w)=>{
    var r=node(parent,key,x,y,w,36);var image=paint(r,new Color(.78f,.74f,.64f,.38f),true);
    var b=r.gameObject.AddComponent<UnityEngine.UI.Button>();b.targetGraphic=image;b.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};bind(root,key,b);
    var text=label(root,r,key+"Text",4,0,w-8,36,15,ink);text.alignment=TextAnchor.MiddleCenter;localize(root,text,id);return b;
};
System.Action<GameObject,string> record=(root,path)=>{
    var old=new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>();foreach(var row in manifest)if((string)row["prefab"]==path)old.Add(row);
    foreach(var row in old)row.Remove();
    foreach(var entry in root.GetComponent<ProjectY.UI.LuaReference>().GetEditorLocalizations()){
        if(entry.Target==null)throw new System.Exception("Missing localized target: "+entry.Id);
        var target=entry.Target.transform;var parts=new System.Collections.Generic.List<string>();while(target!=root.transform){parts.Insert(0,target.name);target=target.parent;}
        var text=entry.Target as UnityEngine.UI.Text;var tmp=entry.Target as TMPro.TMP_Text;
        manifest.Add(new Newtonsoft.Json.Linq.JObject{["prefab"]=path,["node"]=string.Join("/",parts.ToArray()),["type"]=text!=null?"Text":entry.Target.GetType().Name,["text"]=text!=null?text.text:tmp.text,["id"]=entry.Id});
    }
};
System.Action<string,ProjectY.UI.UIKind,System.Action<GameObject>> create=(name,kind,build)=>{
    var definition=System.Linq.Enumerable.FirstOrDefault(config.Entries,e=>e.Name==name);
    if(definition!=null){definition.Validate(true);return;}
    definition=new ProjectY.UI.PanelDefinition{Name=name,Module="Factions",Kind=kind,Layer="Popup",Modal=kind==ProjectY.UI.UIKind.Panel,
        Cache=true,CloseOnBack=true,PauseWorldOnOpen=kind==ProjectY.UI.UIKind.Panel,CloseOnSceneChange=true};
    var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
    var root=new GameObject(definition.PrefabName,typeof(RectTransform));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,preview);
    try{
        ProjectY.Editor.PanelAssets.ConfigureRoot(root,definition,true);build(root);
        var reference=root.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
        definition.Prefab=UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,definition.PrefabPath);definition.Validate(true);
        config.Entries.Add(definition);ProjectY.Editor.LuaViewHints.Export(reference,definition.ViewType);record(root,definition.PrefabPath);
    }finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);}
};
if(!UnityEditor.AssetDatabase.IsValidFolder(ProjectY.UI.PanelConfig.PrefabRoot+"/Factions"))UnityEditor.AssetDatabase.CreateFolder(ProjectY.UI.PanelConfig.PrefabRoot,"Factions");
create("FactionNode",ProjectY.UI.UIKind.Widget,root=>{
    var rect=(RectTransform)root.transform;rect.anchorMin=rect.anchorMax=new Vector2(0,1);rect.pivot=new Vector2(0,1);rect.sizeDelta=new Vector2(260,64);
    var background=paint(rect,cream,true);var b=root.AddComponent<UnityEngine.UI.Button>();b.targetGraphic=background;
    b.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};var colors=b.colors;colors.highlightedColor=new Color(.85f,.91f,.85f);colors.pressedColor=new Color(.71f,.82f,.73f);b.colors=colors;
    bind(root,"Button",b);bind(root,"Accent",paint(node(rect,"Accent",0,0,4,64),allied,false));
    label(root,rect,"Name",16,5,228,29,18,ink);label(root,rect,"Detail",16,35,228,23,13,muted);
});
create("FactionRelations",ProjectY.UI.UIKind.Panel,root=>{
    var page=node(root.transform,"Page",0,0,1200,664);page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);paint(page,paper,true);bind(root,"Page",page);
    paint(node(page,"TopRule",0,0,1200,5),gold,false);
    localize(root,label(root,page,"Title",28,18,640,38,28,ink),"UIFactionTitle");
    localize(root,label(root,page,"Subtitle",30,58,820,25,14,muted),"UIFactionSubtitle");
    button(root,page,"Home","UIFactionHome",906,27,156);button(root,page,"Close","UIFactionClose",1076,27,96);
    label(root,page,"Description",30,93,1140,30,16,ink);
    var frame=node(page,"GraphScroll",30,136,1140,450);paint(frame,new Color(.87f,.85f,.77f,.65f),true);
    var viewport=node(frame,"Viewport",0,0,1140,450);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();
    var graph=node(viewport,"Graph",0,0,1140,440);bind(root,"Graph",graph);
    var scroll=frame.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();scroll.viewport=viewport;scroll.content=graph;scroll.horizontal=false;
    scroll.vertical=true;scroll.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=35;bind(root,"GraphScroll",scroll);
    var track=node(page,"ScrollTrack",1176,136,6,450);paint(track,new Color(.72f,.69f,.60f,.45f),true);
    var handle=node(track,"Handle",0,0,6,80);var handleImage=paint(handle,gold,true);var bar=track.gameObject.AddComponent<UnityEngine.UI.Scrollbar>();
    bar.handleRect=handle;bar.targetGraphic=handleImage;bar.direction=UnityEngine.UI.Scrollbar.Direction.BottomToTop;scroll.verticalScrollbar=bar;
    var rootCard=node(graph,"RootCard",400,20,340,64);paint(rootCard,ink,false);
    var rootName=label(root,rootCard,"RootName",12,3,316,33,21,cream);rootName.alignment=TextAnchor.MiddleCenter;
    var rootDetail=label(root,rootCard,"RootDetail",12,38,316,22,12,new Color(.78f,.72f,.57f));rootDetail.alignment=TextAnchor.MiddleCenter;
    localize(root,rootName,"UIFactionPlayer");localize(root,rootDetail,"UIFactionRoot");
    var kinds=new[]{"Allied","Neutral","Hostile"};var keys=new[]{"UIFactionAllied","UIFactionNeutral","UIFactionHostile"};var palette=new[]{allied,neutral,hostile};
    for(int i=0;i<3;i++){
        var group=node(graph,"Branch"+(i+1),40+i*380,124,300,40);bind(root,kinds[i],paint(group,palette[i],false));
        var caption=label(root,group,"Group"+(i+1),8,0,284,40,17,cream);caption.alignment=TextAnchor.MiddleCenter;localize(root,caption,keys[i]);
        var empty=label(root,graph,"Empty"+(i+1),40+i*380,210,300,30,14,muted);empty.alignment=TextAnchor.MiddleCenter;localize(root,empty,"UIFactionEmpty");
    }
    localize(root,label(root,page,"Help",30,605,1140,28,14,muted),"UIFactionHelp");
    var style=root.AddComponent<ProjectY.UI.StoryGrowthView>();style.SetEditorBindings(root.GetComponentsInChildren<UnityEngine.UI.Text>(true),new ProjectY.UI.StoryGrowthView.ArtEntry[0],page);bind(root,"Style",style);
});
var relations=config.Get("FactionRelations");var relationRoot=UnityEditor.PrefabUtility.LoadPrefabContents(relations.PrefabPath);
try{
    var reference=relationRoot.GetComponent<ProjectY.UI.LuaReference>();
    if(!System.Linq.Enumerable.Any(reference.GetEditorBindings(),e=>e.Key=="UnknownTitle")){
        var title=label(relationRoot,(RectTransform)reference.Get("Graph"),"UnknownTitle",40,204,1060,28,16,muted);
        localize(relationRoot,title,"UIFactionUnknownTitle");
        ((ProjectY.UI.StoryGrowthView)reference.Get("Style")).SetEditorBindings(relationRoot.GetComponentsInChildren<UnityEngine.UI.Text>(true),new ProjectY.UI.StoryGrowthView.ArtEntry[0],(RectTransform)reference.Get("Page"));
        reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(relationRoot,relations.PrefabPath);
        ProjectY.Editor.LuaViewHints.Export(reference,relations.ViewType);record(relationRoot,relations.PrefabPath);
    }
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(relationRoot);}
var hud=config.Get("MainHud");var contents=UnityEditor.PrefabUtility.LoadPrefabContents(hud.PrefabPath);
try{
    var reference=contents.GetComponent<ProjectY.UI.LuaReference>();var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    var rail=reference.GetButton("Inventory").transform.parent;
    var old=entries.Find(e=>e.Key=="NavigationToggle");
    if(old.Target!=null){
        var oldObject=old.Target.gameObject;var locales=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
        locales.RemoveAll(e=>e.Target.transform.IsChildOf(oldObject.transform));reference.SetEditorLocalizations(locales.ToArray());
        entries.RemoveAll(e=>e.Target.transform.IsChildOf(oldObject.transform));reference.SetEditorBindings(entries.ToArray());UnityEngine.Object.DestroyImmediate(oldObject);
    }
    if(!System.Linq.Enumerable.Any(reference.GetEditorBindings(),e=>e.Key=="Factions"))button(contents,rail,"Factions","UIFactionEntry",0,186,94);
    var order=new[]{"Inventory","Growth","Missions","Factions","MenuToggle"};
    for(int i=0;i<order.Length;i++){
        var r=(RectTransform)reference.GetButton(order[i]).transform;r.SetParent(rail,false);r.SetSiblingIndex(i);
        r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(0,-(i==4?256:i*62));r.sizeDelta=new Vector2(94,52);
        var text=reference.GetText(order[i]+"Text");text.rectTransform.anchorMin=Vector2.zero;text.rectTransform.anchorMax=Vector2.one;text.rectTransform.offsetMin=new Vector2(4,0);text.rectTransform.offsetMax=new Vector2(-4,0);
        text.alignment=TextAnchor.MiddleCenter;text.fontSize=18;
    }
    localize(contents,reference.GetText("GrowthText"),"UIMainHudGrowthTextText");
    localize(contents,reference.GetText("InventoryText"),"UIMainHudPanelCommonEntryRailInventoryLabel");
    var menuSlots=new[]{"Focus","Environment","Leave","Stop","GM"};
    for(int i=0;i<menuSlots.Length;i++)((RectTransform)reference.GetButton(menuSlots[i]).transform).anchoredPosition=new Vector2(i%2==0?14:162,-(46+i/2*42));
    var serialized=new UnityEditor.SerializedObject(reference.Get("HUD"));var labels=serialized.FindProperty("layout").FindPropertyRelative("Labels");var all=contents.GetComponentsInChildren<UnityEngine.UI.Text>(true);
    labels.arraySize=all.Length;for(int i=0;i<all.Length;i++)labels.GetArrayElementAtIndex(i).objectReferenceValue=all[i];serialized.ApplyModifiedPropertiesWithoutUndo();
    reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(contents,hud.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,hud.ViewType);record(contents,hud.PrefabPath);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(contents);}
UnityEditor.EditorUtility.SetDirty(config);UnityEditor.AssetDatabase.SaveAssetIfDirty(config);
System.IO.File.WriteAllText("Art/Localization/ui-text-bindings.json",manifest.ToString(Newtonsoft.Json.Formatting.Indented)+"\n",new System.Text.UTF8Encoding(false));
return "Saved FactionRelations, FactionNode, MainHud entries and localized LuaReference bindings. No compile/Refresh/Play transition.";
