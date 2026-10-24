// Unity MCP execute_code body: isolated UI instances and temporary translation overrides; no Play/saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var service=ProjectY.Data.LocalizationService.Shared;
var sourceField=typeof(ProjectY.Data.LocalizationService).GetField("sources",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
var sources=(System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>)sourceField.GetValue(service);
var saved=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>();
foreach(var pair in sources)saved.Add(pair.Key,new System.Collections.Generic.Dictionary<string,string>(pair.Value));
float originalTime=Time.timeScale;int originalPreviews=UnityEditor.SceneManagement.EditorSceneManager.previewSceneCount;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("UILanguagePreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
int views=0,labels=0;
try
{
    var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
    foreach(var definition in config.Entries)foreach(var binding in definition.Prefab.GetComponent<ProjectY.UI.LuaReference>().GetEditorLocalizations())
        service.SetText("LuaTxt",binding.Id,"["+binding.Id+"]");
    foreach(var definition in config.Entries)
    {
        var view=definition.IsWidget?host.CreateWidget(definition.Name,root.transform):host.CreateView(definition.Name);
        try
        {
            foreach(var binding in view.GetEditorLocalizations())
            {
                var legacy=binding.Target as UnityEngine.UI.Text;var tmp=binding.Target as TMPro.TMP_Text;
                string text=legacy!=null?legacy.text:tmp.text;
                if(text!="["+binding.Id+"]")throw new System.Exception("Fixed UI text ignored its table: "+definition.Name+" / "+binding.Id);
                labels++;
            }
            views++;
        }
        finally{if(definition.IsWidget)host.DestroyWidget(view);else host.DestroyView(view);}
    }
    service.SetText("LuaTxt","BattleLogExpandedTitle","Battle log: {0} entries");
    if(ProjectY.UI.LuaLanguage.Format("BattleLogExpandedTitle",12)!="Battle log: 12 entries")throw new System.Exception("C# format override failed.");
    service.SetText("LuaTxt","InventorySearching","");
    if(ProjectY.UI.LuaLanguage.Get("InventorySearching")!="")throw new System.Exception("C# empty override was lost.");
    var translations=new System.Collections.Generic.Dictionary<string,string>{{"DiceRequirement","Required: %s"},{"DiceTens","Tens"},{"DiceUnits","Units"},
        {"DiceSuccess","Success"},{"DiceFailure","Failure"},{"UIDiceRollPanelContinueCaption","Continue"},{"UIDiceRollPanelRevealCaption","Reveal"}};
    foreach(var pair in translations)service.SetText("LuaTxt",pair.Key,pair.Value);
    using(var lua=new XLua.LuaEnv())
    {
        lua.AddLoader((ref string name)=>System.IO.File.ReadAllBytes(System.IO.Path.Combine("Lua",name.Replace('.','/')+".lua")));
        lua.Global.Set("LanguageHost",host);lua.Global.Set("Localizer",service);
        try
        {
            lua.DoString(@"
require('Config.LanguageProxy').Bind(function(id)return Localizer:Find('LuaTxt',id)end)
LanguageUI=require('UI.UISystem')()
local context={services={UI=LanguageHost},log=function(message)error(message,0)end}
context.systems={Get=function(_,name)assert(name=='UI');return LanguageUI end}
LanguageUI:OnInit(context)
LanguageDice=LanguageUI:Open('DiceRoll',{check=require('Game.Presentation.DiceChecks').Percent('Skill check',43,70,true,'inclusive')})
assert(LanguageDice.view.Detail.text=='Required: 70')
LanguageDice.view.Reveal.onClick:Invoke();LanguageUI:Tick(0,.5)
assert(LanguageDice.view.Result.text:find('Success',1,true))
");
            var cameraObject=new GameObject("LanguageCaptureCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
            var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
            camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
            camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.045f,.065f,.105f);
            camera.orthographic=true;camera.orthographicSize=360;camera.cullingMask=1<<31;camera.transform.position=new Vector3(0,0,-10);
            camera.nearClipPlane=.1f;camera.farClipPlane=100;
            ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
            var target=new RenderTexture(1280,720,24);target.Create();var previous=RenderTexture.active;
            var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
            try
            {
                camera.targetTexture=target;
                foreach(var item in root.GetComponentsInChildren<Transform>(true))item.gameObject.layer=31;
                foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace)
                {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
                Canvas.ForceUpdateCanvases();lua.DoString("LanguageUI:Tick(0,.05)");ProjectY.Rendering.UrpCameraRendering.Render(camera);
                RenderTexture.active=target;pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();
                System.IO.File.WriteAllBytes("Art/Localization/dice-english-proof.png",pixels.EncodeToPNG());
            }
            finally{RenderTexture.active=previous;camera.targetTexture=null;target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(pixels);}
            lua.DoString("LanguageDice.view.Continue.onClick:Invoke(); assert(not LanguageHost.IsWorldPaused)");
        }
        finally{lua.DoString("if LanguageUI then LanguageUI:OnShutdown() end;require('Config.LanguageProxy').Bind(nil);LanguageDice=nil;LanguageUI=nil;LanguageHost=nil;Localizer=nil");lua.FullGc();}
    }
}
finally
{
    host.Shutdown();Time.timeScale=originalTime;UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    sources.Clear();foreach(var pair in saved)sources.Add(pair.Key,pair.Value);service.NotifyChanged();
}
if(UnityEditor.SceneManagement.EditorSceneManager.previewSceneCount!=originalPreviews)throw new System.Exception("Language preview scene leaked.");
return new{result="PASS fixed labels, dynamic Lua text, C# formats, empty overrides, real DiceRoll buttons and cleanup",views=views,labels=labels,proof="Art/Localization/dice-english-proof.png"};
