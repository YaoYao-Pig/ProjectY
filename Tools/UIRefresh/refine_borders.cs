// Appearance-only follow-up after viewing native UI captures. No transforms/bindings/data are changed.
var paths=new[]{"Equipment/InventoryPanel","Adventure/CharacterGrowthPanel","Narrative/MissionJournalPanel","Narrative/DialoguePanel","Adventure/StoryEventPanel","Narrative/DialogueEntryWidget","Adventure/StoryChoiceWidget"};
foreach(var relative in paths){
    var path="Assets/DynamicAsset/UI/Prefabs/"+relative+".prefab";
    var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try {
        foreach(var button in root.GetComponentsInChildren<UnityEngine.UI.Button>(true))if(button.image!=null)button.image.pixelsPerUnitMultiplier=4;
        if(root.name=="InventoryPanel"){
            var cell=root.transform.Find("Frame/CellTemplate").GetComponent<UnityEngine.UI.Image>();
            cell.sprite=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Sprite>("Assets/DynamicAsset/UI/Skins/GuildClean/slot_frame.png");cell.pixelsPerUnitMultiplier=6;
            root.transform.Find("Frame/ItemTemplate/SkinFrame").GetComponent<UnityEngine.UI.Image>().pixelsPerUnitMultiplier=6;
            root.transform.Find("Frame/Equipment/SkinFrame").GetComponent<UnityEngine.UI.Image>().pixelsPerUnitMultiplier=6;
            root.transform.Find("Frame/Details").GetComponent<UnityEngine.UI.Image>().color=new UnityEngine.Color(.64f,.78f,.74f,1);
        }
        if(root.name=="StoryEventPanel")root.transform.Find("Page/ChoicesScroll").GetComponent<UnityEngine.UI.Image>().color=UnityEngine.Color.clear;
        bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path,out ok);if(!ok)throw new System.Exception(path);
    } finally {UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
return "Refined small control borders and event choice backing; no hierarchy or controller changes.";
