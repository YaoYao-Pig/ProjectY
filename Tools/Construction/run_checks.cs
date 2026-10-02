// Unity MCP execute_code body. Isolated Edit Mode host; no scene switch or Play Mode.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("SkillAtlasValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var cameraObject=new GameObject("SkillAtlasPreviewCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.orthographic=true;camera.orthographicSize=5;camera.nearClipPlane=.01f;camera.farClipPlane=100;
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.07f,.09f,.08f);camera.transform.position=new Vector3(0,0,-10);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1440,900,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
var previous=RenderTexture.active;var oldTimeScale=Time.timeScale;
try
{
    System.Action<ProjectY.UI.LuaReference> arrange=reference=>{
        foreach(var canvas in root.GetComponentsInChildren<Canvas>(true)){canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
        Canvas.ForceUpdateCanvases();reference.GetComponent<ProjectY.UI.StoryGrowthView>().Prepare();Canvas.ForceUpdateCanvases();
    };
    System.Action<ProjectY.UI.LuaReference,string> capture=(reference,name)=>{
        arrange(reference);reference.GetComponent<ProjectY.UI.SkillAtlasView>().SendMessage("LateUpdate");
        ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
        var image=new Texture2D(target.width,target.height,TextureFormat.RGBA32,false);
        try{image.ReadPixels(new Rect(0,0,target.width,target.height),0,0);image.Apply();System.IO.Directory.CreateDirectory("Docs/Previews/SkillAtlas");System.IO.File.WriteAllBytes("Docs/Previews/SkillAtlas/"+name+".png",image.EncodeToPNG());}
        finally{UnityEngine.Object.DestroyImmediate(image);RenderTexture.active=previous;}
    };
    System.Action<ProjectY.UI.LuaReference,RectTransform> checkPopup=(reference,anchor)=>{
        arrange(reference);var geometry=reference.GetComponent<ProjectY.UI.SkillAtlasView>();var entries=reference.GetEditorBindings();
        var popup=(RectTransform)System.Array.Find(entries,row=>row.Key=="TipTitle").Target.transform.parent;
        var saved=anchor.anchoredPosition;geometry.Follow(anchor);var initial=popup.localPosition;
        anchor.anchoredPosition=saved+Vector2.right*11;geometry.SendMessage("LateUpdate");
        if(Mathf.Abs(popup.localPosition.x-initial.x-11)>.1f)throw new System.Exception("Popup did not follow its cell.");
        anchor.anchoredPosition=new Vector2(840,saved.y);geometry.Follow(anchor);
        var corners=new Vector3[4];anchor.GetWorldCorners(corners);float left=popup.parent.InverseTransformPoint(corners[1]).x;
        if(popup.localPosition.x+popup.rect.width>left-10)throw new System.Exception("Popup did not flip at right edge.");
        anchor.anchoredPosition=new Vector2(-5000,saved.y);geometry.SendMessage("LateUpdate");
        if(geometry.PopupVisible)throw new System.Exception("Offscreen cell retained its popup.");
        anchor.anchoredPosition=saved;
    };
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("ArrangeAtlas",arrange);lua.Global.Set("CaptureAtlas",capture);lua.Global.Set("CheckAtlasPopup",checkPopup);
        try{return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/skill_atlas_ui_integration.lua"),"@Tools/Tests/skill_atlas_ui_integration.lua")[0];}
        finally{lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("ArrangeAtlas",null);lua.Global.Set<string,object>("CaptureAtlas",null);lua.Global.Set<string,object>("CheckAtlasPopup",null);services.Player.ClearListeners();}
    }
}
finally
{
    host.Shutdown();Time.timeScale=oldTimeScale;camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
