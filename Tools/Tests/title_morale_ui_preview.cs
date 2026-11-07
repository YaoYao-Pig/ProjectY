// Isolated real UI check and screenshot. No Play, active-scene mutation or player-save access.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=originalScene.isDirty;
var originalTime=Time.timeScale;var originalRandom=UnityEngine.Random.state;var originalTarget=RenderTexture.active;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new GameObject("Title page validation");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var cameraObject=new GameObject("Title page camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
camera.transform.position=new Vector3(0,0,-10);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.04f,.06f,.05f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var output="Docs/Previews/TitlesAndMorale";System.IO.Directory.CreateDirectory(output);
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"title-ui-unused-"+System.Guid.NewGuid()+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        System.Action<ProjectY.UI.LuaReference> capture=reference=>
        {
            foreach(var child in root.GetComponentsInChildren<Transform>(true))child.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace)
            {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
            Canvas.ForceUpdateCanvases();foreach(var style in root.GetComponentsInChildren<ProjectY.UI.StoryGrowthView>())style.Prepare();Canvas.ForceUpdateCanvases();
            ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
            var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
            try{pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();System.IO.File.WriteAllBytes(output+"/title-page.png",pixels.EncodeToPNG());}
            finally{UnityEngine.Object.DestroyImmediate(pixels);RenderTexture.active=originalTarget;}
        };
        lua.Global.Set("CaptureTitleUI",capture);
        try{return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/title_morale_ui_integration.lua"),"@Tools/Tests/title_morale_ui_integration.lua")[0];}
        finally{lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("CaptureTitleUI",null);services.Player.ClearListeners();}
    }
}
finally
{
    host.Shutdown();camera.targetTexture=null;RenderTexture.active=originalTarget;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=originalTime;UnityEngine.Random.state=originalRandom;
    if(originalScene.isDirty!=dirty)throw new System.Exception("Title preview changed active scene");
}
