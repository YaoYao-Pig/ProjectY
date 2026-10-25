// Unity MCP resource authoring only; save explicit component and language bindings on the existing GM prefab.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
ProjectY.UI.LuaLanguage.ReloadDefaults();
var entry=ProjectY.Editor.PanelAssets.LoadOrCreate().Get("GM");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(entry.PrefabPath);
try{
 var reference=root.GetComponent<ProjectY.UI.LuaReference>();
 var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
 var texts=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
 var frame=reference.GetText("Title").transform.parent;
 if(!bindings.Exists(row=>row.Key=="RevealWorld")){
  var button=UnityEngine.Object.Instantiate(reference.GetButton("GrantSkill"),frame,false);button.name="RevealWorld";
  ((UnityEngine.RectTransform)button.transform).anchoredPosition=new UnityEngine.Vector2(24,-470);
  var caption=button.GetComponentInChildren<UnityEngine.UI.Text>();caption.text=ProjectY.UI.LuaLanguage.Get("UIGMRevealWorldText");
  bindings.Add(new ProjectY.UI.LuaReference.Entry("RevealWorld",button));bindings.Add(new ProjectY.UI.LuaReference.Entry("RevealWorldText",caption));
  texts.Add(new ProjectY.UI.LuaReference.LocalizedText(caption,"UIGMRevealWorldText"));
  var hint=UnityEngine.Object.Instantiate(reference.GetText("NpcHint"),frame,false);hint.name="RevealWorldHint";
  hint.rectTransform.anchoredPosition=new UnityEngine.Vector2(24,-514);hint.rectTransform.sizeDelta=new UnityEngine.Vector2(492,52);
  hint.text=ProjectY.UI.LuaLanguage.Get("UIGMRevealWorldHint");
  bindings.Add(new ProjectY.UI.LuaReference.Entry("RevealWorldHint",hint));texts.Add(new ProjectY.UI.LuaReference.LocalizedText(hint,"UIGMRevealWorldHint"));
 }
 reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(texts.ToArray());reference.ValidateBindings();
 reference.GetText("RevealWorldText").text=ProjectY.UI.LuaLanguage.Get("UIGMRevealWorldText");
 reference.GetText("RevealWorldHint").text=ProjectY.UI.LuaLanguage.Get("UIGMRevealWorldHint");
 UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,entry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return entry.PrefabPath;
