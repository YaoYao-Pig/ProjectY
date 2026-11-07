// Unity MCP execute_code method body; never import into Assets or run a project compilation.
// Config + Map only, real 2500-cell fixture, no Main/Adventure startup or player save access.
const bool verifyFix = true;
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Fog memory capture requires an idle Editor in Edit Mode.");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var originalDirty = originalScene.isDirty;
var originalPipeline = QualitySettings.renderPipeline; var originalTarget = RenderTexture.active;
var originalSun = RenderSettings.sun; var originalSkybox = RenderSettings.skybox;
var originalAmbientMode = RenderSettings.ambientMode; var originalAmbient = RenderSettings.ambientLight;
var originalAmbientIntensity = RenderSettings.ambientIntensity; var originalSky = RenderSettings.ambientSkyColor;
var originalEquator = RenderSettings.ambientEquatorColor; var originalGround = RenderSettings.ambientGroundColor;
var originalFog = RenderSettings.fog; var originalReflection = RenderSettings.reflectionIntensity;
var originalWeatherEnabled = Shader.GetGlobalFloat("_WorldWeatherEnabled");
var manager = UnityEngine.Rendering.VolumeManager.instance; var previousStack = manager.stack; var stack = manager.CreateStack();
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var errors = new System.Collections.Generic.List<string>(); var outputs = new System.Collections.Generic.List<string>();
Application.LogCallback log = (message, trace, kind) => { if (kind == LogType.Error || kind == LogType.Exception) errors.Add(message); };
Application.logMessageReceived += log;
System.Action<bool, string> check = (condition, message) => { if (!condition) throw new System.Exception(message); };
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
System.Func<object, string, object> field = (value, name) => value.GetType().GetField(name, flags).GetValue(value);
const int width = 1200, height = 800;
var folder = "Docs/Previews/WorldFogMemory/" + (verifyFix ? "after" : "before"); System.IO.Directory.CreateDirectory(folder);
RenderTexture target = null; Texture2D readback = null, image = null; GameObject owner = null;
object result = null;
try
{
    manager.stack = stack;
    ProjectY.Samples.MapPreviewData map;
    using (var lua = new XLua.LuaEnv())
    {
        var services = new ProjectY.FrameworkServices(null);
        var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
        try
        {
            var values = lua.DoString(@"
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
function FogMemoryShutdown() registry:Shutdown() end
registry:Start()
local world=registry:Get('Map'):GenerateSeeded(20261026,2500)
return require('Game.Map.MapRenderSnapshot')(world)
", "WorldFogMemoryFixture");
            using (var table = (XLua.LuaTable)values[0]) map = ProjectY.Samples.MapPreviewData.Read(table);
        }
        finally
        {
            using (var shutdown = lua.Global.Get<XLua.LuaFunction>("FogMemoryShutdown")) if (shutdown != null) shutdown.Call();
            lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners();
        }
    }
    check(map.Cells.Length >= 2500, "The real map fixture is incomplete.");
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    foreach (var candidate in new[] { shader, Resources.Load<Shader>("WorldFog"), Resources.Load<Shader>("MapGround"),
        Resources.Load<Shader>("MapWater"), Resources.Load<Shader>("MapNature") })
        check(candidate != null && candidate.isSupported && !UnityEditor.ShaderUtil.ShaderHasError(candidate), "A production map/fog shader has errors.");
    owner = new GameObject("Isolated world fog memory validation"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner, scene);
    var sun = new GameObject("Fixed weak sunlight").AddComponent<Light>(); sun.transform.SetParent(owner.transform, false);
    sun.type = LightType.Directional; sun.color = Color.white; sun.intensity = .18f; sun.shadows = LightShadows.None;
    sun.transform.rotation = Quaternion.Euler(48, -35, 0);
    RenderSettings.sun = sun; RenderSettings.skybox = null; RenderSettings.fog = false;
    RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
    RenderSettings.ambientLight = new Color(.012f, .014f, .018f); RenderSettings.ambientIntensity = 1;
    RenderSettings.reflectionIntensity = 0; Shader.SetGlobalFloat("_WorldWeatherEnabled", 0);
    target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear); target.Create();
    readback = new Texture2D(width, height, TextureFormat.RGBAFloat, false, true);
    image = new Texture2D(width, height, TextureFormat.RGB24, false);

    var bounds = new Bounds(map.Cells[0].Position, Vector3.zero);
    foreach (var cell in map.Cells) bounds.Encapsulate(cell.Position);
    var focus = bounds.center; float left = focus.x - bounds.size.x / 6, right = focus.x + bounds.size.x / 6;
    int farCell = 0; float farDistance = -1;
    for (int i = 0; i < map.Cells.Length; i++)
    {
        var d = map.Cells[i].Position - focus; float distance = d.x * d.x + d.z * d.z;
        if (distance > farDistance) { farDistance = distance; farCell = i; }
    }
    var knownMemory = new ProjectY.Data.WorldMapExplorationData(); knownMemory.Reset(map.Cells.Length);
    knownMemory.Reveal(System.Linq.Enumerable.Range(1, map.Cells.Length).ToArray());
    // Public Reveal deliberately rejects an empty set. Keep exactly one remote visible cell,
    // excluded from memory metrics; every cell is known, so the fixed overlay must still vanish everywhere.
    knownMemory.Reveal(new[] { farCell + 1 });
    var mixed = new ProjectY.Data.WorldMapExplorationData(); mixed.Reset(map.Cells.Length);
    var knownIndices = new System.Collections.Generic.List<int>(); var visibleIndices = new System.Collections.Generic.List<int>();
    for (int i = 0; i < map.Cells.Length; i++)
    {
        if (map.Cells[i].Position.x >= left) knownIndices.Add(i + 1);
        if (map.Cells[i].Position.x >= right) visibleIndices.Add(i + 1);
    }
    mixed.Reveal(knownIndices.ToArray()); mixed.Reveal(visibleIndices.ToArray());
    int memoryRevision = knownMemory.Revision, mixedRevision = mixed.Revision;
    var memoryPixels = new System.Collections.Generic.HashSet<int>();
    var unknownPixels = new System.Collections.Generic.HashSet<int>();
    var mixedMemoryPixels = new System.Collections.Generic.HashSet<int>();
    var visiblePixels = new System.Collections.Generic.HashSet<int>();
    System.Action<Camera> locateSamples = camera =>
    {
        for (int i = 0; i < map.Cells.Length; i++)
        {
            var cell = map.Cells[i]; if (i == farCell || cell.HasWater) continue;
            var point = camera.WorldToViewportPoint(cell.Position + Vector3.up * .02f);
            if (point.z <= 0 || point.x < .06f || point.x > .94f || point.y < .06f || point.y > .94f) continue;
            int px = Mathf.RoundToInt(point.x * width), py = Mathf.RoundToInt(point.y * height);
            System.Collections.Generic.HashSet<int> zone = null;
            if (cell.Position.x < left - map.Radius * 4) zone = unknownPixels;
            else if (cell.Position.x > left + map.Radius * 4 && cell.Position.x < right - map.Radius * 4) zone = mixedMemoryPixels;
            else if (cell.Position.x > right + map.Radius * 4) zone = visiblePixels;
            for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++)
            {
                int index = (py + y) * width + px + x; memoryPixels.Add(index); zone?.Add(index);
            }
        }
    };
    System.Func<string, ProjectY.Data.WorldMapExplorationData, bool, Color[]> capture = (name, exploration, fogVisible) =>
    {
        // Each case has a separate renderer and camera; DrawMesh submissions cannot accumulate across cases.
        var shot = new GameObject(name); shot.transform.SetParent(owner.transform, false);
        ProjectY.Samples.MapPreviewRenderer renderer = null; Camera camera = null;
        var resources = new System.Collections.Generic.List<UnityEngine.Object>();
        try
        {
            camera = new GameObject("Camera").AddComponent<Camera>(); camera.transform.SetParent(shot.transform, false);
            camera.enabled = false; camera.scene = scene; camera.targetTexture = target;
            camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
            camera.orthographic = true; camera.aspect = (float)width / height; camera.nearClipPlane = .1f; camera.farClipPlane = 2000;
            camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.012f, .014f, .018f);
            camera.orthographicSize = Mathf.Max(bounds.size.x / (2 * camera.aspect), bounds.size.z * .46f + bounds.size.y * .25f) * 1.08f;
            var rotation = Quaternion.Euler(55, 0, 0); camera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * 700, rotation);
            ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
            renderer = new ProjectY.Samples.MapPreviewRenderer(shader, shot.transform);
            renderer.Build(map, asset => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path)); renderer.SetExploration(exploration);
            var fog = field(renderer, "worldFog"); var fogMaterial = (Material)field(fog, "material");
            var fogRoot = (GameObject)field(fog, "root"); fogRoot.SetActive(fogVisible); fogMaterial.SetFloat("_FogPreviewTime", 7);
            // Scenic mountain clouds are independent of exploration and would obscure the terrain variance measurement.
            ((ProjectY.Samples.MapCloudRenderer)field(renderer, "cloudRenderer")).SetVisible(false);
            foreach (var nameOfField in new[] { "material", "mask", "mesh", "root" }) resources.Add((UnityEngine.Object)field(fog, nameOfField));
            foreach (var nameOfField in new[] { "material", "roadMaterial", "roadMesh", "waterMesh", "roadObject", "waterEdges" })
                resources.Add((UnityEngine.Object)field(renderer, nameOfField));
            if (memoryPixels.Count == 0) locateSamples(camera);
            renderer.Draw(camera, true, true, true, true);
            manager.Update(stack, camera.transform, 0); ProjectY.Rendering.UrpCameraRendering.Render(camera);
            RenderTexture.active = target; readback.ReadPixels(new Rect(0, 0, width, height), 0, 0); readback.Apply();
            var linear = readback.GetPixels(); var encoded = new Color32[linear.Length]; int pink = 0;
            for (int i = 0; i < linear.Length; i++)
            {
                encoded[i] = linear[i].gamma; var c = encoded[i]; if (c.r > 230 && c.b > 230 && c.g < 30) pink++;
            }
            check(pink < 20, "Capture contains missing-shader pixels: " + name);
            image.SetPixels32(encoded); image.Apply(); string path = folder + "/" + name + ".png";
            System.IO.File.WriteAllBytes(path, image.EncodeToPNG()); outputs.Add(path);
            return linear;
        }
        finally
        {
            if (camera != null) camera.targetTexture = null;
            renderer?.Dispose(); UnityEngine.Object.DestroyImmediate(shot);
            foreach (var resource in resources) check(resource == null, "Map/fog capture leaked an owned material, texture, mesh or object.");
        }
    };
    var memoryOn = capture("memory-fog-on", knownMemory, true);
    var memoryOff = capture("memory-fog-off", knownMemory, false);
    var mixedOn = capture("three-states-fog-on", mixed, true);
    var mixedOff = capture("three-states-fog-off", mixed, false);
    check(memoryPixels.Count > 500 && unknownPixels.Count > 100 && mixedMemoryPixels.Count > 100 && visiblePixels.Count > 100,
        "Insufficient real terrain samples for the three exploration states.");
    System.Func<Color[], Color[], System.Collections.Generic.IEnumerable<int>, double> difference = (a, b, indices) =>
    {
        double sum = 0; int count = 0;
        foreach (int i in indices) { sum += (Math.Abs(a[i].r - b[i].r) + Math.Abs(a[i].g - b[i].g) + Math.Abs(a[i].b - b[i].b)) / 3; count++; }
        return sum / count;
    };
    System.Func<Color[], System.Collections.Generic.IEnumerable<int>, double[]> statistics = (colors, indices) =>
    {
        double sum = 0, square = 0, chroma = 0; int count = 0;
        foreach (int i in indices)
        {
            var c = colors[i]; double luminance = c.r * .2126 + c.g * .7152 + c.b * .0722;
            sum += luminance; square += luminance * luminance; chroma += Math.Max(c.r, Math.Max(c.g, c.b)) - Math.Min(c.r, Math.Min(c.g, c.b)); count++;
        }
        return new[] { sum / count, Math.Sqrt(Math.Max(0, square / count - sum * sum / count / count)), chroma / count };
    };
    double rememberedOverlayDifference = difference(memoryOn, memoryOff, memoryPixels);
    double wholeImageDifference = difference(memoryOn, memoryOff, System.Linq.Enumerable.Range(0, width * height));
    double unknownOverlayDifference = difference(mixedOn, mixedOff, unknownPixels);
    var remembered = statistics(memoryOff, memoryPixels); var rememberedMixed = statistics(mixedOff, mixedMemoryPixels);
    var current = statistics(mixedOff, visiblePixels);
    bool noMemoryVeil = rememberedOverlayDifference < .0005 && wholeImageDifference < .0005;
    bool readableMemory = remembered[1] > .0015;
    bool unknownCovered = unknownOverlayDifference > .01;
    bool colorPreserved = current[2] > .001 && rememberedMixed[2] < current[2] * .35;
    result = new {
        verifyFix, mapCells = map.Cells.Length, knownCells = knownMemory.KnownCount, visibleMemoryFixtureCells = knownMemory.VisibleCount,
        note = "One remote visible cell is required by Reveal; it is excluded from remembered terrain samples.",
        weakSunIntensity = sun.intensity, rememberedOverlayDifference, wholeImageDifference, unknownOverlayDifference,
        memoryLuminanceMean = remembered[0], memoryLuminanceStdDev = remembered[1], memoryChroma = rememberedMixed[2], visibleChroma = current[2],
        noMemoryVeil, readableMemory, unknownCovered, colorPreserved,
        samples = new { memory = memoryPixels.Count, unknown = unknownPixels.Count, mixedMemory = mixedMemoryPixels.Count, visible = visiblePixels.Count },
        outputs, playMode = false, projectCompilationRequested = false, playerSaveAccess = false
    };
    System.IO.File.WriteAllText(folder + "/validation.json", Newtonsoft.Json.JsonConvert.SerializeObject(result, Newtonsoft.Json.Formatting.Indented));
    check(knownMemory.Revision == memoryRevision && mixed.Revision == mixedRevision, "Rendering modified exploration data.");
    check(errors.Count == 0, "Fog memory capture logged errors: " + string.Join(" | ", errors));
    if (verifyFix)
    {
        check(noMemoryVeil, "Known terrain still receives a gray fog overlay; see validation.json.");
        check(readableMemory, "Remembered terrain has lost its lighting/material luminance variation.");
        check(unknownCovered, "Unknown terrain no longer receives exploration cloud cover.");
        check(colorPreserved, "Current visibility no longer preserves color relative to gray memory terrain.");
    }
}
finally
{
    RenderTexture.active = originalTarget;
    if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    if (readback != null) UnityEngine.Object.DestroyImmediate(readback);
    if (image != null) UnityEngine.Object.DestroyImmediate(image);
    if (owner != null) UnityEngine.Object.DestroyImmediate(owner);
    manager.stack = previousStack; manager.DestroyStack(stack);
    RenderSettings.sun = originalSun; RenderSettings.skybox = originalSkybox; RenderSettings.fog = originalFog;
    RenderSettings.ambientMode = originalAmbientMode; RenderSettings.ambientLight = originalAmbient;
    RenderSettings.ambientIntensity = originalAmbientIntensity; RenderSettings.ambientSkyColor = originalSky;
    RenderSettings.ambientEquatorColor = originalEquator; RenderSettings.ambientGroundColor = originalGround;
    RenderSettings.reflectionIntensity = originalReflection; Shader.SetGlobalFloat("_WorldWeatherEnabled", originalWeatherEnabled);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene) UnityEngine.SceneManagement.SceneManager.SetActiveScene(originalScene);
    Application.logMessageReceived -= log;
    check(originalScene.isDirty == originalDirty && QualitySettings.renderPipeline == originalPipeline && RenderSettings.sun == originalSun &&
        RenderSettings.skybox == originalSkybox && RenderSettings.fog == originalFog && RenderSettings.ambientMode == originalAmbientMode &&
        RenderSettings.ambientLight == originalAmbient && RenderSettings.ambientSkyColor == originalSky &&
        RenderSettings.ambientEquatorColor == originalEquator && RenderSettings.ambientGroundColor == originalGround &&
        Mathf.Abs(RenderSettings.ambientIntensity - originalAmbientIntensity) < .0001f &&
        Mathf.Abs(RenderSettings.reflectionIntensity - originalReflection) < .0001f,
        "Fog memory capture did not restore the user's scene or RenderSettings.");
}
return result;
