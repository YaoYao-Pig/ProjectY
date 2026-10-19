// Unity MCP execute_code body. Real Demo component + isolated presentation snapshots; no Play or commands.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
object result;
try
{
    var root=new UnityEngine.GameObject("TrackingSelectionValidation");
    root.SetActive(false);
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var demo=root.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
    var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
    var type=typeof(ProjectY.Samples.AdventureRuntimeDemo);
    var viewField=type.GetField("view",flags);
    var selectedField=type.GetField("selectedBattleTargets",flags);
    var syncMethod=type.GetMethod("SyncBattleTargets",flags);
    var hoverMethod=type.GetMethod("SetBattleTargetHover",flags);
    System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.Exception(message);};
    check(viewField!=null && selectedField!=null && syncMethod!=null && hoverMethod!=null,"Compiled selection presentation members are missing");
    // A null bootstrap intentionally makes any accidental command send observable as a Demo error.
    check(type.GetField("bootstrap",flags).GetValue(demo)==null,"Isolated Demo unexpectedly has a bootstrap");
    var actor=new ProjectY.Data.CombatActorData(1,1);actor.SetMaxHP(100);actor.Restore();actor.Deploy(1,0,0);actor.BeginTurn(4);
    System.Func<int,int,string,int[],ProjectY.Samples.AdventureViewData> snapshot=(active,round,phase,targets)=>
    {
        var units=new[]{
            new ProjectY.Samples.AdventureViewData.Actor{Id=1,Team=1,HP=100,MaxHP=100,AP=4,Name="Archer",OccupiedCells=new[]{0}},
            new ProjectY.Samples.AdventureViewData.Actor{Id=2,Team=2,HP=80,MaxHP=80,AP=4,Name="Guard",OccupiedCells=new[]{1}},
            new ProjectY.Samples.AdventureViewData.Actor{Id=3,Team=2,HP=70,MaxHP=70,AP=4,Name="Scout",OccupiedCells=new[]{2}},
            new ProjectY.Samples.AdventureViewData.Actor{Id=4,Team=2,HP=90,MaxHP=90,AP=4,Name="Raider",OccupiedCells=new[]{3}}
        };
        var previews=new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData.TargetPreview>();
        foreach(var id in targets)previews.Add(new ProjectY.Samples.AdventureViewData.TargetPreview{
            Id=id,HitChance=63.5f,InterceptChance=21,BlockerCount=2,FriendlyRisk=true,Description="A friendly actor can intercept this shot."
        });
        return new ProjectY.Samples.AdventureViewData{
            Phase="battle",BattlePhase=phase,Round=round,ActiveId=active,Error="",Party=new[]{units[0]},Units=units,
            Reachable=new[]{new ProjectY.Samples.AdventureViewData.Cell{Q=1,R=0,CellIndex=1}},
            Skills=new[]{
                new ProjectY.Samples.AdventureViewData.Skill{Id=6,Name="Guided scatter",MaxTargets=2,ManualTargets=true,Guided=true,
                    Targets=targets,TargetCells=new int[0],ContainerTargets=new int[0],TargetPreviews=previews.ToArray()},
                new ProjectY.Samples.AdventureViewData.Skill{Id=7,Name="Single shot",MaxTargets=1,ManualTargets=false,Guided=false,
                    Targets=targets,TargetCells=new int[0],ContainerTargets=new int[0],TargetPreviews=previews.ToArray()}
            }
        };
    };
    System.Func<System.Collections.Generic.List<int>> selected=()=>
        (System.Collections.Generic.List<int>)selectedField.GetValue(demo);
    System.Action<ProjectY.Samples.AdventureViewData,ProjectY.Samples.AdventureViewData> sync=(previous,incoming)=>
    {syncMethod.Invoke(demo,new object[]{previous,incoming});viewField.SetValue(demo,incoming);};
    var view=snapshot(1,1,"combat",new[]{2,3,4});viewField.SetValue(demo,view);
    demo.SelectBattleSkill(6);
    check(ProjectY.Samples.BattleTargetSelection.Active(demo) && ProjectY.Samples.BattleTargetSelection.Count(demo)==0 && ProjectY.Samples.BattleTargetSelection.Limit(demo)==2,"Manual selection did not start empty with configured limit");
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,3);
    check(selected().Count==2 && selected()[0]==2 && selected()[1]==3,"Distinct targets were not retained in click order");
    check(actor.HP==100 && actor.AP==4 && view.Active.HP==100 && view.Active.AP==4,"Selecting targets changed HP or AP");
    check(type.GetField("fatalError",flags).GetValue(demo)==null && view.Error=="","Selecting the final target attempted to send or execute a command");
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,4);
    check(selected().Count==2 && !selected().Contains(4) && view.Error!="","Selection limit did not reject the third target");
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    check(selected().Count==1 && selected()[0]==3 && view.Error=="","Clicking an existing target did not cancel it");
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,3);
    check(selected().Count==0,"Second cancellation did not empty the selection");
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,1);
    check(selected().Count==0 && view.Error!="","An invalid/friendly target entered the selection");
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,3);
    var hint=ProjectY.Samples.BattleTargetSelection.Hint(demo);
    var body=ProjectY.Samples.BattleTargetSelection.PreviewBody(demo);
    check(hint.Contains("2/2") && hint.Contains("63.5") && hint.Contains("21") && body.Contains("friendly actor"),"Hint did not preserve supplied hit/interception risk and description");
    check(ProjectY.Samples.BattleTargetSelection.PreviewTitle(demo)=="Scout","Hovered target identity is missing");

    var next=snapshot(1,1,"combat",new[]{3,4});sync(view,next);view=next;
    check(selected().Count==1 && selected()[0]==3,"Snapshot refresh retained an invalid target");
    next=snapshot(1,2,"combat",new[]{2,3,4});sync(view,next);view=next;
    check(selected().Count==0 && demo.SelectedBattleSkill==0,"Round change did not clear temporary selection");
    demo.SelectBattleSkill(6);ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    next=snapshot(1,2,"deployment",new[]{2,3,4});sync(view,next);view=next;
    check(selected().Count==0 && demo.SelectedBattleSkill==0,"Battle phase change did not clear selection");
    demo.SelectBattleSkill(6);ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    next=snapshot(3,2,"combat",new[]{2,3,4});sync(view,next);view=next;
    check(selected().Count==0 && demo.SelectedBattleSkill==0,"Active actor change did not clear selection");
    next=snapshot(1,2,"combat",new[]{2,3,4});sync(view,next);view=next;
    demo.SelectBattleSkill(6);ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    demo.SelectBattleSkill(7);
    check(selected().Count==0 && !ProjectY.Samples.BattleTargetSelection.Active(demo),"Switching to a single-target skill retained manual targets");
    hoverMethod.Invoke(demo,new object[]{3});
    check(ProjectY.Samples.BattleTargetSelection.Hint(demo).Contains("63.5") && ProjectY.Samples.BattleTargetSelection.PreviewBody(demo).Contains("21"),"Single-target hover does not show the same supplied shot risk");
    demo.SelectBattleSkill(6);ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    ProjectY.Samples.BattleTargetSelection.Cancel(demo);
    check(selected().Count==0 && demo.SelectedBattleSkill==0 && demo.IsBattleMoveSelected,"Cancel did not restore available move selection");
    demo.SelectBattleSkill(6);ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    next=snapshot(1,2,"combat",new[]{2,3,4});next.Phase="area";sync(view,next);view=next;
    check(selected().Count==0 && demo.SelectedBattleSkill==0,"Leaving battle retained manual targets");
    check(actor.HP==100 && actor.AP==4 && type.GetField("fatalError",flags).GetValue(demo)==null,"Selection-only checks mutated gameplay resources or attempted a command");
    result=new{passed=true,realDemo=true,distinctTargets=true,toggleAndLimit=true,snapshotInvalidation=true,
        singleAndMultiShotRisk=true,noCommandsSent=true,gameplayResourcesUnchanged=true,playMode=false};
}
finally
{
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Selection validation changed the user's scene");
return result;
