if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var folder="Assets/DynamicAsset/UI/Skins/CollageMatte/Rewards";
if(!UnityEditor.AssetDatabase.IsValidFolder(folder))UnityEditor.AssetDatabase.CreateFolder("Assets/DynamicAsset/UI/Skins/CollageMatte","Rewards");
var manifest=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Art/UIRefresh/2026-10-25/matte/rewards/manifest.json"));
var sprites=new System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>();
foreach(var row in manifest["slices"]){
    var name=(string)row["name"];var path=folder+"/"+name+".png";
    System.IO.File.Copy("Art/UIRefresh/2026-10-25/matte/rewards/slices/"+name+".png",path,true);UnityEditor.AssetDatabase.ImportAsset(path,UnityEditor.ImportAssetOptions.ForceSynchronousImport);
    var importer=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(path);importer.textureType=UnityEditor.TextureImporterType.Sprite;importer.spriteImportMode=UnityEditor.SpriteImportMode.Single;
    importer.spritePixelsPerUnit=500;importer.npotScale=UnityEditor.TextureImporterNPOTScale.None;importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.textureCompression=UnityEditor.TextureImporterCompression.Uncompressed;importer.filterMode=UnityEngine.FilterMode.Bilinear;importer.wrapMode=UnityEngine.TextureWrapMode.Clamp;
    var b=row["border"];var border=new UnityEngine.Vector4((float)b[0],(float)b[1],(float)b[2],(float)b[3]);
    if(name=="card_background"){border.y=UnityEngine.Mathf.Floor((float)row["height"]*.5f);border.w=(float)row["height"]-border.y;}
    importer.spriteBorder=border;importer.SaveAndReimport();sprites.Add(name,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Sprite>(path));
}
var widgetPath="Assets/DynamicAsset/UI/Prefabs/Narrative/MissionRewardWidget.prefab";
var widget=UnityEditor.PrefabUtility.LoadPrefabContents(widgetPath);
try{
    var r=widget.GetComponent<ProjectY.UI.LuaReference>();var entries=r.GetEditorBindings().Where(e=>e.Key!="Background"&&e.Key!="Badge").ToList();
    entries.Add(new ProjectY.UI.LuaReference.Entry("Background",widget.GetComponent<UnityEngine.UI.Image>()));entries.Add(new ProjectY.UI.LuaReference.Entry("Badge",widget.transform.Find("Badge").GetComponent<UnityEngine.UI.Image>()));r.SetEditorBindings(entries.ToArray());r.ValidateBindings();
    bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(widget,widgetPath,out ok);if(!ok)throw new System.Exception(widgetPath);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(widget);}
var panelPath="Assets/DynamicAsset/UI/Prefabs/Narrative/MissionJournalPanel.prefab";
var panel=UnityEditor.PrefabUtility.LoadPrefabContents(panelPath);
try{
    var node=new UnityEngine.GameObject("RewardArtPalette",typeof(UnityEngine.RectTransform),typeof(ProjectY.UI.LuaReference));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(node,panel.scene);
    var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>();
    foreach(var pair in sprites){var item=new UnityEngine.GameObject(pair.Key,typeof(UnityEngine.RectTransform),typeof(UnityEngine.UI.Image));item.transform.SetParent(node.transform,false);var image=item.GetComponent<UnityEngine.UI.Image>();image.sprite=pair.Value;image.raycastTarget=false;entries.Add(new ProjectY.UI.LuaReference.Entry(pair.Key,image));}
    node.GetComponent<ProjectY.UI.LuaReference>().SetEditorBindings(entries.ToArray());node.SetActive(false);bool ok;var palettePath=folder+"/Palette.prefab";UnityEditor.PrefabUtility.SaveAsPrefabAsset(node,palettePath,out ok);UnityEngine.Object.DestroyImmediate(node);if(!ok)throw new System.Exception(palettePath);
    var source=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(palettePath).GetComponent<ProjectY.UI.LuaReference>();
    var r=panel.GetComponent<ProjectY.UI.LuaReference>();var panelEntries=r.GetEditorBindings().Where(e=>e.Key!="RewardSkin").ToList();panelEntries.Add(new ProjectY.UI.LuaReference.Entry("RewardSkin",source));r.SetEditorBindings(panelEntries.ToArray());r.ValidateBindings();
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(panel,panelPath,out ok);if(!ok)throw new System.Exception(panelPath);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(panel);}
return "8 reward art assets imported; only MissionJournal instances apply them. Shared reward rendering logic, numeric values and configured item icons preserved.";
