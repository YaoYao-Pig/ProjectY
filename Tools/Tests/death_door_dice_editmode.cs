// Actual D20 trajectory, UI controller, queue and reveal buttons in an isolated PreviewScene.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new GameObject("DeathDoorDicePreview");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var previous=RenderTexture.active;var previousTime=Time.timeScale;var originalRandom=UnityEngine.Random.state;
var cameraObject=new GameObject("Death door camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.045f,.065f,.105f);
camera.orthographic=true;camera.orthographicSize=360;camera.cullingMask=1<<31;camera.transform.position=new Vector3(0,0,-10);
camera.nearClipPlane=.1f;camera.farClipPlane=100;ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var path="Docs/Previews/DeathDoor";System.IO.Directory.CreateDirectory(path);
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
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("DiceHost",host);
        try
        {
            lua.DoString(@"
local UI=require('UI.UISystem');local Checks=require('Game.Presentation.DiceChecks');local L=require('Language')
DeathDiceUI=UI();local context={services={UI=DiceHost},log=function(message)error(message,0)end}
context.systems={Get=function(_,name)assert(name=='UI');return DeathDiceUI end};DeathDiceUI:OnInit(context)
local function request(roll,faces,current)
 return Checks.FromBattleEvent({kind='death_door_check',impact={checkName=string.format(L.DeathDoorCheckTitle,'艾岚'),dieSides=20,
  roll=roll,deathFaces=faces,deathChance=faces*5,passed=roll>faces,morale=current,moraleMaximum=100}})
end
DeathDice=DeathDiceUI:Open('DiceRoll',{check=request(19,2,100)})
assert(DiceHost.IsWorldPaused and not DeathDiceUI:Back() and DeathDice.view.Dice.DieCount==1)
assert(DeathDice.view.Dice.SampleCount>10 and not DeathDice.view.Continue.interactable)
DeathDice:Enqueue(request(1,9,60))
");
            for(int frame=0;frame<30;frame++){lua.DoString("DeathDiceUI:Tick(0,.1)");capture(path+"/roll-"+frame.ToString("D2")+".png");}
            lua.DoString(@"
DeathDice.view.Reveal.onClick:Invoke();DeathDiceUI:Tick(0,.01)
assert(DeathDice.view.Dice.Settled and DeathDice.view.Dice:VisibleValue(0)==19 and DeathDice.view.Result.text:find(require('Language').DeathDoorSurvived,1,true))
");
            capture(path+"/survived.png");
            lua.DoString(@"
DeathDice.view.Continue.onClick:Invoke()
assert(DeathDice.check.dice[1].value==1 and not DeathDice.view.Continue.interactable and DiceHost.IsWorldPaused)
DeathDice.view.Reveal.onClick:Invoke();DeathDiceUI:Tick(0,.01)
assert(DeathDice.view.Dice:VisibleValue(0)==1 and DeathDice.view.Result.text:find(require('Language').DeathDoorDied,1,true))
");
            capture(path+"/dead.png");
            lua.DoString(@"
DeathDice.view.Continue.onClick:Invoke()
assert(not DeathDiceUI:IsOpen('DiceRoll') and not DiceHost.IsWorldPaused)
");
            return "PASS native D20: physical trajectory, single die, authoritative top face, survival/death labels, queued checks, fast reveal and pause release";
        }
        finally{lua.DoString("if DeathDiceUI then DeathDiceUI:OnShutdown()end;DeathDice=nil;DeathDiceUI=nil;DiceHost=nil");lua.FullGc();}
    }
}
finally
{
    host.Shutdown();camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=previousTime;UnityEngine.Random.state=originalRandom;
}
