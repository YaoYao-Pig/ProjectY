// Native menu regression and screenshots in isolated PreviewScenes. Never starts Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var entry=config.Get("StartMenu");entry.Validate(true);config.Get("CampaignSaveEntry").Validate(true);
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.UI.UIHost host=null;UnityEngine.Font font=null;UnityEngine.RenderTexture target=null;string report=null;
int scenesBefore=UnityEngine.SceneManagement.SceneManager.sceneCount;
string motionKey=ProjectY.UI.StartMenuView.ReducedMotionPreference;
bool hadMotion=UnityEngine.PlayerPrefs.HasKey(motionKey);int priorMotion=UnityEngine.PlayerPrefs.GetInt(motionKey,1);
UnityEngine.PlayerPrefs.SetInt(motionKey,0);
try
{
    var root=new UnityEngine.GameObject("Scene menu isolated validation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
    font=UnityEngine.Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","Noto Sans CJK SC","Arial"},18);
    var cameraObject=new UnityEngine.GameObject("Menu validation camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);var camera=cameraObject.AddComponent<UnityEngine.Camera>();camera.enabled=false;camera.scene=scene;camera.cullingMask=1<<31;camera.orthographic=true;camera.orthographicSize=360;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=UnityEngine.Color.black;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    target=new UnityEngine.RenderTexture(1280,720,24,UnityEngine.RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"scene-menu-unused-"+System.Guid.NewGuid().ToString("N")+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);lua.Global.Set("MenuFixtureFont",font);
        System.Action<string> capture=name=>
        {
            foreach(var node in root.GetComponentsInChildren<UnityEngine.Transform>(true))node.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<UnityEngine.Canvas>(true))if(canvas.isRootCanvas&&canvas.renderMode!=UnityEngine.RenderMode.WorldSpace){canvas.renderMode=UnityEngine.RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=10;}
            UnityEngine.Canvas.ForceUpdateCanvases();var view=root.GetComponentInChildren<ProjectY.UI.StartMenuView>(true);view.RenderNow();UnityEngine.Canvas.ForceUpdateCanvases();
            var stage=(ProjectY.UI.StartMenuStage)typeof(ProjectY.UI.StartMenuView).GetField("stage",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(view);
            if(name=="home")
            {
                if(stage.Camera.WorldToViewportPoint(stage.SignAnchors[0].position).x>=.45f)throw new System.Exception("Signpost must appear on the left.");
                var reference=view.GetComponent<ProjectY.UI.LuaReference>();var button=(UnityEngine.RectTransform)reference.Get("Start").transform;float roll=UnityEngine.Mathf.DeltaAngle(0,button.localEulerAngles.z);
                if(UnityEngine.Mathf.Abs(roll)>35)throw new System.Exception("Sign lettering is inverted.");
            }
            if(name=="transition"&&stage.Camera.transform.forward.x>=-.1f)throw new System.Exception("Subpage camera must turn right.");
            ProjectY.Rendering.UrpCameraRendering.Render(camera);
            var old=UnityEngine.RenderTexture.active;UnityEngine.Texture2D image=null;
            try{UnityEngine.RenderTexture.active=target;image=new UnityEngine.Texture2D(1280,720,UnityEngine.TextureFormat.RGB24,false);image.ReadPixels(new UnityEngine.Rect(0,0,1280,720),0,0);image.Apply();System.IO.Directory.CreateDirectory("Docs/Previews/MainMenu");System.IO.File.WriteAllBytes("Docs/Previews/MainMenu/"+name+".png",image.EncodeToPNG());}
            finally{UnityEngine.RenderTexture.active=old;if(image!=null)UnityEngine.Object.DestroyImmediate(image);}
        };
        lua.Global.Set("CaptureMenuScene",capture);
        try{report=(string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/start_menu_scene_integration.lua"),"@start_menu_scene_integration")[0];}
        finally{lua.Global.Set<string,object>("CaptureMenuScene",null);lua.Global.Set<string,object>("MenuFixtureFont",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    if(host!=null)host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(hadMotion)UnityEngine.PlayerPrefs.SetInt(motionKey,priorMotion);else UnityEngine.PlayerPrefs.DeleteKey(motionKey);
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(font!=null)UnityEngine.Object.DestroyImmediate(font);
}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene||originalScene.isDirty!=originalDirty)throw new System.Exception("User scene was modified.");
return new {passed=true,report,playMode=false,playerSavesTouched=false,previewDirectory="Docs/Previews/MainMenu"};
