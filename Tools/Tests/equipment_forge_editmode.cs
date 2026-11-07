// Execute as a Unity MCP execute_code body after the project's single coordinated compilation.
// No Play Mode, world generation, user save access, scene replacement or asset modification.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
if(ProjectY.GameBootstrap.Instance!=null)throw new System.Exception("Close the existing runtime before using an isolated UI fixture");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalDirty=originalScene.isDirty;
var originalScale=UnityEngine.Time.timeScale;
var originalRandom=UnityEngine.Random.state;
var originalTarget=UnityEngine.RenderTexture.active;
var localization=ProjectY.Data.LocalizationService.Shared;
var sourcesField=typeof(ProjectY.Data.LocalizationService).GetField("sources",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
var originalSources=(System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>)sourcesField.GetValue(localization);
var savedTexts=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>();
foreach(var source in originalSources)savedTexts.Add(source.Key,new System.Collections.Generic.Dictionary<string,string>(source.Value));
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new UnityEngine.GameObject("EquipmentForgeValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();
var errors=new System.Collections.Generic.List<string>();
UnityEngine.Application.LogCallback captureError=(message,trace,type)=>{
    if(type==UnityEngine.LogType.Error || type==UnityEngine.LogType.Exception || type==UnityEngine.LogType.Assert)errors.Add(message);
};
UnityEngine.Application.logMessageReceived+=captureError;
UnityEngine.RenderTexture target=null;UnityEngine.Texture2D pixels=null;UnityEngine.Camera camera=null;
string result=null;
try{
    host.Initialize();
    foreach(var name in new[]{"Camp","NarrativeEntry","Dialogue","DialogueEntry"})host.GetConfig(name).Validate(true);
    var cameraObject=new UnityEngine.GameObject("ForgePreviewCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    camera=cameraObject.AddComponent<UnityEngine.Camera>();camera.enabled=false;camera.scene=scene;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.08f,.11f,.12f);
    camera.orthographic=true;camera.orthographicSize=360;camera.cullingMask=1<<31;camera.transform.position=new UnityEngine.Vector3(0,0,-10);
    camera.nearClipPlane=.1f;camera.farClipPlane=100;ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var lightObject=new UnityEngine.GameObject("ForgePreviewLight");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);
    var light=lightObject.AddComponent<UnityEngine.Light>();light.type=UnityEngine.LightType.Directional;light.cullingMask=1<<31;
    target=new UnityEngine.RenderTexture(1280,720,24);target.Create();pixels=new UnityEngine.Texture2D(1280,720,UnityEngine.TextureFormat.RGB24,false);
    var savePath=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-forge-"+System.Guid.NewGuid().ToString("N"),"unused.json");
    var font=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf");
    if(font==null)throw new System.Exception("The native UI test font is missing");
    using(var lua=new XLua.LuaEnv()){
        var services=new ProjectY.FrameworkServices(host,savePath);
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("OpenDemo",false);lua.Global.Set("ForgeTestFont",font);
        System.Action<string> screenshot=name=>{
            camera.targetTexture=target;
            foreach(var item in root.GetComponentsInChildren<UnityEngine.Transform>(true))item.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<UnityEngine.Canvas>(true))
                if(canvas.transform.parent==root.transform && canvas.renderMode!=UnityEngine.RenderMode.WorldSpace){
                    canvas.renderMode=UnityEngine.RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;
                }
            UnityEngine.Canvas.ForceUpdateCanvases();
            foreach(var rect in root.GetComponentsInChildren<UnityEngine.RectTransform>(true))UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(rect);
            UnityEngine.Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);
            UnityEngine.RenderTexture.active=target;pixels.ReadPixels(new UnityEngine.Rect(0,0,1280,720),0,0);pixels.Apply();
            var directory=System.IO.Path.GetFullPath("Docs/Previews/EquipmentForge");System.IO.Directory.CreateDirectory(directory);
            System.IO.File.WriteAllBytes(System.IO.Path.Combine(directory,name+".png"),pixels.EncodeToPNG());
        };
        lua.Global.Set("ForgePreviewCapture",screenshot);
        try{result=(string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/equipment_forge_integration.lua"),"@Tools/Tests/equipment_forge_integration.lua")[0];}
        finally{
            using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();
            lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("ForgePreviewCapture",null);services.Player.ClearListeners();
        }
        if(System.IO.File.Exists(savePath))throw new System.Exception("The UI fixture unexpectedly wrote a save");
    }
}finally{
    try{host.Shutdown();}
    finally{
        UnityEngine.RenderTexture.active=originalTarget;
        if(camera!=null)camera.targetTexture=null;
        if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
        if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
        UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
        localization.Clear();foreach(var source in savedTexts)foreach(var entry in source.Value)localization.SetText(source.Key,entry.Key,entry.Value);localization.NotifyChanged();
        UnityEngine.Time.timeScale=originalScale;UnityEngine.Random.state=originalRandom;
        UnityEngine.Application.logMessageReceived-=captureError;
    }
}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("The isolated UI fixture changed the user's active scene state");
if(errors.Count>0)throw new System.Exception("Native forge UI emitted errors: "+string.Join(" | ",errors.ToArray()));
return result+"; preview PNGs: Docs/Previews/EquipmentForge; original scene, localization, time scale and Unity random state restored";
