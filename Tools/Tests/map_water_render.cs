// Unity MCP execute_code body; run once after the authorized C# compilation, in Edit Mode.
// Uses only a temporary preview scene. No source assets or user scenes are saved.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
const bool captureMotion = false;
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalScenes = new System.Collections.Generic.List<UnityEngine.SceneManagement.Scene>();
var originalDirty = new System.Collections.Generic.List<bool>();
var originalRoots = new System.Collections.Generic.List<int[]>();
for (int i = 0; i < UnityEngine.SceneManagement.SceneManager.sceneCount; i++)
{
    var existing = UnityEngine.SceneManagement.SceneManager.GetSceneAt(i);
    originalScenes.Add(existing); originalDirty.Add(existing.isDirty);
    originalRoots.Add(existing.GetRootGameObjects().Select(value => value.GetInstanceID()).ToArray());
}
var originalPipeline = QualitySettings.renderPipeline;
var previousTarget = RenderTexture.active;
var manager = UnityEngine.Rendering.VolumeManager.instance;
var previousStack = manager.stack; var stack = manager.CreateStack();
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var owned = new System.Collections.Generic.List<UnityEngine.Object>();
var errors = new System.Collections.Generic.List<string>();
Application.LogCallback log = (message, trace, type) => { if (type == LogType.Error || type == LogType.Exception) errors.Add(message); };
Application.logMessageReceived += log;
ProjectY.Samples.MapPreviewRenderer renderer = null;
RenderTexture target = null; Texture2D image = null; Camera camera = null;
int particles = 0, waterInstances = 0, pixelCoverage = 0, fallingParticles = 0, risingParticles = 0;
int motionChangedPixels = 0;
string output = "Docs/Previews/Rendering/map-water-flow.png";
System.Action<bool, string> check = (condition, message) => { if (!condition) throw new System.Exception(message); };
System.Func<object, string, object> field = (owner, name) => owner.GetType().GetField(name,
    System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic).GetValue(owner);
