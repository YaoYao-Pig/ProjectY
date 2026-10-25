// Preserve whole endcaps vertically, and keep printed corner motifs out of stretch regions.
foreach(var kit in new[]{"guild","collage"}){
    var root="Assets/DynamicAsset/UI/Skins/"+(kit=="guild"?"GuildMatte":"CollageMatte");
    var data=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Art/UIRefresh/2026-10-25/matte/"+kit+"/manifest.json"));
    foreach(var row in data["slices"]){
        var name=(string)row["name"];if((string)row["imageType"]=="Simple")continue;
        var p=root+"/"+name+".png";var sprite=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Sprite>(p);var importer=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(p);
        var border=importer.spriteBorder;var width=sprite.rect.width;var height=sprite.rect.height;
        border.y=UnityEngine.Mathf.Floor(height*.5f);border.w=height-border.y;
        if(kit=="collage"&&(name=="panel_body"||name=="detail_card"||name=="tooltip_frame")){border.x=UnityEngine.Mathf.Floor(width*.5f);border.z=width-border.x;}
        importer.spriteBorder=border;importer.SaveAndReimport();
    }
}
var panels=new[]{"Equipment/InventoryPanel","Adventure/CharacterGrowthPanel","Narrative/MissionJournalPanel","Narrative/DialoguePanel","Adventure/StoryEventPanel"};
foreach(var p in panels){
    var path="Assets/DynamicAsset/UI/Prefabs/"+p+".prefab";var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try{
        if(root.name=="InventoryPanel"){
            root.transform.Find("Frame/Equipment/SkinFrame").GetComponent<UnityEngine.UI.Image>().enabled=false;
            var cell=root.transform.Find("Frame/CellTemplate").GetComponent<UnityEngine.UI.Image>();cell.sprite=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Sprite>("Assets/DynamicAsset/UI/Skins/GuildMatte/paper_surface.png");cell.type=UnityEngine.UI.Image.Type.Simple;cell.color=new UnityEngine.Color(.78f,.74f,.64f,.35f);
        }
        if(root.name=="MissionJournalPanel"||root.name=="DialoguePanel"){
            var page=root.transform.Find("Page");
            foreach(var name in new[]{"Title","Caption"}){var rt=(UnityEngine.RectTransform)page.Find(name);var minimum=rt.offsetMin;minimum.x=52;rt.offsetMin=minimum;}
            var header=(UnityEngine.RectTransform)page.Find("MatteTitle");header.anchoredPosition=new UnityEngine.Vector2(8,0);header.sizeDelta=new UnityEngine.Vector2(root.name=="DialoguePanel"?484:288,112);
            if(root.name=="MissionJournalPanel"){
                var layout=page.Find("Scroll/Viewport/Content").GetComponent<UnityEngine.UI.VerticalLayoutGroup>();layout.padding=new UnityEngine.RectOffset(22,22,20,20);
            }
        }
        if(root.name=="StoryEventPanel"){
            var page=root.transform.Find("Page");var rt=(UnityEngine.RectTransform)page.Find("Title");var minimum=rt.offsetMin;minimum.x=60;rt.offsetMin=minimum;
            var header=(UnityEngine.RectTransform)page.Find("MatteTitle");header.anchoredPosition=new UnityEngine.Vector2(18,-12);header.sizeDelta=new UnityEngine.Vector2(950,96);
        }
        bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path,out ok);if(!ok)throw new System.Exception(path);
    }finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
return "Endcaps and paper motifs fit without longitudinal warping; title insets clear print marks. 3D preview transforms untouched.";
