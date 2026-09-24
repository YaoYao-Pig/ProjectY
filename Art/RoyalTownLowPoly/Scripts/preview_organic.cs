// Unity MCP 的 Edit Mode 布局预览；只运行真实生成器与快照转换，不伪造远征或战斗状态。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.InvalidOperationException("Edit Mode required");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
ProjectY.Samples.MapAreaViewData layout;
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
 try{var result=lua.DoString(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/RoyalTownLowPoly/Scripts/preview_organic.lua")));using(var rows=(XLua.LuaTable)result[0])layout=ProjectY.Samples.MapAreaViewData.Read(rows);}
 finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.TownSurfaceRenderer surface=null;
try{
 var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
 var ground=new UnityEngine.GameObject("OrganicRoyalGround",typeof(UnityEngine.MeshFilter),typeof(UnityEngine.MeshRenderer));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(ground,preview);
 surface=new ProjectY.Samples.TownSurfaceRenderer(shader,layout);ground.GetComponent<UnityEngine.MeshFilter>().sharedMesh=surface.Mesh;ground.GetComponent<UnityEngine.MeshRenderer>().sharedMaterial=surface.Material;
 var checkedEdges=0;for(var current=0;current<layout.Cells.Length;current++){var cell=layout.Cells[current];if(cell.Blocked)continue;for(var d=0;d<6;d++){
  var index=cell.Neighbors[d];if((cell.WalkMask&(1<<d))==0 || index<0 || layout.Cells[index].Blocked)continue;
  for(var t=0;t<=4;t++)ProjectY.Samples.TownSurfaceRenderer.Ground(layout,current,index,UnityEngine.Vector3.Lerp(cell.Position,layout.Cells[index].Position,t/4f));checkedEdges++;
 }}
 var models=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();foreach(var asset in layout.PropAssets){var model=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path);if(model==null)throw new System.Exception("Missing royal model "+asset.Path);models.Add(asset.Id,model);}
 foreach(var prop in layout.Props){var obj=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(models[prop.AssetId],preview);obj.transform.position=prop.Position;obj.transform.rotation=UnityEngine.Quaternion.Euler(0,prop.Rotation,0);obj.transform.localScale=prop.Scale3;}
 var lamp=new UnityEngine.GameObject("TownSun",typeof(UnityEngine.Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lamp,preview);
 var light=lamp.GetComponent<UnityEngine.Light>();light.type=UnityEngine.LightType.Directional;light.intensity=1.1f;light.color=new UnityEngine.Color(1,.96f,.88f);light.shadows=UnityEngine.LightShadows.Soft;lamp.transform.rotation=UnityEngine.Quaternion.Euler(48,-35,0);
 var cameraObject=new UnityEngine.GameObject("TownCamera",typeof(UnityEngine.Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,preview);
 var camera=cameraObject.GetComponent<UnityEngine.Camera>();camera.scene=preview;camera.enabled=false;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.40f,.54f,.59f);camera.nearClipPlane=.08f;camera.farClipPlane=800;
 var outputs=new System.Collections.Generic.List<string>();
 System.Action<string> capture=name=>{
  var texture=new UnityEngine.RenderTexture(1600,1000,24,UnityEngine.RenderTextureFormat.ARGB32){antiAliasing=4};texture.Create();var previous=UnityEngine.RenderTexture.active;var image=new UnityEngine.Texture2D(1600,1000,UnityEngine.TextureFormat.RGB24,false);
  try{camera.targetTexture=texture;camera.Render();UnityEngine.RenderTexture.active=texture;image.ReadPixels(new UnityEngine.Rect(0,0,1600,1000),0,0);image.Apply();var path=System.IO.Path.Combine(root,"Art/RoyalTownLowPoly/Previews/"+name+".png");System.IO.File.WriteAllBytes(path,image.EncodeToPNG());outputs.Add(path);}
  finally{camera.targetTexture=null;UnityEngine.RenderTexture.active=previous;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(image);}
 };
 var palace=System.Array.Find(layout.Props,p=>p.AssetId==54);var gate=System.Array.Find(layout.Props,p=>p.AssetId==55);
 var center=UnityEngine.Vector3.Lerp(palace.Position,gate.Position,.45f)+UnityEngine.Vector3.up*9;var rotation=UnityEngine.Quaternion.Euler(43,palace.Rotation+150,0);
 camera.orthographic=true;camera.orthographicSize=108;camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*300,rotation);capture("royal-organic-overview");
 camera.orthographicSize=95;rotation=UnityEngine.Quaternion.Euler(90,palace.Rotation+180,0);camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*300,rotation);capture("royal-organic-plan");
 var market=System.Array.Find(layout.Props,p=>p.AssetId==57 && p.Position.y<palace.Position.y-1);center=market.Position+UnityEngine.Vector3.up*3;camera.orthographicSize=35;rotation=UnityEngine.Quaternion.Euler(35,palace.Rotation+155,0);camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*200,rotation);capture("royal-organic-market");
 var report=new{scope="layout-only",seed=2667826519L,facilities=layout.Facilities.Length,npcs=layout.Npcs.Length,props=layout.Props.Length,checkedEdges=checkedEdges,playing=false,images=outputs};
 System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/RoyalTownLowPoly/Integration/royal-organic-preview.json"),Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented));return report;
}finally{if(surface!=null)surface.Dispose();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);}
