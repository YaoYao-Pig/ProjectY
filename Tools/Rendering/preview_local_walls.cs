// Prefix with string previewArea = "interior" / "tavern"; string previewLabel = "after";
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
int assetId = previewArea=="tavern" ? 64 : 66;
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
if(previewArea=="tavern") { state.CellIndex=Enumerable.Range(0,layout.Cells.Length).Where(i=>!layout.Cells[i].Blocked && layout.Cells[i].InteriorId==0).OrderBy(i=>(layout.Cells[i].Position-focalProp.Position).sqrMagnitude).First();state.Members[0].CellIndex=state.CellIndex; }
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
    camera.orthographic=true; camera.orthographicSize=3.4f;
    camera.aspect=1.6f; camera.nearClipPlane=.1f; camera.farClipPlane=500;
    var propMatrix=Matrix4x4.TRS(focalProp.Position,Quaternion.Euler(0,focalProp.Rotation,0),focalProp.Scale3);
    var focus=propMatrix.MultiplyPoint3x4(previewArea=="tavern" ? new Vector3(0,2.1f,3.55f) : new Vector3(-4.4f,.65f,-3.55f));
    var rotation=Quaternion.Euler(previewArea=="tavern" ? 12 : 24,focalProp.Rotation+180,0);
    camera.transform.SetPositionAndRotation(focus-rotation*Vector3.forward*180,rotation);
    var sun=new GameObject("Review Sun").AddComponent<Light>();sun.transform.SetParent(host.transform,false);sun.type=LightType.Directional;
    environment=new ProjectY.Samples.MapEnvironmentController(lighting,sun,camera,host.transform);
    environment.SetArea(layout);environment.Running=false;environment.Hour=previewArea=="tavern" ? 16 : 19;
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
        System.IO.File.WriteAllBytes("Docs/Previews/Rendering/local-wall-"+previewArea+"-"+label+".png",output.EncodeToPNG());return values;
    };
    capture(previewLabel); return new { previewArea, previewLabel, wallCheck=true };
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

