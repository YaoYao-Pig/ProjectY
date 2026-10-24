// Run only after the task's authorized centralized compilation. Does not enter Play or send gameplay commands.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
try
{
    var root=new UnityEngine.GameObject("ProfessionLandingValidation");root.SetActive(false);
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var demo=root.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
    var flags=System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance;
    var type=demo.GetType();
    var viewField=type.GetField("view",flags);
    var cellsField=type.GetField("battleLandingCells",flags);
    var targetField=type.GetField("landingTargetId",flags);
    var sync=type.GetMethod("SyncBattleTargets",flags);
    System.Action<bool,string> check=(value,message)=>{if(!value)throw new System.Exception(message);};
    var data=new ProjectY.Data.CombatActorData(1,1);data.SetMaxHP(100);data.Restore();data.Deploy(1,0,0);data.BeginTurn(4);
    int initialAP=data.AP,initialSequence=data.ActionSequence;bool initialMain=data.MainUsed;
    var target=new ProjectY.Samples.AdventureViewData.Actor {Id=2,Team=2,HP=100,Name="Opponent",OccupiedCells=new[]{1}};
    var source=new ProjectY.Samples.AdventureViewData.Actor {Id=1,Team=1,HP=100,Name="Duelist",OccupiedCells=new[]{0}};
    var landing=new ProjectY.Samples.AdventureViewData.Cell {Q=-1,R=0,CellIndex=2};
    var skill=new ProjectY.Samples.AdventureViewData.Skill {
        Id=1843,Name="Retreating thrust",NeedsLanding=true,MaxTargets=1,
        Targets=new[]{2},TargetCells=System.Array.Empty<int>(),ContainerTargets=System.Array.Empty<int>(),
        TargetPreviews=System.Array.Empty<ProjectY.Samples.AdventureViewData.TargetPreview>(),
        LandingOptions=new[]{new ProjectY.Samples.AdventureViewData.LandingOption {TargetId=2,Cells=new[]{landing}}}
    };
    var view=new ProjectY.Samples.AdventureViewData {Phase="battle",BattlePhase="combat",ActiveId=1,Round=1,
        Units=new[]{source,target},Party=new[]{source},Skills=new[]{skill},Reachable=System.Array.Empty<ProjectY.Samples.AdventureViewData.Cell>(),
        Cells=new[]{new ProjectY.Samples.AdventureViewData.Cell {Q=0,R=0,CellIndex=0},new ProjectY.Samples.AdventureViewData.Cell {Q=1,R=0,CellIndex=1},landing},Error=""};
    viewField.SetValue(demo,view);
    demo.SelectBattleSkill(1843);
    check(ProjectY.Samples.BattleTargetSelection.Active(demo) && ProjectY.Samples.BattleTargetSelection.NeedsLanding(demo),"Landing skill did not enter cancellable selection");
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    check((int)targetField.GetValue(demo)==2 && ((ProjectY.Samples.AdventureViewData.Cell[])cellsField.GetValue(demo)).Length==1,"Target selection did not expose exactly its supplied legal landing cells");
    check(data.AP==initialAP && data.MainUsed==initialMain && data.ActionSequence==initialSequence,"Selecting a target changed authoritative action state");
    ProjectY.Samples.BattleTargetSelection.Confirm(demo);
    check(string.IsNullOrEmpty(demo.LastError) && (int)targetField.GetValue(demo)==2,"Enter prematurely dispatched a landing skill");
    ProjectY.Samples.BattleTargetSelection.Cancel(demo);
    check(demo.SelectedBattleSkill==0 && (int)targetField.GetValue(demo)==0 && ((ProjectY.Samples.AdventureViewData.Cell[])cellsField.GetValue(demo)).Length==0,"Cancel retained stale target or landing highlights");
    check(data.AP==initialAP && data.MainUsed==initialMain,"Cancel consumed an action");
    demo.SelectBattleSkill(1843);ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    var changedSkill=new ProjectY.Samples.AdventureViewData.Skill {Id=1843,NeedsLanding=true,Targets=System.Array.Empty<int>(),TargetCells=System.Array.Empty<int>(),ContainerTargets=System.Array.Empty<int>(),TargetPreviews=System.Array.Empty<ProjectY.Samples.AdventureViewData.TargetPreview>()};
    var changed=new ProjectY.Samples.AdventureViewData {Phase="battle",BattlePhase="combat",ActiveId=1,Round=1,Units=view.Units,Skills=new[]{changedSkill},Reachable=view.Reachable};
    sync.Invoke(demo,new object[]{view,changed});
    check((int)targetField.GetValue(demo)==0,"Invalidated target retained landing selection after a refreshed snapshot");
    check(string.IsNullOrEmpty(demo.LastError),"Presentation-only selection unexpectedly sent a command through the null bootstrap");
    UnityEngine.Debug.Log("PASS profession landing: target then landing, no premature Enter, cancellation preserves AP, stale targets clear");
    return new {ok=true,checks=5};
}
finally {UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
