// Image is also an ILayoutElement. Keep source pixel dimensions from inflating flexible rows.
var roots=new[]{"Assets/DynamicAsset/UI/Skins/GuildMatte","Assets/DynamicAsset/UI/Skins/CollageMatte"};
foreach(var folder in roots){
    foreach(var guid in UnityEditor.AssetDatabase.FindAssets("t:Sprite",new[]{folder})){
        var path=UnityEditor.AssetDatabase.GUIDToAssetPath(guid);if(path.EndsWith("_surface.png"))continue;
        var importer=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(path);importer.spritePixelsPerUnit=500;
        if(path.EndsWith("/inventory_slot_selected.png")&&folder.EndsWith("GuildMatte"))importer.spriteBorder=new UnityEngine.Vector4(55,55,55,55);
        importer.SaveAndReimport();
    }
}
foreach(var folder in roots){
    var path=folder+"/Palette.prefab";var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try{if(folder.EndsWith("CollageMatte"))root.GetComponent<ProjectY.UI.LuaReference>().GetImage("panel_light").sprite=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Sprite>(folder+"/detail_card.png");bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path,out ok);if(!ok)throw new System.Exception(path);}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
foreach(var relative in new[]{"Equipment/InventoryPanel","Adventure/CharacterGrowthPanel","Narrative/MissionJournalPanel","Narrative/DialoguePanel","Adventure/StoryEventPanel","Narrative/DialogueEntryWidget","Adventure/StoryChoiceWidget"}){
    var path="Assets/DynamicAsset/UI/Prefabs/"+relative+".prefab";var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try{
        foreach(var image in root.GetComponentsInChildren<UnityEngine.UI.Image>(true)){
            if(image.sprite==null)continue;var spritePath=UnityEditor.AssetDatabase.GetAssetPath(image.sprite);
            if((spritePath.StartsWith(roots[0])||spritePath.StartsWith(roots[1]))&&!spritePath.EndsWith("_surface.png"))image.pixelsPerUnitMultiplier/=5;
        }
        if(root.name=="InventoryPanel")root.transform.Find("Frame/ItemTemplate/SkinFrame").GetComponent<UnityEngine.UI.Image>().pixelsPerUnitMultiplier=1.6f;
        bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path,out ok);if(!ok)throw new System.Exception(path);
    }finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
return "Matte sprites use 500 PPU; visual border sizes retained, flexible rows use text/layout height rather than source pixel height.";
