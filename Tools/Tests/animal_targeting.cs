// Reproduce clicks on model heads whose projected ground belongs to a different hex.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
ProjectY.Samples.MapAreaViewData layout;var actors=new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData.Actor>();
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
 try{
  var result=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/animal_targeting.lua"));
  using(var root=(XLua.LuaTable)result[0])layout=ProjectY.Samples.MapAreaViewData.Read(root);
  using(var rows=(XLua.LuaTable)result[1])for(int i=1;i<=rows.Length;i++)using(var row=rows.Get<int,XLua.LuaTable>(i))actors.Add(ProjectY.Samples.AdventureViewData.ReadActor(row));
 }finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var owner=new UnityEngine.GameObject("AnimalTargetingCheck");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner,scene);
var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
var rig=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab").GetComponent<ProjectY.Samples.PawnView>();
ProjectY.Samples.MapAreaRenderer terrain=null;ProjectY.Samples.AreaCombatRenderer animals=null;
try{
 terrain=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(layout.AssetPath),layout,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path));
 animals=new ProjectY.Samples.AreaCombatRenderer(owner.transform,rig,shader,part=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(part.Path));
 var known=new int[layout.Cells.Length];for(int i=0;i<known.Length;i++)known[i]=i;
 var state=new ProjectY.Samples.MapAreaViewData.State{Revision=1,Known=known,Visible=known,Members=new ProjectY.Samples.MapAreaViewData.Member[0],Enemies=actors.ToArray(),Defeated=new ProjectY.Samples.AdventureViewData.Actor[0]};
 terrain.UpdateVisibility(state,true);animals.SetState(state,layout);
 int checkedRays=0,previousMisses=0;UnityEngine.Ray firstRay=default(UnityEngine.Ray);
 for(int i=0;i<actors.Count;i++){
  var body=System.Array.Find(actors[i].Appearance.Parts,part=>part.Slot=="body");var mesh=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(body.Path).GetComponent<UnityEngine.MeshFilter>().sharedMesh;
  var point=UnityEngine.Vector3.zero;float front=float.NegativeInfinity;
  foreach(var vertex in mesh.vertices)if(vertex.y>mesh.bounds.size.y*.55f && vertex.z>front){point=vertex;front=vertex.z;}
  point=UnityEngine.Vector3.Lerp(point,mesh.bounds.center,.04f);
  foreach(var pitch in new[]{25,45,65})foreach(var yaw in new[]{-25,65,155,245}){
   var direction=UnityEngine.Quaternion.Euler(pitch,yaw,0)*UnityEngine.Vector3.forward;var head=animals.Target(actors[i].Id).TransformPoint(point);
   var ray=new UnityEngine.Ray(head-direction*30,direction);float distance;
   if(animals.PickActor(ray,out distance)!=actors[i].Id)throw new System.Exception("Model target missed: "+actors[i].Id+" at "+pitch+","+yaw);
   if(terrain.Pick(ray)!=actors[i].CellIndex)previousMisses++;checkedRays++;if(i==0)firstRay=ray;
  }
 }
 if(previousMisses==0)throw new System.Exception("Fixture failed to reproduce old ground-picking bug");
 state.Enemies=new[]{actors[1],actors[2]};animals.SetState(state,layout);float hiddenDistance;
 if(animals.PickActor(firstRay,out hiddenDistance)==actors[0].Id)throw new System.Exception("Hidden animal stayed targetable");
 var before=new ProjectY.Samples.AdventureViewData{Phase="area",Error="请选择未驯服的动物"};
 var poll=new ProjectY.Samples.AdventureViewData{Phase="area",Error=""};poll.RetainPollingFeedback(before);
 if(poll.Error!=before.Error)throw new System.Exception("Polling erased command feedback");
 var transition=new ProjectY.Samples.AdventureViewData{Phase="battle",Error=""};transition.RetainPollingFeedback(before);
 if(transition.Error!="")throw new System.Exception("A phase transition retained unrelated feedback");
 return new{checkedRays=checkedRays,oldGroundPickingMisses=previousMisses,hiddenActorsExcluded=true,pollingFeedbackPreserved=true};
}finally{if(animals!=null)animals.Dispose();if(terrain!=null)terrain.Dispose();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
