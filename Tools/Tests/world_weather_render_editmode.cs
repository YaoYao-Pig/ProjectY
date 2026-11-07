// Unity MCP execute_code method body. Run once after compilation, in an already idle Editor.
// Real Config/Map/Town generators, no Main/Adventure startup, Play mode, scene save or player save access.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Weather preview requires an idle Editor in Edit Mode.");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var originalDirty = originalScene.isDirty;
var originalPipeline = QualitySettings.renderPipeline; var originalTarget = RenderTexture.active;
var originalSkybox = RenderSettings.skybox; var originalSun = RenderSettings.sun;
var originalAmbientMode = RenderSettings.ambientMode; var originalSky = RenderSettings.ambientSkyColor;
var originalEquator = RenderSettings.ambientEquatorColor; var originalGround = RenderSettings.ambientGroundColor;
var originalFog = RenderSettings.fog; var originalFogMode = RenderSettings.fogMode; var originalFogColor = RenderSettings.fogColor;
var originalFogStart = RenderSettings.fogStartDistance; var originalFogEnd = RenderSettings.fogEndDistance;
var originalFogDensity = RenderSettings.fogDensity; var originalReflection = RenderSettings.reflectionIntensity;
var originalWeatherMap = Shader.GetGlobalTexture("_WorldWeatherMap");
var originalWeatherRect = Shader.GetGlobalVector("_WorldWeatherRect");
var originalWeatherEnabled = Shader.GetGlobalFloat("_WorldWeatherEnabled");
var manager = UnityEngine.Rendering.VolumeManager.instance; var previousStack = manager.stack; var stack = manager.CreateStack();
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var reports = new System.Collections.Generic.List<object>(); var outputs = new System.Collections.Generic.List<string>();
var errors = new System.Collections.Generic.List<string>();
Application.LogCallback log = (message, trace, kind) => { if (kind == LogType.Error || kind == LogType.Exception) errors.Add(message); };
Application.logMessageReceived += log;
System.Action<bool, string> check = (condition, message) => { if (!condition) throw new System.Exception(message); };
var binding = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
System.Func<object, string, object> member = (value, name) => value.GetType().GetField(name, binding).GetValue(value);
ProjectY.Samples.MapPreviewRenderer worldRenderer = null; ProjectY.Samples.MapAreaRenderer townRenderer = null;
GameObject owner = null; Texture2D sentinel = null, image = null, linearImage = null; RenderTexture target = null;
const int width = 960, height = 600;
var folder = "Docs/Previews/Weather"; System.IO.Directory.CreateDirectory(folder);
int worldCellCount = 0, townCellCount = 0, clearStarPixels = 0, overcastStarPixels = 0;
try
{
    manager.stack = stack;
    ProjectY.Samples.MapPreviewData world; ProjectY.Samples.MapAreaViewData town;
    ProjectY.Samples.MapEnvironmentData lighting; double regionHexes, evolutionMinutes, windX, windZ;
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
function WeatherPreviewShutdown() registry:Shutdown() end
registry:Start()
local config=registry:Get('Config')
local world=registry:Get('Map'):GenerateSeeded(20261026,2500)
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local area=generator:Generate(3,world.seed,11,{regionId=7,regionType=1,regionConfigId=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}}})
local reader={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
return require('Game.Map.MapRenderSnapshot')(world),require('Game.MapArea.MapAreaSystem').LayoutSnapshot(reader),require('Game.Rendering.MapPresentation').Snapshot(config)
", "WorldWeatherPreview");
            using (var table = (XLua.LuaTable)values[0]) world = ProjectY.Samples.MapPreviewData.Read(table);
            using (var table = (XLua.LuaTable)values[1]) town = ProjectY.Samples.MapAreaViewData.Read(table);
            using (var table = (XLua.LuaTable)values[2])
            {
                lighting = ProjectY.Samples.MapEnvironmentData.Read(table);
                using (var settings = table.Get<XLua.LuaTable>("weatherSystem"))
                {
                    regionHexes = settings.Get<double>("regionHexes"); evolutionMinutes = settings.Get<double>("evolutionMinutes");
                    windX = settings.Get<double>("windX"); windZ = settings.Get<double>("windZ");
                }
            }
        }
        finally
        {
            using (var shutdown = lua.Global.Get<XLua.LuaFunction>("WeatherPreviewShutdown")) if (shutdown != null) shutdown.Call();
            lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners();
        }
    }
    worldCellCount = world.Cells.Length; townCellCount = town.Cells.Length;
    check(worldCellCount >= 2500 && townCellCount > 0, "Real map fixtures were not generated.");
    var field = new ProjectY.Data.WorldWeatherField(world.Seed, world.Radius * regionHexes, evolutionMinutes, windX, windZ);
    owner = new GameObject("World weather isolated validation"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner, scene);
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    foreach (var candidate in new[] { shader, Resources.Load<Shader>("MapWeatherParticle"), Resources.Load<Shader>("MapWeatherCloud"),
        UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Rendering/FantasySky.shader") })
        check(candidate != null && !UnityEditor.ShaderUtil.ShaderHasError(candidate), "A production weather/terrain/sky shader has errors.");
    worldRenderer = new ProjectY.Samples.MapPreviewRenderer(shader, owner.transform);
    worldRenderer.Build(world, asset => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
    var exploration = new ProjectY.Data.WorldMapExplorationData(); exploration.Reset(world.Cells.Length);
    exploration.Reveal(Enumerable.Range(1, world.Cells.Length).ToArray()); worldRenderer.SetExploration(exploration);
    int worldRevision = exploration.Revision;
    townRenderer = new ProjectY.Samples.MapAreaRenderer(shader, UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(town.AssetPath),
        town, asset => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
    var allTown = Enumerable.Range(0, town.Cells.Length).ToArray();
    int outside = Array.FindIndex(town.Cells, cell => cell.RenderGround && cell.Kind != "void" && cell.Kind != "wall" &&
        !cell.Blocked && cell.InteriorId == 0 && cell.CoverInteriorId == 0);
    int inside = Array.FindIndex(town.Cells, cell => cell.InteriorId > 0 && !cell.Blocked);
    check(outside >= 0 && inside >= 0, "Real town fixture lacks outdoor and indoor cells.");
    var townState = new ProjectY.Samples.MapAreaViewData.State { CellIndex = outside, Revision = 1, Known = allTown, Visible = allTown,
        Members = new[] { new ProjectY.Samples.MapAreaViewData.Member { ActorId = 1, CellIndex = outside } } };
    townRenderer.UpdateVisibility(townState, true);
    var sampler = new ProjectY.Samples.MapWeatherSurface(); sampler.SetWorld(world); sampler.SetArea(town);
    int shelteredCells = 0;
    foreach (var cell in town.Cells) if (cell.InteriorId > 0 || cell.CoverInteriorId > 0)
    {
        check(sampler.TryGet(cell.Position.x, cell.Position.z, out _, out var covered) && covered, "Interior column does not block rain.");
        shelteredCells++;
    }
    check(shelteredCells > 0, "Shelter test did not cover an interior.");
    sampler.SetArea(null);
    check(!sampler.TryGet(worldRenderer.Bounds.max.x + world.Radius * 20, worldRenderer.Bounds.max.z + world.Radius * 20, out _, out _),
        "World weather surface accepts a point outside the map.");

    // Find a real deterministic mixed-weather minute; this searches a bounded fixture, never changes the field.
    double mixedMinute = -1; Vector3 rainFocus = worldRenderer.Bounds.center;
    for (int step = 0; step < 16 && mixedMinute < 0; step++)
    {
        double minute = step * evolutionMinutes; bool clear = false, rain = false;
        foreach (var cell in world.Cells)
        {
            var sample = field.Sample(cell.Position.x, cell.Position.z, minute);
            clear |= sample.Cloud < .3f;
            if (sample.Rain > .35f) { rain = true; rainFocus = cell.Position; }
            if (clear && rain) { mixedMinute = minute; break; }
        }
    }
    check(mixedMinute >= 0, "Real world fixture did not contain concurrent clear and rainy regions.");
    target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear); target.Create();
    image = new Texture2D(width, height, TextureFormat.RGB24, false);
    linearImage = new Texture2D(width, height, TextureFormat.RGBAFloat, false, true);
    sentinel = new Texture2D(1, 1, TextureFormat.RGBA32, false); sentinel.SetPixel(0, 0, Color.magenta); sentinel.Apply();
    var sentinelRect = new Vector4(17, 29, .13f, .23f); const float sentinelEnabled = .37f;
    Shader.SetGlobalTexture("_WorldWeatherMap", sentinel); Shader.SetGlobalVector("_WorldWeatherRect", sentinelRect);
    Shader.SetGlobalFloat("_WorldWeatherEnabled", sentinelEnabled);
    System.Action globalsRestored = () => check(Shader.GetGlobalTexture("_WorldWeatherMap") == sentinel &&
        Shader.GetGlobalVector("_WorldWeatherRect") == sentinelRect && Mathf.Abs(Shader.GetGlobalFloat("_WorldWeatherEnabled") - sentinelEnabled) < .0001f,
        "Weather camera leaked global shader state.");
    System.Func<Camera, Color32[]> pixels = camera =>
    {
        manager.Update(stack, camera.transform, 1);
        ProjectY.Rendering.UrpCameraRendering.Render(camera); RenderTexture.active = target;
        linearImage.ReadPixels(new Rect(0, 0, width, height), 0, 0); linearImage.Apply();
        var linear = linearImage.GetPixels(); var encoded = new Color32[linear.Length];
        for (int i = 0; i < encoded.Length; i++) encoded[i] = linear[i].gamma;
        image.SetPixels32(encoded); image.Apply();
        int pink = 0; foreach (var c in encoded) if (c.r > 230 && c.b > 230 && c.g < 30) pink++;
        check(pink < 50, "Weather capture contains a missing-shader color."); globalsRestored();
        return encoded;
    };
    System.Action<string, int, bool, bool, bool> capture = (name, preview, local, sky, overview) =>
    {
        // DrawMesh submissions last until the next Editor frame: each capture gets a distinct camera.
        var shotRoot = new GameObject(name); shotRoot.transform.SetParent(owner.transform, false);
        var camera = new GameObject("Camera").AddComponent<Camera>(); camera.transform.SetParent(shotRoot.transform, false);
        camera.enabled = false; camera.scene = scene; camera.targetTexture = target;
        camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
        camera.aspect = (float)width / height; camera.nearClipPlane = .1f; camera.farClipPlane = 3000;
        ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
        var sun = new GameObject("Sun").AddComponent<Light>(); sun.transform.SetParent(shotRoot.transform, false); sun.type = LightType.Directional;
        ProjectY.Samples.MapEnvironmentController environment = null;
        var owned = new System.Collections.Generic.List<UnityEngine.Object>();
        bool sawWeatherCamera = false; float duringCameraEnabled = -1;
        Action<UnityEngine.Rendering.ScriptableRenderContext, Camera> observe = (context, renderingCamera) =>
        { if (renderingCamera == camera) { sawWeatherCamera = true; duringCameraEnabled = Shader.GetGlobalFloat("_WorldWeatherEnabled"); } };
        try
        {
            environment = new ProjectY.Samples.MapEnvironmentController(lighting, sun, camera, shotRoot.transform);
            ((ProjectY.Rendering.FantasyPresentation)member(environment, "presentation")).SetStyle(ProjectY.Rendering.WorldVisualStyle.MedievalFantasy);
            if (local)
            {
                townState.CellIndex = inside; townState.Members[0].CellIndex = inside; townState.Revision++;
                townRenderer.UpdateVisibility(townState, true); // Exercise rain while the occupied building roof is cut away.
            }
            environment.BindWeather(world, field); environment.SetArea(local ? town : null);
            environment.Running = false; environment.Hour = sky ? 0 : 12;
            environment.SetWeatherContext(mixedMinute, new Vector2(rainFocus.x, rainFocus.z));
            if (preview < 0) environment.UseAutomaticWeather(); else environment.SelectWeather(preview);
            var focus = local ? town.Cells[inside].Position : overview ? worldRenderer.Bounds.center : rainFocus;
            camera.orthographic = !sky;
            if (sky)
            {
                camera.fieldOfView = 65;
                camera.transform.SetPositionAndRotation(focus + Vector3.up * 150, Quaternion.Euler(-50, 145, 0));
            }
            else
            {
                camera.orthographicSize = overview ? Mathf.Max(worldRenderer.Bounds.size.x, worldRenderer.Bounds.size.z) * .7f : (local ? town.Radius * 15 : world.Radius * 18);
                var rotation = Quaternion.Euler(52, -35, 0);
                camera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * 800, rotation);
            }
            environment.ApplyCameraFocus(focus); environment.Tick(5, local ? townState : null); environment.ApplyCameraFocus(focus);
            worldRenderer.SetVisible(!local && !sky);
            if (!sky) { if (local) townRenderer.Draw(camera); else worldRenderer.Draw(camera, true, true, true, true); }
            environment.DrawWeather(1.25f, focus);
            var weather = environment.Weather;
            var fieldPixels = weather.WeatherMap.GetPixels32(); int cloudMin = 255, cloudMax = 0, rainMin = 255, rainMax = 0;
            foreach (var p in fieldPixels) { cloudMin = Math.Min(cloudMin, p.r); cloudMax = Math.Max(cloudMax, p.r); rainMin = Math.Min(rainMin, p.g); rainMax = Math.Max(rainMax, p.g); }
            check(weather.RainCount <= lighting.WeatherEffects.MaxRainParticles && weather.SplashCount <= lighting.WeatherEffects.MaxSplashParticles &&
                weather.CloudCount <= lighting.WeatherEffects.MaxClouds, "Visible weather exceeded a configured budget.");
            if (preview == 2 && !sky) check(weather.RainCount > 0, "Rain preview emitted no rain particles.");
            if (preview == 0) check(weather.RainCount == 0 && weather.SplashCount == 0, "Clear preview emitted rain or splashes.");
            if (preview < 0) check(cloudMax - cloudMin > 48 && rainMax > 20 && rainMin == 0, "Weather texture lost regional variation.");
            foreach (var resource in new[] { "rainMaterial", "splashMaterial", "cloudMaterial", "cloudMesh", "weatherMap" }) owned.Add((UnityEngine.Object)member(weather, resource));
            var rainSystem = (ParticleSystem)member(weather, "rain"); var splashSystem = (ParticleSystem)member(weather, "splashes");
            owned.Add(rainSystem.gameObject); owned.Add(splashSystem.gameObject);
            check(rainSystem.particleCount == weather.RainCount && splashSystem.particleCount == weather.SplashCount, "Particle counts differ from published weather budgets.");
            if (local)
            {
                sampler.SetArea(town);
                var actual = new ParticleSystem.Particle[lighting.WeatherEffects.MaxRainParticles]; int count = rainSystem.GetParticles(actual);
                for (int i = 0; i < count; i++)
                    if (sampler.TryGet(actual[i].position.x, actual[i].position.z, out _, out var covered)) check(!covered, "A rain particle crossed a sheltered town column.");
            }
            UnityEngine.Rendering.RenderPipelineManager.beginCameraRendering += observe;
            var rendered = pixels(camera);
            check(sawWeatherCamera && Mathf.Abs(duringCameraEnabled - (local ? 0 : 1)) < .0001f, "Weather globals were not scoped to the target camera.");
            string path = folder + "/" + name + ".png"; System.IO.File.WriteAllBytes(path, image.EncodeToPNG()); outputs.Add(path);
            if (sky)
            {
                check(RenderSettings.skybox != null && camera.clearFlags == CameraClearFlags.Skybox, "Night preview lacks the production skybox.");
                check(RenderSettings.skybox.GetFloat("_Daylight") < .01f, "Night preview still uses daylight.");
                RenderSettings.skybox.SetFloat("_StarVisibility", 0); var noStars = pixels(camera); int starPixels = 0;
                for (int i = 0; i < rendered.Length; i++)
                    if (Math.Abs(rendered[i].r - noStars[i].r) + Math.Abs(rendered[i].g - noStars[i].g) + Math.Abs(rendered[i].b - noStars[i].b) > 12) starPixels++;
                if (preview == 0) clearStarPixels = starPixels; else overcastStarPixels = starPixels;
                reports.Add(new { view = name, starPixels, cloudCoverage = RenderSettings.skybox.GetFloat("_CloudCoverage") });
            }
            reports.Add(new { view = name, rain = weather.RainCount, splashes = weather.SplashCount, clouds = weather.CloudCount,
                cloudMin, cloudMax, rainMin, rainMax, refreshes = weather.RefreshCount });
            int refreshed = weather.RefreshCount; environment.DrawWeather(.001f, focus);
            check(weather.RefreshCount == refreshed, "Weather rebuilt its map before the configured refresh interval.");
            environment.HideWeather();
            check(weather.RainCount == 0 && weather.SplashCount == 0 && weather.CloudCount == 0 && rainSystem.particleCount == 0 && splashSystem.particleCount == 0,
                "Hiding weather left particles or clouds active."); globalsRestored();
            if (local)
            {
                // Only the enclosure flag changes in this isolated fixture; real town geometry remains untouched.
                var underground = new ProjectY.Samples.MapAreaViewData { AreaType = ProjectY.Samples.MapAreaPresentationSettings.Load().undergroundAreaTypes[0],
                    Radius = town.Radius, Cells = town.Cells, Props = Array.Empty<ProjectY.Samples.MapAreaViewData.Prop>() };
                environment.SetArea(underground); environment.SelectWeather(2); environment.Tick(5, townState); environment.DrawWeather(1, focus);
                check(weather.RainCount == 0 && weather.SplashCount == 0 && weather.CloudCount == 0, "Underground weather is still visible.");
                environment.SetArea(null); environment.UseAutomaticWeather(); environment.SetWeatherContext(mixedMinute, Vector2.zero);
                environment.DrawWeather(1, rainFocus); check(environment.AutomaticWeather && !weather.IsLocal, "Returning outdoors did not restore automatic world weather.");
            }
        }
        finally
        {
            UnityEngine.Rendering.RenderPipelineManager.beginCameraRendering -= observe;
            environment?.Dispose(); foreach (var resource in owned) check(resource == null, "Disposing weather leaked an owned GPU or particle resource.");
            camera.targetTexture = null; UnityEngine.Object.DestroyImmediate(shotRoot); globalsRestored();
            check(QualitySettings.renderPipeline == originalPipeline && RenderSettings.skybox == originalSkybox, "Weather capture did not restore its environment.");
        }
    };
    capture("world-clear", 0, false, false, false);
    capture("world-rain", 2, false, false, false);
    capture("world-regional", -1, false, false, true);
    capture("town-rain-shelter", 2, true, false, false);
    capture("night-clear-stars", 0, false, true, false);
    capture("night-overcast-stars", 1, false, true, false);
    check(clearStarPixels > 20 && overcastStarPixels < clearStarPixels, "Clouds did not reduce the actual rendered star contribution.");
    check(exploration.Revision == worldRevision && exploration.VisibleCount == world.Cells.Length, "Weather changed world exploration state.");
    check(errors.Count == 0, "Weather validation logged errors: " + string.Join(" | ", errors));
    reports.Add(new { shelteredCells, clearStarPixels, overcastStarPixels, isolation = "No Play, scene saves, player saves or full-game startup" });
}
finally
{
    worldRenderer?.Dispose(); townRenderer?.Dispose();
    Shader.SetGlobalTexture("_WorldWeatherMap", originalWeatherMap); Shader.SetGlobalVector("_WorldWeatherRect", originalWeatherRect);
    Shader.SetGlobalFloat("_WorldWeatherEnabled", originalWeatherEnabled);
    manager.stack = previousStack; manager.DestroyStack(stack); RenderTexture.active = originalTarget;
    if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    if (image != null) UnityEngine.Object.DestroyImmediate(image); if (linearImage != null) UnityEngine.Object.DestroyImmediate(linearImage);
    if (sentinel != null) UnityEngine.Object.DestroyImmediate(sentinel);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene) UnityEngine.SceneManagement.SceneManager.SetActiveScene(originalScene);
    Application.logMessageReceived -= log;
    check(originalScene.isDirty == originalDirty && QualitySettings.renderPipeline == originalPipeline && RenderSettings.sun == originalSun &&
        RenderSettings.skybox == originalSkybox && RenderSettings.ambientMode == originalAmbientMode && RenderSettings.ambientSkyColor == originalSky &&
        RenderSettings.ambientEquatorColor == originalEquator && RenderSettings.ambientGroundColor == originalGround && RenderSettings.fog == originalFog &&
        RenderSettings.fogMode == originalFogMode && RenderSettings.fogColor == originalFogColor &&
        Mathf.Abs(RenderSettings.fogStartDistance - originalFogStart) < .001f && Mathf.Abs(RenderSettings.fogEndDistance - originalFogEnd) < .001f &&
        Mathf.Abs(RenderSettings.fogDensity - originalFogDensity) < .00001f && Mathf.Abs(RenderSettings.reflectionIntensity - originalReflection) < .001f,
        "Weather validation changed the original scene, render pipeline or environment state.");
}
var result = new { worldCellCount, townCellCount, reports, outputs, playMode = false, gpuPerformanceMeasured = false };
System.IO.File.WriteAllText(folder + "/validation.json", Newtonsoft.Json.JsonConvert.SerializeObject(result, Newtonsoft.Json.Formatting.Indented));
return result;
