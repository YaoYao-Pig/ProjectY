// Prefix with string previewArea = "dungeon"; string previewLabel = "after";
// Actual renderer, isolated PreviewScene, HDR -> sRGB. Never enters Play or saves the open scene.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
ProjectY.Samples.MapAreaViewData layout;
ProjectY.Samples.MapEnvironmentData lighting;
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null);
    var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
    lua.AddLoader(loader.Load); lua.Global.Set("Services",services); lua.Global.Set("PreviewArea",previewArea);
    try
    {
        var rows = lua.DoString(System.IO.File.ReadAllText("Tools/Rendering/preview_local_surfaces.lua"));
        using (var row=(XLua.LuaTable)rows[0]) layout=ProjectY.Samples.MapAreaViewData.Read(row);
        using (var row=(XLua.LuaTable)rows[1]) lighting=ProjectY.Samples.MapEnvironmentData.Read(row);
    }
    finally { lua.Global.Set<string,object>("Services",null); services.Player.ClearListeners(); }
}
int assetId = previewArea=="dungeon" ? 25 : previewArea=="mine" ? 901 : previewArea=="tavern" ? 64 : 66;
var focalProp=layout.Props.First(p=>p.AssetId==assetId && (previewArea!="dungeon" ||
    layout.Surfaces[layout.Cells[p.Cells[0]].SurfaceId].Pattern.x!=5));
int cellIndex=Enumerable.Range(0,layout.Cells.Length).Where(i=>!layout.Cells[i].Blocked &&
    (focalProp.InteriorId==0 || layout.Cells[i].InteriorId==focalProp.InteriorId) &&
    (focalProp.Layer<0 || layout.Cells[i].Layer==focalProp.Layer))
    .OrderBy(i=>(layout.Cells[i].Position-focalProp.Position).sqrMagnitude).First();
var state=new ProjectY.Samples.MapAreaViewData.State {
    CellIndex=cellIndex,Revision=1,Known=Enumerable.Range(0,layout.Cells.Length).ToArray(),Visible=Enumerable.Range(0,layout.Cells.Length).ToArray(),
    Members=new [] {new ProjectY.Samples.MapAreaViewData.Member {CellIndex=cellIndex}}
};
var sceneBefore=UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool dirtyBefore=sceneBefore.isDirty;
var pipelineBefore=QualitySettings.renderPipeline; var targetBefore=RenderTexture.active;
var skyBefore=RenderSettings.skybox; var ambientBefore=RenderSettings.ambientSkyColor;
var fogBefore=RenderSettings.fog; var sunBefore=RenderSettings.sun;
var manager=UnityEngine.Rendering.VolumeManager.instance; var stackBefore=manager.stack; var stack=manager.CreateStack(); manager.stack=stack;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapEnvironmentController environment=null;
ProjectY.Samples.MapAreaRenderer renderer=null;
Camera camera=null; RenderTexture target=null; Texture2D pixels=null; Texture2D output=null;
var settings=ProjectY.Samples.MapAreaPresentationSettings.Load(); int shadowBudget=settings.shadowLightBudget;
try
{
    var host=new GameObject("Local Surface Review"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    camera=new GameObject("Review Camera").AddComponent<Camera>(); camera.transform.SetParent(host.transform,false); camera.enabled=false;
    camera.scene=scene; camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true; camera.orthographicSize=3.3f;
    camera.aspect=1.6f; camera.nearClipPlane=.1f; camera.farClipPlane=500;
    var wall=layout.Cells.Where(c=>c.Kind=="wall").OrderBy(c=>(c.Position-focalProp.Position).sqrMagnitude).First();
    var focus=wall.Position+Vector3.up*(wall.WallHeight*.48f);
    var towardRoom=focalProp.Position-wall.Position;towardRoom.y=0;towardRoom.Normalize();
    var rotation=Quaternion.Euler(55,previewArea=="interior" || previewArea=="tavern" ? focalProp.Rotation+150 : 35,0);
    camera.transform.position=focus+towardRoom*10+Vector3.up*3;camera.transform.LookAt(focus);
    var sun=new GameObject("Review Sun").AddComponent<Light>();sun.transform.SetParent(host.transform,false);sun.type=LightType.Directional;
    environment=new ProjectY.Samples.MapEnvironmentController(lighting,sun,camera,host.transform);
    environment.SetArea(layout);environment.Running=false;environment.Hour=19;
    ProjectY.Rendering.FantasyPresentation.ApplyToActive(ProjectY.Rendering.WorldVisualStyle.MedievalFantasy);
    var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    if (UnityEditor.ShaderUtil.ShaderHasError(shader)) throw new System.Exception("Surface shader has errors");
    renderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(layout.AssetPath),layout,
        asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
    environment.Tick(3,state);environment.ApplyCameraFocus(focus);renderer.UpdateVisibility(state,true);
    target=new RenderTexture(1280,800,24,RenderTextureFormat.ARGBHalf,RenderTextureReadWrite.Linear);target.Create();camera.targetTexture=target;
    pixels=new Texture2D(1280,800,TextureFormat.RGBAFloat,false,true);output=new Texture2D(1280,800,TextureFormat.RGB24,false);
    Func<string,Color[]> capture=label=>{
        manager.Update(stack,camera.transform,1);renderer.Draw(camera);ProjectY.Rendering.UrpCameraRendering.Render(camera);
        RenderTexture.active=target;pixels.ReadPixels(new Rect(0,0,1280,800),0,0);pixels.Apply();var values=pixels.GetPixels();
        if(values.Any(c=>float.IsNaN(c.r)||float.IsInfinity(c.r)))throw new System.Exception("Invalid HDR pixels");
        output.SetPixels32(values.Select(c=>(Color32)c.gamma).ToArray());output.Apply();
        System.IO.File.WriteAllBytes("Docs/Previews/Rendering/local-wall-dungeon-"+label+".png",output.EncodeToPNG());return values;
    };
    capture(previewLabel); return new { previewArea, previewLabel, wallCheck=true,wallSurface=wall.SurfaceId,wallPattern=layout.Surfaces[wall.SurfaceId].Pattern.ToString() };
}
finally
{
    settings.shadowLightBudget=shadowBudget;
    if(camera!=null)camera.targetTexture=null;
    if(renderer!=null)renderer.Dispose();if(environment!=null)environment.Dispose();
    manager.stack=stackBefore;manager.DestroyStack(stack);RenderTexture.active=targetBefore;
    if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);if(output!=null)UnityEngine.Object.DestroyImmediate(output);
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=sceneBefore || sceneBefore.isDirty!=dirtyBefore ||
        QualitySettings.renderPipeline!=pipelineBefore || RenderSettings.skybox!=skyBefore || RenderSettings.ambientSkyColor!=ambientBefore ||
        RenderSettings.fog!=fogBefore || RenderSettings.sun!=sunBefore)throw new System.Exception("Preview did not restore state");
}
