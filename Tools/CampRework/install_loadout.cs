// Add the loadout entry and explicit preview references without rebuilding the camp UI.
if(EditorApplication.isPlayingOrWillChangePlaymode||EditorApplication.isCompiling)throw new System.InvalidOperationException("Loadout install requires idle Edit Mode.");
var path="Assets/DynamicAsset/UI/Prefabs/Camp/CampPanel.prefab";
var root=PrefabUtility.LoadPrefabContents(path);
try
{
    var panel=root.GetComponent<ProjectY.UI.CampPanelView>();var layout=panel.EditorLayout;
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    var texts=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
    var existing=entries.Find(entry=>entry.Key=="Loadout");
    var button=existing.Target as UnityEngine.UI.Button;
    if(button==null)
    {
        button=UnityEngine.Object.Instantiate(layout.Close,layout.Close.transform.parent,false);button.name="Loadout";
        button.onClick=new UnityEngine.UI.Button.ButtonClickedEvent();
        var rect=(RectTransform)button.transform;rect.anchoredPosition=((RectTransform)layout.Close.transform).anchoredPosition+new Vector2(-166,0);
        var label=button.GetComponentInChildren<TMPro.TMP_Text>(true);label.name="LoadoutText";label.text=ProjectY.UI.LuaLanguage.Get("CampLoadoutTitle");
        entries.Add(new ProjectY.UI.LuaReference.Entry("Loadout",button));
        texts.Add(new ProjectY.UI.LuaReference.LocalizedText(label,"CampLoadoutTitle"));
    }
    var buttonLabel=button.GetComponentInChildren<TMPro.TMP_Text>(true);buttonLabel.name="LoadoutText";buttonLabel.text=ProjectY.UI.LuaLanguage.Get("CampLoadoutTitle");
    var source=new SerializedObject(layout.Scene);
    var pawn=(ProjectY.Samples.PawnView)source.FindProperty("pawnPrefab").objectReferenceValue;
    var parts=new System.Collections.Generic.List<ProjectY.Samples.MapRuntimeDemo.AssetBinding>();
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"camp-loadout-assets-unused-"+System.Guid.NewGuid()+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try
        {
            using(var rows=(XLua.LuaTable)lua.DoString("local c=require('Config.ConfigSystem')();c:OnInit({services=Services});local out={};for _,r in ipairs(c:GetTable('PawnPartTable'):All()) do out[#out+1]={id=r.id,path=r.prefabPath} end;return out")[0])
            for(int i=1;i<=rows.Length;i++)using(var row=rows.Get<int,XLua.LuaTable>(i))
            {
                var assetPath=row.Get<string>("path");var asset=AssetDatabase.LoadAssetAtPath<GameObject>(assetPath);
                if(asset==null)throw new System.InvalidOperationException("Camp loadout animal part is missing: "+assetPath);
                parts.Add(new ProjectY.Samples.MapRuntimeDemo.AssetBinding{id=row.Get<int>("id"),path=assetPath,prefab=asset});
            }
        }
        finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
    layout.Preview.BindPawns(pawn,parts.ToArray());
    reference.SetEditorBindings(entries.ToArray());reference.SetEditorLocalizations(texts.ToArray());reference.ValidateBindings();
    PrefabUtility.SaveAsPrefabAsset(root,path);
    foreach(var entry in entries)ProjectY.Editor.LuaViewHints.Register(entry.Target.GetType(),"CS."+entry.Target.GetType().FullName);
    ProjectY.Editor.LuaViewHints.Export(reference,"CampPanelView");
    return "Camp loadout button, localization and animal preview references saved.";
}
finally{PrefabUtility.UnloadPrefabContents(root);}
