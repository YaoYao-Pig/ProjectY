// Execute through Unity MCP in the existing idle Editor after the shared compilation.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.AreaCombatRenderer renderer=null;
UnityEngine.RenderTexture target=null;
UnityEngine.Texture2D pixels=null;
var originalTarget=UnityEngine.RenderTexture.active;
object result;
try
{
    System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.Exception(message);};
    var root=new UnityEngine.GameObject("Skill range isolated validation");
    root.SetActive(false);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var demo=root.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
    var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
    var type=typeof(ProjectY.Samples.AdventureRuntimeDemo);
    var actor=new ProjectY.Samples.AdventureViewData.Actor {Id=1,Team=1,Alive=true,OccupiedCells=new[]{0}};
    var skill=new ProjectY.Samples.AdventureViewData.Skill {Id=3,Targets=new[]{2},TargetCells=new[]{4},ContainerTargets=new[]{9},
        ImpactAreas=new[]{
            new ProjectY.Samples.AdventureViewData.ImpactArea {TargetId=2,CellIndex=1,Cells=new[]{2,3}},
            new ProjectY.Samples.AdventureViewData.ImpactArea {CellIndex=3,Cells=new[]{4,5,6}},
            new ProjectY.Samples.AdventureViewData.ImpactArea {ContainerId=9,CellIndex=4,Cells=new[]{5,6}}}};
    var view=new ProjectY.Samples.AdventureViewData {Phase="battle",BattlePhase="combat",Round=1,ActiveId=1,Units=new[]{actor},
        Skills=new[]{skill},Reachable=System.Array.Empty<ProjectY.Samples.AdventureViewData.Cell>()};
    type.GetField("view",flags).SetValue(demo,view);demo.SelectBattleSkill(3);
    var impact=type.GetProperty("BattleImpactCells",flags);
    System.Func<int[]> cells=()=>(int[])impact.GetValue(demo);
    type.GetMethod("SetBattleTargetHover",flags).Invoke(demo,new object[]{2});
    check(cells().Length==2 && cells()[0]==2,"Actor hover must use the supplied impact cells");
    type.GetMethod("ClearBattleHover",flags).Invoke(demo,null);
    check(cells().Length==0,"Moving over UI must clear impact cells");
    type.GetMethod("SetBattleCellHover",flags).Invoke(demo,new object[]{new ProjectY.Samples.AdventureViewData.Cell {CellIndex=3}});
    check(cells().Length==3,"Ground hover must use zero-based selection and one-based snapshot cells");
    type.GetMethod("ClearBattleHover",flags).Invoke(demo,null);
    type.GetField("hoveredBattleContainer",flags).SetValue(demo,9);
    check(cells().Length==2 && cells()[0]==5,"Container hover must use its resolved impact center");
    type.GetMethod("CancelBattleSkillSelection",flags).Invoke(demo,null);check(cells().Length==0,"Cancel must clear the preview");
    demo.SelectBattleSkill(3);type.GetMethod("SetBattleTargetHover",flags).Invoke(demo,new object[]{2});
    var next=new ProjectY.Samples.AdventureViewData {Phase="battle",BattlePhase="combat",Round=2,ActiveId=1,Units=new[]{actor},Skills=new[]{skill},Reachable=view.Reachable};
    type.GetMethod("SyncBattleTargets",flags).Invoke(demo,new object[]{view,next});
    check(cells().Length==0,"New rounds must invalidate the impact preview");
    check(type.GetField("fatalError",flags).GetValue(demo)==null,"Preview selection sent a gameplay command");

    var shader=UnityEngine.Resources.Load<UnityEngine.Shader>("Rendering/SkillRange");
    check(shader!=null && shader.isSupported && !UnityEditor.ShaderUtil.ShaderHasError(shader),"Skill range shader must compile");
    renderer=new ProjectY.Samples.AreaCombatRenderer(root.transform,null,shader,null);
    var renderType=typeof(ProjectY.Samples.AreaCombatRenderer);
    var mesh=(UnityEngine.Mesh)renderType.GetField("highlight",flags).GetValue(renderer);
    var material=(UnityEngine.Material)renderType.GetField("highlightMaterial",flags).GetValue(renderer);
    var host=new UnityEngine.GameObject("Range shader sample");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    host.AddComponent<UnityEngine.MeshFilter>().sharedMesh=mesh;
    host.AddComponent<UnityEngine.MeshRenderer>().sharedMaterial=material;
    var cameraObject=new UnityEngine.GameObject("Range validation camera");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera=cameraObject.AddComponent<UnityEngine.Camera>();camera.enabled=false;camera.scene=scene;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true;camera.orthographicSize=1.4f;camera.aspect=1;
    camera.transform.position=new UnityEngine.Vector3(0,5,0);camera.transform.rotation=UnityEngine.Quaternion.Euler(90,0,0);
    camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=UnityEngine.Color.black;
    target=new UnityEngine.RenderTexture(256,256,24,UnityEngine.RenderTextureFormat.ARGBHalf);target.Create();camera.targetTexture=target;
    camera.Render();UnityEngine.RenderTexture.active=target;
    pixels=new UnityEngine.Texture2D(256,256,UnityEngine.TextureFormat.RGBAFloat,false,true);
    pixels.ReadPixels(new UnityEngine.Rect(0,0,256,256),0,0);pixels.Apply();
    float fill=pixels.GetPixel(128,128).maxColorComponent;
    float edge=pixels.GetPixel(200,128).maxColorComponent;
    float halo=pixels.GetPixel(207,128).maxColorComponent;
    check(fill>.03f && edge>fill*2 && halo>.003f,"The rendered grid must contain a fill, bright edge and visible halo");
    result=new {passed=true,actorGroundContainerHover=true,cancelAndRoundCleanup=true,shaderRendered=true,fill=fill,edge=edge,halo=halo,playMode=false};
}
finally
{
    UnityEngine.RenderTexture.active=originalTarget;
    if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
    if(renderer!=null)renderer.Dispose();
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Skill range validation changed the user's scene");
return result;
