// Native Editor-only preview from the real four-member movement trajectory.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var root="Art/AssetExpansion202610/ShipwreckV2";
var layouts=new System.Collections.Generic.List<ProjectY.Samples.MapAreaViewData>();
var views=new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData>();var names=new System.Collections.Generic.List<string>();
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
 try{using(var rows=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/shipwreck_v2_preview.lua"))[0])
  for(int i=1;i<=rows.Length;i++)using(var row=rows.Get<int,XLua.LuaTable>(i))using(var map=row.Get<XLua.LuaTable>("layout"))using(var view=row.Get<XLua.LuaTable>("view")){
   names.Add(row.Get<string>("name"));layouts.Add(ProjectY.Samples.MapAreaViewData.Read(map));views.Add(ProjectY.Samples.AdventureViewData.Read(view));
  }
 }finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool wasDirty=original.isDirty;
ProjectY.Samples.AdventureRuntimeDemo demo=null;
foreach(var r in original.GetRootGameObjects())foreach(var d in r.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))demo=d;
if(demo==null)throw new System.Exception("Adventure scene missing");
var fields=new UnityEditor.SerializedObject(demo);var rig=(ProjectY.Samples.PawnView)fields.FindProperty("pawnPrefab").objectReferenceValue;
var shader=(UnityEngine.Shader)fields.FindProperty("previewShader").objectReferenceValue;
var lootCatalog=(ProjectY.Samples.EquipmentAssetCatalog)fields.FindProperty("equipmentCatalog").objectReferenceValue;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var previous=UnityEngine.RenderTexture.active;
var target=new UnityEngine.RenderTexture(1600,1000,24,UnityEngine.RenderTextureFormat.ARGBHalf,UnityEngine.RenderTextureReadWrite.Linear);target.Create();
var pixels=new UnityEngine.Texture2D(1600,1000,UnityEngine.TextureFormat.RGBAFloat,false,true);
var image=new UnityEngine.Texture2D(1600,1000,UnityEngine.TextureFormat.RGB24,false);
var checks=new Newtonsoft.Json.Linq.JArray();var paths=new Newtonsoft.Json.Linq.JArray();
try{
 var host=new UnityEngine.GameObject("ShipwreckV2_Preview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
 var camera=new UnityEngine.GameObject("ShipwreckV2_Camera").AddComponent<UnityEngine.Camera>();camera.transform.SetParent(host.transform,false);
 camera.scene=scene;camera.enabled=false;camera.targetTexture=target;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
 camera.orthographic=true;camera.aspect=1.6f;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.13f,.22f,.25f);camera.nearClipPlane=.1f;camera.farClipPlane=800;
 for(int i=0;i<2;i++){
  var light=new UnityEngine.GameObject("ShipwreckV2_Light"+i).AddComponent<UnityEngine.Light>();light.transform.SetParent(host.transform,false);
  light.type=UnityEngine.LightType.Directional;light.intensity=i==0?1.15f:.38f;light.color=i==0?new UnityEngine.Color(1,.95f,.84f):new UnityEngine.Color(.7f,.83f,1);
  light.transform.rotation=UnityEngine.Quaternion.Euler(i==0?new UnityEngine.Vector3(48,-35,0):new UnityEngine.Vector3(32,140,0));
 }
 for(int n=0;n<layouts.Count;n++){
  var map=layouts[n];var view=views[n];var state=view.Area;var name=names[n];
  using(var renderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(map.AssetPath),map,a=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(a.Path)))
  using(var squad=new ProjectY.Samples.SquadPawnRenderer(host.transform,rig,p=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(p.Path)))
  using(var lootRenderer=new ProjectY.Samples.AreaLootRenderer(host.transform,lootCatalog,renderer.IsCellShown)){
   renderer.UpdateVisibility(state,true);squad.SetState(state,view.Party,map);squad.Skip();
   var leader=map.Cells[state.CellIndex];int mainVisible=0,upperVisible=0,mainTotal=0,upperTotal=0,stairsVisible=0,sternShown=0,foreShown=0;
   for(int i=0;i<map.Cells.Length;i++){
    var c=map.Cells[i];if(c.Kind=="stairs"){if(renderer.IsCellShown(i))stairsVisible++;continue;}
    if(c.Layer==1){mainTotal++;if(renderer.IsCellShown(i))mainVisible++;}
    if(c.Layer==2){upperTotal++;if(renderer.IsCellShown(i))upperVisible++;if(renderer.IsCellShown(i)&&c.CoverInteriorId==2001)sternShown++;if(renderer.IsCellShown(i)&&c.CoverInteriorId==2002)foreShown++;}
   }
   if(name.Contains("lower")&&(mainVisible!=0||upperVisible!=0))throw new System.Exception("Lower cabin is covered by higher deck: "+name);
   if((name.Contains("arrival")||name.Contains("restored"))&&upperVisible!=upperTotal)throw new System.Exception("Exposed raised decks are hidden: "+name);
   if(name.Contains("captain")&&(sternShown!=0||foreShown==0))throw new System.Exception("Captain cabin cutaway affected wrong upper platform");
   var picked=renderer.Pick(new UnityEngine.Ray(leader.Position+UnityEngine.Vector3.up*20,UnityEngine.Vector3.down));
   if(picked!=state.CellIndex)throw new System.Exception("Click picked the wrong floor in "+name+": "+picked+" vs "+state.CellIndex);
   var cut=typeof(ProjectY.Samples.MapAreaRenderer).GetMethod("IsCut",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
   int shownProps=0,hiddenProps=0;
   foreach(var p in map.Props){bool hidden=(bool)cut.Invoke(renderer,new object[]{p.InteriorId,p.Cutaway,p.Layer,p.CutawayGroup,p.CutawayLayer});if(hidden)hiddenProps++;else shownProps++;}
   lootRenderer.Apply(state,map);
   var lootObjects=(System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>)typeof(ProjectY.Samples.AreaLootRenderer).GetField("objects",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(lootRenderer);
   int visibleLoot=0;
   foreach(var loot in state.Loots){bool expected=renderer.IsCellShown(loot.CellIndex);if(lootObjects[loot.Id].activeSelf!=expected)throw new System.Exception("Loot visibility differs from its floor");if(expected)visibleLoot++;}
   checks.Add(new Newtonsoft.Json.Linq.JObject(new Newtonsoft.Json.Linq.JProperty("state",name),new Newtonsoft.Json.Linq.JProperty("leader_layer",leader.Layer),new Newtonsoft.Json.Linq.JProperty("members",state.Members.Length),new Newtonsoft.Json.Linq.JProperty("main_visible",mainVisible),new Newtonsoft.Json.Linq.JProperty("upper_visible",upperVisible),new Newtonsoft.Json.Linq.JProperty("stairs_visible",stairsVisible),new Newtonsoft.Json.Linq.JProperty("shown_props",shownProps),new Newtonsoft.Json.Linq.JProperty("hidden_props",hiddenProps),new Newtonsoft.Json.Linq.JProperty("picked_index",picked),new Newtonsoft.Json.Linq.JProperty("visible_loot",visibleLoot)));
   System.Action<string,UnityEngine.Vector3,float,UnityEngine.Vector3> capture=(label,focus,size,angles)=>{
    var rotation=UnityEngine.Quaternion.Euler(angles);camera.orthographicSize=size;camera.transform.SetPositionAndRotation(focus-rotation*UnityEngine.Vector3.forward*250,rotation);
    renderer.Draw(camera);ProjectY.Rendering.UrpCameraRendering.Render(camera);UnityEngine.RenderTexture.active=target;
    pixels.ReadPixels(new UnityEngine.Rect(0,0,1600,1000),0,0);pixels.Apply();var linear=pixels.GetPixels();var output=new UnityEngine.Color32[linear.Length];
    for(int k=0;k<linear.Length;k++)output[k]=linear[k].gamma;image.SetPixels32(output);image.Apply();
    var path=root+"/Previews/"+label+".png";System.IO.File.WriteAllBytes(path,image.EncodeToPNG());paths.Add(path);
   };
   var hull=System.Array.Find(map.Props,p=>p.AssetId==800);if(hull==null)throw new System.Exception("Expanded hull absent");
   if(n==0)capture("generated-overview",hull.Position+UnityEngine.Vector3.up*3,62,new UnityEngine.Vector3(50,-35,0));
   if(name=="ship-lower-cargo")capture("generated-lower-plan",hull.Position,60,new UnityEngine.Vector3(82,0,0));
   capture(name,leader.Position+UnityEngine.Vector3.up*.5f,name.Contains("lower")?15:18,new UnityEngine.Vector3(58,-30,0));
  }
 }
 camera.targetTexture=null;
 var result=new Newtonsoft.Json.Linq.JObject(new Newtonsoft.Json.Linq.JProperty("passed",true),new Newtonsoft.Json.Linq.JProperty("checks",checks),new Newtonsoft.Json.Linq.JProperty("images",paths),new Newtonsoft.Json.Linq.JProperty("playMode",false));
 System.IO.File.WriteAllText(root+"/Integration/unity_multilevel_validation.json",result.ToString());return result;
}finally{
 UnityEngine.RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(pixels);UnityEngine.Object.DestroyImmediate(image);
 UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
 if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=original||original.isDirty!=wasDirty)throw new System.Exception("Preview modified active scene");
}
