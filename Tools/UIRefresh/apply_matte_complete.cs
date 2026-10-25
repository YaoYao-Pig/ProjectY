// Consolidated native matte artwork migration. Run the four stages in their original order.
// Each stage retains its own scope; only the original final return statements are omitted.

// Stage: apply_matte.cs
{
// Restore the approved 08/09 construction with specifically corrected matte materials.
// Asset-only native migration; no existing RectTransform, 3D preview or gameplay command is changed.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var sourceRoot="Art/UIRefresh/2026-10-25/matte";
var assetRoot="Assets/DynamicAsset/UI/Skins";
System.Action<string> ensure=null;ensure=path=>{if(UnityEditor.AssetDatabase.IsValidFolder(path))return;var i=path.LastIndexOf('/');ensure(path.Substring(0,i));UnityEditor.AssetDatabase.CreateFolder(path.Substring(0,i),path.Substring(i+1));};
var kits=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>>();
foreach(var name in new[]{"guild","collage"}){
    var folder=assetRoot+"/"+(name=="guild"?"GuildMatte":"CollageMatte");ensure(folder);
    var manifest=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(sourceRoot+"/"+name+"/manifest.json"));
    var kit=new System.Collections.Generic.Dictionary<string,UnityEngine.Sprite>();
    foreach(var slice in manifest["slices"]){
        var key=(string)slice["name"];var target=folder+"/"+key+".png";
        System.IO.File.Copy(sourceRoot+"/"+name+"/slices/"+key+".png",target,true);
        UnityEditor.AssetDatabase.ImportAsset(target,UnityEditor.ImportAssetOptions.ForceSynchronousImport);
        var importer=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(target);
        importer.textureType=UnityEditor.TextureImporterType.Sprite;importer.spriteImportMode=UnityEditor.SpriteImportMode.Single;
        importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.textureCompression=UnityEditor.TextureImporterCompression.Uncompressed;
        importer.wrapMode=UnityEngine.TextureWrapMode.Clamp;importer.filterMode=UnityEngine.FilterMode.Bilinear;importer.npotScale=UnityEditor.TextureImporterNPOTScale.None;importer.spritePixelsPerUnit=100;
        var b=slice["border"];importer.spriteBorder=new UnityEngine.Vector4((float)b[0],(float)b[1],(float)b[2],(float)b[3]);importer.SaveAndReimport();
        kit.Add(key,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Sprite>(target));
    }
    foreach(var key in new[]{"paper_surface",name=="guild"?"leather_surface":"ink_surface"}){
        var target=folder+"/"+key+".png";System.IO.File.Copy(sourceRoot+"/"+name+"/"+key+".png",target,true);UnityEditor.AssetDatabase.ImportAsset(target,UnityEditor.ImportAssetOptions.ForceSynchronousImport);
        var importer=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(target);importer.textureType=UnityEditor.TextureImporterType.Sprite;importer.spriteImportMode=UnityEditor.SpriteImportMode.Single;importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.textureCompression=UnityEditor.TextureImporterCompression.Uncompressed;importer.wrapMode=UnityEngine.TextureWrapMode.Clamp;importer.npotScale=UnityEditor.TextureImporterNPOTScale.None;importer.spriteBorder=UnityEngine.Vector4.zero;importer.SaveAndReimport();kit.Add(key,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Sprite>(target));
    }
    kits.Add(name,kit);
}
System.Func<string,UnityEngine.Color> color=html=>{UnityEngine.Color c;if(!UnityEngine.ColorUtility.TryParseHtmlString(html,out c))throw new System.Exception(html);return c;};
System.Func<UnityEngine.GameObject,string,UnityEngine.RectTransform> rect=(root,path)=>{var t=root.transform.Find(path) as UnityEngine.RectTransform;if(t==null)throw new System.Exception(root.name+"/"+path);return t;};
System.Action<UnityEngine.UI.Image,UnityEngine.Sprite,float,bool> art=(image,sprite,ppu,center)=>{if(image==null||sprite==null)throw new System.Exception("Missing artwork target");image.sprite=sprite;image.overrideSprite=null;image.type=sprite.border==UnityEngine.Vector4.zero?UnityEngine.UI.Image.Type.Simple:UnityEngine.UI.Image.Type.Sliced;image.fillCenter=center;image.color=UnityEngine.Color.white;image.pixelsPerUnitMultiplier=ppu;};
System.Action<UnityEngine.GameObject,string,UnityEngine.Sprite,float> surface=(root,path,sprite,ppu)=>art(rect(root,path).GetComponent<UnityEngine.UI.Image>(),sprite,ppu,true);
System.Action<UnityEngine.Transform,string,UnityEngine.Sprite,float,float,float,float,float> underlay=(parent,name,sprite,x,y,w,h,ppu)=>{
    var found=parent.Find(name);UnityEngine.GameObject node;
    if(found==null){node=new UnityEngine.GameObject(name,typeof(UnityEngine.RectTransform),typeof(UnityEngine.UI.Image));node.transform.SetParent(parent,false);}else node=found.gameObject;
    var r=(UnityEngine.RectTransform)node.transform;r.anchorMin=r.anchorMax=new UnityEngine.Vector2(0,1);r.pivot=new UnityEngine.Vector2(0,1);r.anchoredPosition=new UnityEngine.Vector2(x,-y);r.sizeDelta=new UnityEngine.Vector2(w,h);
    var image=node.GetComponent<UnityEngine.UI.Image>();art(image,sprite,ppu,true);image.raycastTarget=false;node.transform.SetAsFirstSibling();
};
var paletteRefs=new System.Collections.Generic.Dictionary<string,ProjectY.UI.LuaReference>();
System.Action<UnityEngine.GameObject,string> palette=(root,name)=>{
    if(!paletteRefs.ContainsKey(name)){
        var kit=kits[name];bool guild=name=="guild";
        var roles=new System.Collections.Generic.Dictionary<string,string>{
            {"panel_light",guild?"panel_body":"button_secondary"},{"panel_dark",guild?"inventory_slot":"panel_body"},{"header_strip","panel_header"},{"inset_light","detail_card"},
            {"button_light","button_secondary"},{"button_accent","button_primary_normal"},{"button_hover","button_primary_hover"},{"button_pressed","button_primary_pressed"},
            {"tab_light","tab_inactive"},{"tab_accent","tab_active"},{"slot_frame","inventory_slot"},{"selected_frame","inventory_slot_selected"},{"node_round","skill_node_learned"},{"rule_horizontal","separator"},
            {"node_learned","skill_node_learned"},{"node_available","skill_node_available"},{"node_locked","skill_node_locked"}
        };
        var colors=new System.Collections.Generic.Dictionary<string,UnityEngine.Color>{{"ink",color(guild?"#302B21":"#223B40")},{"muted",color("#5F655C")},{"accent_ink",color(guild?"#48654A":"#9D3C2B")},{"on_accent",color("#FFF0D3")},{"disabled_ink",color(guild?"#A8A18E":"#6A716C")},{"on_dark",color("#F5E7CE")}};
        var node=new UnityEngine.GameObject("MatteArtPalette",typeof(UnityEngine.RectTransform),typeof(ProjectY.UI.LuaReference));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(node,root.scene);
        var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>();
        foreach(var key in roles.Keys.Concat(colors.Keys)){
            var child=new UnityEngine.GameObject(key,typeof(UnityEngine.RectTransform),typeof(UnityEngine.UI.Image));child.transform.SetParent(node.transform,false);var image=child.GetComponent<UnityEngine.UI.Image>();image.raycastTarget=false;
            if(roles.ContainsKey(key)){image.sprite=kit[roles[key]];}else image.color=colors[key];entries.Add(new ProjectY.UI.LuaReference.Entry(key,image));
        }
        node.GetComponent<ProjectY.UI.LuaReference>().SetEditorBindings(entries.ToArray());node.SetActive(false);
        var path=assetRoot+"/"+(guild?"GuildMatte":"CollageMatte")+"/Palette.prefab";bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(node,path,out ok);UnityEngine.Object.DestroyImmediate(node);if(!ok)throw new System.Exception(path);
        paletteRefs.Add(name,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path).GetComponent<ProjectY.UI.LuaReference>());
    }
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();var entries2=reference.GetEditorBindings().Where(e=>e.Key!="Skin").ToList();entries2.Add(new ProjectY.UI.LuaReference.Entry("Skin",paletteRefs[name]));reference.SetEditorBindings(entries2.ToArray());
};
System.Action<UnityEngine.GameObject,string> buttons=(root,name)=>{
    var kit=kits[name];bool guild=name=="guild";
    foreach(var button in root.GetComponentsInChildren<UnityEngine.UI.Button>(true)){
        if(button.image==null||button.name.StartsWith("HealthPart"))continue;
        var main=button.name=="Invest"||button.name=="Equip"||button.name=="PrimaryAction"||button.name=="Continue";
        art(button.image,kit[main?"button_primary_normal":"button_secondary"],2,true);
        var colors=button.colors;colors.normalColor=UnityEngine.Color.white;colors.highlightedColor=new UnityEngine.Color(1.04f,1.04f,1.04f,1);colors.pressedColor=new UnityEngine.Color(.9f,.9f,.9f,1);colors.disabledColor=new UnityEngine.Color(.9f,.9f,.9f,.65f);colors.selectedColor=UnityEngine.Color.white;button.colors=colors;button.transition=UnityEngine.UI.Selectable.Transition.ColorTint;
        foreach(var text in button.GetComponentsInChildren<UnityEngine.UI.Text>(true))text.color=main||guild?color("#F5E7CE"):color("#223B40");
        foreach(var text in button.GetComponentsInChildren<TMPro.TMP_Text>(true))text.color=main||guild?color("#F5E7CE"):color("#223B40");
    }
};
var paths=new[]{"Equipment/InventoryPanel","Adventure/CharacterGrowthPanel","Narrative/MissionJournalPanel","Narrative/DialoguePanel","Adventure/StoryEventPanel","Narrative/DialogueEntryWidget","Adventure/StoryChoiceWidget"};
foreach(var relative in paths){
    var path="Assets/DynamicAsset/UI/Prefabs/"+relative+".prefab";var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try{
        bool guild=root.name=="InventoryPanel"||root.name=="CharacterGrowthPanel";var key=guild?"guild":"collage";var kit=kits[key];
        if(root.name=="InventoryPanel"){
            surface(root,"Frame",kit["panel_body"],1.8f);rect(root,"Frame").GetComponent<UnityEngine.UI.Image>().fillCenter=false;
            underlay(rect(root,"Frame"),"MatteLeatherBacking",kit["leather_surface"],8,8,1424,744,1);
            surface(root,"Frame/Bag",kit["panel_body"],2);surface(root,"Frame/Details",kit["inventory_slot"],2);
            surface(root,"Frame/CellTemplate",kit["inventory_slot"],7);rect(root,"Frame/CellTemplate").GetComponent<UnityEngine.UI.Image>().color=new UnityEngine.Color(1,1,1,.33f);
            art(rect(root,"Frame/ItemTemplate/SkinFrame").GetComponent<UnityEngine.UI.Image>(),kit["inventory_slot_selected"],5,false);
            art(rect(root,"Frame/Equipment/SkinFrame").GetComponent<UnityEngine.UI.Image>(),kit["panel_body"],3.5f,false);
            underlay(rect(root,"Frame"),"MatteTitle",kit["panel_header"],20,18,700,62,2);
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true)){
                var p=UnityEditor.AnimationUtility.CalculateTransformPath(text.transform,root.transform);
                if(p.StartsWith("Frame/Equipment/CharacterPreview/")||p.Contains("HealthOverlay"))continue;
                text.color=p.StartsWith("Frame/Bag/")?color("#302B21"):color("#F5E7CE");
            }
            buttons(root,key);
            foreach(var entry in root.GetComponent<ProjectY.UI.LuaReference>().GetEditorBindings().Where(e=>e.Key.StartsWith("Slot_")&&e.Target is UnityEngine.UI.Button)){
                var b=(UnityEngine.UI.Button)entry.Target;art(b.image,kit["inventory_slot"],3,true);
            }
        }else if(root.name=="CharacterGrowthPanel"){
            surface(root,"Page",kit["panel_body"],2.6f);surface(root,"Page/Hero",kit["inventory_slot"],3);
            surface(root,"Page/Skills/GraphScroll",kit["paper_surface"],1);surface(root,"Page/Skills/SkillRowsScroll",kit["detail_card"],2.5f);
            underlay(rect(root,"Page"),"MatteBookHeader",kit["panel_header"],280,20,900,80,2.3f);
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true)){
                var p=UnityEditor.AnimationUtility.CalculateTransformPath(text.transform,root.transform);text.color=p.StartsWith("Page/Hero/")||text.name=="BookTitle"||text.name=="BookSubtitle"?color("#F5E7CE"):color("#302B21");
            }
            buttons(root,key);palette(root,key);
        }else if(root.name=="MissionJournalPanel"){
            surface(root,"Page",kit["panel_body"],2);surface(root,"Page/Scroll",kit["detail_card"],3.5f);surface(root,"Page/MissionsScroll",kit["tooltip_frame"],2);
            underlay(rect(root,"Page"),"MatteTitle",kit["panel_header"],12,8,280,82,2);
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true))text.color=text.name=="Hint"?color("#F5E7CE"):color("#223B40");
            foreach(var text in root.GetComponentsInChildren<TMPro.TMP_Text>(true))text.color=text.name=="PrimaryHint"?color("#F5E7CE"):color("#223B40");
            buttons(root,key);palette(root,key);
        }else if(root.name=="DialoguePanel"){
            surface(root,"Page",kit["panel_body"],2);
            underlay(rect(root,"Page"),"MatteTitle",kit["panel_header"],12,12,470,86,2);
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true))text.color=text.name=="Hint"?color("#F5E7CE"):color("#223B40");
            rect(root,"Page/HeaderRule").GetComponent<UnityEngine.UI.Image>().color=color("#C7B993");buttons(root,key);
        }else if(root.name=="StoryEventPanel"){
            surface(root,"Page",kit["panel_body"],2);
            underlay(rect(root,"Page"),"MatteTitle",kit["panel_header"],18,16,710,64,2);
            underlay(rect(root,"Page"),"MatteCaption",kit["button_secondary"],22,547,694,68,2);
            underlay(rect(root,"Page"),"MatteRightPaper",kit["detail_card"],718,84,465,532,2);
            foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>(true))text.color=text.name=="Hint"?color("#F5E7CE"):color("#223B40");
            rect(root,"Page/ChoicesScroll").GetComponent<UnityEngine.UI.Image>().color=UnityEngine.Color.clear;rect(root,"Page/GoldRule").GetComponent<UnityEngine.UI.Image>().color=color("#C46C43");buttons(root,key);
        }else{
            buttons(root,key);palette(root,key);
        }
        root.GetComponent<ProjectY.UI.LuaReference>().ValidateBindings();bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path,out ok);if(!ok)throw new System.Exception(path);
    }finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
}

// Stage: fit_matte.cs
{
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
}

// Stage: normalize_matte_layout.cs
{
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
}

// Stage: apply_reward_art.cs
{
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
}
return new {stages=4,prefabs=8,sourceSprites=40,surfaces=4,paletteRoles=17,paletteColors=6,rewardRoles=8,spritePixelsPerUnit=500,helperPixelsPerUnitMultiplier=.4f,projectCompilation=false};
