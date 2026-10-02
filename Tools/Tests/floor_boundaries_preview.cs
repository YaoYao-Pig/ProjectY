// Execute in the existing Editor via MCP after the one requested project compile.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var layouts=new System.Collections.Generic.List<ProjectY.Samples.MapAreaViewData>();
var names=new System.Collections.Generic.List<string>();var owners=new System.Collections.Generic.List<int>();
using(var lua=new XLua.LuaEnv()){
 var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
 using(var rows=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/floor_boundaries_preview.lua"))[0])
 for(int i=1;i<=rows.Length;i++)using(var row=rows.Get<int,XLua.LuaTable>(i))using(var data=row.Get<XLua.LuaTable>("layout")){
  layouts.Add(ProjectY.Samples.MapAreaViewData.Read(data));names.Add(row.Get<string>("name"));owners.Add(row.Get<int>("ownerIndex")-1);
 }
}
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=original.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var previous=RenderTexture.active;var target=new RenderTexture(1440,1000,24,RenderTextureFormat.ARGBHalf,RenderTextureReadWrite.Linear);target.Create();
var pixels=new Texture2D(1440,1000,TextureFormat.RGBAFloat,false,true);var image=new Texture2D(1440,1000,TextureFormat.RGB24,false);
var output="Docs/Previews/MapArea/FloorBoundaries";System.IO.Directory.CreateDirectory(output);
var checks=new Newtonsoft.Json.Linq.JArray();
try{
 var host=new GameObject("FloorBoundaryReview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
 var camera=new GameObject("Camera").AddComponent<Camera>();camera.transform.SetParent(host.transform,false);camera.scene=scene;camera.enabled=false;
 camera.targetTexture=target;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
 camera.orthographic=true;camera.aspect=1.44f;camera.nearClipPlane=.1f;camera.farClipPlane=600;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.12f,.18f,.22f);
 for(int i=0;i<2;i++){var light=new GameObject("Light"+i).AddComponent<Light>();light.transform.SetParent(host.transform,false);light.type=LightType.Directional;light.intensity=i==0?1.15f:.4f;light.transform.rotation=Quaternion.Euler(i==0?new Vector3(50,-35,0):new Vector3(30,140,0));}
 var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
 for(int n=0;n<layouts.Count;n++){
  var map=layouts[n];var selected=map.Cells[owners[n]];var shown=new bool[map.Cells.Length];int tested=0;
  using(var surface=new ProjectY.Samples.TownSurfaceRenderer(shader,map,c=>c.RenderGround&&(map.IsTown||c.UsesSurfaceMesh))){
   foreach(var patch in map.FloorBoundaryPatches){
    System.Array.Clear(shown,0,shown.Length);shown[patch.OwnerIndex]=true;surface.SetVisibility(shown);
    var center=Vector3.zero;foreach(var p in patch.Points)center+=p;center/=patch.Points.Length;
    int hit;float distance=surface.Raycast(new Ray(center+Vector3.up,Vector3.down),float.PositiveInfinity,out hit);
    if(hit!=-1||Mathf.Abs(distance-1)>.002f)throw new System.Exception("Boundary is selectable or has a hole: "+names[n]+"/"+tested+" hit="+hit+" distance="+distance);
    var floor=map.Cells[patch.OwnerIndex];surface.Raycast(new Ray(floor.Position+Vector3.up,Vector3.down),float.PositiveInfinity,out hit);
    if(hit!=patch.OwnerIndex)throw new System.Exception("Full hex lost its selectable identity");tested++;
   }
   System.Array.Clear(shown,0,shown.Length);surface.SetVisibility(shown);
   if(surface.Mesh.triangles.Length!=0)throw new System.Exception("Hidden floor leaves boundary geometry visible");
  }
  var all=new int[map.Cells.Length];for(int i=0;i<all.Length;i++)all[i]=i;
  // Isolate the selected building for three-view inspection: neighboring gatehouses
  // otherwise completely occlude the side view. The preceding pick checks used the full map.
  if(map.IsTown){
   map.Props=System.Array.FindAll(map.Props,p=>p.InteriorId==selected.InteriorId);
   foreach(var cell in map.Cells)if(cell.InteriorId!=selected.InteriorId)cell.RenderGround=false;
  }
  using(var renderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(map.AssetPath),map,a=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(a.Path))){
   var state=new ProjectY.Samples.MapAreaViewData.State{Known=all,Visible=all,Members=new[]{new ProjectY.Samples.MapAreaViewData.Member{ActorId=1,CellIndex=owners[n]}},Revision=1};
   renderer.UpdateVisibility(state,true);
   Vector3 focus;float yaw;
   if(map.IsTown){var building=System.Array.Find(map.Props,p=>p.InteriorId==selected.InteriorId&&!p.Cutaway);focus=building.Position+Vector3.up*3.2f;yaw=building.Rotation;camera.orthographicSize=9;}
   else{var hull=System.Array.Find(map.Props,p=>p.AssetId==800);focus=hull.Position+new Vector3(0,7.2f,-28);yaw=0;camera.orthographicSize=14;}
   for(int v=0;v<3;v++){
    var rotation=Quaternion.Euler(v==0?90:v==1?35:18,yaw+(v==2?90:0),0);camera.transform.SetPositionAndRotation(focus-rotation*Vector3.forward*250,rotation);
    renderer.Draw(camera);ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;pixels.ReadPixels(new Rect(0,0,1440,1000),0,0);pixels.Apply();
    var linear=pixels.GetPixels();var encoded=new Color32[linear.Length];for(int i=0;i<linear.Length;i++)encoded[i]=linear[i].gamma;image.SetPixels32(encoded);image.Apply();
    System.IO.File.WriteAllBytes(output+"/"+names[n]+"-"+(v==0?"top":v==1?"front":"side")+".png",image.EncodeToPNG());
   }
   // Exact same floor owns the visual patch and the cutaway decision.
   var lower=-1;for(int i=0;i<map.Cells.Length;i++)if(!map.Cells[i].Blocked&&map.Cells[i].Layer==0&&(!map.IsTown||map.Cells[i].InteriorId==selected.InteriorId)){lower=i;break;}
   if(lower<0)throw new System.Exception("Missing lower-floor visibility fixture");
   state.Members[0].CellIndex=lower;state.Revision++;renderer.UpdateVisibility(state,true);
   if(renderer.IsCellShown(owners[n]))throw new System.Exception("Upper boundary owner remains visible downstairs");
  }
  checks.Add(new Newtonsoft.Json.Linq.JObject{{"map",names[n]},{"patches",tested},{"unselectable",true},{"fullHexPickPreserved",true},{"fogAndCutaway",true},{"views",3}});
 }
 var report=new Newtonsoft.Json.Linq.JObject{{"passed",true},{"playMode",false},{"checks",checks}};
 System.IO.File.WriteAllText(output+"/validation.json",report.ToString());return report;
}finally{
 RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(pixels);UnityEngine.Object.DestroyImmediate(image);
 UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
 if(original.isDirty!=dirty||UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=original)throw new System.Exception("Preview changed the active scene");
}
