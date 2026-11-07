// Run only after the coordinated compilation and AnatomyBattleHUDAssets.Sync.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
object result;
try
{
    System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.Exception(message);};
    var root=new UnityEngine.GameObject("Anatomy input validation");root.SetActive(false);
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var demo=root.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
    var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
    var type=typeof(ProjectY.Samples.AdventureRuntimeDemo);
    var actor=new ProjectY.Samples.AdventureViewData.Actor {Id=1,Team=1,Alive=true,Name="Actor",OccupiedCells=new[]{0}};
    var target=new ProjectY.Samples.AdventureViewData.Actor {Id=2,Team=2,Alive=true,Name="Target",OccupiedCells=new[]{1}};
    var parts=new ProjectY.Samples.AdventureViewData.BodyPartChoice[6];
    for(int i=0;i<6;i++)parts[i]=new ProjectY.Samples.AdventureViewData.BodyPartChoice {Id=i,Name="Part "+i};
    var skill=new ProjectY.Samples.AdventureViewData.Skill {Id=2601,SelectBodyPart=true,Targets=new[]{2},
        TargetCells=System.Array.Empty<int>(),ContainerTargets=System.Array.Empty<int>(),TargetPreviews=System.Array.Empty<ProjectY.Samples.AdventureViewData.TargetPreview>(),
        BodyPartOptions=new[]{new ProjectY.Samples.AdventureViewData.BodyPartOption {TargetId=2,Parts=parts}}};
    var view=new ProjectY.Samples.AdventureViewData {Phase="battle",BattlePhase="combat",Round=1,ActiveId=1,Units=new[]{actor,target},
        Skills=new[]{skill},Reachable=System.Array.Empty<ProjectY.Samples.AdventureViewData.Cell>()};
    type.GetField("view",flags).SetValue(demo,view);demo.SelectBattleSkill(2601);
    check(ProjectY.Samples.BattleTargetSelection.Active(demo) && ProjectY.Samples.BattleTargetSelection.NeedsBodyPart(demo),"Precision selection must reserve the command flow");
    check(!ProjectY.Samples.BattleTargetSelection.ChoosingBodyPart(demo),"Selecting a skill must wait for a target");
    ProjectY.Samples.BattleTargetSelection.Confirm(demo);
    check(type.GetField("fatalError",flags).GetValue(demo)==null,"Enter must not submit a targetless precision attack");
    ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    check(ProjectY.Samples.BattleTargetSelection.ChoosingBodyPart(demo) && ProjectY.Samples.BattleTargetSelection.Count(demo)==1,"Target click must open body choices");
    for(int i=0;i<6;i++)check(ProjectY.Samples.BattleTargetSelection.BodyPartName(demo,i)=="Part "+i,"Body index must preserve its configured name");
    ProjectY.Samples.BattleTargetSelection.Confirm(demo);
    check(type.GetField("fatalError",flags).GetValue(demo)==null,"Enter must not bypass body selection");
    ProjectY.Samples.BattleTargetSelection.ChooseBodyPart(demo,99);
    check(!string.IsNullOrEmpty(view.Error) && type.GetField("fatalError",flags).GetValue(demo)==null,"Invalid part must reject without issuing gameplay commands");
    ProjectY.Samples.BattleTargetSelection.Cancel(demo);
    check(demo.SelectedBattleSkill==0 && ProjectY.Samples.BattleTargetSelection.Count(demo)==0,"Cancel must clear temporary target/body state");
    demo.SelectBattleSkill(2601);ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    var next=new ProjectY.Samples.AdventureViewData {Phase="battle",BattlePhase="combat",Round=2,ActiveId=1,Units=view.Units,Skills=view.Skills,Reachable=view.Reachable};
    type.GetMethod("SyncBattleTargets",flags).Invoke(demo,new object[]{view,next});
    check(demo.SelectedBattleSkill==0 && !ProjectY.Samples.BattleTargetSelection.ChoosingBodyPart(demo),"Round changes must discard the previous body target");
    demo.SelectBattleSkill(2601);ProjectY.Samples.BattleTargetSelection.Toggle(demo,2);
    skill.Targets=System.Array.Empty<int>();
    type.GetMethod("SyncBattleTargets",flags).Invoke(demo,new object[]{view,view});
    check(demo.SelectedBattleSkill==0 && !ProjectY.Samples.BattleTargetSelection.ChoosingBodyPart(demo) && ProjectY.Samples.BattleTargetSelection.Count(demo)==0,"Invalidated targets must close the part selector");

    var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(config.Get("BattleHUD").PrefabPath);
    var instance=UnityEngine.Object.Instantiate(prefab,root.transform,false);
    var reference=instance.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
    var hud=(ProjectY.UI.BattleHUDView)reference.Get("HUD");hud.Prepare();
    var panel=(UnityEngine.RectTransform)reference.Get("AnatomyPanel");
    check(panel==hud.EditorLayout.Anatomy,"Layout and Lua binding must share the anatomy panel");
    for(int i=0;i<6;i++)
    {check(reference.Get("AnatomyPart"+i) is UnityEngine.UI.Button,"Each body choice requires a persisted Button");
     check(reference.Get("AnatomyPart"+i+"Text") is UnityEngine.UI.Text,"Each body choice requires a persisted caption");}
    foreach(float width in new[]{1280f,640f})
    {
        hud.EditorLayout.Root.sizeDelta=new UnityEngine.Vector2(width,720);panel.gameObject.SetActive(true);hud.PreviewLayout(width);
        check(!reference.Get("SkillControls").gameObject.activeSelf && !reference.Get("ItemControls").gameObject.activeSelf,"Resizing must keep normal controls hidden during body selection");
        check(panel.anchoredPosition.x>=0 && panel.anchoredPosition.y>=0 && panel.anchoredPosition.x+panel.rect.width<=hud.EditorLayout.Deck.rect.width+.1f,
            "Body selector must fit inside the skill deck");
        panel.gameObject.SetActive(false);hud.PreviewLayout(width);
        check(reference.Get("SkillControls").gameObject.activeSelf && reference.Get("ItemControls").gameObject.activeSelf,"Cancel must restore both control rows");
    }
    var mainPrefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(config.Get("MainHud").PrefabPath);
    var nested=mainPrefab.GetComponentInChildren<ProjectY.UI.BattleHUDView>(true);
    check(nested!=null && nested.EditorLayout.Anatomy!=null,"MainHud must inherit the upgraded BattleHUD selector");
    nested.GetComponent<ProjectY.UI.LuaReference>().ValidateBindings();
    result=new {passed=true,targetThenBody=true,noPrematureCommand=true,cancelAndInvalidation=true,sixPersistedButtons=true,narrowLayout=true,mainHudInherited=true,playMode=false};
}
finally {UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Anatomy validation changed the user's active scene");
return result;
