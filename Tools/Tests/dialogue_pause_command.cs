// 独立加载实际 AdventureDemo 场景的预览副本，使用真实 Demo.SendCommand；不进入 Play。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
if(ProjectY.GameBootstrap.Instance!=null)throw new System.Exception("An existing game runtime must not be replaced by this fixture");
var sourceScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
if(sourceScene.path!="Assets/GameFramework/Samples/Adventure/AdventureDemo.unity")throw new System.Exception("Open AdventureDemo in Edit Mode before this focused check");
ProjectY.Samples.AdventureRuntimeDemo sourceDemo=null;
foreach(var root in sourceScene.GetRootGameObjects())foreach(var item in root.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)){
 if(sourceDemo!=null)throw new System.Exception("Duplicate configured demo");sourceDemo=item;
}
if(sourceDemo==null)throw new System.Exception("No configured AdventureRuntimeDemo");
var sourceFields=new UnityEditor.SerializedObject(sourceDemo);
var sourceBootstrap=(ProjectY.GameBootstrap)sourceFields.FindProperty("bootstrap").objectReferenceValue;
var sourceCamera=(UnityEngine.Camera)sourceFields.FindProperty("mapCamera").objectReferenceValue;
var sourceSun=(UnityEngine.Light)sourceFields.FindProperty("environmentSun").objectReferenceValue;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.GameBootstrap bootstrap=null;ProjectY.Samples.AdventureRuntimeDemo demo=null;
var originalScale=UnityEngine.Time.timeScale;
var errors=new System.Collections.Generic.List<string>();
UnityEngine.Application.LogCallback capture=(message,trace,type)=>{if(type==UnityEngine.LogType.Error || type==UnityEngine.LogType.Exception || type==UnityEngine.LogType.Assert)errors.Add(message);};
UnityEngine.Application.logMessageReceived+=capture;
System.Action<UnityEngine.MonoBehaviour,string> lifecycle=(component,name)=>{
 var method=component.GetType().GetMethod(name,System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
 if(method==null)throw new System.Exception("Missing lifecycle: "+name);method.Invoke(component,null);
};
try{
 bootstrap=UnityEngine.Object.Instantiate(sourceBootstrap);demo=UnityEngine.Object.Instantiate(sourceDemo);
 var camera=UnityEngine.Object.Instantiate(sourceCamera);var sun=UnityEngine.Object.Instantiate(sourceSun);
 foreach(var value in new UnityEngine.GameObject[]{bootstrap.gameObject,demo.gameObject,camera.gameObject,sun.gameObject})UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(value,scene);
 camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
 var fields=new UnityEditor.SerializedObject(demo);
 fields.FindProperty("bootstrap").objectReferenceValue=bootstrap;fields.FindProperty("mapCamera").objectReferenceValue=camera;fields.FindProperty("environmentSun").objectReferenceValue=sun;fields.ApplyModifiedPropertiesWithoutUndo();
 lifecycle(bootstrap,"Awake");
 if(!bootstrap.IsEditorConsoleReady)throw new System.Exception("Preview bootstrap did not initialize");
 lifecycle(demo,"Start");
 var runner=System.IO.File.ReadAllText("Tools/LuaConsole/runtime.lua");
 System.Action<string> check=code=>{
  var result=bootstrap.ExecuteEditorConsole(runner,code,"@dialogue_pause_command");
  if(!(bool)result[0])throw new System.Exception((string)result[3]);
 };
 if(!string.IsNullOrEmpty(demo.LastError))throw new System.Exception(demo.LastError);
 demo.SendCommand("gm_goto_npc",1,0);
 if(!string.IsNullOrEmpty(demo.LastError))throw new System.Exception(demo.LastError);
 // 读取已验证的场景临时 NPC ID；不依赖固定生成顺序。
 int localNpc=0;
 using(var layout=(XLua.LuaTable)bootstrap.CallModule("Game.Adventure.DemoBridge","area_layout")[0])
 using(var rows=layout.Get<XLua.LuaTable>("npcs"))
  for(int i=1;i<=rows.Length;i++)using(var row=rows.Get<int,XLua.LuaTable>(i))if(row.Get<int>("narrativeId")==1)localNpc=row.Get<int>("id");
 if(localNpc==0)throw new System.Exception("Narrative NPC not rendered");
 demo.SendCommand("area_interact",2,localNpc);
 check("local s=console.systems:Get('Narrative'); assert(s.data.DialogueOpen and s.data.DialogueNodeId==1); assert(console.services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==0)");
 var narrative=(ProjectY.Data.NarrativeData)bootstrap.CallModule("Game.Narrative.Bridge","data")[0];
 var player=demo.HealthTarget(narrative.DialogueActorId).GetComponentInParent<ProjectY.Samples.PawnView>();
 if(player==null)throw new System.Exception("Missing rendered player pawn");
 if(player.PresentationBusy)throw new System.Exception("Opening a paused dialogue queued an interaction animation");
 // 人为保留一个真实未结束动画，验证选项/关闭不会等待 Time.timeScale=0 下的动作。
 player.PlayInteraction(true);if(!player.PresentationBusy)throw new System.Exception("Fixture must contain a busy animated pawn");
 check("local ui=console.systems:Get('UI'); local p=ui.panels.Dialogue.ctrl; assert(p.pool[2].view.Button.interactable); p.pool[2].view.Button.onClick:Invoke(); p:Tick(); assert(console.systems:Get('Narrative').data.DialogueNodeId==2, 'Choice was swallowed by the real Demo animation gate'); assert(console.systems:Get('Narrative').data:Status('mission',100)=='active')");
 player.PlayInteraction(true);if(!player.PresentationBusy)throw new System.Exception("Close test needs a busy actor");
 check("local ui=console.systems:Get('UI'); ui.panels.Dialogue.ctrl.view.Close.onClick:Invoke(); assert(not console.systems:Get('Narrative').data.DialogueOpen); assert(not ui:IsOpen('Dialogue')); assert(not console.services.UI.IsWorldPaused)");
 if(UnityEngine.Time.timeScale!=originalScale)throw new System.Exception("Dialogue close did not restore time scale");
 if(!string.IsNullOrEmpty(demo.LastError))throw new System.Exception(demo.LastError);
 return "PASS real AdventureDemo command chain: dialogue opens without queued frozen animation; real choice and close buttons dispatch while actor animation is busy at timeScale=0; pause is released";
}finally{
 try{
  // 先按正常关闭顺序释放 Lua 回调和 UI，再销毁拥有显示对象的预览场景。
  if(bootstrap!=null)lifecycle(bootstrap,"OnDestroy");
  if(demo!=null)lifecycle(demo,"OnDestroy");
 }finally{
  UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
  if(UnityEngine.Time.timeScale!=originalScale)UnityEngine.Time.timeScale=originalScale;
  UnityEngine.Application.logMessageReceived-=capture;
 }
 if(errors.Count>0)throw new System.Exception("Preview emitted errors: "+string.Join(" | ",errors.ToArray()));
}
