// Unity MCP execute_code body. Saved HUD and actual clips, Edit Mode, isolated preview scene.
if(EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var activeScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=activeScene.isDirty;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic;
int checks=0;System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.Exception(message);checks++;};
var savedTarget=RenderTexture.active;var target=new RenderTexture(1280,720,24);target.Create();
Texture2D pixels=null;System.IDisposable markerView=null;System.IDisposable partyView=null;
try
{
    var cameraObject=new GameObject("Map HUD preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true;camera.orthographicSize=100;camera.nearClipPlane=.1f;camera.farClipPlane=1000;camera.targetTexture=target;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.08f,.14f,.16f);camera.transform.SetPositionAndRotation(new Vector3(0,300,0),Quaternion.Euler(90,0,0));
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var canvasObject=new GameObject("HUD preview",typeof(RectTransform),typeof(Canvas));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(canvasObject,scene);
    var canvas=canvasObject.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;
    var prefab=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab");
    var root=UnityEngine.Object.Instantiate(prefab,canvasObject.transform,false);root.SetActive(false);
    var rootRect=(RectTransform)root.transform;rootRect.anchorMin=Vector2.zero;rootRect.anchorMax=Vector2.one;rootRect.offsetMin=rootRect.offsetMax=Vector2.zero;rootRect.localScale=Vector3.one;
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
    var hud=(ProjectY.UI.MainHudView)reference.Get("HUD");var transition=(ProjectY.UI.HudModeTransition)reference.Get("MapTransition");
    var map=reference.GetReference("MapHud");map.ValidateBindings();
    transition.SetProgress(0); // Same inactive-root Bind/OnHide lifecycle as UIHost.
    foreach(var nested in root.GetComponentsInChildren<ProjectY.UI.LuaReference>(true))
        typeof(ProjectY.UI.LuaReference).GetMethod("ApplyLocalizations",flags).Invoke(nested,null);
    root.SetActive(true);hud.Prepare();hud.SetCharacterSkillBar((RectTransform)reference.Get("CharacterSkills"));hud.SetMode(true,false);
    reference.Get("Menu").gameObject.SetActive(false);reference.Get("Hint").gameObject.SetActive(false);
    reference.Get("Interaction").gameObject.SetActive(false);reference.Get("HealthLayer").gameObject.SetActive(false);
    var animation=root.GetComponent<ProjectY.UI.AnimationWrap>();check(animation.HasClip("map-overview"),"Saved overview clip missing");
    var mainGroups=(CanvasGroup[])typeof(ProjectY.UI.HudModeTransition).GetField("mainGroups",flags).GetValue(transition);
    var mapGroups=(CanvasGroup[])typeof(ProjectY.UI.HudModeTransition).GetField("mapGroups",flags).GetValue(transition);
    check(mainGroups.Length==11 && mapGroups.Length==4,"Saved animation groups");
    Canvas.ForceUpdateCanvases();hud.ApplyLayout();((ProjectY.Samples.MapHudLayout)map.Get("Layout")).ApplyLayout();
    System.IO.Directory.CreateDirectory("Docs/Previews/WorldMapOverview");
    System.Action<float,string> capture=(progress,name)=>{
        transition.SetProgress(progress);Canvas.ForceUpdateCanvases();camera.Render();RenderTexture.active=target;
        if(pixels==null)pixels=new Texture2D(target.width,target.height,TextureFormat.RGB24,false);
        pixels.ReadPixels(new Rect(0,0,target.width,target.height),0,0);pixels.Apply();
        System.IO.File.WriteAllBytes("Docs/Previews/WorldMapOverview/"+name+".png",pixels.EncodeToPNG());
    };
    capture(0,"MainHud");
    foreach(var g in mainGroups)check(g.alpha>.99f && g.interactable && g.blocksRaycasts,"Main HUD initial visibility/input");
    foreach(var g in mapGroups)check(g.alpha<.01f && !g.blocksRaycasts,"Map HUD must initially be hidden");
    capture(.75f,"Transition");
    foreach(var g in mainGroups)check(!g.interactable && !g.blocksRaycasts,"Outgoing HUD must not accept clicks");
    foreach(var g in mapGroups)check(!g.interactable && !g.blocksRaycasts,"Incoming HUD must not accept clicks mid-motion");
    capture(1,"MapHud");
    foreach(var g in mainGroups)check(g.alpha<.01f && !g.blocksRaycasts,"Main HUD must exit fully");
    foreach(var g in mapGroups)check(g.alpha>.99f && g.blocksRaycasts && ((RectTransform)g.transform).anchoredPosition.sqrMagnitude<.01f,"Map HUD must enter from edges and become interactive");
    check(((CanvasGroup)reference.Get("Group")).alpha==1,"Do not hide shared MainHud root or map labels");
    transition.SetProgress(.35f);transition.SetProgress(0);
    foreach(var g in mainGroups)check(g.alpha>.99f && ((RectTransform)g.transform).anchoredPosition.sqrMagnitude<.01f,"Reversal must restore authored layout");
    using(var lua=new XLua.LuaEnv())
    {
        lua.Global.Set("mapMotion",transition);lua.DoString("mapMotion:SetProgress(1)");
        check(mapGroups[0].alpha>.99f,"New component must work through actual xLua reflection");
    }

    var view=new ProjectY.Samples.AdventureViewData {Phase="map",Sites=new[]{new ProjectY.Samples.AdventureViewData.Site{Id=7,Name="预览城镇",Position=Vector3.zero}},
        MapMarkers=new[]{new ProjectY.Samples.AdventureViewData.MapMarker{SiteId=7,Kind="available",Count=2},
            new ProjectY.Samples.AdventureViewData.MapMarker{SiteId=7,Kind="active",Count=1},new ProjectY.Samples.AdventureViewData.MapMarker{SiteId=7,Kind="ready",Count=1},
            new ProjectY.Samples.AdventureViewData.MapMarker{SiteId=999,Kind="ready",Count=1}},
        Travel=new ProjectY.Samples.AdventureViewData.TravelState(),WorldParties=new ProjectY.Samples.AdventureViewData.WorldPartyState{Rows=new ProjectY.Samples.AdventureViewData.WorldParty[0]}};
    var markerType=typeof(ProjectY.Samples.AdventureRuntimeDemo).Assembly.GetType("ProjectY.Samples.WorldMapMarkerView",true);
    markerView=(System.IDisposable)System.Activator.CreateInstance(markerType,flags,null,new object[]{hud},null);
    System.Action tickMarkers=()=>{markerType.GetMethod("Tick",flags).Invoke(markerView,new object[]{camera,view,new Vector3(-20,0,-20),1f});hud.UpdateFollowers();};
    tickMarkers();var markers=(System.Collections.IDictionary)markerType.GetField("markers",flags).GetValue(markerView);
    System.Func<int> visibleCount=()=>{int n=0;foreach(var value in markers.Values)if(((RectTransform)value.GetType().GetField("Root",flags).GetValue(value)).gameObject.activeSelf)n++;return n;};
    System.Func<int> taskIconCount=()=>{int n=0;var value=markers[7];foreach(var icon in (UnityEngine.UI.Image[])value.GetType().GetField("Icons",flags).GetValue(value))if(icon.gameObject.activeSelf)n++;return n;};
    check(markers.Count==2 && visibleCount()==2 && taskIconCount()==3,"One compact badge per known site plus player; no duplicated names or unknown markers");
    map.GetToggle("AvailableMissions").isOn=false;tickMarkers();check(visibleCount()==2 && taskIconCount()==2,"Available filter");
    map.GetToggle("ActiveMissions").isOn=false;tickMarkers();check(visibleCount()==2 && taskIconCount()==1,"Active filter");
    map.GetToggle("ReadyMissions").isOn=false;tickMarkers();check(visibleCount()==1,"Ready filter");
    map.GetToggle("PlayerMarker").isOn=false;tickMarkers();check(visibleCount()==0 && markers.Count==2,"Player filter and pooled marker reuse");
    map.GetToggle("Route").isOn=false;check(!(bool)markerType.GetProperty("ShowRoute",flags).GetValue(markerView,null),"Route filter");
    foreach(var key in new[]{"AvailableMissions","ActiveMissions","ReadyMissions","PlayerMarker","Route"})map.GetToggle(key).isOn=true;
    tickMarkers();capture(1,"MapHud");
    markerType.GetMethod("Hide",flags).Invoke(markerView,null);check(!map.Get("MarkerRoot").gameObject.activeSelf,"Marker layer lifecycle");

    // Use the saved scene host's serialized model bindings without starting it.
    var hosts=Resources.FindObjectsOfTypeAll<ProjectY.Samples.AdventureRuntimeDemo>();ProjectY.Samples.AdventureRuntimeDemo source=null;
    foreach(var candidate in hosts)if(candidate.gameObject.scene==activeScene){source=candidate;break;}
    check(source!=null,"Existing Adventure scene host required for model visibility checks");
    var bindings=typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("worldPartyBindings",flags).GetValue(source);
    var partyType=typeof(ProjectY.Samples.AdventureRuntimeDemo).Assembly.GetType("ProjectY.Samples.WorldPartyView",true);
    partyView=(System.IDisposable)System.Activator.CreateInstance(partyType,flags,null,new object[]{canvasObject.transform,bindings,1f,Shader.Find("ProjectY/Map Preview Instanced"),new ProjectY.Samples.MapRenderLod.Settings()},null);
    partyType.GetMethod("Sync",flags).Invoke(partyView,new object[]{view});partyType.GetMethod("SetOverview",flags).Invoke(partyView,new object[]{true});
    partyType.GetMethod("Sync",flags).Invoke(partyView,new object[]{view});partyType.GetMethod("Render",flags).Invoke(partyView,new object[]{camera});
    var partyRoot=(GameObject)partyType.GetField("root",flags).GetValue(partyView);
    check(!partyRoot.activeSelf,"Polling must not reactivate NPC/faction models in overview");
    check((int)partyType.GetMethod("Pick",flags).Invoke(partyView,new object[]{camera,Vector2.zero})==0,"Hidden parties must not be selectable");
    partyType.GetMethod("SetOverview",flags).Invoke(partyView,new object[]{false});check(partyRoot.activeSelf,"Returning to close view restores party presentation");
    root.SetActive(false);transition.SetProgress(0);root.SetActive(true);transition.SetProgress(0);
    check(mainGroups[0].alpha>.99f,"Cached HUD reopen must reset correctly");
    check(activeScene.isDirty==dirty && !EditorApplication.isPlayingOrWillChangePlaymode,"Keep active scene and Play state unchanged");
    return "PASS world-map overview: "+checks+" native HUD/clip/filter/visibility/lifecycle checks; preview images in Docs/Previews/WorldMapOverview";
}
finally
{
    if(markerView!=null)markerView.Dispose();if(partyView!=null)partyView.Dispose();RenderTexture.active=savedTarget;
    if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
