// Run through Unity MCP after configuration export and the concentrated C# compile.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required.");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var source=config.Get("TitleForge");
ProjectY.UI.PanelDefinition definition=null;
foreach(var row in config.Entries)if(row.Name=="SkillCraft")definition=row;
bool created=definition==null;
if(created)definition=new ProjectY.UI.PanelDefinition{Name="SkillCraft",Module="Adventure",Kind=ProjectY.UI.UIKind.Panel,
    Layer="Popup",Modal=true,ModalDimAlpha=.72f,Cache=true,CloseOnBack=true,PauseWorldOnOpen=true,CloseOnSceneChange=true};
if(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(definition.PrefabPath)==null)
    if(!UnityEditor.AssetDatabase.CopyAsset(source.PrefabPath,definition.PrefabPath))throw new System.Exception("Could not create craft panel.");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(definition.PrefabPath);
try
{
    root.name=definition.PrefabName;
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var language=new System.Collections.Generic.Dictionary<string,string>();
    foreach(var row in Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Localization/LuaTxt.json"))["rows"])
        language.Add((string)row["id"],(string)row["txt"]);
    var mapping=new System.Collections.Generic.Dictionary<string,string>{
        {"TitleForgeTitle","SkillCraftTitle"},{"TitleForgeClose","SkillCraftClose"},{"TitleForgeNameLabel","SkillCraftNameLabel"},
        {"TitleForgeNamePlaceholder","SkillCraftNamePlaceholder"},{"TitleForgePermanent","SkillCraftPermanent"},
        {"TitleForgePrimary","SkillCraftBodyTab"},{"TitleForgeCombat","SkillCraftElementTab"},{"TitleForgeLife","SkillCraftStatusTab"},
        {"TitleForgeSpecial","SkillCraftSavedTab"},{"TitleForgeNegative","SkillCraftNewTab"},{"TitleForgePreview","SkillCraftPreviewTitle"},
        {"TitleForgeCraft","SkillCraftCreate"},{"TitleForgeDecrease","SkillCraftRemove"},{"TitleForgeIncrease","SkillCraftSelect"}};
    foreach(var owner in root.GetComponentsInChildren<ProjectY.UI.LuaReference>(true))
    {
        var entries=owner.GetEditorLocalizations();
        for(int i=0;i<entries.Length;i++)
        {
            string id;if(mapping.TryGetValue(entries[i].Id,out id))entries[i].Id=id;
            if(entries[i].Target is UnityEngine.UI.Text) ((UnityEngine.UI.Text)entries[i].Target).text=language[entries[i].Id];
        }
        owner.SetEditorLocalizations(entries);owner.ValidateBindings();
    }
    // Every item is a selectable material; labels remain serialized components.
    var rowReference=reference.GetReference("EffectTemplate");
    System.Action<RectTransform,float,float,float,float> box=(rect,x,y,w,h)=>{
        rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(w,h);};
    box((RectTransform)rowReference.Get("Root"),0,0,640,110);
    box(rowReference.GetText("Title").rectTransform,14,5,430,27);
    var price=rowReference.GetText("Price");price.fontSize=12;price.alignment=TextAnchor.UpperLeft;
    box(price.rectTransform,14,33,430,32);
    var description=rowReference.GetText("Description");description.fontSize=13;
    description.resizeTextForBestFit=true;description.resizeTextMinSize=10;description.resizeTextMaxSize=13;
    box(description.rectTransform,14,67,430,37);
    box((RectTransform)rowReference.Get("Minus").transform,458,35,62,36);
    box(rowReference.GetText("MinusText").rectTransform,1,0,60,36);rowReference.GetText("MinusText").fontSize=14;
    box(rowReference.GetText("Rank").rectTransform,522,36,49,34);rowReference.GetText("Rank").fontSize=13;
    box((RectTransform)rowReference.Get("Plus").transform,572,35,62,36);
    box(rowReference.GetText("PlusText").rectTransform,1,0,60,36);rowReference.GetText("PlusText").fontSize=14;
    foreach(var key in new[]{"PositiveCost","DiscountCost","TotalCost"}){
        var label=reference.GetText(key);label.fontSize=15;label.resizeTextForBestFit=true;label.resizeTextMinSize=11;label.resizeTextMaxSize=15;}
    reference.GetInputField("Name").characterLimit=32;
    definition.Prefab=UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,definition.PrefabPath);
    definition.Validate(true);if(created)config.Entries.Add(definition);
    UnityEditor.EditorUtility.SetDirty(config);UnityEditor.AssetDatabase.SaveAssetIfDirty(config);
    ProjectY.Editor.LuaViewHints.Export(reference,definition.ViewType);
    var manifestPath="Art/Localization/ui-text-bindings.json";
    var manifest=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(manifestPath));
    var stale=new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>();
    foreach(var row in manifest)if((string)row["prefab"]==definition.PrefabPath)stale.Add(row);
    foreach(var row in stale)row.Remove();
    foreach(var owner in root.GetComponentsInChildren<ProjectY.UI.LuaReference>(true))foreach(var entry in owner.GetEditorLocalizations())
    {
        var text=entry.Target as UnityEngine.UI.Text;if(text==null)continue;
        var parts=new System.Collections.Generic.List<string>();var target=entry.Target.transform;
        while(target!=root.transform){parts.Insert(0,target.name);target=target.parent;}
        manifest.Add(new Newtonsoft.Json.Linq.JObject{["prefab"]=definition.PrefabPath,["node"]=string.Join("/",parts.ToArray()),["type"]="Text",["text"]=text.text,["id"]=entry.Id});
    }
    System.IO.File.WriteAllText(manifestPath,manifest.ToString(Newtonsoft.Json.Formatting.Indented)+"\n",new System.Text.UTF8Encoding(false));
    return "Saved SkillCraft prefab, registry, bindings, localization and view hints.";
}
finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
