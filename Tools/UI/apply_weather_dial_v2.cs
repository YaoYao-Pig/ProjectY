// Native MainHud prefab migration. Requires compiled WeatherDialView/Face and the v2 Sprite slices.
// Preserve existing bindings, text components, mode-transition wrappers and unrelated HUD content.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new InvalidOperationException("Weather dial installation requires idle Edit Mode.");
const string prefabPath = "Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab";
var manifest = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Art/WeatherDial/v2/sprites.json"));
var sprites = new System.Collections.Generic.Dictionary<string, Sprite>();
var rows = new System.Collections.Generic.Dictionary<string, Newtonsoft.Json.Linq.JToken>();
foreach (var atlas in manifest["atlases"])
{
    foreach (var asset in UnityEditor.AssetDatabase.LoadAllAssetsAtPath((string)atlas["path"]))
        if (asset is Sprite sprite) sprites.Add(sprite.name, sprite);
    foreach (var row in atlas["sprites"]) rows.Add((string)row["name"], row);
}
if (sprites.Count != 9) throw new InvalidOperationException("Import v2 weather dial sprites before installing the HUD.");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool originalDirty = originalScene.isDirty;
var root = UnityEditor.PrefabUtility.LoadPrefabContents(prefabPath);
int retainedBindings = 0;
try
{
    var reference = root.GetComponent<ProjectY.UI.LuaReference>(); reference.ValidateBindings();
    var before = reference.GetEditorBindings();
    var hud = (ProjectY.UI.MainHudView)reference.Get("HUD"); var hudFields = new UnityEditor.SerializedObject(hud);
    var clock = hudFields.FindProperty("layout.Clock").objectReferenceValue as RectTransform;
    if (clock == null) throw new InvalidOperationException("MainHud Clock layout binding is missing.");
    var parentBefore = clock.parent;
    var oldNeedle = (RectTransform)reference.Get("ClockNeedle");
    var time = reference.GetText("ClockTime"); var day = reference.GetText("ClockDay"); var coins = reference.GetText("Coins");
    var controls = reference.Get("TimeControls").transform.parent as RectTransform;
    if (controls == null || controls.name != "WorldControls") throw new InvalidOperationException("WorldControls binding has an unexpected owner.");
    var backdrop = clock.GetComponent<UnityEngine.UI.Image>(); if (backdrop != null) backdrop.enabled = false;
    const float diameter = 192, scale = diameter / 200;
    System.Func<Transform,string,RectTransform> node = (parent,name) =>
    {
        var value = parent.Find(name) as RectTransform;
        if (value != null) return value;
        value = (RectTransform)new GameObject(name, typeof(RectTransform)).transform; value.SetParent(parent,false); value.gameObject.layer=5; return value;
    };
    var art = node(clock,"WeatherDialArt"); art.anchorMin=art.anchorMax=new Vector2(.5f,1); art.pivot=new Vector2(.5f,1);
    art.anchoredPosition=Vector2.zero; art.sizeDelta=Vector2.one*diameter;
    var artGroup=art.GetComponent<CanvasGroup>();if(artGroup==null)artGroup=art.gameObject.AddComponent<CanvasGroup>();
    artGroup.alpha=0;artGroup.interactable=false;artGroup.blocksRaycasts=false;
    System.Func<string,RectTransform,UnityEngine.UI.Image> piece = (key,reuse) =>
    {
        var row=rows[key]; var placement=row["designPlacementAt200"];
        var r=reuse!=null?reuse:node(art,key);r.SetParent(art,false);r.anchorMin=r.anchorMax=new Vector2(.5f,.5f);
        r.pivot=new Vector2((float)row["pivot"]["x"],(float)row["pivot"]["y"]);
        r.anchoredPosition=new Vector2((float)placement["anchoredPosition"][0],(float)placement["anchoredPosition"][1])*scale;
        r.sizeDelta=new Vector2((float)placement["size"][0],(float)placement["size"][1])*scale;r.localScale=Vector3.one;r.localRotation=Quaternion.identity;
        var image=r.GetComponent<UnityEngine.UI.Image>();if(image==null)image=r.gameObject.AddComponent<UnityEngine.UI.Image>();
        image.enabled=true;image.sprite=sprites[key];image.type=UnityEngine.UI.Image.Type.Simple;image.preserveAspect=true;image.color=Color.white;image.raycastTarget=false;
        return image;
    };
    // The approved plain face is reconstructed as exact time sectors; no painted horizon/approximate angle mapping.
    var faceRect=node(art,"TimeSectors");faceRect.anchorMin=faceRect.anchorMax=faceRect.pivot=new Vector2(.5f,.5f);faceRect.anchoredPosition=Vector2.zero;
    var faceSize=rows["WeatherDialV2_Face"]["designPlacementAt200"]["size"];
    faceRect.sizeDelta=new Vector2((float)faceSize[0],(float)faceSize[1])*scale;
    var face=faceRect.GetComponent<ProjectY.UI.WeatherDialFace>();if(face==null)face=faceRect.gameObject.AddComponent<ProjectY.UI.WeatherDialFace>();
    var faceFields=new UnityEditor.SerializedObject(face);
    faceFields.FindProperty("dayColor").colorValue=new Color(252/255f,224/255f,134/255f,1);
    faceFields.FindProperty("duskColor").colorValue=new Color(221/255f,141/255f,64/255f,1);
    faceFields.FindProperty("nightColor").colorValue=new Color(62/255f,76/255f,90/255f,1);
    faceFields.FindProperty("tickColor").colorValue=new Color(.98f,.93f,.80f,1);
    var profile=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Rendering/MapEnvironmentTable.json"))["rows"][0];
    var keys=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Rendering/MapLightKeyTable.json"))["rows"];
    System.Func<string,double> hour=name=>{int id=(int)profile[name];foreach(var key in keys)if((int)key["id"]==id)return (double)key["hour"];throw new InvalidOperationException("Missing clock light key.");};
    faceFields.FindProperty("dayStart").doubleValue=hour("dialDayKeyId");faceFields.FindProperty("duskStart").doubleValue=hour("dialDuskKeyId");faceFields.FindProperty("nightStart").doubleValue=hour("dialNightKeyId");
    faceFields.ApplyModifiedPropertiesWithoutUndo();face.raycastTarget=false;face.SetVerticesDirty();faceRect.SetAsFirstSibling();
    var sun=piece("WeatherDialV2_Sun",null);var cloud=piece("WeatherDialV2_Cloud",null);var storm=piece("WeatherDialV2_StormCloud",null);
    var rain=piece("WeatherDialV2_Rain",null);var lightning=piece("WeatherDialV2_Lightning",null);
    foreach(var image in new[]{sun,cloud,storm,rain,lightning})
    {
        var shadow=image.GetComponent<UnityEngine.UI.Shadow>();if(shadow==null)shadow=image.gameObject.AddComponent<UnityEngine.UI.Shadow>();
        shadow.effectColor=new Color(.03f,.025f,.015f,.25f);shadow.effectDistance=new Vector2(1.0f,-1.3f)*scale;shadow.useGraphicAlpha=true;
    }
    piece("WeatherDialV2_Frame",null).rectTransform.SetAsLastSibling();
    var shadowRect=node(art,"HandShadow"); var handShadow=piece("WeatherDialV2_Hand",shadowRect);
    handShadow.color=new Color(.02f,.015f,.01f,.28f);handShadow.rectTransform.anchoredPosition+=new Vector2(1.2f,-1.7f)*scale;
    handShadow.rectTransform.SetAsLastSibling();
    var hand=piece("WeatherDialV2_Hand",oldNeedle);hand.rectTransform.SetAsLastSibling();
    piece("WeatherDialV2_Hub",null).rectTransform.SetAsLastSibling();
    // Keep the original localized text components and their binding identities; only relocate the footer.
    System.Action<UnityEngine.UI.Text,float,float,float,float,int> textBox=(text,x,y,w,h,size)=>
    {
        var r=text.rectTransform;r.SetParent(clock,false);r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);
        r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);r.localScale=Vector3.one;
        text.fontSize=size;text.alignment=TextAnchor.MiddleCenter;text.raycastTarget=false;text.color=new Color(.98f,.93f,.80f,1);
        var outline=text.GetComponent<UnityEngine.UI.Outline>();if(outline==null)outline=text.gameObject.AddComponent<UnityEngine.UI.Outline>();
        outline.effectColor=new Color(.035f,.04f,.04f,.85f);outline.effectDistance=new Vector2(1,-1);
    };
    textBox(time,0,diameter+2,100,24,20);textBox(day,100,diameter+4,diameter-100,22,13);textBox(coins,0,diameter+27,diameter,23,15);
    var logs=reference.GetText("Logs").rectTransform;
    logs.anchorMin=new Vector2(0,1);logs.anchorMax=Vector2.one;logs.pivot=new Vector2(0,1);
    logs.anchoredPosition=new Vector2(14,-34);logs.sizeDelta=new Vector2(-28,96);
    var dial=clock.GetComponent<ProjectY.UI.WeatherDialView>();if(dial==null)dial=clock.gameObject.AddComponent<ProjectY.UI.WeatherDialView>();
    var dialFields=new UnityEditor.SerializedObject(dial);
    var names=new[]{"hand","handShadow","sun","cloud","stormCloud","rain","lightning","sunImage","cloudImage","stormImage","rainImage","lightningImage","face"};
    UnityEngine.Object[] refs={hand.rectTransform,handShadow.rectTransform,sun.rectTransform,cloud.rectTransform,storm.rectTransform,rain.rectTransform,lightning.rectTransform,sun,cloud,storm,rain,lightning,face};
    for(int i=0;i<names.Length;i++)dialFields.FindProperty(names[i]).objectReferenceValue=refs[i];
    dialFields.ApplyModifiedPropertiesWithoutUndo();
    var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(before);
    bindings.RemoveAll(e=>e.Key=="WeatherDial"||e.Key=="WeatherDialGroup");bindings.Add(new ProjectY.UI.LuaReference.Entry("WeatherDial",dial));bindings.Add(new ProjectY.UI.LuaReference.Entry("WeatherDialGroup",artGroup));reference.SetEditorBindings(bindings.ToArray());reference.ValidateBindings();
    hudFields.FindProperty("clockDiameter").floatValue=diameter;hudFields.FindProperty("clockFooterHeight").floatValue=54;hudFields.FindProperty("worldControls").objectReferenceValue=controls;
    hudFields.ApplyModifiedPropertiesWithoutUndo();hud.ApplyLayout();
    foreach(var entry in before) if(entry.Key!="WeatherDial"&&entry.Key!="WeatherDialGroup")
    {if(reference.Get(entry.Key)!=entry.Target)throw new InvalidOperationException("Weather dial migration changed an unrelated binding: "+entry.Key);retainedBindings++;}
    if(clock.parent!=parentBefore)throw new InvalidOperationException("Clock mode-transition wrapper was changed.");
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,prefabPath);
}
finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
if(originalScene.isDirty!=originalDirty)throw new InvalidOperationException("Weather dial installation changed the open scene.");
var result=new{prefabPath,retainedBindings,newBindings=new[]{"WeatherDial","WeatherDialGroup"},diameter=192,footerHeight=54,sourceSprites=8,proceduralFace=true,sceneSaved=false,playMode=false};
System.IO.Directory.CreateDirectory("Docs/Previews/WeatherDial");
System.IO.File.WriteAllText("Docs/Previews/WeatherDial/install.json",Newtonsoft.Json.JsonConvert.SerializeObject(result,Newtonsoft.Json.Formatting.Indented));
return result;
