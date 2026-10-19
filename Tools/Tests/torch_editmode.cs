// Unity MCP execute_code method body. Independent PreviewScene, real exported config/Catalog/controller, no Play.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
ProjectY.Samples.MapEnvironmentData lighting;
string iconPath, prefabPath;
int itemId, assetId;
bool physicalTorchEnabled;
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null, System.IO.Path.Combine(System.IO.Path.GetTempPath(), "torch-preview-unused-" + System.Guid.NewGuid() + ".json"));
    var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
    try
    {
        var result = lua.DoString(@"
            local config=require('Config.ConfigSystem')()
            config:OnInit({services=Services})
            local definition=config:GetTable('TorchTable'):Get(1)
            local item=config:GetTable('EquipmentItemTable'):Get(definition.itemId)
            local asset=config:GetTable('EquipmentAssetTable'):Get(item.assetId)
            local data=Services.Adventure
            data.Equipment.Grid:Define(item.id,item.width,item.height)
            data.Equipment.Grid:Configure(3,3)
            data.Equipment:AddStack(item.id,1)
            local state=require('Game.Adventure.Torch').Snapshot({config=config,data=data})
            assert(state.available and state.enabled and state.count==1)
            return require('Game.Rendering.MapPresentation').Snapshot(config),item.iconPath,asset.prefabPath,state.enabled,item.id,item.assetId
        ", "@torch_editmode_config");
        using (var root = (XLua.LuaTable)result[0]) lighting = ProjectY.Samples.MapEnvironmentData.Read(root);
        iconPath = (string)result[1]; prefabPath = (string)result[2]; physicalTorchEnabled = System.Convert.ToBoolean(result[3]);
        itemId = System.Convert.ToInt32(result[4]); assetId = System.Convert.ToInt32(result[5]);
    }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
if (itemId != 94 || assetId != 403) throw new System.Exception("Unexpected portable light identity");
var catalog = UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.EquipmentAssetCatalog>(ProjectY.Editor.EquipmentAssets.CatalogPath);
if (catalog == null || catalog.ItemIcon(itemId, iconPath) == null || catalog.Resolve(new ProjectY.Samples.EquipmentVisualData.Asset { Id = assetId, Path = prefabPath }) == null)
    throw new System.Exception("Run Project Y/装备/同步旅行火炬资源 before this check");

var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var originalDirty = originalScene.isDirty;
var originalPipeline = QualitySettings.renderPipeline; var originalTarget = RenderTexture.active;
var originalAmbientMode = RenderSettings.ambientMode; var originalSky = RenderSettings.ambientSkyColor;
var originalEquator = RenderSettings.ambientEquatorColor; var originalGround = RenderSettings.ambientGroundColor;
var originalFog = RenderSettings.fog; var originalFogMode = RenderSettings.fogMode; var originalFogColor = RenderSettings.fogColor;
var originalFogStart = RenderSettings.fogStartDistance; var originalFogEnd = RenderSettings.fogEndDistance; var originalFogDensity = RenderSettings.fogDensity;
var originalReflection = RenderSettings.reflectionIntensity; var originalSun = RenderSettings.sun; var originalSkybox = RenderSettings.skybox;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapEnvironmentController environment = null;
Camera camera = null; Material material = null; RenderTexture target = null; Texture2D pixels = null;
double offBrightness = 0, onBrightness = 0;
bool controllerRestored = false, destroyed = false;
System.Func<bool> restored = () => QualitySettings.renderPipeline == originalPipeline && RenderSettings.sun == originalSun && RenderSettings.skybox == originalSkybox &&
    RenderSettings.ambientMode == originalAmbientMode && RenderSettings.ambientSkyColor == originalSky && RenderSettings.ambientEquatorColor == originalEquator && RenderSettings.ambientGroundColor == originalGround &&
    RenderSettings.fog == originalFog && RenderSettings.fogMode == originalFogMode && RenderSettings.fogColor == originalFogColor &&
    Mathf.Abs(RenderSettings.fogStartDistance - originalFogStart) < .001f && Mathf.Abs(RenderSettings.fogEndDistance - originalFogEnd) < .001f &&
    Mathf.Abs(RenderSettings.fogDensity - originalFogDensity) < .00001f && Mathf.Abs(RenderSettings.reflectionIntensity - originalReflection) < .001f;
try
{
    var host = new GameObject("Torch EditMode Check") { hideFlags = HideFlags.DontSave };
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var cameraObject = new GameObject("Torch Check Camera"); cameraObject.transform.SetParent(host.transform, false);
    camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic = true; camera.orthographicSize = 4; camera.aspect = 1; camera.nearClipPlane = .1f; camera.farClipPlane = 30;
    camera.transform.SetPositionAndRotation(new Vector3(0, 10, 0), Quaternion.Euler(90, 0, 0));
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = Color.black;
    var sunObject = new GameObject("Torch Check Sun"); sunObject.transform.SetParent(host.transform, false);
    var sun = sunObject.AddComponent<Light>(); sun.type = LightType.Directional;
    environment = new ProjectY.Samples.MapEnvironmentController(lighting, sun, camera, host.transform);
    var layout = new ProjectY.Samples.MapAreaViewData { Cells = new[] { new ProjectY.Samples.MapAreaViewData.Cell { Position = Vector3.zero, InteriorId = 0 } } };
    environment.SetArea(layout); environment.Running = false; environment.Hour = 0;
    environment.Tick(3, null); environment.ApplyCameraFocus(Vector3.zero);
    // Reflection is limited to test inspection of the owned light, never used as a gameplay binding.
    var field = typeof(ProjectY.Samples.MapEnvironmentController).GetField("torch", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
    if (field == null) throw new System.Exception("Controller no longer exposes its expected owned-light field to this check");
    var torch = (Light)field.GetValue(environment);
    if (torch == null || torch.enabled || torch.type != LightType.Point) throw new System.Exception("Torch was not created disabled as a point light");
    if (Mathf.Abs(torch.range - lighting.TorchRange) > .001f || Mathf.Abs(torch.intensity - lighting.TorchIntensity) > .001f || torch.color != lighting.TorchColor)
        throw new System.Exception("Torch ignored the exported color/range/intensity");
    var leader = new Vector3(2.25f, .4f, -1.75f);
    environment.SetTorch(physicalTorchEnabled, leader);
    if (!torch.enabled || Vector3.Distance(torch.transform.position, leader + Vector3.up * lighting.TorchHeight) > .001f)
        throw new System.Exception("Torch did not follow the rendered leader");
    environment.SetTorch(false, leader); if (torch.enabled) throw new System.Exception("Torch switch failed to extinguish the light");
    environment.SetTorch(true, leader); environment.SetArea(null);
    if (torch.enabled) throw new System.Exception("Leaving the local map retained its torch light");
    environment.SetTorch(true, leader); if (torch.enabled) throw new System.Exception("World map must not enable the local torch");
    environment.SetArea(layout);

    // Compare the real map shader with only the portable light changed. Preview renderer disables grading/SSAO.
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    if (shader == null || UnityEditor.ShaderUtil.ShaderHasError(shader)) throw new System.Exception("Production map shader is unavailable");
    material = new Material(shader) { hideFlags = HideFlags.HideAndDontSave };
    material.SetColor("_Color", new Color(.45f, .45f, .45f)); material.SetFloat("_UseVertexColor", 0); material.SetFloat("_UseSurfacePattern", 0);
    var floor = GameObject.CreatePrimitive(PrimitiveType.Plane); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(floor, scene);
    floor.transform.SetParent(host.transform, false); floor.GetComponent<MeshRenderer>().sharedMaterial = material;
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    target = new RenderTexture(128, 128, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear) { hideFlags = HideFlags.HideAndDontSave };
    target.Create(); camera.targetTexture = target;
    pixels = new Texture2D(128, 128, TextureFormat.RGBAFloat, false, true) { hideFlags = HideFlags.HideAndDontSave };
    var request = new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest();
    System.Func<bool, double> measure = enabled =>
    {
        environment.SetTorch(enabled, Vector3.zero);
        ProjectY.Rendering.UrpCameraRendering.Render(camera, request);
        RenderTexture.active = target; pixels.ReadPixels(new Rect(0, 0, 128, 128), 0, 0); pixels.Apply();
        var colors = pixels.GetPixels(); double sum = 0;
        for (var y = 48; y < 80; y++) for (var x = 48; x < 80; x++)
        {
            var color = colors[y * 128 + x];
            if (float.IsNaN(color.r) || float.IsInfinity(color.r) || (color.r > .9f && color.b > .9f && color.g < .05f))
                throw new System.Exception("Invalid map shader pixel");
            sum += color.r * .2126 + color.g * .7152 + color.b * .0722;
        }
        return sum / 1024;
    };
    measure(false); // Warm the same camera/URP request before comparing.
    offBrightness = measure(false); onBrightness = measure(true);
    if (offBrightness <= .001 || onBrightness <= offBrightness + .01 || onBrightness <= offBrightness * 1.05)
        throw new System.Exception("Torch did not increase measured surface brightness: off=" + offBrightness + ", on=" + onBrightness);
    environment.Dispose(); environment = null;
    destroyed = torch == null; if (!destroyed) throw new System.Exception("Dispose leaked the torch GameObject");
    controllerRestored = restored(); if (!controllerRestored) throw new System.Exception("Controller did not restore the original RenderSettings/pipeline");
}
finally
{
    try { if (environment != null) environment.Dispose(); }
    finally
    {
        // Failure cleanup is explicit even if construction, rendering or a check throws.
        RenderTexture.active = originalTarget; if (camera != null) camera.targetTexture = null;
        if (pixels != null) UnityEngine.Object.DestroyImmediate(pixels);
        if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
        if (material != null) UnityEngine.Object.DestroyImmediate(material);
        RenderSettings.ambientMode = originalAmbientMode; RenderSettings.ambientSkyColor = originalSky;
        RenderSettings.ambientEquatorColor = originalEquator; RenderSettings.ambientGroundColor = originalGround;
        RenderSettings.fog = originalFog; RenderSettings.fogMode = originalFogMode; RenderSettings.fogColor = originalFogColor;
        RenderSettings.fogStartDistance = originalFogStart; RenderSettings.fogEndDistance = originalFogEnd; RenderSettings.fogDensity = originalFogDensity;
        RenderSettings.reflectionIntensity = originalReflection; RenderSettings.sun = originalSun; RenderSettings.skybox = originalSkybox; QualitySettings.renderPipeline = originalPipeline;
        UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    }
}
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != originalDirty || !restored())
    throw new System.Exception("Torch preview changed the user's active scene or environment");
return new { passed = true, itemId, assetId, iconBound = true, prefabBound = true, physicalTorchEnabled, range = lighting.TorchRange,
    intensity = lighting.TorchIntensity, height = lighting.TorchHeight, offBrightness, onBrightness, brightnessRatio = onBrightness / offBrightness,
    followAndSwitch = true, areaExit = true, destroyed, controllerRestored, scenePreserved = true, playMode = false };
