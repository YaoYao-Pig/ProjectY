// Edit Mode only: independent GM system state, real panel buttons, and a panel capture.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new UnityEngine.GameObject("GMValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var font=UnityEngine.Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","Noto Sans CJK SC","Arial"},16);
string result;
try{
 using(var lua=new XLua.LuaEnv()){
  var services=new ProjectY.FrameworkServices(host);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);lua.Global.Set("GMFont",font);
  try{
   result=(string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/gm_integration.lua"),"@Tools/Tests/gm_integration.lua")[0];
   var cameraObject=new UnityEngine.GameObject("GMCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);var camera=cameraObject.AddComponent<UnityEngine.Camera>();
   camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);camera.enabled=false;camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=10;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.16f,.20f,.18f);
   var rt=new UnityEngine.RenderTexture(1280,720,24);var previous=UnityEngine.RenderTexture.active;var image=new UnityEngine.Texture2D(1280,720,UnityEngine.TextureFormat.RGB24,false);
   try{
    camera.targetTexture=rt;foreach(var canvas in root.GetComponentsInChildren<UnityEngine.Canvas>(true))if(canvas.transform.parent==root.transform){canvas.renderMode=UnityEngine.RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
    UnityEngine.Canvas.ForceUpdateCanvases();camera.Render();UnityEngine.RenderTexture.active=rt;image.ReadPixels(new UnityEngine.Rect(0,0,1280,720),0,0);image.Apply();
    System.IO.Directory.CreateDirectory("Docs/Previews");System.IO.File.WriteAllBytes("Docs/Previews/GM.png",image.EncodeToPNG());
   }finally{UnityEngine.RenderTexture.active=previous;camera.targetTexture=null;UnityEngine.Object.DestroyImmediate(image);UnityEngine.Object.DestroyImmediate(rt);}
  }finally{lua.DoString("if CloseGMPreview then CloseGMPreview() end");lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("GMFont",null);services.Player.ClearListeners();}
 }
 if(host.IsWorldPaused)throw new System.Exception("GM pause was not released");
}finally{host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);UnityEngine.Object.DestroyImmediate(font);}
return result;
