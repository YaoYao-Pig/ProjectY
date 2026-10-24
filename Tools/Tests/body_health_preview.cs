// Render the real inventory/controller in an isolated PreviewScene. Never enters Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var hostObject=new GameObject("Health preview host");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(hostObject,scene);
var host=hostObject.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var previous=RenderTexture.active;var target=new RenderTexture(1080,1040,24,RenderTextureFormat.ARGB32);target.Create();
var cameraObject=new GameObject("Health preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.orthographic=true;
camera.aspect=1080f/1040;camera.nearClipPlane=.1f;camera.farClipPlane=2000;
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.035f,.055f,.065f);camera.targetTexture=target;
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host);
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try
        {
            var values=lua.DoString(@"
                registry=require('Core.SystemRegistry')(Services)
                registry:Register('Config',require('Config.ConfigSystem'))
                registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
                registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
                registry:Register('UI',require('UI.UISystem'),{'Config'});registry:Start()
                local data=Services.Adventure;data:Reset(51)
                local battle=registry:Get('Battle');registry:Get('Equipment'):Start()
                local a=data:AddPartyActor(1,1);a:SetMaxHP(battle.stats:MaximumHP(a));a:Restore();battle.appearances:Party(a,51)
                local injury=CS.ProjectY.Data.BodyHealth
                injury.Injure(a,0,1,25);injury.Injure(a,1,4,55);injury.Injure(a,4,1,60)
                injury.Hit(a,3,injury.MaximumHP(a,3),2);injury.Hit(a,3,1,2);injury.Hit(a,4,2,1)
                battle.gameEffects:Apply(1902,a,a)
                local demo={SetEquipmentOpen=function()end,SendCommand=function()end}
                panel=registry:Get('UI'):Open('Inventory',{demo=demo});panel.view.Health.onClick:Invoke();panel.view.HealthPart4.onClick:Invoke()
                return panel.view.Root
            ");
            var rect=(RectTransform)values[0];rect.SetParent(null,false);
            var canvas=rect.GetComponent<Canvas>();canvas.renderMode=RenderMode.WorldSpace;canvas.worldCamera=camera;
            var scaler=rect.GetComponent<UnityEngine.UI.CanvasScaler>();if(scaler!=null)scaler.enabled=false;
            rect.sizeDelta=new Vector2(1440,760);rect.localPosition=Vector3.zero;rect.localScale=Vector3.one;
            var reference=rect.GetComponent<ProjectY.UI.LuaReference>();((ProjectY.UI.InventoryPanelView)reference.Get("Inventory")).Prepare();
            Canvas.ForceUpdateCanvases();
            var health=(RectTransform)reference.Get("HealthOverlay");var center=health.TransformPoint(health.rect.center);
            camera.orthographicSize=health.rect.height*health.lossyScale.y/2;
            camera.transform.position=new Vector3(center.x,center.y,-1000);
            ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
            var pixels=new Texture2D(target.width,target.height,TextureFormat.RGBA32,false);
            try
            {
                pixels.ReadPixels(new Rect(0,0,target.width,target.height),0,0);pixels.Apply();
                System.IO.Directory.CreateDirectory("Docs/Previews/BodyHealth");
                System.IO.File.WriteAllBytes("Docs/Previews/BodyHealth/BodyHealth.png",pixels.EncodeToPNG());
            }
            finally {UnityEngine.Object.DestroyImmediate(pixels);}
            var diseaseScroll=(UnityEngine.UI.ScrollRect)reference.Get("HealthDiseaseScroll");
            if(reference.GetText("HealthDiseases").preferredHeight>diseaseScroll.viewport.rect.height+1)throw new System.Exception("Single infection summary is clipped");
            var detail=reference.GetText("HealthDetail");var note=(UnityEngine.UI.Text)health.Find("HealthNote").GetComponent<UnityEngine.UI.Text>();
            if(detail.preferredHeight>detail.rectTransform.rect.height+1 || note.preferredHeight>note.rectTransform.rect.height+1)
                throw new System.Exception("Health text overflows its saved layout");
        }
        finally {lua.DoString("if registry then registry:Shutdown()end");lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    host.Shutdown();camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Health preview changed the user's scene");
return "Docs/Previews/BodyHealth/BodyHealth.png";
