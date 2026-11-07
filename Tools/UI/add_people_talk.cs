// Unity MCP execute_code body. Run after exporting PeopleDialogue language keys.
// Saves only UnitDetails, its generated view hints and its localization manifest entries.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var definition=config.Get("UnitDetails");
var language=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Localization/LuaTxt.json"));
var text=System.Linq.Enumerable.FirstOrDefault(language["rows"],row=>(string)row["id"]=="PeopleDialogueTalk");
if(text==null||string.IsNullOrEmpty((string)text["txt"]))throw new System.InvalidOperationException("Export PeopleDialogueTalk first");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(definition.PrefabPath);
try{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    var existing=bindings.Find(entry=>entry.Key=="Talk");
    UnityEngine.UI.Button button;
    if(existing.Target==null){
        var source=(UnityEngine.UI.Button)reference.Get("Observe");
        var clone=UnityEngine.Object.Instantiate(source.gameObject,reference.Get("Page").transform,false);
        clone.name="Talk";button=clone.GetComponent<UnityEngine.UI.Button>();
    }else button=(UnityEngine.UI.Button)existing.Target;
    var rect=(RectTransform)button.transform;
    rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(0,1);
    rect.anchoredPosition=new Vector2(900,-98);rect.sizeDelta=new Vector2(172,40);
    var caption=button.GetComponentInChildren<ProjectY.UI.UITxt>(true);
    if(caption==null)throw new System.InvalidOperationException("UnitDetails button requires UITxt");
    caption.name="TalkText";caption.DefaultText=(string)text["txt"];
    caption.rectTransform.anchorMin=caption.rectTransform.anchorMax=caption.rectTransform.pivot=new Vector2(0,1);
    caption.rectTransform.anchoredPosition=new Vector2(5,0);caption.rectTransform.sizeDelta=new Vector2(162,40);
    reference.GetUITxt("TargetName").rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal,570);
    bindings.RemoveAll(entry=>entry.Key=="Talk"||entry.Key=="TalkText");
    bindings.Add(new ProjectY.UI.LuaReference.Entry("Talk",button));
    bindings.Add(new ProjectY.UI.LuaReference.Entry("TalkText",caption));
    reference.SetEditorBindings(bindings.ToArray());
    var localizations=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
    localizations.RemoveAll(entry=>entry.Target==caption);
    localizations.Add(new ProjectY.UI.LuaReference.LocalizedText(caption,"PeopleDialogueTalk"));
    reference.SetEditorLocalizations(localizations.ToArray());
    var style=(ProjectY.UI.NarrativeView)reference.Get("Style");
    var serialized=new UnityEditor.SerializedObject(style);var labels=serialized.FindProperty("richLabels");
    bool registered=false;for(int i=0;i<labels.arraySize;i++)if(labels.GetArrayElementAtIndex(i).objectReferenceValue==caption)registered=true;
    if(!registered){labels.InsertArrayElementAtIndex(labels.arraySize);labels.GetArrayElementAtIndex(labels.arraySize-1).objectReferenceValue=caption;}
    serialized.ApplyModifiedPropertiesWithoutUndo();
    reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,definition.PrefabPath);
    ProjectY.Editor.LuaViewHints.Export(reference,definition.ViewType);
    var manifestPath="Art/Localization/ui-text-bindings.json";
    var manifest=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(manifestPath));
    var remove=new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>();
    foreach(var row in manifest)if((string)row["prefab"]==definition.PrefabPath&&(string)row["node"]=="Page/Talk/TalkText")remove.Add(row);
    foreach(var row in remove)row.Remove();
    manifest.Add(new Newtonsoft.Json.Linq.JObject{["prefab"]=definition.PrefabPath,["node"]="Page/Talk/TalkText",
        ["type"]="UITxt",["text"]=(string)text["txt"],["id"]="PeopleDialogueTalk"});
    System.IO.File.WriteAllText(manifestPath,manifest.ToString(Newtonsoft.Json.Formatting.Indented)+"\n",new System.Text.UTF8Encoding(false));
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return "Saved UnitDetails Talk button, preserved Observe, and exported explicit bindings/localization/view hints.";
