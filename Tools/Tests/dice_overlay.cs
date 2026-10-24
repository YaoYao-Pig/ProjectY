// Run as a Unity MCP execute_code body. Real UIHost, UISystem, Lua controller and buttons; no Play or saves.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required.");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("DiceOverlayPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var target=new RenderTexture(1280,720,24);target.Create();
var previous=RenderTexture.active;var previousTime=Time.timeScale;
var cameraObject=new GameObject("DiceOverlayPreviewCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.045f,.065f,.105f);
camera.orthographic=true;camera.orthographicSize=360;camera.cullingMask=1<<31;camera.transform.position=new Vector3(0,0,-10);
camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.targetTexture=target;
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var path="Art/Dice/UnityPreview/Overlay";System.IO.Directory.CreateDirectory(path);
System.Action<string> capture=file=>
{
    foreach(var item in root.GetComponentsInChildren<Transform>(true))item.gameObject.layer=31;
    foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace)
    {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
    Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
    var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
    try{pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();System.IO.File.WriteAllBytes(file,pixels.EncodeToPNG());}
    finally{UnityEngine.Object.DestroyImmediate(pixels);RenderTexture.active=previous;}
};
try
{
    using(var lua=new XLua.LuaEnv())
    {
        lua.AddLoader((ref string module)=>System.IO.File.ReadAllBytes(System.IO.Path.Combine("Lua",module.Replace('.','/')+".lua")));
        lua.Global.Set("DiceHost",host);
        try
        {
            lua.DoString(@"
local UI=require('UI.UISystem'); local Checks=require('Game.Presentation.DiceChecks')
DiceUI=UI()
local context={services={UI=DiceHost},log=function(message) error(message,0) end}
context.systems={Get=function(_,name) assert(name=='UI');return DiceUI end}
DiceUI:OnInit(context)
DiceController=DiceUI:Open('DiceRoll',{check=Checks.Percent('清理阻路石堆',43,70,true,'inclusive')})
assert(DiceHost.IsWorldPaused and not DiceUI:Back())
DiceController:Enqueue(Checks.Percent('驯服山地鹿',62.37,50,false,'exclusive',100))
");
            for(int frame=0;frame<40;frame++)
            {
                lua.DoString("DiceUI:Tick(0,.075)");
                if(frame%2==0)capture(path+"/roll-"+(frame/2).ToString("D2")+".png");
            }
            capture(path+"/success.png");
            lua.DoString(@"
assert(DiceController.view.Dice.Settled and DiceController.view.Continue.interactable)
assert(DiceController.view.Result.text:find('43',1,true))
DiceController.view.Continue.onClick:Invoke()
assert(DiceController.check.reading=='62.37' and not DiceController.view.Continue.interactable)
DiceController.view.Reveal.onClick:Invoke();DiceUI:Tick(0,.5)
assert(DiceController.view.Result.text:find('62.37',1,true))
");
            capture(path+"/hundredths.png");
            lua.DoString(@"
DiceController.view.Continue.onClick:Invoke()
assert(not DiceUI:IsOpen('DiceRoll') and not DiceHost.IsWorldPaused)
local Checks=require('Game.Presentation.DiceChecks')
DiceUI:Open('DiceRoll',{check=Checks.Percent('缓存重开',100,70,false,'inclusive')})
assert(DiceHost.IsWorldPaused)
DiceUI:OnSceneChanged()
assert(not DiceUI:IsOpen('DiceRoll') and not DiceHost.IsWorldPaused)
");
            if(Time.timeScale!=previousTime)throw new System.Exception("Pause lease did not restore timeScale.");
        }
        finally{lua.DoString("if DiceUI then DiceUI:OnShutdown() end; DiceController=nil; DiceUI=nil; DiceHost=nil");lua.FullGc();}
    }
}
finally
{
    host.Shutdown();Time.timeScale=previousTime;RenderTexture.active=previous;camera.targetTexture=null;
    target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
return "PASS actual DiceRoll UI pause/back, unscaled playback, queued checks, real buttons, exact hundredths, cached reopen, scene cleanup and final UI captures.";
