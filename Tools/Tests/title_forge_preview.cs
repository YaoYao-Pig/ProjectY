// Unity MCP execute_code body. Isolated native UI/services only; no Play, Refresh or player saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required for title forge UI validation.");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=originalScene.isDirty;
var originalTime=Time.timeScale;var originalRandom=UnityEngine.Random.state;var originalTarget=RenderTexture.active;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new GameObject("Title forge validation");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var cameraObject=new GameObject("Title forge camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
camera.transform.position=new Vector3(0,0,-10);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.04f,.06f,.05f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var output="Docs/Previews/TitleForge";System.IO.Directory.CreateDirectory(output);
var measurements=new System.Text.StringBuilder();
try{
    using(var lua=new XLua.LuaEnv()){
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"title-forge-ui-unused-"+System.Guid.NewGuid()+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        System.Action<string,ProjectY.UI.LuaReference> capture=(name,reference)=>{
            System.Func<UnityEngine.UI.Text,string> metrics=text=>{
                var names=new System.Collections.Generic.List<string>();var cursor=text.transform;
                while(cursor!=null){names.Insert(0,cursor.name);cursor=cursor.parent;}
                return string.Join("/",names.ToArray())+"; preferredHeight="+text.preferredHeight+"; rectHeight="+text.rectTransform.rect.height
                    +"; text="+text.text+"; font="+(text.font!=null?text.font.name:"<null>")+"; size="+text.fontSize;
            };
            foreach(var child in root.GetComponentsInChildren<Transform>(true))child.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace)
            {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
            Canvas.ForceUpdateCanvases();foreach(var style in root.GetComponentsInChildren<ProjectY.UI.StoryGrowthView>())style.Prepare();Canvas.ForceUpdateCanvases();
            if(name=="title-forge"){
                foreach(var key in new[]{"Title","Owner","Balance","NameLabel","Permanent","PreviewTitle","PositiveCost","DiscountCost","TotalCost","Hint"}){
                    var text=reference.GetText(key);float needed=text.preferredHeight,available=text.rectTransform.rect.height;
                    measurements.AppendLine(metrics(text));
                    if(needed>available+.5f)throw new System.Exception("Title forge text clipped: "+metrics(text));
                }
                var list=(ProjectY.UI.LuaReference)reference.Get("EffectList");var scroll=(UnityEngine.UI.ScrollRect)list.Get("ScrollRect");
                if(scroll.content.rect.height<=scroll.viewport.rect.height)throw new System.Exception("All title effects must use a genuinely scrollable list.");
                foreach(var cell in scroll.content.GetComponentsInChildren<ProjectY.UI.LuaReference>(false)){
                    foreach(var entry in cell.GetEditorBindings())if(entry.Target is UnityEngine.UI.Text text){
                        if(text.preferredHeight>text.rectTransform.rect.height+.5f)throw new System.Exception("Title row text clipped: "+metrics(text));
                    }
                }
                var saved=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Adventure/TitleForgePanel.prefab").GetComponent<ProjectY.UI.LuaReference>();
                foreach(var entry in saved.GetEditorLocalizations()){
                    if(entry.Target==null)throw new System.Exception("Missing saved localization target: "+entry.Id);
                    ProjectY.UI.LuaLanguage.Get(entry.Id);
                }
            }
            ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
            var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
            try{pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();System.IO.File.WriteAllBytes(output+"/"+name+".png",pixels.EncodeToPNG());}
            finally{UnityEngine.Object.DestroyImmediate(pixels);RenderTexture.active=originalTarget;}
        };
        lua.Global.Set("CaptureTitleForgeUI",capture);
        try{
            var result=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/title_forge_ui.lua"),"@Tools/Tests/title_forge_ui.lua")[0];
            System.IO.File.WriteAllText(output+"/validation.txt",result+"\n"+measurements,new System.Text.UTF8Encoding(false));
            return result+"\n"+measurements;
        }finally{lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("CaptureTitleForgeUI",null);services.Player.ClearListeners();}
    }
}finally{
    host.Shutdown();camera.targetTexture=null;RenderTexture.active=originalTarget;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=originalTime;UnityEngine.Random.state=originalRandom;
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene||originalScene.isDirty!=dirty)throw new System.Exception("Title forge validation changed the active scene.");
}
