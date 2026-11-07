// Targeted native update; preserves the user's existing camp layout and bindings.
if(EditorApplication.isPlayingOrWillChangePlaymode||EditorApplication.isCompiling)throw new System.InvalidOperationException("Roster install requires idle Edit Mode.");
var path="Assets/DynamicAsset/UI/Prefabs/Camp/CampPanel.prefab";
var root=PrefabUtility.LoadPrefabContents(path);
try
{
    var panel=root.GetComponent<ProjectY.UI.CampPanelView>();var layout=panel.EditorLayout;
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    var texts=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
    var button=entries.Find(entry=>entry.Key=="Roster").Target as UnityEngine.UI.Button;
    if(button==null)
    {
        button=UnityEngine.Object.Instantiate(layout.Close,layout.Close.transform.parent,false);button.name="Roster";
        button.onClick=new UnityEngine.UI.Button.ButtonClickedEvent();
        var rect=(RectTransform)button.transform;rect.anchoredPosition=((RectTransform)layout.Close.transform).anchoredPosition+new Vector2(-332,0);
        entries.Add(new ProjectY.UI.LuaReference.Entry("Roster",button));
        texts.Add(new ProjectY.UI.LuaReference.LocalizedText(button.GetComponentInChildren<TMPro.TMP_Text>(true),"RosterTitle"));
    }
    var label=button.GetComponentInChildren<TMPro.TMP_Text>(true);label.name="RosterText";label.text=ProjectY.UI.LuaLanguage.Get("RosterTitle");
    reference.SetEditorBindings(entries.ToArray());reference.SetEditorLocalizations(texts.ToArray());reference.ValidateBindings();
    PrefabUtility.SaveAsPrefabAsset(root,path);
    foreach(var entry in entries)ProjectY.Editor.LuaViewHints.Register(entry.Target.GetType(),"CS."+entry.Target.GetType().FullName);
    ProjectY.Editor.LuaViewHints.Export(reference,"CampPanelView");
    return "Camp roster button and localization binding saved.";
}
finally{PrefabUtility.UnloadPrefabContents(root);}
