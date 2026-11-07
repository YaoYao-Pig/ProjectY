// Execute through Unity MCP in idle Edit Mode. Creates the saved ESC menu once.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var font=UnityEditor.AssetDatabase.LoadAssetAtPath<TMPro.TMP_FontAsset>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc.asset");
if(config==null||font==null)throw new System.InvalidOperationException("PanelConfig and font are required");
if(config.Entries.Exists(e=>e.Name=="PauseMenu"))throw new System.InvalidOperationException("PauseMenu already exists; edit its saved prefab directly");
var entry=new ProjectY.UI.PanelDefinition{Name="PauseMenu",Module="Adventure",Layer="Popup",Modal=true,
    ModalDimAlpha=.3f,Cache=true,CloseOnBack=true,PauseWorldOnOpen=true,CloseOnSceneChange=true};
if(System.IO.File.Exists(entry.PrefabPath))throw new System.InvalidOperationException("PauseMenu prefab already exists");
var texts=new System.Collections.Generic.Dictionary<string,string>();
foreach(var row in Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Localization/LuaTxt.json"))["rows"])
    texts.Add((string)row["id"],(string)row["txt"]);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject(entry.PrefabName,typeof(RectTransform));
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
try{
    ProjectY.Editor.PanelAssets.ConfigureRoot(root,entry,true);
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    var localized=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>();
    var ink=new Color(.055f,.083f,.076f,1);var paper=new Color(.91f,.92f,.87f,1);var gold=new Color(.90f,.76f,.47f,1);
    System.Func<Transform,string,Vector2,Vector2,Vector2,Vector2,RectTransform> rect=(parent,name,min,max,offsetMin,offsetMax)=>{
        var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);
        r.anchorMin=min;r.anchorMax=max;r.offsetMin=offsetMin;r.offsetMax=offsetMax;return r;
    };
    System.Func<RectTransform,Color,bool,UnityEngine.UI.Image> paint=(r,color,hit)=>{
        var image=r.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=hit;return image;
    };
    System.Func<RectTransform,string,string,int,ProjectY.UI.UITxt> label=(r,key,id,size)=>{
        var value=r.gameObject.AddComponent<ProjectY.UI.UITxt>();value.font=font;value.fontSize=size;value.color=paper;
        value.richText=false;value.enableWordWrapping=true;value.raycastTarget=false;value.alignment=TMPro.TextAlignmentOptions.MidlineLeft;
        value.DefaultText=id==null?"":texts[id];bindings.Add(new ProjectY.UI.LuaReference.Entry(key,value));
        if(id!=null)localized.Add(new ProjectY.UI.LuaReference.LocalizedText(value,id));return value;
    };
    System.Func<RectTransform,string,string,UnityEngine.UI.Button> button=(r,key,id)=>{
        var image=paint(r,new Color(.12f,.19f,.15f,1),true);
        var value=r.gameObject.AddComponent<UnityEngine.UI.Button>();value.targetGraphic=image;
        value.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};
        var colors=value.colors;colors.normalColor=Color.white;colors.highlightedColor=new Color(1.35f,1.28f,1.12f,1);
        colors.pressedColor=new Color(.8f,.85f,.7f,1);colors.fadeDuration=.1f;value.colors=colors;
        bindings.Add(new ProjectY.UI.LuaReference.Entry(key,value));
        var text=label(rect(r,key+"Text",Vector2.zero,Vector2.one,new Vector2(26,0),new Vector2(-24,0)),key+"Text",id,25);
        if(key=="Resume")text.color=gold;
        return value;
    };
    var page=rect(root.transform,"Page",Vector2.zero,new Vector2(.5f,1),Vector2.zero,Vector2.zero);
    paint(page,ink,true);bindings.Add(new ProjectY.UI.LuaReference.Entry("Page",page));
    paint(rect(page,"Edge",new Vector2(1,0),Vector2.one,new Vector2(-2,0),Vector2.zero),gold,false);
    var title=label(rect(page,"Title",new Vector2(0,1),Vector2.one,new Vector2(56,-108),new Vector2(-48,-48)),"Title","PauseMenuTitle",32);title.color=gold;
    paint(rect(page,"Rule",new Vector2(0,1),Vector2.one,new Vector2(56,-130),new Vector2(-56,-129)),new Color(.4f,.39f,.27f,1),false);
    var actions=rect(page,"Actions",new Vector2(0,.5f),new Vector2(1,.5f),new Vector2(56,-182),new Vector2(-56,182));
    bindings.Add(new ProjectY.UI.LuaReference.Entry("Actions",actions.gameObject.AddComponent<CanvasGroup>()));
    string[] keys={"Resume","Save","Load","Settings","Quit"};
    for(int i=0;i<keys.Length;i++){
        var r=rect(actions,keys[i],new Vector2(0,1),Vector2.one,new Vector2(0,-(i*76+60)),new Vector2(0,-i*76));
        button(r,keys[i],"PauseMenu"+keys[i]);
    }
    var hint=label(rect(page,"Hint",Vector2.zero,new Vector2(1,0),new Vector2(56,38),new Vector2(-56,114)),"Hint",null,17);
    hint.color=new Color(.66f,.77f,.70f,1);
    var dialog=rect(page,"QuitDialog",Vector2.zero,Vector2.one,Vector2.zero,Vector2.zero);
    paint(dialog,new Color(ink.r,ink.g,ink.b,.98f),true);bindings.Add(new ProjectY.UI.LuaReference.Entry("QuitDialog",dialog));
    var dialogTitle=label(rect(dialog,"QuitTitle",new Vector2(0,.5f),new Vector2(1,.5f),new Vector2(56,70),new Vector2(-56,130)),"QuitTitle","PauseMenuQuit",30);dialogTitle.color=gold;
    label(rect(dialog,"QuitPrompt",new Vector2(0,.5f),new Vector2(1,.5f),new Vector2(56,-35),new Vector2(-56,65)),"QuitPrompt","MenuQuitPrompt",21);
    button(rect(dialog,"QuitCancel",new Vector2(0,.5f),new Vector2(.5f,.5f),new Vector2(56,-130),new Vector2(-8,-70)),"QuitCancel","MenuCancel");
    button(rect(dialog,"QuitConfirm",new Vector2(.5f,.5f),new Vector2(1,.5f),new Vector2(8,-130),new Vector2(-56,-70)),"QuitConfirm","MenuConfirm");
    dialog.gameObject.SetActive(false);
    reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(localized.ToArray());reference.ValidateBindings();
    entry.Prefab=UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);entry.Validate(true);
    config.Entries.Add(entry);UnityEditor.EditorUtility.SetDirty(config);UnityEditor.AssetDatabase.SaveAssetIfDirty(config);
    ProjectY.Editor.LuaViewHints.Export(reference,entry.ViewType);
    var manifestPath="Art/Localization/ui-text-bindings.json";
    var manifest=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(manifestPath));
    foreach(var item in localized){
        var parts=new System.Collections.Generic.List<string>();var node=item.Target.transform;
        while(node!=root.transform){parts.Insert(0,node.name);node=node.parent;}
        manifest.Add(new Newtonsoft.Json.Linq.JObject{["prefab"]=entry.PrefabPath,["node"]=string.Join("/",parts.ToArray()),["type"]="UITxt",["text"]=texts[item.Id],["id"]=item.Id});
    }
    System.IO.File.WriteAllText(manifestPath,manifest.ToString(Newtonsoft.Json.Formatting.Indented)+"\n",new System.Text.UTF8Encoding(false));
}finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
return "Saved PauseMenu half-screen prefab, pause policy, LuaReference bindings, localization and View hints.";
