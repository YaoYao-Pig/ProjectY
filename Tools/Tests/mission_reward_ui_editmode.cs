if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("MissionRewardValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();var scale=Time.timeScale;
var cameraObject=new GameObject("MissionPreviewCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.08f,.11f,.12f);camera.orthographic=true;
camera.orthographicSize=360;camera.cullingMask=1<<31;camera.transform.position=new Vector3(0,0,-10);camera.nearClipPlane=.1f;camera.farClipPlane=100;
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();var previous=RenderTexture.active;var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
string path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-mission-rewards-"+System.Guid.NewGuid().ToString("N")+".json");
try{
    using(var lua=new XLua.LuaEnv()){
        var services=new ProjectY.FrameworkServices(host,path);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("OpenDemo",false);
        lua.Global.Set("MissionTestFont",UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf"));
        System.Action<string> capture=name=>{
            camera.targetTexture=target;
            foreach(var item in root.GetComponentsInChildren<Transform>(true))item.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace){canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
            Canvas.ForceUpdateCanvases();
            foreach(var rect in root.GetComponentsInChildren<RectTransform>(true))UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(rect);
            Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);
            RenderTexture.active=target;pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();
            System.IO.Directory.CreateDirectory("Docs/Previews/Missions");System.IO.File.WriteAllBytes("Docs/Previews/Missions/"+name+".png",pixels.EncodeToPNG());
        };
        lua.Global.Set("MissionPreviewCapture",capture);
        try{return (string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/mission_reward_ui.lua"),"@Tools/Tests/mission_reward_ui.lua")[0];}
        finally{using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("MissionPreviewCapture",null);services.Player.ClearListeners();}
    }
}finally{host.Shutdown();RenderTexture.active=previous;camera.targetTexture=null;target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(pixels);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=scale;}
