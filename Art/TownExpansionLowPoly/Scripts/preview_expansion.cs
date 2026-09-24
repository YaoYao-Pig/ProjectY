// Unity MCP 的一次性 Edit Mode 预览；使用真实远征命令、绑定模型和运行时剖切判定。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
ProjectY.Samples.MapEnvironmentData lighting;ProjectY.Samples.MapAreaViewData layout;var views=new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData>();var names=new System.Collections.Generic.List<string>();
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
 try{
  var result=lua.DoString(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/TownExpansionLowPoly/Scripts/preview_expansion.lua")));
  using(var row=(XLua.LuaTable)result[2])lighting=ProjectY.Samples.MapEnvironmentData.Read(row);
  using(var rows=(XLua.LuaTable)result[0])layout=ProjectY.Samples.MapAreaViewData.Read(rows);
  using(var rows=(XLua.LuaTable)result[1])for(var i=1;i<=rows.Length;i++)using(var row=rows.Get<int,XLua.LuaTable>(i))using(var value=row.Get<XLua.LuaTable>("view")){
   names.Add(row.Get<string>("name"));views.Add(ProjectY.Samples.AdventureViewData.Read(value));
  }
 }finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
ProjectY.Samples.AdventureRuntimeDemo demo=null;
foreach(var r in UnityEngine.SceneManagement.SceneManager.GetActiveScene().GetRootGameObjects())foreach(var value in r.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))demo=value;
if(demo==null)throw new System.Exception("Adventure demo missing");var fields=new UnityEditor.SerializedObject(demo);
var bindings=fields.FindProperty("assetBindings");var bound=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();
for(var i=0;i<bindings.arraySize;i++){
 var item=bindings.GetArrayElementAtIndex(i);var prefab=item.FindPropertyRelative("prefab").objectReferenceValue as UnityEngine.GameObject;
 if(prefab==null)throw new System.Exception("Missing serialized model binding");bound.Add(item.FindPropertyRelative("id").intValue,prefab);
}
foreach(var asset in layout.PropAssets)if(UnityEditor.AssetDatabase.GetAssetPath(bound[asset.Id])!=asset.Path)throw new System.Exception("Config / scene binding differs: "+asset.Id);
var rig=(ProjectY.Samples.PawnView)fields.FindProperty("pawnPrefab").objectReferenceValue;
var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
ProjectY.Samples.SquadPawnRenderer squad=null;ProjectY.Samples.TownNpcRenderer npcs=null;ProjectY.Samples.TownSurfaceRenderer surface=null;ProjectY.Samples.MapAreaRenderer renderer=null;
ProjectY.Samples.MapEnvironmentController environment=null;
try{
 var terrain=new UnityEngine.GameObject("TownSurfaces",typeof(UnityEngine.MeshFilter),typeof(UnityEngine.MeshRenderer));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(terrain,preview);
 surface=new ProjectY.Samples.TownSurfaceRenderer(shader,layout);terrain.GetComponent<UnityEngine.MeshFilter>().sharedMesh=surface.Mesh;terrain.GetComponent<UnityEngine.MeshRenderer>().sharedMaterial=surface.Material;
 renderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(layout.AssetPath),layout,asset=>bound[asset.Id]);
 var models=new System.Collections.Generic.List<UnityEngine.GameObject>();
 foreach(var prop in layout.Props){
  var obj=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(bound[prop.AssetId],preview);obj.transform.position=prop.Position;obj.transform.rotation=UnityEngine.Quaternion.Euler(0,prop.Rotation,0);obj.transform.localScale=prop.Scale3;models.Add(obj);
 }
 var host=new UnityEngine.GameObject("PreviewSquad");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,preview);
 System.Func<ProjectY.Samples.PawnAppearanceData.Part,UnityEngine.GameObject> resolve=part=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(part.Path);
 var sun=new UnityEngine.GameObject("Sun",typeof(UnityEngine.Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(sun,preview);
 var light=sun.GetComponent<UnityEngine.Light>();light.type=UnityEngine.LightType.Directional;light.intensity=1.15f;light.color=new UnityEngine.Color(1,.96f,.87f);light.shadows=UnityEngine.LightShadows.Soft;sun.transform.rotation=UnityEngine.Quaternion.Euler(48,-35,0);
 var cameraObject=new UnityEngine.GameObject("Camera",typeof(UnityEngine.Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,preview);
 var camera=cameraObject.GetComponent<UnityEngine.Camera>();camera.scene=preview;camera.enabled=false;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.36f,.47f,.50f);camera.nearClipPlane=.08f;camera.farClipPlane=700;
 environment=new ProjectY.Samples.MapEnvironmentController(lighting,light,camera,host.transform);environment.SetArea(layout);
 environment.Hour=23.5f;environment.Running=true;environment.Tick(lighting.CycleSeconds/12,views[0].Area);
 if(UnityEngine.Mathf.Abs(environment.Hour-1.5f)>.001f)throw new System.Exception("Visual clock wrap failed");
 environment.Running=false;environment.Hour=12;environment.Tick(3,views[0].Area);var clearIntensity=light.intensity;
 environment.SelectWeather(1);environment.Tick(3,views[0].Area);if(light.intensity>=clearIntensity*.8f)throw new System.Exception("Weather did not affect light");
 environment.SelectWeather(0);environment.Hour=10;environment.Tick(3,views[0].Area);
 var captureFocus=UnityEngine.Vector3.zero;
 var outputs=new System.Collections.Generic.List<string>();var checks=new System.Collections.Generic.List<object>();var fullObstacleCount=renderer.CameraObstacles.Count;
 System.Action<string> capture=name=>{
  environment.ApplyCameraFocus(captureFocus);
  var texture=new UnityEngine.RenderTexture(1600,1000,24,UnityEngine.RenderTextureFormat.ARGB32){antiAliasing=4};texture.Create();var previous=UnityEngine.RenderTexture.active;var image=new UnityEngine.Texture2D(1600,1000,UnityEngine.TextureFormat.RGB24,false);
  try{camera.targetTexture=texture;camera.Render();UnityEngine.RenderTexture.active=texture;image.ReadPixels(new UnityEngine.Rect(0,0,1600,1000),0,0);image.Apply();var path=System.IO.Path.Combine(root,"Art/TownExpansionLowPoly/Previews/"+name+".png");System.IO.File.WriteAllBytes(path,image.EncodeToPNG());outputs.Add(path);}
  finally{camera.targetTexture=null;UnityEngine.RenderTexture.active=previous;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(image);}
 };
 var palace=System.Array.Find(layout.Props,p=>p.AssetId==72);var gate=System.Array.Find(layout.Props,p=>p.AssetId==55);
 for(var n=0;n<views.Count;n++){
  var view=views[n];var state=view.Area;environment.Tick(2,state);var name=names[n];renderer.UpdateVisibility(state,false);
  var expected=new System.Collections.Generic.HashSet<int>();foreach(var member in state.Members){var id=layout.Cells[member.CellIndex].InteriorId;if(id>0)expected.Add(id);}
  var hidden=0;
  for(var i=0;i<layout.Props.Length;i++){
   var prop=layout.Props[i];if(renderer.IsInteriorOpen(prop.InteriorId)!=expected.Contains(prop.InteriorId))throw new System.Exception("Cutaway differs from party cells");
   var active=!prop.Cutaway || !renderer.IsInteriorOpen(prop.InteriorId);models[i].SetActive(active);if(!active)hidden++;
  }
  if(hidden!=expected.Count)throw new System.Exception("Interior cover count differs");
  if(hidden>0 && renderer.CameraObstacles.Count>=fullObstacleCount)throw new System.Exception("Hidden cover still blocks camera");
  if(name.EndsWith("returned") && renderer.CameraObstacles.Count!=fullObstacleCount)throw new System.Exception("Exterior cover did not restore");
  checks.Add(new{name=name,members=state.Members.Length,openInteriors=expected.Count,hiddenCovers=hidden,cameraObstacles=renderer.CameraObstacles.Count});
  if(name.EndsWith("returned"))continue;
  if(n>0 && !(name.StartsWith("bakery")||name.StartsWith("herbalist")||name.StartsWith("chapel")||name.StartsWith("warehouse")||name.StartsWith("stable")||name.StartsWith("watchtower")))continue;
  if(squad!=null)squad.Dispose();if(npcs!=null)npcs.Dispose();squad=new ProjectY.Samples.SquadPawnRenderer(host.transform,rig,resolve);squad.SetState(state,view.Party,layout);squad.Tick(1);
  npcs=new ProjectY.Samples.TownNpcRenderer(host.transform,rig,layout,resolve);npcs.SetState(state,layout);npcs.Tick(1);
  if(n==0){
   var center=UnityEngine.Vector3.Lerp(palace.Position,gate.Position,.50f)+UnityEngine.Vector3.up*8;var rotation=UnityEngine.Quaternion.Euler(48,palace.Rotation+154,0);
   captureFocus=center;camera.orthographic=true;camera.orthographicSize=84;camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*250,rotation);
   foreach(var hour in new[]{12,19,23}){environment.Hour=hour;environment.Tick(2,state);capture("city-"+hour);}
   environment.Hour=12;environment.SelectWeather(1);environment.Tick(3,state);capture("city-overcast");environment.SelectWeather(0);environment.Hour=10;environment.Tick(3,state);
  }else{
   var walk=new ProjectY.Samples.TownWalkCamera(layout,state,renderer.CameraObstacles,(ray,limit)=>{int hit;return surface.Raycast(ray,limit,out hit);});captureFocus=squad.Position(state.Members[0].ActorId);walk.Apply(camera,captureFocus);capture(name+"-walk");
   var interior=layout.Cells[state.CellIndex].InteriorId;
   if(interior>0 && name.EndsWith("interior")){
    var prop=System.Array.Find(layout.Props,p=>p.InteriorId==interior && !p.Cutaway);
    camera.orthographic=true;camera.orthographicSize=prop.AssetId==72?18:8.5f;var center=prop.Position+UnityEngine.Vector3.up*.5f;
    if(prop.AssetId==72)center+=UnityEngine.Quaternion.Euler(0,prop.Rotation,0)*new UnityEngine.Vector3(0,0,-5);
    captureFocus=center;var rotation=UnityEngine.Quaternion.Euler(58,prop.Rotation+170,0);camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*80,rotation);capture(name+"-plan");
    if(name.StartsWith("bakery")){environment.Hour=23;environment.Tick(2,state);capture("bakery-night-plan");environment.Hour=10;environment.Tick(2,state);}
   }
  }
 }
 var report=new{facilities=layout.Facilities.Length,npcs=layout.Npcs.Length,models=layout.Props.Length,mapBindings=bindings.arraySize,pawnBindings=fields.FindProperty("pawnBindings").arraySize,checks=checks,images=outputs,playing=false};
 System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/TownExpansionLowPoly/Integration/preview.json"),Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented));return report;
}finally{if(environment!=null)environment.Dispose();if(renderer!=null)renderer.Dispose();if(surface!=null)surface.Dispose();if(npcs!=null)npcs.Dispose();if(squad!=null)squad.Dispose();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);}
