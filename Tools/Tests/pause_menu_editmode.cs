// Native prefab/layout and pause ownership check, isolated from the user's scene and saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
UnityEditor.AssetDatabase.ImportAsset("Assets/GameFramework/Resources/_Gen/Config/LuaTxt.bytes");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var definition=config.Get("PauseMenu");definition.Validate(true);
if(!definition.Modal||!definition.PauseWorldOnOpen||!definition.CloseOnBack||!definition.CloseOnSceneChange)throw new System.Exception("Invalid pause policy");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;float originalScale=Time.timeScale;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();ProjectY.UI.UIHost host=null;RenderTexture target=null;
string result=null;
try{
    var root=new GameObject("Pause menu native preview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
    var cameraObject=new GameObject("Pause menu preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.cullingMask=1<<31;camera.orthographic=true;camera.orthographicSize=360;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.27f,.32f,.31f,1);camera.nearClipPlane=.1f;camera.farClipPlane=100;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    target=new RenderTexture(1280,720,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
    using(var lua=new XLua.LuaEnv()){
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"pause-menu-unused-"+System.Guid.NewGuid().ToString("N")+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        System.Action<ProjectY.UI.LuaReference> capture=reference=>{
            if(!host.IsWorldPaused||Time.timeScale!=0)throw new System.Exception("Menu failed to pause world");
            foreach(var node in root.GetComponentsInChildren<Transform>(true))node.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.isRootCanvas){canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=10;}
            Canvas.ForceUpdateCanvases();var page=(RectTransform)reference.Get("Page");
            var rootRect=(RectTransform)reference.transform;
            if(Mathf.Abs(page.rect.width-rootRect.rect.width*.5f)>.1f||page.anchorMin!=Vector2.zero||page.anchorMax!=new Vector2(.5f,1))throw new System.Exception("Page must occupy the left half");
            float prior=float.PositiveInfinity;
            foreach(var key in new[]{"Resume","Save","Load","Settings","Quit"}){
                var button=(UnityEngine.UI.Button)reference.Get(key);var corners=new Vector3[4];((RectTransform)button.transform).GetWorldCorners(corners);
                if(corners[1].y>=prior)throw new System.Exception("Incorrect menu ordering");prior=corners[1].y;
                var label=(ProjectY.UI.UITxt)reference.Get(key+"Text");if(label.DefaultText!=ProjectY.UI.LuaLanguage.Get("PauseMenu"+key))throw new System.Exception("Unlocalized button "+key);
            }
            if(reference.GetEditorLocalizations().Length!=10)throw new System.Exception("Missing localized fixed labels");
            ProjectY.Rendering.UrpCameraRendering.Render(camera);
            var old=RenderTexture.active;Texture2D image=null;
            try{RenderTexture.active=target;image=new Texture2D(1280,720,TextureFormat.RGB24,false);image.ReadPixels(new Rect(0,0,1280,720),0,0);image.Apply();
                System.IO.Directory.CreateDirectory("Docs/Previews/PauseMenu");System.IO.File.WriteAllBytes("Docs/Previews/PauseMenu/menu.png",image.EncodeToPNG());}
            finally{RenderTexture.active=old;if(image!=null)UnityEngine.Object.DestroyImmediate(image);}
        };
        lua.Global.Set("CapturePauseMenu",capture);
        try{result=(string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/pause_menu.lua"),"@pause_menu_native")[0];}
        finally{lua.Global.Set<string,object>("CapturePauseMenu",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}finally{
    if(host!=null)host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
}
if(Time.timeScale!=originalScale||UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene||originalScene.isDirty!=originalDirty)throw new System.Exception("User scene/time state was modified");
return new{passed=true,result,playMode=false,playerSavesTouched=false,screenshot="Docs/Previews/PauseMenu/menu.png"};
