// Unity MCP execute_code body. Author native assets after LuaTxt export; no Refresh or compilation.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required for TitleForge authoring.");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var growthDefinition=config.Get("CharacterGrowth");
var growth=UnityEditor.PrefabUtility.LoadPrefabContents(growthDefinition.PrefabPath);
var growthRef=growth.GetComponent<ProjectY.UI.LuaReference>();
var sourceSkin=(ProjectY.UI.LuaReference)growthRef.Get("Skin");
var font=UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf");
if(font==null)throw new System.InvalidOperationException("The saved Noto Sans CJK utility font is required.");
var ink=sourceSkin.GetImage("ink").color;var muted=sourceSkin.GetImage("muted").color;
var language=new System.Collections.Generic.Dictionary<string,string>();
foreach(var row in Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Localization/LuaTxt.json"))["rows"])
    language.Add((string)row["id"],(string)row["txt"]);
var manifestPath="Art/Localization/ui-text-bindings.json";
var manifest=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(manifestPath));
ProjectY.UI.PanelDefinition definition=null;
foreach(var entry in config.Entries)if(entry.Name=="TitleForge")definition=entry;
bool newDefinition=definition==null;
if(newDefinition)definition=new ProjectY.UI.PanelDefinition{Name="TitleForge",Module="Adventure",Kind=ProjectY.UI.UIKind.Panel,
    Layer="Popup",Modal=true,ModalDimAlpha=.72f,Cache=true,CloseOnBack=true,PauseWorldOnOpen=true,CloseOnSceneChange=true};
