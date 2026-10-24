// Unity MCP method body. One production MapArea view per call, without Play or saving the open scene.
// Prefix with string previewLabel / bool previewIndoor to capture a matching before/after pair.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
ProjectY.Samples.MapAreaViewData layout;
ProjectY.Samples.MapEnvironmentData lighting;
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null);
    var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
    lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
    try
    {
        var data = lua.DoString(System.IO.File.ReadAllText("Tools/Rendering/preview_daylight.lua"));
        using (var row = (XLua.LuaTable)data[0]) layout = ProjectY.Samples.MapAreaViewData.Read(row);
        using (var row = (XLua.LuaTable)data[1]) lighting = ProjectY.Samples.MapEnvironmentData.Read(row);
    }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalDirty = originalScene.isDirty;
var originalPipeline = QualitySettings.renderPipeline;
var originalTarget = RenderTexture.active;
var originalSkybox = RenderSettings.skybox;
var originalReflection = RenderSettings.reflectionIntensity;
var manager = UnityEngine.Rendering.VolumeManager.instance;
var previousStack = manager.stack; var stack = manager.CreateStack(); manager.stack = stack;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapAreaRenderer renderer = null;
ProjectY.Samples.MapEnvironmentController environment = null;
RenderTexture target = null; Texture2D pixels = null; Texture2D image = null;
try
{
    var host = new GameObject("Local lighting preview");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var camera = new GameObject("Camera").AddComponent<Camera>(); camera.transform.SetParent(host.transform, false);
    camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic = true; camera.nearClipPlane = .1f; camera.farClipPlane = 500; camera.aspect = 1.6f;
    var sun = new GameObject("Sun").AddComponent<Light>(); sun.transform.SetParent(host.transform, false);
    sun.type = LightType.Directional;
    environment = new ProjectY.Samples.MapEnvironmentController(lighting, sun, camera, host.transform);
    environment.SetArea(layout); environment.Running = false; environment.Hour = previewIndoor ? 19 : 12;
    ProjectY.Rendering.FantasyPresentation.ApplyToActive(ProjectY.Rendering.WorldVisualStyle.MedievalFantasy);
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    if (UnityEditor.ShaderUtil.ShaderHasError(shader)) throw new System.Exception("Map shader has errors");
    var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(layout.AssetPath);
    renderer = new ProjectY.Samples.MapAreaRenderer(shader, prefab, layout,
        asset => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
    var windmill = layout.Props.First(p => p.AssetId == 113);
    var interiorProp = layout.Props.First(p => p.InteriorId > 0 &&
        UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(layout.PropAssets.First(a => a.Id == p.AssetId).Path)
            .GetComponent<MeshRenderer>().sharedMaterials.Any(m => m.name.Contains("InteriorGlow")));
    int cellIndex = previewIndoor ? Array.FindIndex(layout.Cells, c => c.InteriorId == interiorProp.InteriorId && !c.Blocked) : 0;
    var state = new ProjectY.Samples.MapAreaViewData.State {
        CellIndex = cellIndex, Revision = 1, Known = Enumerable.Range(0, layout.Cells.Length).ToArray(),
        Visible = Enumerable.Range(0, layout.Cells.Length).ToArray(),
        Members = previewIndoor ? new [] { new ProjectY.Samples.MapAreaViewData.Member { CellIndex = cellIndex } }
            : new ProjectY.Samples.MapAreaViewData.Member[0]
    };
    var focus = previewIndoor ? interiorProp.Position + Vector3.up : windmill.Position + Vector3.up * 3;
    var rotation = Quaternion.Euler(previewIndoor ? 55 : 38, previewIndoor ? interiorProp.Rotation + 150 : windmill.Rotation + 160, 0);
    camera.orthographicSize = previewIndoor ? 11 : 16;
    camera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * 180, rotation);
    environment.Tick(3, state); environment.ApplyCameraFocus(focus);
    renderer.UpdateVisibility(state, true);
    target = new RenderTexture(1280, 800, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
    target.Create(); camera.targetTexture = target;
    pixels = new Texture2D(1280, 800, TextureFormat.RGBAFloat, false, true);
    image = new Texture2D(1280, 800, TextureFormat.RGB24, false);
    manager.Update(stack, camera.transform, 1);
    renderer.Draw(camera);
    ProjectY.Rendering.UrpCameraRendering.Render(camera);
    RenderTexture.active = target; pixels.ReadPixels(new Rect(0, 0, 1280, 800), 0, 0); pixels.Apply();
    var linear = pixels.GetPixels(); var encoded = new Color32[linear.Length];
    for (int i = 0; i < linear.Length; i++)
    {
        var c = linear[i];
        if (float.IsNaN(c.r) || float.IsInfinity(c.r) || c.r > .9f && c.b > .9f && c.g < .05f)
            throw new System.Exception("Invalid rendered pixel");
        encoded[i] = c.gamma;
    }
    image.SetPixels32(encoded); image.Apply();
    var path = "Docs/Previews/Rendering/local-lighting-" + (previewIndoor ? "interior-" : "village-") + previewLabel + ".png";
    System.IO.File.WriteAllBytes(path, image.EncodeToPNG());
    var capturedIndoor = environment.IndoorBlend; var capturedSun = sun.intensity;

    // Inspect the actual submitted material blocks: visible / remembered / unknown must not share live emission.
    var propBatches = (System.Collections.IEnumerable)typeof(ProjectY.Samples.MapAreaRenderer)
        .GetField("propBatches", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic).GetValue(renderer);
    Func<int> emissiveCount = () => {
        int count = 0;
        foreach (var batch in propBatches)
        {
            var type = batch.GetType();
            var size = (int)type.GetField("Count").GetValue(batch);
            var block = (MaterialPropertyBlock)type.GetField("Properties").GetValue(batch);
            var emissions = block.GetVectorArray("_EmissionColor");
            for (int i = 0; i < size; i++) if (emissions[i].x > 1) count++;
        }
        return count;
    };
    int visibleEmission = emissiveCount();
    if (visibleEmission == 0 && previewLabel != "before") throw new System.Exception("No HDR source light in production batches");
    state.Visible = new int[0]; state.Revision++;
    renderer.UpdateVisibility(state, false);
    if (emissiveCount() != 0) throw new System.Exception("Remembered props leak HDR emission");
    state.Known = new int[0]; state.Revision++;
    renderer.UpdateVisibility(state, false);
    foreach (var batch in propBatches)
        if ((int)batch.GetType().GetField("Count").GetValue(batch) != 0) throw new System.Exception("Unknown props are still drawn");
    // Pixel mode retains its original lighting recipe, and the daylight multiplier cannot brighten midnight.
    ProjectY.Rendering.FantasyPresentation.ApplyToActive(ProjectY.Rendering.WorldVisualStyle.PixelInk);
    environment.Hour = 12; environment.Tick(3, null);
    if (Mathf.Abs(sun.intensity - 1.1f) > .001f) throw new System.Exception("Fantasy gain leaked into pixel mode");
    ProjectY.Rendering.FantasyPresentation.ApplyToActive(ProjectY.Rendering.WorldVisualStyle.MedievalFantasy);
    environment.Hour = 0; environment.Tick(3, null);
    if (Mathf.Abs(sun.intensity - .22f) > .001f) throw new System.Exception("Daylight gain leaked into midnight");
    return new { path, productionInstancing = true, indoor = capturedIndoor, sun = capturedSun,
        meanBrightness = encoded.Average(p => (p.r + p.g + p.b) / 3.0), visibleEmission,
        rememberedEmissionSuppressed = true, unknownPropsHidden = true, pixelAndNightPreserved = true, playMode = false };
}
finally
{
    if (renderer != null) renderer.Dispose();
    if (environment != null) environment.Dispose();
    manager.stack = previousStack; manager.DestroyStack(stack);
    RenderTexture.active = originalTarget;
    if (pixels != null) UnityEngine.Object.DestroyImmediate(pixels);
    if (image != null) UnityEngine.Object.DestroyImmediate(image);
    if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != originalDirty ||
        QualitySettings.renderPipeline != originalPipeline || RenderSettings.skybox != originalSkybox ||
        Mathf.Abs(RenderSettings.reflectionIntensity - originalReflection) > .001f)
        throw new System.Exception("Preview did not restore scene/environment state");
}
