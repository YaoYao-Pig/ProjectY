if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var outputs=new System.Collections.Generic.List<object>();
foreach(var areaId in new[]{20,30}){
 ProjectY.Samples.MapAreaViewData layout;ProjectY.Samples.AdventureViewData view;
 using(var lua=new XLua.LuaEnv()){
  var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);lua.Global.Set("LootPreviewArea",areaId);
  try{
   var result=lua.DoString(System.IO.File.ReadAllText("Tools/Loot/preview.lua"));
   using(var table=(XLua.LuaTable)result[0])layout=ProjectY.Samples.MapAreaViewData.Read(table);
   using(var table=(XLua.LuaTable)result[1])view=ProjectY.Samples.AdventureViewData.Read(table);
  }finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
 }
 var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new UnityEngine.GameObject("LootPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
 var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
 var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.EquipmentAssetCatalog>(ProjectY.Editor.EquipmentAssets.CatalogPath);
 ProjectY.Samples.MapAreaRenderer terrain=null;ProjectY.Samples.AreaLootRenderer loot=null;ProjectY.Samples.SquadPawnRenderer squad=null;
 var ambient=UnityEngine.RenderSettings.ambientLight;var ambientMode=UnityEngine.RenderSettings.ambientMode;var fog=UnityEngine.RenderSettings.fog;
 try{
  UnityEngine.RenderSettings.ambientMode=UnityEngine.Rendering.AmbientMode.Flat;UnityEngine.RenderSettings.ambientLight=new UnityEngine.Color(.6f,.64f,.67f);UnityEngine.RenderSettings.fog=false;
  var lightObject=new UnityEngine.GameObject("Sun",typeof(UnityEngine.Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);var light=lightObject.GetComponent<UnityEngine.Light>();light.type=UnityEngine.LightType.Directional;light.intensity=1.1f;light.transform.rotation=UnityEngine.Quaternion.Euler(48,-35,0);
  terrain=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(layout.AssetPath),layout,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path));terrain.UpdateVisibility(view.Area,true);
  loot=new ProjectY.Samples.AreaLootRenderer(root.transform,catalog);loot.Apply(view.Area,layout);
  var rig=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab").GetComponent<ProjectY.Samples.PawnView>();
  squad=new ProjectY.Samples.SquadPawnRenderer(root.transform,rig,part=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(part.Path));squad.SetState(view.Area,view.Party,layout);squad.Capture(0);squad.Tick(.033f);
  var cameraObject=new UnityEngine.GameObject("Camera",typeof(UnityEngine.Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);var camera=cameraObject.GetComponent<UnityEngine.Camera>();
  camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.orthographicSize=areaId==20?11:14;camera.nearClipPlane=.1f;camera.farClipPlane=600;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.15f,.19f,.18f);
  if(view.Area.Loots.Length==0)throw new System.Exception("Preview seed has no loot");
  var center=areaId==20?layout.Cells[view.Area.Loots[0].CellIndex].Position:terrain.Bounds.center;
  var rotation=UnityEngine.Quaternion.Euler(58,-25,0);camera.transform.SetPositionAndRotation(center-rotation*UnityEngine.Vector3.forward*180,rotation);
  var rt=new UnityEngine.RenderTexture(1440,900,24);rt.Create();var previous=UnityEngine.RenderTexture.active;var image=new UnityEngine.Texture2D(1440,900,UnityEngine.TextureFormat.RGB24,false);
  try{
   camera.targetTexture=rt;terrain.Draw(camera);camera.Render();UnityEngine.RenderTexture.active=rt;image.ReadPixels(new UnityEngine.Rect(0,0,1440,900),0,0);image.Apply();
   var path="Docs/Previews/Loot-"+areaId+".png";System.IO.File.WriteAllBytes(path,image.EncodeToPNG());outputs.Add(new{area=areaId,cells=layout.Cells.Length,loot=view.Area.Loots.Length,path=path});
  }finally{camera.targetTexture=null;UnityEngine.RenderTexture.active=previous;rt.Release();UnityEngine.Object.DestroyImmediate(rt);UnityEngine.Object.DestroyImmediate(image);}
 }finally{
  if(squad!=null)squad.Dispose();if(loot!=null)loot.Dispose();if(terrain!=null)terrain.Dispose();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
  UnityEngine.RenderSettings.ambientLight=ambient;UnityEngine.RenderSettings.ambientMode=ambientMode;UnityEngine.RenderSettings.fog=fog;
 }
}
return outputs;
