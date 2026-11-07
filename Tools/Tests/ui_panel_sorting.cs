// Real nested-Canvas regression: a later-created HUD must not paint above Loading.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;float originalScale=Time.timeScale;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();ProjectY.UI.UIHost host=null;RenderTexture target=null;Font font=null;
var reports=new System.Collections.Generic.List<string>();
try{
    var root=new GameObject("Panel sorting validation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
    var loading=host.CreateView("Loading");host.SetVisible(loading,true);host.SetOrder(loading,102);
    var hud=host.CreateView("MainHud");host.SetVisible(hud,true);host.SetOrder(hud,101);
    var loadingCanvas=host.GetPanel(loading).Canvas;var hudCanvas=host.GetPanel(hud).Canvas;
    if(!loadingCanvas.overrideSorting||loadingCanvas.sortingOrder!=102||!hudCanvas.overrideSorting||hudCanvas.sortingOrder!=101)
        throw new System.Exception("Panel sort configuration was lost when the inactive clone became active");
    host.SetVisible(loading,false);host.SetVisible(loading,true);host.SetOrder(loading,103);
    if(!loadingCanvas.overrideSorting||loadingCanvas.sortingOrder!=103)throw new System.Exception("Cached reopen lost panel order");
    reports.Add("New and cached panels apply native override sorting after activation");
    font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","Noto Sans CJK SC","Arial"},18);
    foreach(var label in loading.GetComponentsInChildren<UnityEngine.UI.Text>(true))label.font=font;
    ((UnityEngine.UI.Text)loading.Get("Title")).text=ProjectY.UI.LuaLanguage.Get("CampaignLoadingLoadTitle");
    ((UnityEngine.UI.Text)loading.Get("Stage")).text=ProjectY.UI.LuaLanguage.Get("CampaignLoadingResources");
    ((UnityEngine.UI.Slider)loading.Get("Progress")).value=.11f;((UnityEngine.UI.Text)loading.Get("Percent")).text="11%";
    var cameraObject=new GameObject("Sorting preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.cullingMask=1<<31;camera.orthographic=true;camera.orthographicSize=360;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.magenta;camera.nearClipPlane=.1f;camera.farClipPlane=100;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    target=new RenderTexture(1280,720,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
    foreach(var node in root.GetComponentsInChildren<Transform>(true))node.gameObject.layer=31;
    foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.isRootCanvas){canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=10;}
    System.Func<string,Color32[]> capture=name=>{
        Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);
        var previous=RenderTexture.active;var texture=new Texture2D(1280,720,TextureFormat.RGB24,false);
        try{RenderTexture.active=target;texture.ReadPixels(new Rect(0,0,1280,720),0,0);texture.Apply();
            if(name!=null){System.IO.Directory.CreateDirectory("Docs/Previews/Loading");System.IO.File.WriteAllBytes("Docs/Previews/Loading/"+name+".png",texture.EncodeToPNG());}
            return texture.GetPixels32();}
        finally{RenderTexture.active=previous;UnityEngine.Object.DestroyImmediate(texture);}
    };
    var withHud=capture("loading-over-hud");host.SetVisible(hud,false);var withoutHud=capture(null);
    int different=0;for(int i=0;i<withHud.Length;i++)if(!withHud[i].Equals(withoutHud[i]))different++;
    if(different!=0)throw new System.Exception("HUD leaked through Loading: "+different+" pixels differ");
    host.SetVisible(loading,false);host.SetVisible(hud,true);var hudOnly=capture(null);
    different=0;for(int i=0;i<hudOnly.Length;i++)if(!hudOnly[i].Equals(withoutHud[i]))different++;
    if(different<1000)throw new System.Exception("HUD control render was not visible");
    reports.Add("Loading pixels are identical with/without a visible HUD; HUD returns when Loading closes");
    if(host.IsWorldPaused)throw new System.Exception("Loading did not release pause");
}finally{
    if(host!=null)host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(font!=null)UnityEngine.Object.DestroyImmediate(font);
}
if(Time.timeScale!=originalScale||UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene||originalScene.isDirty!=originalDirty)throw new System.Exception("User scene/time was modified");
return new{passed=true,checks=reports,playMode=false,screenshot="Docs/Previews/Loading/loading-over-hud.png"};
