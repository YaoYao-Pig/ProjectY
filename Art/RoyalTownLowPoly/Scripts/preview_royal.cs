// 通过 Unity MCP 在独立预览场景中查看真实布局、模型和角色；不进入 Play、不保存临时对象。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
ProjectY.Samples.MapAreaViewData layout;ProjectY.Samples.AdventureViewData view,bridgeView,underView;
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
 try{
  var result=lua.DoString(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/RoyalTownLowPoly/Scripts/preview_royal.lua")));
  using(var rows=(XLua.LuaTable)result[0])layout=ProjectY.Samples.MapAreaViewData.Read(rows);
  using(var rows=(XLua.LuaTable)result[1])view=ProjectY.Samples.AdventureViewData.Read(rows);
  using(var rows=(XLua.LuaTable)result[2])bridgeView=ProjectY.Samples.AdventureViewData.Read(rows);
  using(var rows=(XLua.LuaTable)result[3])underView=ProjectY.Samples.AdventureViewData.Read(rows);
 }finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
var state=view.Area;var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
ProjectY.Samples.SquadPawnRenderer squad=null;ProjectY.Samples.TownNpcRenderer npcs=null;ProjectY.Samples.TownSurfaceRenderer surface=null;ProjectY.Samples.MapAreaRenderer runtimeRenderer=null;
try{
 var terrainObject=new UnityEngine.GameObject("TownSurfaces",typeof(UnityEngine.MeshFilter),typeof(UnityEngine.MeshRenderer));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(terrainObject,preview);
 surface=new ProjectY.Samples.TownSurfaceRenderer(shader,layout);
 terrainObject.GetComponent<UnityEngine.MeshFilter>().sharedMesh=surface.Mesh;terrainObject.GetComponent<UnityEngine.MeshRenderer>().sharedMaterial=surface.Material;
 // 每条通行边取中间位置，核对台阶采样与层身份；几何顶面拾取分别检查桥上和桥下。
 var checkedEdges=0;
 for(var i=0;i<layout.Cells.Length;i++){
  var cell=layout.Cells[i];if(cell.Blocked)continue;
  for(var d=0;d<6;d++){
   var next=cell.Neighbors[d];if((cell.WalkMask&(1<<d))==0 || next<0 || layout.Cells[next].Blocked)continue;
   for(var t=0;t<=10;t++)ProjectY.Samples.TownSurfaceRenderer.Ground(layout,i,next,UnityEngine.Vector3.Lerp(cell.Position,layout.Cells[next].Position,t/10f));
   checkedEdges++;
  }
 }
 foreach(var current in new[]{bridgeView,underView}){
  var index=current.Area.CellIndex;var position=layout.Cells[index].Position;int hit;
  surface.Raycast(new UnityEngine.Ray(position+UnityEngine.Vector3.up,UnityEngine.Vector3.down),2,out hit);
  if(hit!=index)throw new System.Exception("Town upper/lower picking crossed layers");
 }
 var models=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();foreach(var asset in layout.PropAssets)models.Add(asset.Id,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path));
 runtimeRenderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(layout.AssetPath),layout,asset=>models[asset.Id]);
 var obstacles=runtimeRenderer.CameraObstacles;
 foreach(var prop in layout.Props){
  var obj=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(models[prop.AssetId],preview);
  obj.transform.position=prop.Position;obj.transform.rotation=UnityEngine.Quaternion.Euler(0,prop.Rotation,0);obj.transform.localScale=prop.Scale3;
  
 }
 ProjectY.Samples.AdventureRuntimeDemo demo=null;
 foreach(var r in UnityEngine.SceneManagement.SceneManager.GetActiveScene().GetRootGameObjects())foreach(var d in r.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))demo=d;
 if(demo==null)throw new System.Exception("Adventure demo missing");var fields=new UnityEditor.SerializedObject(demo);
 if(fields.FindProperty("assetBindings").arraySize!=63 || fields.FindProperty("pawnBindings").arraySize!=18)throw new System.Exception("Scene bindings not synchronized");
 var rig=(ProjectY.Samples.PawnView)fields.FindProperty("pawnPrefab").objectReferenceValue;
 var host=new UnityEngine.GameObject("TownPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,preview);
 System.Func<ProjectY.Samples.PawnAppearanceData.Part,UnityEngine.GameObject> resolve=part=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(part.Path);
 squad=new ProjectY.Samples.SquadPawnRenderer(host.transform,rig,resolve);squad.SetState(state,view.Party,layout);squad.Tick(1);
 npcs=new ProjectY.Samples.TownNpcRenderer(host.transform,rig,layout,resolve);npcs.SetState(state,layout);npcs.Tick(1);
 var lamp=new UnityEngine.GameObject("TownSun",typeof(UnityEngine.Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lamp,preview);
 var light=lamp.GetComponent<UnityEngine.Light>();light.type=UnityEngine.LightType.Directional;light.intensity=1.1f;light.color=new UnityEngine.Color(1,.96f,.88f);light.shadows=UnityEngine.LightShadows.Soft;lamp.transform.rotation=UnityEngine.Quaternion.Euler(48,-35,0);
 var camobj=new UnityEngine.GameObject("TownCamera",typeof(UnityEngine.Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camobj,preview);
 var camera=camobj.GetComponent<UnityEngine.Camera>();camera.scene=preview;camera.enabled=false;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.40f,.54f,.59f);camera.nearClipPlane=.08f;camera.farClipPlane=800;
 var outputs=new System.Collections.Generic.List<string>();
 System.Action<string> capture=name=>{
  var texture=new UnityEngine.RenderTexture(1600,1000,24,UnityEngine.RenderTextureFormat.ARGB32){antiAliasing=4};texture.Create();
  var previous=UnityEngine.RenderTexture.active;var image=new UnityEngine.Texture2D(1600,1000,UnityEngine.TextureFormat.RGB24,false);
  try{camera.targetTexture=texture;camera.Render();UnityEngine.RenderTexture.active=texture;image.ReadPixels(new UnityEngine.Rect(0,0,1600,1000),0,0);image.Apply();
   var path=System.IO.Path.Combine(root,"Art/RoyalTownLowPoly/Previews/"+name+".png");System.IO.File.WriteAllBytes(path,image.EncodeToPNG());outputs.Add(path);
  }finally{camera.targetTexture=null;UnityEngine.RenderTexture.active=previous;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(image);}
 };
 var palace=System.Array.Find(layout.Props,p=>p.AssetId==54);var gate=System.Array.Find(layout.Props,p=>p.AssetId==55);
 var center=UnityEngine.Vector3.Lerp(palace.Position,gate.Position,.45f)+UnityEngine.Vector3.up*9;
 camera.orthographic=true;camera.orthographicSize=108;var rotation=UnityEngine.Quaternion.Euler(43,palace.Rotation+150,0);camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*300,rotation);capture("royal-overview");
 camera.orthographicSize=48;rotation=UnityEngine.Quaternion.Euler(28,palace.Rotation+165,0);center=palace.Position+UnityEngine.Vector3.up*22;camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*220,rotation);capture("royal-palace");
 var controller=new ProjectY.Samples.TownWalkCamera(layout,state,obstacles,(ray,limit)=>{int hit;return surface.Raycast(ray,limit,out hit);});controller.Apply(camera,squad.Position(state.Members[0].ActorId));capture("royal-street");
 foreach(var current in new[]{bridgeView,underView}){
  // 每张预览独立创建显示对象，位置来自前面真正走完路线后的快照。
  squad.Dispose();npcs.Dispose();squad=new ProjectY.Samples.SquadPawnRenderer(host.transform,rig,resolve);squad.SetState(current.Area,current.Party,layout);squad.Tick(1);
  npcs=new ProjectY.Samples.TownNpcRenderer(host.transform,rig,layout,resolve);npcs.SetState(current.Area,layout);npcs.Tick(1);
  var walk=new ProjectY.Samples.TownWalkCamera(layout,current.Area,obstacles,(ray,limit)=>{int hit;return surface.Raycast(ray,limit,out hit);});walk.Apply(camera,squad.Position(current.Area.Members[0].ActorId));
  capture(current==bridgeView?"royal-bridge":"royal-underpass");
 }
 var report=new{facilities=layout.Facilities.Length,npcs=layout.Npcs.Length,members=state.Members.Length,mapBindings=63,pawnBindings=18,checkedEdges=checkedEdges,palaceInteraction=true,leaveAndReenter=true,playing=false,images=outputs};
 System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/RoyalTownLowPoly/Integration/royal-preview.json"),Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented));
 return report;
}finally{if(runtimeRenderer!=null)runtimeRenderer.Dispose();if(surface!=null)surface.Dispose();if(npcs!=null)npcs.Dispose();if(squad!=null)squad.Dispose();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);}
