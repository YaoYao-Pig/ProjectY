// Native asset-only migration. Execute through Unity MCP; never rebuilds a panel or its 3D preview.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling) throw new System.Exception("Idle Edit Mode required");
var artRoot="Art/UIRefresh/2026-10-25";
var spriteRoot="Assets/DynamicAsset/UI/Skins";
System.Action<string> folder=null;
folder=path=>{if(UnityEditor.AssetDatabase.IsValidFolder(path))return;var parent=path.Substring(0,path.LastIndexOf('/'));folder(parent);UnityEditor.AssetDatabase.CreateFolder(parent,path.Substring(path.LastIndexOf('/')+1));};
folder(spriteRoot);
var kits=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>>();
foreach(var kitName in new[]{"guild-clean","collage-clean"}) {
    var nativeName=kitName=="guild-clean"?"GuildClean":"CollageClean";
    folder(spriteRoot+"/"+nativeName);
    var manifest=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(artRoot+"/"+kitName+"/manifest.json"));
    var sprites=new System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>();
    foreach(var slice in manifest["slices"]) {
        var name=(string)slice["name"];
        var destination=spriteRoot+"/"+nativeName+"/"+name+".png";
        System.IO.File.Copy(artRoot+"/"+kitName+"/slices/"+name+".png",destination,true);
        UnityEditor.AssetDatabase.ImportAsset(destination,UnityEditor.ImportAssetOptions.ForceSynchronousImport);
        var importer=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(destination);
        importer.textureType=UnityEditor.TextureImporterType.Sprite;
        importer.spriteImportMode=UnityEditor.SpriteImportMode.Single;
        importer.alphaIsTransparency=true;importer.mipmapEnabled=false;importer.sRGBTexture=true;
        importer.textureCompression=UnityEditor.TextureImporterCompression.Uncompressed;
        importer.filterMode=UnityEngine.FilterMode.Bilinear;importer.wrapMode=UnityEngine.TextureWrapMode.Clamp;
        importer.npotScale=UnityEditor.TextureImporterNPOTScale.None;importer.maxTextureSize=2048;importer.spritePixelsPerUnit=100;
        var border=slice["suggestedSpriteBorder_LBRT"]??slice["suggestedNineSliceBorders"];
        if(border==null)throw new System.Exception("Missing sprite border: "+name);
        importer.spriteBorder=new UnityEngine.Vector4((float)border[0],(float)border[1],(float)border[2],(float)border[3]);
        importer.SaveAndReimport();
        var sprite=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Sprite>(destination);
        if(sprite==null)throw new System.Exception("Sprite import failed: "+destination);
        sprites.Add(name,sprite);
    }
    if(sprites.Count!=16)throw new System.Exception("Expected 16 skin parts");
    kits.Add(kitName,sprites);
}
System.Func<string,UnityEngine.Color> color=hex=>{UnityEngine.Color result;if(!UnityEngine.ColorUtility.TryParseHtmlString(hex,out result))throw new System.Exception("Invalid color");return result;};
System.Action<UnityEngine.UI.Image,System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>,string> paint=(image,kit,key)=>{
    if(image==null)throw new System.Exception("Missing Image for "+key);
    image.sprite=kit[key];image.overrideSprite=null;image.type=UnityEngine.UI.Image.Type.Sliced;image.color=UnityEngine.Color.white;image.pixelsPerUnitMultiplier=2;
};
System.Func<UnityEngine.GameObject,string,UnityEngine.RectTransform> rect=(root,path)=>{
    var value=root.transform.Find(path) as UnityEngine.RectTransform;if(value==null)throw new System.Exception(root.name+": missing "+path);return value;
};
System.Action<UnityEngine.GameObject,string,System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>,string> surface=(root,path,kit,key)=>paint(rect(root,path).GetComponent<UnityEngine.UI.Image>(),kit,key);
System.Action<UnityEngine.GameObject,System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>,bool> buttons=(root,kit,guild)=>{
    foreach(var button in root.GetComponentsInChildren<UnityEngine.UI.Button>(true)) {
        var image=button.image;if(image==null)continue;
        var path=UnityEditor.AnimationUtility.CalculateTransformPath(button.transform,root.transform);
        if(path.Contains("HealthPart"))continue;
        bool main=button.name=="Invest"||button.name=="Equip"||button.name=="PrimaryAction"||button.name=="Continue";
        paint(image,kit,main?"button_accent":"button_light");image.pixelsPerUnitMultiplier=4;
        var colors=button.colors;colors.normalColor=UnityEngine.Color.white;colors.highlightedColor=new UnityEngine.Color(1.04f,1.04f,1.04f,1);colors.pressedColor=new UnityEngine.Color(.88f,.88f,.88f,1);colors.selectedColor=UnityEngine.Color.white;colors.disabledColor=new UnityEngine.Color(.8f,.8f,.8f,.7f);colors.colorMultiplier=1;colors.fadeDuration=.08f;button.colors=colors;button.transition=UnityEngine.UI.Selectable.Transition.ColorTint;
        foreach(var text in button.GetComponentsInChildren<UnityEngine.UI.Text>(true))text.color=main?color("#F5F0E4"):color(guild?"#293A32":"#233E45");
        foreach(var text in button.GetComponentsInChildren<TMPro.TMP_Text>(true))text.color=main?color("#F5F0E4"):color(guild?"#293A32":"#233E45");
    }
};
var palettes=new System.Collections.Generic.Dictionary<bool,ProjectY.UI.LuaReference>();
System.Action<UnityEngine.GameObject,System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>,bool> bindPalette=(root,kit,guild)=>{
    if(!palettes.ContainsKey(guild)) {
    var node=new UnityEngine.GameObject("ArtSkinSources",typeof(UnityEngine.RectTransform),typeof(ProjectY.UI.LuaReference));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(node,root.scene);
    var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>();
    var colors=new System.Collections.Generic.Dictionary<string,UnityEngine.Color>{
        {"ink",color(guild?"#293A32":"#233E45")},{"muted",color(guild?"#64685C":"#65757A")},{"accent_ink",color(guild?"#40594A":"#9F4836")},
        {"on_accent",color("#FFF7E9")},{"disabled_ink",color("#737C78")},{"on_dark",color("#F2EBDD")}
    };
    foreach(var key in kit.Keys.Concat(colors.Keys)) {
        var child=node.transform.Find(key);UnityEngine.GameObject item;
        if(child==null){item=new UnityEngine.GameObject(key,typeof(UnityEngine.RectTransform),typeof(UnityEngine.UI.Image));item.transform.SetParent(node.transform,false);}else item=child.gameObject;
        var image=item.GetComponent<UnityEngine.UI.Image>();image.raycastTarget=false;
        if(kit.ContainsKey(key)){image.sprite=kit[key];image.color=UnityEngine.Color.white;}else image.color=colors[key];
        entries.Add(new ProjectY.UI.LuaReference.Entry(key,image));
    }
    var skin=node.GetComponent<ProjectY.UI.LuaReference>();skin.SetEditorBindings(entries.ToArray());skin.ValidateBindings();node.SetActive(false);
    var palettePath=spriteRoot+"/"+(guild?"GuildClean":"CollageClean")+"/Palette.prefab";
    bool saved;UnityEditor.PrefabUtility.SaveAsPrefabAsset(node,palettePath,out saved);UnityEngine.Object.DestroyImmediate(node);if(!saved)throw new System.Exception(palettePath);
    palettes.Add(guild,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(palettePath).GetComponent<ProjectY.UI.LuaReference>());
    }
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();var bindings=reference.GetEditorBindings().Where(e=>e.Key!="Skin").ToList();bindings.Add(new ProjectY.UI.LuaReference.Entry("Skin",palettes[guild]));reference.SetEditorBindings(bindings.ToArray());
    var oldSources=root.transform.Find("ArtSkinSources");if(oldSources!=null)UnityEngine.Object.DestroyImmediate(oldSources.gameObject);
};
System.Action<UnityEngine.GameObject,string,string,System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>,string> frame=(root,parentPath,name,kit,key)=>{
    var parent=rect(root,parentPath);var old=parent.Find(name);UnityEngine.GameObject node;
    if(old==null){node=new UnityEngine.GameObject(name,typeof(UnityEngine.RectTransform),typeof(UnityEngine.UI.Image));node.transform.SetParent(parent,false);}else node=old.gameObject;
    var r=(UnityEngine.RectTransform)node.transform;r.anchorMin=UnityEngine.Vector2.zero;r.anchorMax=UnityEngine.Vector2.one;r.offsetMin=r.offsetMax=UnityEngine.Vector2.zero;
    var image=node.GetComponent<UnityEngine.UI.Image>();paint(image,kit,key);image.pixelsPerUnitMultiplier=6;image.raycastTarget=false;
};
var targets=new[]{
    "Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Narrative/MissionJournalPanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Narrative/DialoguePanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Adventure/StoryEventPanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Narrative/DialogueEntryWidget.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Adventure/StoryChoiceWidget.prefab"
};
var saved=new System.Collections.Generic.List<string>();
foreach(var path in targets) {
    var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try {
        bool guild=root.name=="InventoryPanel"||root.name=="CharacterGrowthPanel";
        var kit=kits[guild?"guild-clean":"collage-clean"];
        var reference=root.GetComponent<ProjectY.UI.LuaReference>();
        if(root.name=="InventoryPanel") {
            surface(root,"Frame",kit,"panel_light");surface(root,"Frame/Bag",kit,"inset_light");surface(root,"Frame/Details",kit,"panel_dark");
            surface(root,"Frame/CellTemplate",kit,"slot_frame");rect(root,"Frame/CellTemplate").GetComponent<UnityEngine.UI.Image>().pixelsPerUnitMultiplier=6;
            rect(root,"Frame/Details").GetComponent<UnityEngine.UI.Image>().color=new UnityEngine.Color(.64f,.78f,.74f,1);
            frame(root,"Frame/ItemTemplate","SkinFrame",kit,"slot_frame");root.transform.Find("Frame/ItemTemplate/SkinFrame").SetAsLastSibling();
            frame(root,"Frame/Equipment","SkinFrame",kit,"slot_frame");root.transform.Find("Frame/Equipment/SkinFrame").SetSiblingIndex(1);
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true)) {
                var p=UnityEditor.AnimationUtility.CalculateTransformPath(text.transform,root.transform);
                if(p.StartsWith("Frame/Equipment/CharacterPreview/"))continue;
                if(p.StartsWith("Frame/Details/"))text.color=color("#F1EBDD");
                else if(p.StartsWith("Frame/Equipment/HealthOverlay/"))continue;
                else text.color=color("#293A32");
            }
            buttons(root,kit,true);
            // Preserve all preview transforms/components; only skin the pre-existing 2D equipment slot Images.
            foreach(var binding in reference.GetEditorBindings().Where(e=>e.Key.StartsWith("Slot_")&&e.Target is UnityEngine.UI.Button)) {
                var button=(UnityEngine.UI.Button)binding.Target;paint(button.image,kit,"inset_light");button.image.pixelsPerUnitMultiplier=4;
            }
        } else if(root.name=="CharacterGrowthPanel") {
            surface(root,"Page",kit,"panel_light");surface(root,"Page/Hero",kit,"panel_dark");
            surface(root,"Page/Skills/GraphScroll",kit,"inset_light");surface(root,"Page/Skills/SkillRowsScroll",kit,"inset_light");
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true)) {
                var p=UnityEditor.AnimationUtility.CalculateTransformPath(text.transform,root.transform);
                text.color=p.StartsWith("Page/Hero/")?color("#F1EBDD"):color("#293A32");
            }
            buttons(root,kit,true);bindPalette(root,kit,true);
        } else if(root.name=="MissionJournalPanel") {
            surface(root,"Page",kit,"panel_light");surface(root,"Page/Scroll",kit,"panel_dark");surface(root,"Page/MissionsScroll",kit,"inset_light");
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true))text.color=color("#233E45");
            foreach(var text in root.GetComponentsInChildren<TMPro.TMP_Text>(true))text.color=text.transform.IsChildOf(rect(root,"Page/Scroll"))?color("#F2EBDD"):color("#233E45");
            buttons(root,kit,false);bindPalette(root,kit,false);
        } else if(root.name=="DialoguePanel") {
            surface(root,"Page",kit,"panel_light");
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true))text.color=color(text.name=="Title"?"#233E45":"#65757A");
            rect(root,"Page/HeaderRule").GetComponent<UnityEngine.UI.Image>().color=color("#A7B3AE");
            buttons(root,kit,false);
        } else if(root.name=="StoryEventPanel") {
            surface(root,"Page",kit,"panel_light");rect(root,"Page/GoldRule").GetComponent<UnityEngine.UI.Image>().color=color("#B85E49");
            rect(root,"Page/ChoicesScroll").GetComponent<UnityEngine.UI.Image>().color=UnityEngine.Color.clear;
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true))text.color=color(text.name=="Caption"||text.name=="Hint"?"#65757A":"#233E45");
            buttons(root,kit,false);
        } else {
            paint(root.GetComponent<UnityEngine.UI.Image>(),kit,"panel_light");
            buttons(root,kit,false);bindPalette(root,kit,false);
            foreach(var image in root.GetComponentsInChildren<UnityEngine.UI.Image>(true)) {
                var p=UnityEditor.AnimationUtility.CalculateTransformPath(image.transform,root.transform);
                if(p=="Locked/Body"||p.StartsWith("Locked/Shackle"))image.color=color("#737C78");
            }
        }
        reference.ValidateBindings();
        bool success;UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path,out success);if(!success)throw new System.Exception("Prefab save failed: "+path);
        saved.Add(path);
    } finally {UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
System.IO.File.WriteAllText(artRoot+"/applied-assets.json",Newtonsoft.Json.JsonConvert.SerializeObject(new {sprites=kits.Sum(k=>k.Value.Count),prefabs=saved},Newtonsoft.Json.Formatting.Indented));
return new {sprites=32,prefabs=saved.Count,projectScriptCompilationTriggered=false};
