// Existing idle Editor, PreviewScene and an OS temporary save. Never enters Play.
if(EditorApplication.isPlayingOrWillChangePlaymode||EditorApplication.isCompiling)throw new System.InvalidOperationException("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var oldTime=Time.timeScale;var oldTarget=RenderTexture.active;
var oldRandom=UnityEngine.Random.state;var oldEvent=UnityEngine.EventSystems.EventSystem.current;
var texts=ProjectY.Data.LocalizationService.Shared;var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var sourceField=typeof(ProjectY.Data.LocalizationService).GetField("sources",flags);
var previousTexts=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>();
foreach(var pair in (System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>)sourceField.GetValue(texts))previousTexts.Add(pair.Key,new System.Collections.Generic.Dictionary<string,string>(pair.Value));
var root=new GameObject("EconomyValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var cameraObject=new GameObject("BankCaptureCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.025f,.035f,.03f);
camera.orthographic=true;camera.orthographicSize=360;camera.transform.position=new Vector3(0,0,-10);camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
var path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"ProjectY-Economy-"+System.Guid.NewGuid().ToString("N")+".json");
System.Action<RectTransform> capture=panel=>{
    foreach(var canvas in root.GetComponentsInChildren<Canvas>(true)){canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
    foreach(var transform in root.GetComponentsInChildren<Transform>(true))transform.gameObject.layer=31;
    foreach(var rect in root.GetComponentsInChildren<RectTransform>())UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(rect);
    Canvas.ForceUpdateCanvases();
    var chart=panel.GetComponentInChildren<ProjectY.UI.BankChartGraphic>();
    var pointer=new UnityEngine.EventSystems.PointerEventData(UnityEngine.EventSystems.EventSystem.current);
    pointer.position=RectTransformUtility.WorldToScreenPoint(camera,chart.rectTransform.TransformPoint(Vector3.zero));chart.OnPointerEnter(pointer);
    if(chart.HoverIndex<0)throw new System.Exception("Candle hover did not select a sample");chart.OnPointerExit(pointer);
    Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
    pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();System.IO.Directory.CreateDirectory("Art/Economy/Previews");
    System.IO.File.WriteAllBytes("Art/Economy/Previews/bank.png",pixels.EncodeToPNG());
};
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,path);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("BankFont",UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf"));lua.Global.Set("CaptureBank",capture);
        try{var result=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/economy_integration.lua"),"@Tools/Tests/economy_integration.lua")[0];System.IO.File.WriteAllText("Art/Economy/Previews/validation.txt",result.ToString());return result;}
        finally{using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))shutdown?.Call();lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("CaptureBank",null);services.Player.ClearListeners();}
    }
}
finally
{
    host.Shutdown();RenderTexture.active=oldTarget;camera.targetTexture=null;target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(pixels);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=oldTime;UnityEngine.Random.state=oldRandom;
    if(oldEvent!=null)UnityEngine.EventSystems.EventSystem.current=oldEvent;
    texts.Clear();foreach(var source in previousTexts)foreach(var item in source.Value)texts.SetText(source.Key,item.Key,item.Value);texts.NotifyChanged();
    Debug.Log("Economy validation temporary save: "+path);
}
