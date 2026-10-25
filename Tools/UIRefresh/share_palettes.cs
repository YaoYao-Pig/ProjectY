// Keep UI artwork source bindings on shared prefab assets rather than cloning 22 hidden Images per dialogue row.
var paths=new[]{"Adventure/CharacterGrowthPanel","Narrative/MissionJournalPanel","Narrative/DialogueEntryWidget","Adventure/StoryChoiceWidget"};
foreach(var relative in paths){
    var path="Assets/DynamicAsset/UI/Prefabs/"+relative+".prefab";
    var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try {
        var reference=root.GetComponent<ProjectY.UI.LuaReference>();
        var palettePath="Assets/DynamicAsset/UI/Skins/"+(root.name=="CharacterGrowthPanel"?"GuildClean":"CollageClean")+"/Palette.prefab";
        var palette=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(palettePath);
        if(palette==null){
            var source=UnityEngine.Object.Instantiate(reference.GetReference("Skin").gameObject);
            UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(source,root.scene);source.name="ArtSkinSources";
            bool saved;UnityEditor.PrefabUtility.SaveAsPrefabAsset(source,palettePath,out saved);UnityEngine.Object.DestroyImmediate(source);if(!saved)throw new System.Exception(palettePath);
            palette=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(palettePath);
        }
        var bindings=reference.GetEditorBindings().Where(e=>e.Key!="Skin").ToList();bindings.Add(new ProjectY.UI.LuaReference.Entry("Skin",palette.GetComponent<ProjectY.UI.LuaReference>()));reference.SetEditorBindings(bindings.ToArray());
        var ownSources=root.transform.Find("ArtSkinSources");if(ownSources!=null)UnityEngine.Object.DestroyImmediate(ownSources.gameObject);
        reference.ValidateBindings();bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path,out ok);if(!ok)throw new System.Exception(path);
    } finally {UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
return "4 Skin bindings now reference 2 shared read-only palette prefab assets; no extra source objects instantiated with rows.";
