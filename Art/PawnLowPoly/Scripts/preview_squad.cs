if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var root = System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
ProjectY.Samples.MapAreaViewData layout;
ProjectY.Samples.MapAreaViewData.State state;
ProjectY.Samples.AdventureViewData view;
using (var lua = new XLua.LuaEnv()) {
 var services = new ProjectY.FrameworkServices(null);
 var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
 lua.Global.Set("Services", services);
 var result = lua.DoString(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/PawnLowPoly/Scripts/preview_squad.lua")));
 using (var terrain = (XLua.LuaTable)result[0]) layout = ProjectY.Samples.MapAreaViewData.Read(terrain);
 using (var snapshot = (XLua.LuaTable)result[1]) view = ProjectY.Samples.AdventureViewData.Read(snapshot);
 state=view.Area;
 lua.Global.Set<string,object>("Services",null); services.Player.ClearListeners();
}
// 临时预览场景只承载生产快照的静态网格，关闭时完整释放，不改当前编辑场景。
var preview = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
var material = new UnityEngine.Material(shader) { enableInstancing = true };
var outputs = new System.Collections.Generic.List<string>();
ProjectY.Samples.SquadPawnRenderer squad=null;
try {
 var terrainPrefab = UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(layout.AssetPath);
 var mesh = terrainPrefab.GetComponent<UnityEngine.MeshFilter>().sharedMesh;
 var bounds = new UnityEngine.Bounds(layout.Cells[0].Position,UnityEngine.Vector3.zero);
 var block = new UnityEngine.MaterialPropertyBlock();
 for (var i=0;i<layout.Cells.Length;i++) {
  var cell=layout.Cells[i]; var top=cell.Position.y+(cell.Kind=="wall"?cell.WallHeight:0);
  var obj=new UnityEngine.GameObject("Terrain_"+i,typeof(UnityEngine.MeshFilter),typeof(UnityEngine.MeshRenderer));
  UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(obj,preview);
  obj.GetComponent<UnityEngine.MeshFilter>().sharedMesh=mesh;
  var mr=obj.GetComponent<UnityEngine.MeshRenderer>(); var materials=new UnityEngine.Material[mesh.subMeshCount];
  for(var m=0;m<materials.Length;m++) materials[m]=material; mr.sharedMaterials=materials;
  var color=cell.Color; if(cell.Kind=="entry")color=new UnityEngine.Color(.30f,.69f,.61f); if(cell.Kind=="landmark")color=new UnityEngine.Color(.78f,.56f,.25f);
  block.SetVector("_Color",UnityEngine.QualitySettings.activeColorSpace==UnityEngine.ColorSpace.Linear?color.linear:color);mr.SetPropertyBlock(block);
  obj.transform.position=new UnityEngine.Vector3(cell.Position.x,top,cell.Position.z);
  obj.transform.localScale=new UnityEngine.Vector3(layout.Radius,top+.4f,layout.Radius);
  bounds.Encapsulate(obj.transform.position);
 }
 var models=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();
 foreach(var asset in layout.PropAssets) models.Add(asset.Id,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path));
 foreach(var prop in layout.Props) {
  var obj=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(models[prop.AssetId],preview);
  obj.transform.position=prop.Position;obj.transform.rotation=UnityEngine.Quaternion.Euler(0,prop.Rotation,0);obj.transform.localScale=UnityEngine.Vector3.one*prop.Scale;
 }
 var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
 ProjectY.Samples.AdventureRuntimeDemo demo=null;
 foreach(var r in scene.GetRootGameObjects())foreach(var d in r.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))demo=d;
 if(demo==null)throw new System.InvalidOperationException("Missing demo");
 var fields=new UnityEditor.SerializedObject(demo);
 var rig=(ProjectY.Samples.PawnView)fields.FindProperty("pawnPrefab").objectReferenceValue;
 var bindings=fields.FindProperty("pawnBindings");
 var assets=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();
 var paths=new System.Collections.Generic.Dictionary<int,string>();
 for(int i=0;i<bindings.arraySize;i++){
  var b=bindings.GetArrayElementAtIndex(i);int id=b.FindPropertyRelative("id").intValue;
  assets.Add(id,(UnityEngine.GameObject)b.FindPropertyRelative("prefab").objectReferenceValue);
  paths.Add(id,b.FindPropertyRelative("path").stringValue);
 }
 var host=new UnityEngine.GameObject("PreviewSquad");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,preview);
 squad=new ProjectY.Samples.SquadPawnRenderer(host.transform,rig,part=>{
  if(paths[part.Id]!=part.Path)throw new System.InvalidOperationException("Part path differs");return assets[part.Id];
 });
 squad.SetState(state,view.Party,layout);squad.Tick(1);
 var pawnViews=host.GetComponentsInChildren<ProjectY.Samples.PawnView>();
 if(pawnViews.Length!=4 || bindings.arraySize!=16)throw new System.InvalidOperationException("Squad bindings differ");
 // 在真实组件上替换装备，再恢复；确认不会把旧部件留在挂点上重复显示。
 var guard=pawnViews[0];var appearance=view.Party[0].Appearance;
 var originalCount=guard.GetComponentsInChildren<UnityEngine.MeshRenderer>().Length;
 var unarmed=new ProjectY.Samples.PawnAppearanceData{TemplateId=appearance.TemplateId,Parts=System.Array.FindAll(appearance.Parts,part=>part.Slot!="mainHand" && part.Slot!="offHand")};
 guard.ApplyAppearance(unarmed,part=>assets[part.Id]);
 if(guard.GetComponentsInChildren<UnityEngine.MeshRenderer>().Length!=originalCount-2)throw new System.InvalidOperationException("Unequip did not remove meshes");
 guard.ApplyAppearance(appearance,part=>assets[part.Id]);
 if(guard.GetComponentsInChildren<UnityEngine.MeshRenderer>().Length!=originalCount)throw new System.InvalidOperationException("Re-equip duplicated meshes");
 var lamp=new UnityEngine.GameObject("PreviewSun",typeof(UnityEngine.Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lamp,preview);
 var light=lamp.GetComponent<UnityEngine.Light>();light.type=UnityEngine.LightType.Directional;light.intensity=1.25f;light.color=new UnityEngine.Color(1,.96f,.88f);
 lamp.transform.rotation=UnityEngine.Quaternion.Euler(48,-35,0);
 var cameraObject=new UnityEngine.GameObject("PreviewCamera",typeof(UnityEngine.Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,preview);
 var camera=cameraObject.GetComponent<UnityEngine.Camera>();camera.scene=preview;camera.enabled=false;
 camera.orthographic=true;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.10f,.14f,.15f);
 camera.nearClipPlane=.1f;camera.farClipPlane=1200;
 System.Action<string,UnityEngine.Vector3,float> capture=(name,focus,zoom)=>{
  var rotation=UnityEngine.Quaternion.Euler(52,155,0);camera.transform.SetPositionAndRotation(focus-rotation*UnityEngine.Vector3.forward*500,rotation);camera.orthographicSize=zoom;
  var texture=new UnityEngine.RenderTexture(1536,1000,24,UnityEngine.RenderTextureFormat.ARGB32);texture.antiAliasing=4;texture.Create();
  var previous=UnityEngine.RenderTexture.active;var image=new UnityEngine.Texture2D(1536,1000,UnityEngine.TextureFormat.RGB24,false);
  try {
   camera.targetTexture=texture;camera.Render();UnityEngine.RenderTexture.active=texture;
   image.ReadPixels(new UnityEngine.Rect(0,0,1536,1000),0,0);image.Apply();
   var path=System.IO.Path.Combine(root,"Art/PawnLowPoly/Previews/"+name+".png");System.IO.File.WriteAllBytes(path,image.EncodeToPNG());outputs.Add(path);
  } finally {camera.targetTexture=null;UnityEngine.RenderTexture.active=previous;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(image);}
 };
 var groupFocus=UnityEngine.Vector3.zero;foreach(var member in state.Members)groupFocus+=layout.Cells[member.CellIndex].Position;groupFocus/=4;
 capture("squad-maparea-unity",groupFocus+UnityEngine.Vector3.up*.7f,7.5f);
 var report=new {members=4,bindings=16,cellRadius=layout.Radius,swapVerified=true,playing=UnityEditor.EditorApplication.isPlaying,image=outputs[0]};
 System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/PawnLowPoly/Integration/squad-unity.json"),Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented));
 return report;
} finally { if(squad!=null)squad.Dispose(); UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);UnityEngine.Object.DestroyImmediate(material); }
