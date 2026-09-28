// 编辑态实际运行显示器，读取真实生成算法与 Demo 绑定；预览结束释放相机、材质和预览场景。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
var request=Newtonsoft.Json.Linq.JObject.Parse("{\"area\":20,\"region\":5}");
ProjectY.Samples.MapAreaViewData layout;
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
 lua.Global.Set("Services",services);lua.Global.Set("PreviewArea",(int)request["area"]);lua.Global.Set("PreviewRegion",(int)request["region"]);
 try{var result=lua.DoString(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/ForestAnimals/Scripts/preview_forest.lua")));using(var table=(XLua.LuaTable)result[0])layout=ProjectY.Samples.MapAreaViewData.Read(table);}
 finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
var models=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();
models.Add(layout.AssetId,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(layout.AssetPath));
foreach(var asset in layout.PropAssets)models.Add(asset.Id,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path));
var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
if(UnityEditor.ShaderUtil.ShaderHasError(shader))throw new System.Exception("Map shader error");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();ProjectY.Samples.MapAreaRenderer renderer=null;
var ambient=UnityEngine.RenderSettings.ambientLight;var mode=UnityEngine.RenderSettings.ambientMode;var fog=UnityEngine.RenderSettings.fog;
var outputs=new System.Collections.Generic.List<string>();
try{
 UnityEngine.RenderSettings.ambientMode=UnityEngine.Rendering.AmbientMode.Flat;UnityEngine.RenderSettings.ambientLight=new UnityEngine.Color(.6f,.64f,.67f);UnityEngine.RenderSettings.fog=false;
 var sunObj=new UnityEngine.GameObject("DressingPreviewSun",typeof(UnityEngine.Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(sunObj,scene);
 var sun=sunObj.GetComponent<UnityEngine.Light>();sun.type=UnityEngine.LightType.Directional;sun.intensity=1.1f;sun.color=new UnityEngine.Color(1,.94f,.82f);sun.shadows=UnityEngine.LightShadows.Soft;sun.transform.rotation=UnityEngine.Quaternion.Euler(48,-35,0);
 var camObj=new UnityEngine.GameObject("DressingPreviewCamera",typeof(UnityEngine.Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camObj,scene);
 var camera=camObj.GetComponent<UnityEngine.Camera>();camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.nearClipPlane=.1f;camera.farClipPlane=800;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.16f,.19f,.21f);
 renderer=new ProjectY.Samples.MapAreaRenderer(shader,models[layout.AssetId],layout,asset=>models[asset.Id]);
 var state=new ProjectY.Samples.MapAreaViewData.State{Revision=1,Known=new int[0],Visible=new int[0],Members=new ProjectY.Samples.MapAreaViewData.Member[0]};
 renderer.UpdateVisibility(state,true);
 System.Action<string,UnityEngine.Vector3,float> capture=(name,center,size)=>{
  camera.orthographicSize=size;var rotation=UnityEngine.Quaternion.Euler(58,155,0);camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*240,rotation);
  var texture=new UnityEngine.RenderTexture(1600,1000,24,UnityEngine.RenderTextureFormat.ARGB32){antiAliasing=4};texture.Create();var previous=UnityEngine.RenderTexture.active;var image=new UnityEngine.Texture2D(1600,1000,UnityEngine.TextureFormat.RGB24,false);
  try{camera.targetTexture=texture;renderer.Draw(camera);camera.Render();UnityEngine.RenderTexture.active=texture;image.ReadPixels(new UnityEngine.Rect(0,0,1600,1000),0,0);image.Apply();var path=System.IO.Path.Combine(root,"Art/ForestAnimals/Previews/"+name+".png");System.IO.File.WriteAllBytes(path,image.EncodeToPNG());outputs.Add(path);}
  finally{camera.targetTexture=null;UnityEngine.RenderTexture.active=previous;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(image);}
 };
 var glade=layout.Cells[layout.Rooms[0].CenterIndex].Position;
 var animalNames=new[]{"Horse","Chicken","Rabbit"};
 for(int i=0;i<3;i++){
  var asset=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/ForestAnimals/Models/"+animalNames[i]+".fbx");
  var obj=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(asset,scene);
  obj.transform.position=glade+new UnityEngine.Vector3((i-1)*3.1f,.015f,0);
 }
 capture("Forest-Unity-Overview",renderer.Bounds.center,82);
 capture("Forest-Unity-Animals",glade+UnityEngine.Vector3.up*.8f,11);
 var result=new{area=(int)request["area"],region=(int)request["region"],cells=layout.Cells.Length,props=layout.Props.Length,surfaces=layout.Surfaces.Count,images=outputs};
 System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/ForestAnimals/Integration/preview-"+(int)request["area"]+"-"+(int)request["region"]+".json"),Newtonsoft.Json.JsonConvert.SerializeObject(result,Newtonsoft.Json.Formatting.Indented));return result;
}finally{if(renderer!=null)renderer.Dispose();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);UnityEngine.RenderSettings.ambientLight=ambient;UnityEngine.RenderSettings.ambientMode=mode;UnityEngine.RenderSettings.fog=fog;}
