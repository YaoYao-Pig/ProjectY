// Unity MCP execute_code body. Uses a PreviewScene, isolated LuaEnv/services and actual saved UI.
// Run only after the single coordinated compile and Tools/UI/build_unit_details.cs; never enters Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;
float originalTime=Time.timeScale;var originalRandom=UnityEngine.Random.state;var originalTarget=RenderTexture.active;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("Unit details isolated UI check");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var adapterObject=new GameObject("Unit details native input fixture");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(adapterObject,scene);
adapterObject.SetActive(false);
var demo=adapterObject.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
var hud=adapterObject.AddComponent<ProjectY.UI.MainHudView>();
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("mainHud",flags).SetValue(demo,hud);
typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("selectedCharacter",flags).SetValue(demo,1);
// The UI submits its own real inspection command. Snapshot rendering alone is gated to avoid constructing a world scene.
typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("settlementPresentationPending",flags).SetValue(demo,true);
var openProperty=typeof(ProjectY.Samples.AdventureRuntimeDemo).GetProperty("UnitDetailsOpen",flags);
if(openProperty==null)throw new System.Exception("UnitInspectionInput must be compiled first");
var cameraObject=new GameObject("Unit details preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
camera.transform.position=new Vector3(0,0,-10);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.025f,.04f,.035f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var output="Docs/Previews/UnitDetails";System.IO.Directory.CreateDirectory(output);
int nativeCases=0;
System.Action<bool,string> check=(condition,message)=>{if(!condition)throw new System.Exception(message);};
System.Action<ProjectY.UI.LuaReference> layout=reference=>{
    Canvas.ForceUpdateCanvases();
    ((ProjectY.UI.NarrativeView)reference.Get("Style")).Prepare(demo.MainHudFont,1100);
    foreach(var key in new[]{"TargetScroll","AttributeScroll","TraitScroll"}){
        var scroll=(UnityEngine.UI.ScrollRect)reference.Get(key);
        var text=scroll.content.GetComponent<ProjectY.UI.UITxt>();if(text!=null)text.ForceMeshUpdate(true,true);
        UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(scroll.content);
    }
    Canvas.ForceUpdateCanvases();
};
try{
    using(var lua=new XLua.LuaEnv()){
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"unit-details-unused-"+System.Guid.NewGuid()+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("InspectionDemo",demo);
        lua.Global.Set("InspectionInputOpen",(System.Func<bool>)(()=> (bool)openProperty.GetValue(demo)));
        System.Action<ProjectY.UI.LuaReference,string> inspect=(reference,phase)=>{
            reference.ValidateBindings();layout(reference);
            var page=(RectTransform)reference.Get("Page");
            check(Mathf.Abs(page.rect.width-1100)<.1f&&Mathf.Abs(page.rect.height-640)<.1f,"Unexpected UnitDetails page dimensions");
            foreach(var key in new[]{"TargetScroll","AttributeScroll","TraitScroll"}){
                var scroll=(UnityEngine.UI.ScrollRect)reference.Get(key);
                check(scroll.vertical&&!scroll.horizontal&&scroll.viewport.GetComponent<UnityEngine.UI.RectMask2D>()!=null,"Independent vertical masked scroll missing: "+key);
                check(scroll.content.rect.height>scroll.viewport.rect.height,"Long fixture content did not become scrollable: "+key);
                scroll.verticalNormalizedPosition=0;Canvas.ForceUpdateCanvases();
                check(scroll.content.anchoredPosition.y>0,"Scroll could not reach overflow content: "+key);
                scroll.verticalNormalizedPosition=1;
            }
            foreach(var text in reference.GetComponentsInChildren<ProjectY.UI.UITxt>(true)){
                check(text.font!=null&&text.fontSize>=16,"Unbound or undersized details text: "+text.name);
                if(text.GetComponent<UnityEngine.UI.ContentSizeFitter>()==null&&text.DefaultText.Length>0){
                    text.ForceMeshUpdate(true,true);
                    var parts=new System.Collections.Generic.List<string>();var current=text.transform;
                    while(current!=reference.transform&&current!=null){parts.Insert(0,current.name);current=current.parent;}
                    check(text.preferredHeight<=text.rectTransform.rect.height+2,"Fixed text vertically clips: "+string.Join("/",parts.ToArray())+
                        " preferred="+text.preferredHeight+" actual="+text.rectTransform.rect.height+" font="+text.fontSize);
                }
            }
            foreach(var binding in reference.GetEditorLocalizations())check(!string.IsNullOrEmpty(ProjectY.UI.LuaLanguage.Get(binding.Id)),"Missing localized label "+binding.Id);
            nativeCases++;
        };
        System.Action<ProjectY.UI.LuaReference,string> capture=(reference,name)=>{
            foreach(var child in root.GetComponentsInChildren<Transform>(true))child.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace){
                canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;
            }
            layout(reference);ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
            var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
            try{pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();System.IO.File.WriteAllBytes(output+"/"+name+".png",pixels.EncodeToPNG());}
            finally{UnityEngine.Object.DestroyImmediate(pixels);RenderTexture.active=originalTarget;}
        };
        lua.Global.Set("InspectUnitDetails",inspect);lua.Global.Set("CaptureUnitDetails",capture);
        try{
            var report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/unit_details_ui.lua"),"@Tools/Tests/unit_details_ui.lua")[0];
            check(!host.IsWorldPaused&&Mathf.Approximately(Time.timeScale,originalTime),"Pause lease was not restored");
            check(!(bool)openProperty.GetValue(demo),"Native detail input ownership leaked");
            return new{passed=true,nativeCases,report,previews=output,playMode=false};
        }finally{lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("InspectionDemo",null);services.Player.ClearListeners();}
    }
}finally{
    host.Shutdown();camera.targetTexture=null;RenderTexture.active=originalTarget;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=originalTime;UnityEngine.Random.state=originalRandom;
    if(originalScene.isDirty!=originalDirty)throw new System.Exception("Unit details check changed the active scene");
}
