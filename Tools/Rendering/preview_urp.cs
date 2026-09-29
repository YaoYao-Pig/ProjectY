// Execute with Unity MCP in Edit Mode. Uses a temporary preview scene; does not save the open scene.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
ProjectY.Samples.MapAreaViewData layout;ProjectY.Samples.AdventureViewData view;ProjectY.Samples.MapEnvironmentData lighting;
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
 try{var result=lua.DoString(System.IO.File.ReadAllText("Tools/Rendering/preview_urp.lua"));
  using(var row=(XLua.LuaTable)result[0])layout=ProjectY.Samples.MapAreaViewData.Read(row);
  using(var row=(XLua.LuaTable)result[1])view=ProjectY.Samples.AdventureViewData.Read(row);
  using(var row=(XLua.LuaTable)result[2])lighting=ProjectY.Samples.MapEnvironmentData.Read(row);
 }finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var originalDirty=originalScene.isDirty;
var originalPipeline=UnityEngine.QualitySettings.renderPipeline;
var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
ProjectY.Samples.TownSurfaceRenderer surface=null;ProjectY.Samples.MapEnvironmentController environment=null;
UnityEngine.RenderTexture target=null;UnityEngine.Texture2D image=null;var previous=UnityEngine.RenderTexture.active;
var outputs=new System.Collections.Generic.List<object>();
try{
 var host=new UnityEngine.GameObject("URP Smoke Preview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,preview);
 var terrain=new UnityEngine.GameObject("Town Surface",typeof(UnityEngine.MeshFilter),typeof(UnityEngine.MeshRenderer));terrain.transform.SetParent(host.transform,false);
 surface=new ProjectY.Samples.TownSurfaceRenderer(shader,layout);terrain.GetComponent<UnityEngine.MeshFilter>().sharedMesh=surface.Mesh;terrain.GetComponent<UnityEngine.MeshRenderer>().sharedMaterial=surface.Material;
 foreach(var prop in layout.Props){
  var asset=System.Array.Find(layout.PropAssets,a=>a.Id==prop.AssetId);var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path);
  if(prefab==null)throw new System.Exception("Missing model: "+asset.Path);
  var obj=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(prefab,preview);obj.transform.SetParent(host.transform,false);
  obj.transform.position=prop.Position;obj.transform.rotation=UnityEngine.Quaternion.Euler(0,prop.Rotation,0);obj.transform.localScale=prop.Scale3;
 }
 var light=new UnityEngine.GameObject("Sun").AddComponent<UnityEngine.Light>();light.transform.SetParent(host.transform,false);light.type=UnityEngine.LightType.Directional;
 var camera=new UnityEngine.GameObject("Camera").AddComponent<UnityEngine.Camera>();camera.transform.SetParent(host.transform,false);camera.enabled=false;camera.scene=preview;
 camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(preview);
 camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.nearClipPlane=.1f;camera.farClipPlane=700;camera.aspect=1.6f;
 environment=new ProjectY.Samples.MapEnvironmentController(lighting,light,camera,host.transform);environment.SetArea(layout);environment.Running=false;
 var palace=System.Array.Find(layout.Props,p=>p.AssetId==72);var gate=System.Array.Find(layout.Props,p=>p.AssetId==55);
 var focus=UnityEngine.Vector3.Lerp(palace.Position,gate.Position,.50f)+UnityEngine.Vector3.up*8;
 var rotation=UnityEngine.Quaternion.Euler(48,palace.Rotation+154,0);camera.orthographic=true;camera.orthographicSize=80;
 camera.transform.SetPositionAndRotation(focus-rotation*UnityEngine.Vector3.forward*250,rotation);
 target=new UnityEngine.RenderTexture(1280,800,24,UnityEngine.RenderTextureFormat.ARGBHalf);target.Create();camera.targetTexture=target;
 image=new UnityEngine.Texture2D(1280,800,UnityEngine.TextureFormat.RGB24,false);
 System.IO.Directory.CreateDirectory("Docs/Previews/Rendering");
 foreach(var hour in new[]{12,19}){
  environment.Hour=hour;environment.Tick(3,view.Area);environment.ApplyCameraFocus(focus);
  ProjectY.Rendering.UrpCameraRendering.Render(camera);
  UnityEngine.RenderTexture.active=target;image.ReadPixels(new UnityEngine.Rect(0,0,1280,800),0,0);image.Apply();
  var pixels=image.GetPixels32();int magenta=0;double sum=0;
  foreach(var p in pixels){if(p.r>220&&p.g<35&&p.b>220)magenta++;sum+=p.r+p.g+p.b;}
  if(magenta>100||sum/pixels.Length<15)throw new System.Exception("Invalid URP render: pink/black image");
  string path="Docs/Previews/Rendering/urp-town-"+hour+".png";System.IO.File.WriteAllBytes(path,image.EncodeToPNG());
  outputs.Add(new{path=path,magentaPixels=magenta,meanBrightness=sum/pixels.Length/3});
 }
 // The portrait renderer must accept an explicit single-camera request without world post-processing.
 ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);ProjectY.Rendering.UrpCameraRendering.Render(camera);
 if(UnityEditor.ShaderUtil.ShaderHasError(shader))throw new System.Exception("Map shader compile failed");
 camera.targetTexture=null;
}finally{
 if(environment!=null)environment.Dispose();if(surface!=null)surface.Dispose();UnityEngine.RenderTexture.active=previous;
 if(image!=null)UnityEngine.Object.DestroyImmediate(image);if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
 UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);
}
if(UnityEngine.QualitySettings.renderPipeline!=originalPipeline || originalScene.isDirty!=originalDirty)throw new System.Exception("Preview leaked rendering/scene state");
var report=new{pipeline=UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline.name,models=layout.Props.Length,outputs=outputs,restored=true,playMode=false};
System.IO.File.WriteAllText("Docs/Previews/Rendering/validation.json",Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented));
return report;
