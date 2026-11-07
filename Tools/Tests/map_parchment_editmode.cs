// Native saved-art and dense-label preview. No Play, active scene edits, or gameplay state.
if(EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic;
System.Func<object,string,object> field=(o,n)=>o.GetType().GetField(n,flags).GetValue(o);
System.Func<object,string,object[],object> call=(o,n,a)=>o.GetType().GetMethod(n,flags).Invoke(o,a);
int checks=0;System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.Exception(message);checks++;};
var oldTarget=RenderTexture.active;var target=new RenderTexture(1280,720,24);target.Create();Texture2D pixels=null;
System.IDisposable coordinator=null,siteView=null,markerView=null;ProjectY.Samples.MapPreviewRenderer renderer=null;
try
{
    var host=new GameObject("Parchment map check");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var cameraObject=new GameObject("Camera");cameraObject.transform.SetParent(host.transform,false);var camera=cameraObject.AddComponent<Camera>();
    camera.enabled=false;camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true;camera.orthographicSize=24;camera.nearClipPlane=.1f;camera.farClipPlane=1000;camera.targetTexture=target;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.22f,.36f,.40f);
    camera.transform.SetPositionAndRotation(new Vector3(0,300,0),Quaternion.Euler(90,0,0));ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var lightObject=new GameObject("Sun");lightObject.transform.SetParent(host.transform,false);var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.2f;light.transform.rotation=Quaternion.Euler(50,-25,0);
    var map=new ProjectY.Samples.MapPreviewData {Radius=1,Towns=new ProjectY.Samples.MapPreviewData.Town[0],Buildings=new ProjectY.Samples.MapPreviewData.Building[0],
        Roads=new ProjectY.Samples.MapPreviewData.Road[0],Decorations=new ProjectY.Samples.MapPreviewData.Decoration[0],Waterfalls=new ProjectY.Samples.MapPreviewData.Waterfall[0],Groundcover=new ProjectY.Samples.MapPreviewData.Cover[0]};
    var assets=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapAssetTable.json"))["rows"];
    var ground=assets.First(row=>(string)row["name"]=="Hex_Shore");
    map.Assets=new[]{new ProjectY.Samples.MapPreviewData.Asset {Id=(int)ground["id"],Path=(string)ground["prefabPath"],TintMaterial=(string)ground["tintMaterial"],ReferenceHeight=(float)ground["referenceHeight"]}};
    map.Surfaces=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapBiomeTable.json"))["rows"].Select(row=>{
        Color tint;ColorUtility.TryParseHtmlString((string)row["groundColor"],out tint);
        return new ProjectY.Samples.MapPreviewData.Surface {Id=(int)row["id"],GroundTexture=(string)row["groundTexture"],Color=tint,TextureWorldSize=(float)row["textureWorldSize"],TextureStrength=(float)row["textureStrength"],WindStrength=(float)row["windStrength"]};}).ToArray();
    var cells=new System.Collections.Generic.List<ProjectY.Samples.MapPreviewData.Cell>();
    for(int r=-16;r<=16;r++)for(int q=-24;q<=24;q++)cells.Add(new ProjectY.Samples.MapPreviewData.Cell {Q=q,R=r,Position=new Vector3(1.7320508f*(q+r*.5f),0,r*1.5f),
        Color=new Color(.48f,.56f,.34f),TerrainAssetId=map.Assets[0].Id,SurfaceA=map.Surfaces[0].Id,SurfaceB=map.Surfaces[0].Id,Neighbors=new int[0]});
    map.Cells=cells.ToArray();renderer=new ProjectY.Samples.MapPreviewRenderer(Shader.Find("ProjectY/Map Preview Instanced"),host.transform);
    renderer.Build(map,asset=>AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
    // The game uses an Overlay canvas after camera rendering. This preview uses a
    // camera-space canvas, so draw only this preview-owned sea material before UI.
    var boundary=field(renderer,"boundary");var boundaryMaterial=(Material)field(boundary,"material");boundaryMaterial.renderQueue=2900;
    var canvasObject=new GameObject("Canvas",typeof(RectTransform),typeof(Canvas));canvasObject.transform.SetParent(host.transform,false);
    var canvas=canvasObject.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;
    var root=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab"),canvas.transform,false);
    var rootRect=(RectTransform)root.transform;rootRect.anchorMin=Vector2.zero;rootRect.anchorMax=Vector2.one;rootRect.offsetMin=rootRect.offsetMax=Vector2.zero;rootRect.localScale=Vector3.one;
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();var hud=(ProjectY.UI.MainHudView)reference.Get("HUD");var mapRef=reference.GetReference("MapHud");
    foreach(var nested in root.GetComponentsInChildren<ProjectY.UI.LuaReference>(true))typeof(ProjectY.UI.LuaReference).GetMethod("ApplyLocalizations",flags).Invoke(nested,null);
    hud.Prepare();hud.SetCharacterSkillBar((RectTransform)reference.Get("CharacterSkills"));hud.SetMode(true,false);
    var style=(ProjectY.Samples.MapHudLayout)mapRef.Get("Layout");
    var transition=(ProjectY.UI.HudModeTransition)reference.Get("MapTransition");transition.SetProgress(1);
    Canvas.ForceUpdateCanvases();hud.ApplyLayout();style.ApplyLayout();Canvas.ForceUpdateCanvases();
    check(mapRef.GetText("Title").font.name.Contains("SourceHan"),"Serif title must survive MainHud.Prepare");
    foreach(var label in mapRef.GetComponentsInChildren<UnityEngine.UI.Text>(false))
        if(label.text.Length>0)check(label.preferredHeight<=label.rectTransform.rect.height+.1f,"Map label height clips its font: "+label.name);
    check(style.Available!=null && style.Active!=null && style.Ready!=null && style.Party!=null,"Saved task sprites");
    var assembly=typeof(ProjectY.Samples.AdventureRuntimeDemo).Assembly;
    coordinator=(System.IDisposable)System.Activator.CreateInstance(assembly.GetType("ProjectY.Samples.MapLabelCoordinator",true),flags,null,new object[]{hud},null);
    call(coordinator,"Configure",new object[]{camera});
    siteView=(System.IDisposable)System.Activator.CreateInstance(assembly.GetType("ProjectY.Samples.WorldSiteView",true),flags,null,new object[]{hud,map,renderer,coordinator},null);
    markerView=(System.IDisposable)System.Activator.CreateInstance(assembly.GetType("ProjectY.Samples.WorldMapMarkerView",true),flags,null,new object[]{hud,coordinator},null);
    var sites=new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData.Site>();var missions=new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData.MapMarker>();
    string[] names={"白石镇","林间营地","河湾村","北风隘口","旧矿井","青石驿站","湖畔村","古塔遗址"};
    for(int i=0;i<80;i++)
    {
        int q=i%10-5,r=i/10-4;
        string name=i==0?"带有很长很长地理与势力说明的远方城镇名字用来验证省略":names[i%names.Length];
        sites.Add(new ProjectY.Samples.AdventureViewData.Site {Id=i+1,Name=name,ShortName=name,Q=q,R=r,Kind=i%4==0?"town":"event",Position=new Vector3(1.7320508f*(q+r*.5f),0,r*1.5f),Available=true});
        if(i%5==0)foreach(var kind in new[]{"available","active","ready"})missions.Add(new ProjectY.Samples.AdventureViewData.MapMarker {SiteId=i+1,Kind=kind,Count=2});
    }
    var view=new ProjectY.Samples.AdventureViewData {Sites=sites.ToArray(),MapMarkers=missions.ToArray()};
    call(siteView,"Sync",new object[]{view.Sites});call(siteView,"SetOverview",new object[]{true});
    System.Action tick=()=>{call(siteView,"Tick",new object[]{camera,false,Vector2.zero,.1f});call(markerView,"Tick",new object[]{camera,view,new Vector3(-12,0,-9),1f});hud.UpdateFollowers();};
    tick();
    var items=(System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>)field(coordinator,"items");
    var obstacles=(System.Collections.Generic.List<Rect>)field(coordinator,"obstacles");
    int visible=0;
    for(int i=0;i<items.Count;i++)if(items[i].Visible)
    {
        visible++;check(camera.pixelRect.Contains(items[i].Rect.min)&&camera.pixelRect.Contains(items[i].Rect.max),"Labels remain inside viewport");
        for(int j=0;j<i;j++)if(items[j].Visible)check(!items[i].Rect.Overlaps(items[j].Rect),"Native labels overlap");
        foreach(var obstacle in obstacles)check(!items[i].Rect.Overlaps(obstacle),"Native labels overlap HUD cards");
    }
    check(visible>0 && visible<items.Count,"Dense scene must retain useful labels and suppress clutter");
    var tags=(System.Collections.IDictionary)field(siteView,"tags");var longTag=tags[1];
    var text=(UnityEngine.UI.Text)field(longTag,"Label");var rect=(RectTransform)field(longTag,"Rect");
    check(text.text.EndsWith("…") && text.preferredWidth<=rect.rect.width-18+.1f && rect.rect.height==24,"Long names must fit compact paper labels");
    var markerPool=(System.Collections.IDictionary)field(markerView,"markers");
    check(markerPool.Count==17,"Three mission types aggregate into one badge per site plus player");
    // Verify both outgoing and incoming HUD geometry participates in the same pass.
    transition.SetProgress(.2f);tick();check(obstacles.Count>0,"Outgoing main HUD still reserves screen space");
    transition.SetProgress(.8f);tick();check(obstacles.Count>0,"Incoming map HUD reserves screen space");transition.SetProgress(1);tick();
    int oldRevision=(int)coordinator.GetType().GetProperty("Revision").GetValue(coordinator,null);tick();
    check((int)coordinator.GetType().GetProperty("Revision").GetValue(coordinator,null)==oldRevision,"Stationary layout must be stable without flickering");
    mapRef.GetToggle("SiteTags").isOn=false;tick();foreach(var value in tags.Values)check(!((RectTransform)field(value,"Rect")).gameObject.activeSelf,"Site filter must hide all names");
    mapRef.GetToggle("SiteTags").isOn=true;tick();
    System.IO.Directory.CreateDirectory("Docs/Previews/WorldMapOverview");
    System.Action<string> capture=name=>{
        renderer.Draw(camera,true,false,false,false);camera.Render();RenderTexture.active=target;
        if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);pixels=new Texture2D(target.width,target.height,TextureFormat.RGB24,false);
        pixels.ReadPixels(new Rect(0,0,target.width,target.height),0,0);pixels.Apply();System.IO.File.WriteAllBytes("Docs/Previews/WorldMapOverview/"+name+".png",pixels.EncodeToPNG());};
    capture("ParchmentMapHud-Dense");
    // Wider distribution is a readability preview using the same native labels and art.
    foreach(var site in sites){site.Position*=3;site.Name=site.ShortName=names[(site.Id-1)%names.Length];}
    view.Sites=sites.ToArray();call(siteView,"Sync",new object[]{view.Sites});tick();capture("ParchmentMapHud");
    return "PASS parchment native UI: "+checks+" checks; dense layout "+visible+"/"+items.Count+" visible, compact text, sprite bindings, filters, shared obstacles and stable layout; saved native previews.";
}
finally
{
    if(markerView!=null)markerView.Dispose();if(siteView!=null)siteView.Dispose();if(coordinator!=null)coordinator.Dispose();if(renderer!=null)renderer.Dispose();
    RenderTexture.active=oldTarget;if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