try
{
    manager.stack = stack;
    var host = new GameObject("Map Water Validation");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var cameraObject = new GameObject("Camera"); cameraObject.transform.SetParent(host.transform, false);
    camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic = true; camera.orthographicSize = 6.1f; camera.aspect = 1.6f;
    camera.nearClipPlane = .1f; camera.farClipPlane = 80;
    camera.transform.position = new Vector3(10, 13, -15); camera.transform.LookAt(new Vector3(-.3f, .5f, .8f));
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.10f, .14f, .18f);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var lightObject = new GameObject("Sun"); lightObject.transform.SetParent(host.transform, false);
    var sun = lightObject.AddComponent<Light>(); sun.type = LightType.Directional; sun.intensity = 1.55f;
    sun.color = new Color(1, .94f, .85f); sun.transform.rotation = Quaternion.Euler(48, -35, 0);
    int width = captureMotion ? 768 : 1280, height = captureMotion ? 480 : 800;
    target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
    target.Create(); camera.targetTexture = target;
    image = new Texture2D(width, height, TextureFormat.RGB24, false);

    // Production asset definitions and imported FBX meshes; the fixture changes layout only.
    var rows = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapAssetTable.json"))["rows"];
    var assets = new System.Collections.Generic.List<ProjectY.Samples.MapPreviewData.Asset>();
    foreach (string name in new[] { "Hex_Riverbed", "Hex_Shore", "Hex_Water" })
    {
        var row = rows.Single(value => (string)value["name"] == name);
        assets.Add(new ProjectY.Samples.MapPreviewData.Asset { Id = (int)row["id"], Path = (string)row["prefabPath"],
            TintMaterial = (string)row["tintMaterial"], ReferenceHeight = (float)row["referenceHeight"] });
    }
    var axial = new[] { new Vector2Int(-2, 0), new Vector2Int(-1, 0), new Vector2Int(-2, 1),
        new Vector2Int(0, 0), new Vector2Int(1, 0), new Vector2Int(0, 1), new Vector2Int(1, -1), new Vector2Int(1, 1),
        new Vector2Int(-3, 0), new Vector2Int(-3, 1), new Vector2Int(-2, -1), new Vector2Int(-1, -1),
        new Vector2Int(0, -1), new Vector2Int(2, -1), new Vector2Int(2, 0), new Vector2Int(2, 1),
        new Vector2Int(1, 2), new Vector2Int(0, 2), new Vector2Int(-1, 2), new Vector2Int(-1, 1) };
    var cells = new ProjectY.Samples.MapPreviewData.Cell[axial.Length];
    for (int i = 0; i < cells.Length; i++)
    {
        bool wet = i < 8, river = i < 3; var coordinate = axial[i];
        float ground = river ? 1.1f : wet ? 0 : coordinate.x <= -1 ? 1.8f : .92f;
        var neighbors = new System.Collections.Generic.List<int>();
        for (int j = 0; j < axial.Length; j++)
        {
            var delta = axial[j] - coordinate;
            if (Mathf.Max(Mathf.Abs(delta.x), Mathf.Abs(delta.y), Mathf.Abs(delta.x + delta.y)) == 1) neighbors.Add(j);
        }
        cells[i] = new ProjectY.Samples.MapPreviewData.Cell {
            Position = new Vector3(Mathf.Sqrt(3) * (coordinate.x + coordinate.y * .5f), ground, coordinate.y * 1.5f),
            Color = new Color(.44f, .53f, .35f), HasWater = wet, IsRiver = river,
            WaterLevel = river ? 1.6f : wet ? .7f : 0, WaterDepth = river ? .5f : wet ? .7f : 0,
            RiverId = river || i == 3 ? 7 : 0, FlowTo = i == 0 ? 1 : i == 1 ? 3 : i == 3 ? 4 : -1,
            TerrainAssetId = river ? assets[0].Id : assets[1].Id, WaterAssetId = assets[2].Id, Neighbors = neighbors.ToArray() };
    }
    var map = new ProjectY.Samples.MapPreviewData { Radius = 1, Seed = 173, GenerationVersion = 5, RegionCount = 2, RiverCount = 1,
        Cells = cells, Assets = assets.ToArray(), Towns = System.Array.Empty<ProjectY.Samples.MapPreviewData.Town>(),
        Buildings = System.Array.Empty<ProjectY.Samples.MapPreviewData.Building>(), Roads = System.Array.Empty<ProjectY.Samples.MapPreviewData.Road>(),
        Decorations = System.Array.Empty<ProjectY.Samples.MapPreviewData.Decoration>(),
        // 普通水位落差即使没有瀑布标签，也必须获得弧形水幕、白沫和撞水粒子。
        Waterfalls = System.Array.Empty<ProjectY.Samples.MapPreviewData.Waterfall>() };
    var groundShader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    var waterShader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Resources/MapWater.shader");
    check(groundShader != null && waterShader != null, "Production shaders missing");
    check(!UnityEditor.ShaderUtil.ShaderHasError(waterShader), "Water shader has compiler errors");
    renderer = new ProjectY.Samples.MapPreviewRenderer(groundShader, host.transform);
    System.Func<ProjectY.Samples.MapPreviewData.Asset, GameObject> resolve = asset => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path);
    renderer.Build(map, resolve);
    var effects = (ProjectY.Samples.MapWaterEffects)field(renderer, "waterEffects");
    var splash = (ParticleSystem)field(effects, "splashes");
    check(effects.Flows.Length == cells.Length, "Flow array differs from cell count");
    for (int i = 0; i < 3; i++)
        check(Vector2.Distance(new Vector2(effects.Flows[i].x, effects.Flows[i].y), Vector2.right) < .001f && effects.Flows[i].z == 1,
            "River centerline direction did not propagate to the widened bank");
    for (int i = 3; i < 8; i++) check(effects.Flows[i].z == 0, "Lake inherited river mode");
    check(Mathf.Abs(effects.Flows[0].w - .5f) < .001f && Mathf.Abs(effects.Flows[3].w - .7f) < .001f, "Water depth lost at renderer boundary");
    foreach (string name in new[] { "material", "roadMaterial", "roadObject", "waterEdges" }) owned.Add((UnityEngine.Object)field(renderer, name));
    owned.Add(effects.SurfaceMaterial); owned.Add(effects.FoamMaterial);
    foreach (string name in new[] { "flowTexture", "splashObject", "splashMaterial" }) owned.Add((UnityEngine.Object)field(effects, name));
    var replaced = new System.Collections.Generic.List<UnityEngine.Object> { (Mesh)field(renderer, "roadMesh"), (Mesh)field(renderer, "waterMesh") };
    foreach (Material value in (System.Collections.IEnumerable)field(renderer, "waterMaterials")) replaced.Add(value);
    renderer.Build(map, resolve);
    check(host.GetComponentsInChildren<ParticleSystem>(true).Length == 1 && (ParticleSystem)field(effects, "splashes") == splash,
        "Rebuilding duplicated the splash system");
    foreach (var value in replaced) check(value == null, "Rebuilding leaked an old water/road resource");
    owned.Add((Mesh)field(renderer, "roadMesh")); owned.Add((Mesh)field(renderer, "waterMesh"));
    foreach (Material value in (System.Collections.IEnumerable)field(renderer, "waterMaterials")) owned.Add(value);
    var curtainMesh = (Mesh)field(renderer, "waterMesh");
    check(curtainMesh.GetIndexCount(curtainMesh.subMeshCount - 1) > 0, "Untagged water drops have no crest/impact foam");
    foreach (var normal in curtainMesh.normals) check(Mathf.Abs(normal.magnitude - 1) < .002f, "Invalid smoothed curtain normal");

    // EditMode preview scenes do not reliably submit DrawMeshInstanced. Reflect the actual
    // built batches into temporary renderers, preserving their meshes, per-instance colors and flow.
    var proxies = new GameObject("Batch render proxies"); proxies.transform.SetParent(host.transform, false);
    var batches = ((System.Collections.IEnumerable)field(renderer, "batches")).Cast<object>().ToArray();
    foreach (object batch in batches)
    {
        if ((int)field(batch, "Submesh") != 0) continue;
        var source = (Mesh)field(batch, "Mesh"); int count = (int)field(batch, "Count");
        var kind = (ProjectY.Samples.MapPreviewRenderer.Kind)field(batch, "Kind");
        bool water = kind == ProjectY.Samples.MapPreviewRenderer.Kind.Water;
        var matrices = (Matrix4x4[])field(batch, "Matrices");
        var materials = new Material[source.subMeshCount]; var slots = new object[source.subMeshCount];
        for (int slot = 0; slot < slots.Length; slot++)
        {
            slots[slot] = batches.Single(value => (Mesh)field(value, "Mesh") == source
                && (ProjectY.Samples.MapPreviewRenderer.Kind)field(value, "Kind") == kind && (int)field(value, "Submesh") == slot);
            check((int)field(slots[slot], "Count") == count, "Submesh instance counts differ");
            materials[slot] = water ? effects.SurfaceMaterial : (Material)field(renderer, "material");
        }
        for (int i = 0; i < count; i++)
        {
            var proxy = new GameObject(water ? "Water batch instance" : "Terrain batch instance", typeof(MeshFilter), typeof(MeshRenderer));
            proxy.transform.SetParent(proxies.transform, false);
            proxy.transform.SetPositionAndRotation(matrices[i].GetColumn(3), matrices[i].rotation); proxy.transform.localScale = matrices[i].lossyScale;
            // Imported FBX meshes need not be CPU-readable; use the original mesh without reading indices.
            proxy.GetComponent<MeshFilter>().sharedMesh = source;
            var view = proxy.GetComponent<MeshRenderer>(); view.sharedMaterials = materials;
            view.shadowCastingMode = water ? UnityEngine.Rendering.ShadowCastingMode.Off : UnityEngine.Rendering.ShadowCastingMode.On;
            for (int slot = 0; slot < slots.Length; slot++)
            {
                var colors = (Vector4[])field(slots[slot], "Colors"); var flows = (Vector4[])field(slots[slot], "WaterFlows");
                var properties = new MaterialPropertyBlock(); properties.SetVector("_Color", colors[i]);
                if (water) properties.SetVector("_WaterFlow", flows[i]);
                view.SetPropertyBlock(properties, slot);
            }
            if (water) waterInstances++;
        }
    }
    check(waterInstances >= 8, "Production Build omitted water instances");
    renderer.SetVisible(true);
    for (int i = 0; i < 30; i++) { splash.Simulate(.05f, false, false, true); effects.Tick(camera, .05f); }
    particles = splash.particleCount; check(particles > 0, "No splash particles emitted in the visible fixture");
    var liveParticles = new ParticleSystem.Particle[splash.main.maxParticles];
    int liveCount = splash.GetParticles(liveParticles);
    for (int i = 0; i < liveCount; i++)
    {
        if (liveParticles[i].velocity.y < -1) fallingParticles++;
        if (liveParticles[i].velocity.y > .5f) risingParticles++;
    }
    check(fallingParticles > 0 && risingParticles > 0, "Water drop lacks downward impact or upward splash");
    Color32[] firstFrame = null;
    if (captureMotion) System.IO.Directory.CreateDirectory("Temp/CodexWaterMotion20261003");
    for (int frame = 0; frame < (captureMotion ? 60 : 1); frame++)
    {
        // 只覆盖本次预览的克隆材质时间；游戏运行默认仍使用 _Time，不改全局 Shader 时间。
        float previewTime = 37 + frame / 12f;
        effects.SurfaceMaterial.SetFloat("_WaterPreviewTime", previewTime);
        effects.FoamMaterial.SetFloat("_WaterPreviewTime", previewTime);
        foreach (Material value in (System.Collections.IEnumerable)field(renderer, "waterMaterials")) value.SetFloat("_WaterPreviewTime", previewTime);
        manager.Update(stack, camera.transform, 0);
        ProjectY.Rendering.UrpCameraRendering.Render(camera);
        RenderTexture.active = target; image.ReadPixels(new Rect(0, 0, width, height), 0, 0); image.Apply();
        if (frame == 0) firstFrame = image.GetPixels32();
        if (captureMotion) System.IO.File.WriteAllBytes("Temp/CodexWaterMotion20261003/frame-" + frame.ToString("D3") + ".png", image.EncodeToPNG());
        if (frame + 1 < 60 && captureMotion) { splash.Simulate(1f / 12, false, false, true); effects.Tick(camera, 1f / 12); }
    }
    var pixels = image.GetPixels32(); var background = pixels[0]; int pink = 0;
    foreach (var pixel in pixels)
    {
        if (pixel.r > 225 && pixel.b > 225 && pixel.g < 30) pink++;
        if (Mathf.Abs(pixel.r - background.r) + Mathf.Abs(pixel.g - background.g) + Mathf.Abs(pixel.b - background.b) > 24) pixelCoverage++;
    }
    if (captureMotion)
    {
        for (int i = 0; i < pixels.Length; i++)
            if (Mathf.Abs(pixels[i].r - firstFrame[i].r) + Mathf.Abs(pixels[i].g - firstFrame[i].g) + Mathf.Abs(pixels[i].b - firstFrame[i].b) > 8) motionChangedPixels++;
        check(motionChangedPixels > 1000, "Water motion did not visibly evolve");
    }
    check(pink < 30 && pixelCoverage > 10000, "Preview is empty or contains shader-error pink");
    System.IO.Directory.CreateDirectory("Docs/Previews/Rendering"); System.IO.File.WriteAllBytes(output, image.EncodeToPNG());

    renderer.Draw(camera, false, false, false, false);
    check(!splash.gameObject.activeSelf && splash.particleCount == 0 && !((GameObject)field(renderer, "waterEdges")).activeSelf,
        "Disabling water did not hide and clear water effects");
    renderer.SetVisible(true);
    for (int i = 0; i < 10; i++) effects.Tick(camera, .05f);
    check(splash.particleCount > 0, "Splash system did not resume after water was enabled");
    renderer.SetVisible(false);
    check(!splash.gameObject.activeSelf && splash.particleCount == 0, "SetVisible(false) retained hidden particles");
    UnityEngine.Object.DestroyImmediate(proxies);
    renderer.Dispose(); renderer = null;
    foreach (var value in owned) check(value == null, "Dispose leaked an owned runtime resource");
    check(effects.Flows.Length == 0 && host.GetComponentsInChildren<ParticleSystem>(true).Length == 0, "Dispose retained flow or particle state");
    check(!UnityEditor.ShaderUtil.ShaderHasError(waterShader) && !UnityEditor.ShaderUtil.ShaderHasError(groundShader), "Shader compiler errors after rendering");
    check(errors.Count == 0, "Render errors: " + string.Join("; ", errors.ToArray()));
}
finally
{
    if (renderer != null) renderer.Dispose();
    if (camera != null) camera.targetTexture = null;
    RenderTexture.active = previousTarget;
    manager.stack = previousStack; manager.DestroyStack(stack);
    if (image != null) UnityEngine.Object.DestroyImmediate(image);
    if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    Application.logMessageReceived -= log;
    check(QualitySettings.renderPipeline == originalPipeline && UnityEngine.SceneManagement.SceneManager.GetActiveScene() == originalScene,
        "Preview changed pipeline or active scene");
    check(UnityEngine.SceneManagement.SceneManager.sceneCount == originalScenes.Count, "Preview changed the open scene set");
    for (int i = 0; i < originalScenes.Count; i++)
        check(originalScenes[i].isDirty == originalDirty[i] && originalScenes[i].GetRootGameObjects().Select(value => value.GetInstanceID()).SequenceEqual(originalRoots[i]),
            "Preview changed an existing scene or its dirty state");
}
check(errors.Count == 0, "Render/cleanup errors: " + string.Join("; ", errors.ToArray()));
return new { output, waterInstances, particles, fallingParticles, risingParticles, pixelCoverage, flowPropagation = true, lakeMode = true,
    motionFrames = captureMotion ? 60 : 1, motionChangedPixels,
    untaggedDropFoam = true, curtainNormals = true,
    hiddenParticlesCleared = true, rebuildReusesSystem = true, disposed = true, stateRestored = true, playMode = false };
