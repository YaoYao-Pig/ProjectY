// 通过 Unity MCP 在独立预览场景中查看真实布局、模型和角色；不进入 Play、不保存临时对象。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
ProjectY.Samples.MapAreaViewData layout;ProjectY.Samples.AdventureViewData view;
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
 try{
  var result=lua.DoString(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/TownLowPoly/Scripts/preview_town.lua")));
  using(var rows=(XLua.LuaTable)result[0])layout=ProjectY.Samples.MapAreaViewData.Read(rows);
  using(var rows=(XLua.LuaTable)result[1])view=ProjectY.Samples.AdventureViewData.Read(rows);
 }finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
var state=view.Area;var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
var material=new UnityEngine.Material(shader){enableInstancing=true};
ProjectY.Samples.SquadPawnRenderer squad=null;ProjectY.Samples.TownNpcRenderer npcs=null;
try{
 var terrain=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(layout.AssetPath);var mesh=terrain.GetComponent<UnityEngine.MeshFilter>().sharedMesh;
 var block=new UnityEngine.MaterialPropertyBlock();
 foreach(var cell in layout.Cells){
  var obj=new UnityEngine.GameObject("TownGround",typeof(UnityEngine.MeshFilter),typeof(UnityEngine.MeshRenderer));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(obj,preview);
  obj.GetComponent<UnityEngine.MeshFilter>().sharedMesh=mesh;
  var renderer=obj.GetComponent<UnityEngine.MeshRenderer>();var slots=new UnityEngine.Material[mesh.subMeshCount];for(var i=0;i<slots.Length;i++)slots[i]=material;renderer.sharedMaterials=slots;
  var color=UnityEngine.QualitySettings.activeColorSpace==UnityEngine.ColorSpace.Linear?cell.Color.linear:cell.Color;block.SetVector("_Color",color);renderer.SetPropertyBlock(block);
  obj.transform.position=cell.Position;obj.transform.localScale=new UnityEngine.Vector3(layout.Radius,cell.Position.y+.4f,layout.Radius);
 }
 var models=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();foreach(var asset in layout.PropAssets)models.Add(asset.Id,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path));
 var obstacles=new System.Collections.Generic.List<UnityEngine.Bounds>();
 foreach(var prop in layout.Props){
  var obj=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(models[prop.AssetId],preview);
  obj.transform.position=prop.Position;obj.transform.rotation=UnityEngine.Quaternion.Euler(0,prop.Rotation,0);obj.transform.localScale=UnityEngine.Vector3.one*prop.Scale;
  var obstacle=obj.GetComponent<UnityEngine.MeshRenderer>().bounds;obstacle.Expand(.35f);obstacles.Add(obstacle);
 }
 ProjectY.Samples.AdventureRuntimeDemo demo=null;
 foreach(var r in UnityEngine.SceneManagement.SceneManager.GetActiveScene().GetRootGameObjects())foreach(var d in r.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))demo=d;
 if(demo==null)throw new System.Exception("Adventure demo missing");var fields=new UnityEditor.SerializedObject(demo);
 if(fields.FindProperty("assetBindings").arraySize!=49 || fields.FindProperty("pawnBindings").arraySize!=18)throw new System.Exception("Scene bindings not synchronized");
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
   var path=System.IO.Path.Combine(root,"Art/TownLowPoly/Previews/"+name+".png");System.IO.File.WriteAllBytes(path,image.EncodeToPNG());outputs.Add(path);
  }finally{camera.targetTexture=null;UnityEngine.RenderTexture.active=previous;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(image);}
 };
 var center=layout.Cells[state.GoalIndex].Position;
 camera.orthographic=true;camera.orthographicSize=57;var rotation=UnityEngine.Quaternion.Euler(53,155,0);camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*300,rotation);capture("town-overview-unity");
 var controller=new ProjectY.Samples.TownWalkCamera(layout,state,obstacles);controller.Apply(camera,squad.Position(state.Members[0].ActorId));capture("town-street-unity");
 var report=new{facilities=layout.Facilities.Length,npcs=layout.Npcs.Length,members=state.Members.Length,mapBindings=49,pawnBindings=18,playing=false,images=outputs};
 System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/TownLowPoly/Integration/town-preview.json"),Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented));
 return report;
}finally{if(npcs!=null)npcs.Dispose();if(squad!=null)squad.Dispose();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);UnityEngine.Object.DestroyImmediate(material);}
