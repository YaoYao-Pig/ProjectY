// Targeted native selection-state check. No Play, scene save or player data.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new UnityEngine.GameObject("GMKillInputCheck");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
try{
 var demo=root.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
 var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
 var type=typeof(ProjectY.Samples.AdventureRuntimeDemo);
 var view=new ProjectY.Samples.AdventureViewData{Phase="map",Error="",Reachable=new ProjectY.Samples.AdventureViewData.Cell[0]};
 type.GetField("view",flags).SetValue(demo,view);
 var selecting=type.GetField("gmKillSelecting",flags);
 demo.SendCommand("gm_begin_kill");
 if((bool)selecting.GetValue(demo)||string.IsNullOrEmpty(demo.LastError))throw new System.Exception("World map must reject point selection");
 view.Phase="battle";demo.SendCommand("gm_begin_kill");
 if(!(bool)selecting.GetValue(demo)||!string.IsNullOrEmpty(demo.LastError))throw new System.Exception("Battle selection did not start");
 type.GetMethod("TryGMKillTarget",flags).Invoke(demo,new object[]{0});
 if(!(bool)selecting.GetValue(demo)||demo.LastError!=ProjectY.UI.LuaLanguage.Get("GMKillInvalidTarget"))throw new System.Exception("Empty click must keep target selection active");
 type.GetMethod("CancelGMKillSelection",flags).Invoke(demo,null);
 if((bool)selecting.GetValue(demo))throw new System.Exception("Cancel did not clear selection");
 var revision=demo.BattleHUDRevision;type.GetMethod("CancelGMKillSelection",flags).Invoke(demo,null);
 if(demo.BattleHUDRevision!=revision)throw new System.Exception("Repeated cancellation must be idempotent");
 view.Phase="event";demo.SendCommand("gm_begin_kill");
 if((bool)selecting.GetValue(demo))throw new System.Exception("Event phase must reject selection");
 return "PASS native GM selection: scene gate, begin, empty click, cancellation, repeat cancellation and event gate";
}finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
