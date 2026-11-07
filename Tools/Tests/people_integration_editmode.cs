// Unity MCP execute_code body. Run after the coordinated compile, config export and add_people_talk.cs.
// Real native services, data, configuration and saved prefabs in a fresh PreviewScene; never enters Play.
// World renderer snapshots are suppressed. Lua explicitly presents the newly opened dialogue after Talk.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
if(ProjectY.GameBootstrap.Instance!=null)throw new System.InvalidOperationException("An existing runtime must not be replaced by this check");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;
float originalScale=Time.timeScale;var originalRandom=UnityEngine.Random.state;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var localization=ProjectY.Data.LocalizationService.Shared;
var sources=(System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>)
    typeof(ProjectY.Data.LocalizationService).GetField("sources",flags).GetValue(localization);
var savedTexts=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>();
foreach(var source in sources)savedTexts.Add(source.Key,new System.Collections.Generic.Dictionary<string,string>(source.Value));
var errors=new System.Collections.Generic.List<string>();
UnityEngine.Application.LogCallback capture=(message,trace,type)=>{
    if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert)errors.Add(message);
};
UnityEngine.Application.logMessageReceived+=capture;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("People isolated integration");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();
var savePath=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-people-"+System.Guid.NewGuid().ToString("N"),"party.json");
var originalTarget=RenderTexture.active;
var cameraObject=new GameObject("People preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
camera.transform.position=new Vector3(0,0,-10);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.025f,.04f,.035f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var previewPath="Docs/Previews/People";System.IO.Directory.CreateDirectory(previewPath);
string report=null;
try{
    var adapter=new GameObject("People native UI input host");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(adapter,scene);
    adapter.SetActive(false);
    var demo=adapter.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
    var hud=adapter.AddComponent<ProjectY.UI.MainHudView>();
    typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("mainHud",flags).SetValue(demo,hud);
    typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("selectedCharacter",flags).SetValue(demo,1);
    typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("settlementPresentationPending",flags).SetValue(demo,true);
    typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("view",flags).SetValue(demo,new ProjectY.Samples.AdventureViewData{Phase="area",Error=""});
    var font=UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf");
    if(font==null)throw new System.Exception("Native UI font is missing");
    typeof(ProjectY.UI.MainHudView).GetField("font",flags).SetValue(hud,font);
    var inputProperty=typeof(ProjectY.Samples.AdventureRuntimeDemo).GetProperty("UnitDetailsOpen",flags);
    if(inputProperty==null)throw new System.Exception("UnitInspectionInput must be compiled before this check");
    host.Initialize();
    foreach(var name in new[]{"UnitDetails","InspectionTarget","Dialogue","DialogueEntry"})host.GetConfig(name).Validate(true);
    using(var lua=new XLua.LuaEnv()){
        var services=new ProjectY.FrameworkServices(host,savePath);
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("OpenDemo",false);lua.Global.Set("PeopleNativeDemo",demo);
        lua.Global.Set("PeopleNativeInputOpen",(System.Func<bool>)(()=> (bool)inputProperty.GetValue(demo)));
        System.Action<ProjectY.UI.LuaReference,string> captureUi=(reference,name)=>{
            foreach(var child in root.GetComponentsInChildren<Transform>(true))child.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace){
                canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;
            }
            Canvas.ForceUpdateCanvases();
            foreach(var label in reference.GetComponentsInChildren<ProjectY.UI.UITxt>(true))label.ForceMeshUpdate(true,true);
            foreach(var scroll in reference.GetComponentsInChildren<UnityEngine.UI.ScrollRect>(true))
                if(scroll.content!=null)UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(scroll.content);
            Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
            var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
            try{pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();System.IO.File.WriteAllBytes(previewPath+"/"+name+".png",pixels.EncodeToPNG());}
            finally{UnityEngine.Object.DestroyImmediate(pixels);RenderTexture.active=originalTarget;}
        };
        lua.Global.Set("CapturePeopleUi",captureUi);
        try{
            report=(string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/people_integration.lua"),"@Tools/Tests/people_integration.lua")[0];
            if(host.IsWorldPaused||(bool)inputProperty.GetValue(demo))throw new System.Exception("Native UI pause/input ownership leaked");
        }finally{
            using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();
            lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("PeopleNativeDemo",null);services.Player.ClearListeners();
        }
    }
}finally{
    try{host.Shutdown();}
    finally{
        camera.targetTexture=null;RenderTexture.active=originalTarget;target.Release();UnityEngine.Object.DestroyImmediate(target);
        UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
        localization.Clear();foreach(var source in savedTexts)foreach(var entry in source.Value)localization.SetText(source.Key,entry.Key,entry.Value);localization.NotifyChanged();
        Time.timeScale=originalScale;UnityEngine.Random.state=originalRandom;
        UnityEngine.Application.logMessageReceived-=capture;
    }
}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene||originalScene.isDirty!=originalDirty)
    throw new System.Exception("People integration changed the user's active scene");
if(errors.Count>0)throw new System.Exception("Native people integration emitted errors: "+string.Join(" | ",errors.ToArray()));
return new{passed=true,report,temporarySave=savePath,playMode=false,
    boundary="Real Talk button and Dialogue prefab; world-renderer snapshot presentation and C# dialogue command gate are not exercised"};