var existing=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(definition.PrefabPath);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=existing!=null?UnityEditor.PrefabUtility.LoadPrefabContents(definition.PrefabPath):new GameObject(definition.PrefabName,typeof(RectTransform));
if(existing==null)UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
try{
    ProjectY.Editor.PanelAssets.ConfigureRoot(root,definition,existing==null);
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    System.Action<RectTransform,float,float,float,float> box=(rect,x,y,w,h)=>{
        rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(w,h);
    };
    System.Func<Transform,string,float,float,float,float,RectTransform> node=(parent,name,x,y,w,h)=>{
        var found=parent.Find(name);var rect=found!=null?(RectTransform)found:(RectTransform)new GameObject(name,typeof(RectTransform)).transform;
        rect.SetParent(parent,false);rect.gameObject.layer=parent.gameObject.layer;box(rect,x,y,w,h);return rect;
    };
    System.Action<ProjectY.UI.LuaReference,string,Component> bind=(owner,key,value)=>{
        var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(owner.GetEditorBindings());
        entries.RemoveAll(e=>e.Key==key);entries.Add(new ProjectY.UI.LuaReference.Entry(key,value));owner.SetEditorBindings(entries.ToArray());
    };
    System.Func<RectTransform,string,bool,UnityEngine.UI.Image> paint=(rect,key,hit)=>{
        var image=rect.GetComponent<UnityEngine.UI.Image>();if(image==null)image=rect.gameObject.AddComponent<UnityEngine.UI.Image>();
        image.sprite=sourceSkin.GetImage(key).sprite;image.type=UnityEngine.UI.Image.Type.Sliced;image.pixelsPerUnitMultiplier=.4f;
        image.color=Color.white;image.raycastTarget=hit;return image;
    };
    System.Func<ProjectY.UI.LuaReference,Transform,string,float,float,float,float,int,UnityEngine.UI.Text> label=(owner,parent,key,x,y,w,h,size)=>{
        var rect=node(parent,key,x,y,w,h);var text=rect.GetComponent<UnityEngine.UI.Text>();if(text==null)text=rect.gameObject.AddComponent<UnityEngine.UI.Text>();
        text.font=font;text.fontSize=size;text.color=ink;text.raycastTarget=false;text.supportRichText=false;
        text.alignment=TextAnchor.MiddleLeft;text.horizontalOverflow=HorizontalWrapMode.Wrap;text.verticalOverflow=VerticalWrapMode.Truncate;
        text.text="";bind(owner,key,text);return text;
    };
    System.Action<ProjectY.UI.LuaReference,UnityEngine.UI.Text,string> localize=(owner,text,id)=>{
        if(!language.ContainsKey(id))throw new System.InvalidOperationException("Export language key first: "+id);
        text.text=language[id];var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(owner.GetEditorLocalizations());
        entries.RemoveAll(e=>e.Target==text);entries.Add(new ProjectY.UI.LuaReference.LocalizedText(text,id));owner.SetEditorLocalizations(entries.ToArray());
    };
    System.Func<ProjectY.UI.LuaReference,Transform,string,string,float,float,float,float,UnityEngine.UI.Button> button=(owner,parent,key,id,x,y,w,h)=>{
        var rect=node(parent,key,x,y,w,h);var image=paint(rect,"button_light",true);
        var result=rect.GetComponent<UnityEngine.UI.Button>();if(result==null)result=rect.gameObject.AddComponent<UnityEngine.UI.Button>();
        result.targetGraphic=image;result.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};bind(owner,key,result);
        var text=label(owner,rect,key+"Text",5,0,w-10,h,17);text.alignment=TextAnchor.MiddleCenter;localize(reference,text,id);return result;
    };
    System.Func<Transform,string,float,float,float,float,UnityEngine.UI.ScrollRect> scroll=(parent,name,x,y,w,h)=>{
        var frame=node(parent,name,x,y,w,h);paint(frame,"inset_light",true);
        var viewport=node(frame,"Viewport",10,8,w-30,h-16);
        if(viewport.GetComponent<UnityEngine.UI.RectMask2D>()==null)viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();
        var content=node(viewport,"Content",0,0,w-30,h-16);
        var result=frame.GetComponent<UnityEngine.UI.ScrollRect>();if(result==null)result=frame.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();
        result.viewport=viewport;result.content=content;result.horizontal=false;result.vertical=true;result.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;result.scrollSensitivity=36;
        var track=node(frame,"Track",w-13,10,5,h-20);var trackImage=track.GetComponent<UnityEngine.UI.Image>();
        if(trackImage==null)trackImage=track.gameObject.AddComponent<UnityEngine.UI.Image>();trackImage.color=new Color(.25f,.18f,.12f,.15f);
        var handle=node(track,"Handle",0,0,5,60);var handleImage=handle.GetComponent<UnityEngine.UI.Image>();
        if(handleImage==null)handleImage=handle.gameObject.AddComponent<UnityEngine.UI.Image>();handleImage.color=new Color(.48f,.34f,.19f,.7f);
        var bar=track.GetComponent<UnityEngine.UI.Scrollbar>();if(bar==null)bar=track.gameObject.AddComponent<UnityEngine.UI.Scrollbar>();
        bar.direction=UnityEngine.UI.Scrollbar.Direction.BottomToTop;bar.handleRect=handle;bar.targetGraphic=handleImage;
        result.verticalScrollbar=bar;result.verticalScrollbarVisibility=UnityEngine.UI.ScrollRect.ScrollbarVisibility.AutoHide;
        return result;
    };
    var page=node(root.transform,"Page",0,0,1100,660);page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.anchoredPosition=Vector2.zero;
    paint(page,"panel_light",true);bind(reference,"Page",page);
    var skinNode=root.transform.Find("Skin");
    var skin=skinNode!=null?skinNode.GetComponent<ProjectY.UI.LuaReference>():UnityEngine.Object.Instantiate(sourceSkin,root.transform,false);
    skin.name="Skin";skin.gameObject.SetActive(false);bind(reference,"Skin",skin);
    var heading=label(reference,page,"Title",30,14,690,46,29);heading.font=growthRef.GetText("Title").font;
    localize(reference,heading,"TitleForgeTitle");
    button(reference,page,"Close","TitleForgeClose",920,22,150,38);
    label(reference,page,"Owner",32,63,650,30,18);
    var balance=label(reference,page,"Balance",730,61,338,34,21);balance.alignment=TextAnchor.MiddleRight;
    localize(reference,label(reference,page,"NameLabel",32,105,100,36,18),"TitleForgeNameLabel");
    var nameRoot=node(page,"Name",132,103,460,40);paint(nameRoot,"inset_light",true);
    var input=nameRoot.GetComponent<UnityEngine.UI.InputField>();if(input==null)input=nameRoot.gameObject.AddComponent<UnityEngine.UI.InputField>();
    var inputText=label(reference,nameRoot,"NameText",12,0,436,40,21);
    var placeholder=label(reference,nameRoot,"NamePlaceholder",12,0,436,40,18);placeholder.color=muted;
    localize(reference,placeholder,"TitleForgeNamePlaceholder");input.textComponent=inputText;input.placeholder=placeholder;
    input.targetGraphic=nameRoot.GetComponent<UnityEngine.UI.Image>();input.lineType=UnityEngine.UI.InputField.LineType.SingleLine;
    input.contentType=UnityEngine.UI.InputField.ContentType.Standard;input.characterLimit=32;input.text="";bind(reference,"Name",input);
    var permanence=label(reference,page,"Permanent",624,98,444,50,16);permanence.color=muted;localize(reference,permanence,"TitleForgePermanent");
    string[] categories={"primary","combat","life","special","negative"};string[] groupKeys={"TitleForgePrimary","TitleForgeCombat","TitleForgeLife","TitleForgeSpecial","TitleForgeNegative"};
    for(int i=0;i<categories.Length;i++)button(reference,page,"Group_"+categories[i],groupKeys[i],32+i*134,160,126,34);
    var effects=scroll(page,"Effects",32,206,670,330);
    var effectList=effects.GetComponent<ProjectY.UI.LuaReference>();if(effectList==null)effectList=effects.gameObject.AddComponent<ProjectY.UI.LuaReference>();
    bind(effectList,"ScrollRect",effects);bind(reference,"EffectList",effectList);
    var templateRoot=node(root.transform,"Templates",0,0,640,1);
    var header=node(templateRoot,"HeaderTemplate",0,0,640,34);paint(header,"header_strip",false);
    var headerRef=header.GetComponent<ProjectY.UI.LuaReference>();if(headerRef==null)headerRef=header.gameObject.AddComponent<ProjectY.UI.LuaReference>();
    bind(headerRef,"Root",header);var headerTitle=label(headerRef,header,"Title",14,0,612,34,18);headerTitle.color=sourceSkin.GetImage("on_dark").color;
    header.gameObject.SetActive(false);bind(reference,"HeaderTemplate",headerRef);
    var effect=node(templateRoot,"EffectTemplate",0,0,640,84);paint(effect,"inset_light",false);
    var effectRef=effect.GetComponent<ProjectY.UI.LuaReference>();if(effectRef==null)effectRef=effect.gameObject.AddComponent<ProjectY.UI.LuaReference>();
    bind(effectRef,"Root",effect);label(effectRef,effect,"Title",14,5,326,29,18);
    var description=label(effectRef,effect,"Description",14,36,437,44,14);description.color=muted;description.alignment=TextAnchor.UpperLeft;
    var price=label(effectRef,effect,"Price",330,6,127,23,13);price.alignment=TextAnchor.MiddleRight;price.color=muted;
    button(effectRef,effect,"Minus","TitleForgeDecrease",469,25,38,36);
    var rank=label(effectRef,effect,"Rank",510,26,76,34,17);rank.alignment=TextAnchor.MiddleCenter;
    button(effectRef,effect,"Plus","TitleForgeIncrease",588,25,38,36);
    effect.gameObject.SetActive(false);bind(reference,"EffectTemplate",effectRef);
    localize(reference,label(reference,page,"PreviewTitle",730,161,338,32,20),"TitleForgePreview");
    var preview=scroll(page,"PreviewScroll",730,206,338,330);bind(reference,"PreviewScroll",preview);
    box(preview.viewport,20,14,298,302);box(preview.content,0,0,298,302);
    var previewText=preview.content.GetComponent<UnityEngine.UI.Text>();if(previewText==null)previewText=preview.content.gameObject.AddComponent<UnityEngine.UI.Text>();
    previewText.font=font;previewText.fontSize=16;previewText.color=ink;previewText.alignment=TextAnchor.UpperLeft;previewText.supportRichText=false;
    previewText.horizontalOverflow=HorizontalWrapMode.Wrap;previewText.verticalOverflow=VerticalWrapMode.Overflow;previewText.raycastTarget=false;previewText.text="";
    bind(reference,"Preview",previewText);bind(reference,"PreviewContent",preview.content);
    label(reference,page,"PositiveCost",32,551,242,34,18);
    label(reference,page,"DiscountCost",284,551,230,34,18);
    label(reference,page,"TotalCost",530,551,240,34,22);
    button(reference,page,"Craft","TitleForgeCraft",838,553,230,48);
    var hint=label(reference,page,"Hint",32,607,1036,32,16);hint.color=muted;

    // Preserve the existing journal and add a direct entry alongside its equip action.
    var titles=(RectTransform)growthRef.Get("Titles");
    box(growthRef.GetText("TitleSummary").rectTransform,0,0,595,32);
    var reputation=label(growthRef,titles,"TitleReputation",600,0,268,32,18);reputation.alignment=TextAnchor.MiddleRight;
    var forgeRoot=node(titles,"TitleForge",660,330,208,35);var forgeImage=paint(forgeRoot,"button_accent",true);
    var forge=forgeRoot.GetComponent<UnityEngine.UI.Button>();if(forge==null)forge=forgeRoot.gameObject.AddComponent<UnityEngine.UI.Button>();
    forge.targetGraphic=forgeImage;forge.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};bind(growthRef,"TitleForge",forge);
    var forgeText=label(growthRef,forgeRoot,"TitleForgeText",5,0,198,35,17);forgeText.alignment=TextAnchor.MiddleCenter;
    localize(growthRef,forgeText,"TitleForgeOpen");
    var style=new UnityEditor.SerializedObject(growthRef.Get("Style"));var styleLabels=style.FindProperty("labels");
    foreach(var value in new[]{reputation,forgeText}){
        bool found=false;for(int i=0;i<styleLabels.arraySize;i++)if(styleLabels.GetArrayElementAtIndex(i).objectReferenceValue==value)found=true;
        if(!found){int index=styleLabels.arraySize;styleLabels.InsertArrayElementAtIndex(index);styleLabels.GetArrayElementAtIndex(index).objectReferenceValue=value;}
    }
    style.ApplyModifiedPropertiesWithoutUndo();
    reference.ValidateBindings();effectList.ValidateBindings();effectRef.ValidateBindings();headerRef.ValidateBindings();growthRef.ValidateBindings();
    definition.Prefab=UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,definition.PrefabPath);definition.Validate(true);
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(growth,growthDefinition.PrefabPath);
    ProjectY.Editor.LuaViewHints.Export(reference,definition.ViewType);ProjectY.Editor.LuaViewHints.Export(growthRef,growthDefinition.ViewType);
    if(newDefinition)config.Entries.Add(definition);
    UnityEditor.EditorUtility.SetDirty(config);UnityEditor.AssetDatabase.SaveAssetIfDirty(config);
    foreach(var pair in new[]{new{Root=root,Path=definition.PrefabPath},new{Root=growth,Path=growthDefinition.PrefabPath}}){
        var stale=new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>();foreach(var row in manifest)if((string)row["prefab"]==pair.Path)stale.Add(row);
        foreach(var row in stale)row.Remove();
        foreach(var entry in pair.Root.GetComponent<ProjectY.UI.LuaReference>().GetEditorLocalizations()){
            var parts=new System.Collections.Generic.List<string>();var target=entry.Target.transform;
            while(target!=pair.Root.transform){parts.Insert(0,target.name);target=target.parent;}
            var text=entry.Target as UnityEngine.UI.Text;var rich=entry.Target as TMPro.TMP_Text;
            manifest.Add(new Newtonsoft.Json.Linq.JObject{["prefab"]=pair.Path,["node"]=string.Join("/",parts.ToArray()),
                ["type"]=text!=null?"Text":"UITxt",["text"]=text!=null?text.text:rich.text,["id"]=entry.Id});
        }
    }
    System.IO.File.WriteAllText(manifestPath,manifest.ToString(Newtonsoft.Json.Formatting.Indented)+"\n",new System.Text.UTF8Encoding(false));
    return "Saved TitleForgePanel and CharacterGrowth entry, registry, explicit references, view hints and localization manifest.";
}finally{
    UnityEditor.PrefabUtility.UnloadPrefabContents(growth);
    if(existing!=null)UnityEditor.PrefabUtility.UnloadPrefabContents(root);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
