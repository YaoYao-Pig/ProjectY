// Unity MCP resource authoring: add a saved, localized GM switch without script refresh.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
ProjectY.UI.LuaLanguage.ReloadDefaults();
var entry=ProjectY.Editor.PanelAssets.LoadOrCreate().Get("GM");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(entry.PrefabPath);
try{
 var reference=root.GetComponent<ProjectY.UI.LuaReference>();
 var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
 var texts=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
 var frame=reference.GetText("Title").transform.parent;
 var dice=(UnityEngine.RectTransform)reference.GetButton("DiceOpen").transform;dice.sizeDelta=new UnityEngine.Vector2(230,36);
 reference.GetText("DiceOpenText").rectTransform.sizeDelta=new UnityEngine.Vector2(230,36);
 if(!bindings.Exists(row=>row.Key=="NoRandomEncounters")){
  var button=UnityEngine.Object.Instantiate(reference.GetButton("GrantSkill"),frame,false);button.name="NoRandomEncounters";
  var rect=(UnityEngine.RectTransform)button.transform;rect.anchoredPosition=new UnityEngine.Vector2(286,-408);rect.sizeDelta=new UnityEngine.Vector2(230,36);
  var caption=button.GetComponentInChildren<UnityEngine.UI.Text>();caption.rectTransform.sizeDelta=new UnityEngine.Vector2(230,36);
  caption.text=ProjectY.UI.LuaLanguage.Get("GMNoRandomEncountersOff");
  bindings.Add(new ProjectY.UI.LuaReference.Entry("NoRandomEncounters",button));bindings.Add(new ProjectY.UI.LuaReference.Entry("NoRandomEncountersText",caption));
  texts.Add(new ProjectY.UI.LuaReference.LocalizedText(caption,"GMNoRandomEncountersOff"));
  var hint=UnityEngine.Object.Instantiate(reference.GetText("RevealWorldHint"),frame,false);hint.name="NoRandomEncountersHint";
  hint.rectTransform.anchoredPosition=new UnityEngine.Vector2(24,-446);hint.rectTransform.sizeDelta=new UnityEngine.Vector2(492,22);
  hint.fontSize=12;hint.text=ProjectY.UI.LuaLanguage.Get("GMNoRandomEncountersHint");
  bindings.Add(new ProjectY.UI.LuaReference.Entry("NoRandomEncountersHint",hint));texts.Add(new ProjectY.UI.LuaReference.LocalizedText(hint,"GMNoRandomEncountersHint"));
 }
 // DiceSettings is the opaque second page and must remain above controls added to the main page.
 ((UnityEngine.RectTransform)reference.Get("DiceSettings")).SetAsLastSibling();
 reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(texts.ToArray());reference.ValidateBindings();
 UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,entry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return entry.PrefabPath;
