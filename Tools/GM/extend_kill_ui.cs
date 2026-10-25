// Run through Unity MCP to author the saved GM controls; no runtime component searches.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
ProjectY.UI.LuaLanguage.ReloadDefaults();
var entry=ProjectY.Editor.PanelAssets.LoadOrCreate().Get("GM");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(entry.PrefabPath);
try{
 var reference=root.GetComponent<ProjectY.UI.LuaReference>();
 var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
 var texts=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
 var frame=reference.GetText("Title").transform.parent;
 reference.GetText("RevealWorldHint").rectTransform.sizeDelta=new UnityEngine.Vector2(230,64);
 if(!bindings.Exists(row=>row.Key=="KillTarget")){
  var button=UnityEngine.Object.Instantiate(reference.GetButton("GrantSkill"),frame,false);button.name="KillTarget";
  ((UnityEngine.RectTransform)button.transform).anchoredPosition=new UnityEngine.Vector2(286,-470);
  var caption=button.GetComponentInChildren<UnityEngine.UI.Text>();caption.text=ProjectY.UI.LuaLanguage.Get("UIGMKillTargetText");
  bindings.Add(new ProjectY.UI.LuaReference.Entry("KillTarget",button));bindings.Add(new ProjectY.UI.LuaReference.Entry("KillTargetText",caption));
  texts.Add(new ProjectY.UI.LuaReference.LocalizedText(caption,"UIGMKillTargetText"));
  var hint=UnityEngine.Object.Instantiate(reference.GetText("RevealWorldHint"),frame,false);hint.name="KillTargetHint";
  hint.rectTransform.anchoredPosition=new UnityEngine.Vector2(286,-514);hint.text=ProjectY.UI.LuaLanguage.Get("UIGMKillTargetHint");
  bindings.Add(new ProjectY.UI.LuaReference.Entry("KillTargetHint",hint));texts.Add(new ProjectY.UI.LuaReference.LocalizedText(hint,"UIGMKillTargetHint"));
 }
 reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(texts.ToArray());reference.ValidateBindings();
 reference.GetText("KillTargetHint").text=ProjectY.UI.LuaLanguage.Get("UIGMKillTargetHint");
 UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,entry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return entry.PrefabPath;
