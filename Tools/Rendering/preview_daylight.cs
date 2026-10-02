// Render actual game lighting, not a manually lit mockup. Edit Mode; preserves scene/environment state.
// Requires the farm config and scene bindings recorded in Integration/integration-status.json.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
ProjectY.Samples.MapAreaViewData layout;
ProjectY.Samples.MapEnvironmentData lighting;
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null); var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
    lua.Global.Set("Services", services); lua.Global.Set("PreviewArea", 3); lua.Global.Set("PreviewRegion", 1);
    try { var result = lua.DoString(System.IO.File.ReadAllText("Tools/Rendering/preview_daylight.lua")); using (var table = (XLua.LuaTable)result[0]) layout = ProjectY.Samples.MapAreaViewData.Read(table); using (var table = (XLua.LuaTable)result[1]) lighting = ProjectY.Samples.MapEnvironmentData.Read(table); }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
var originals = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool dirty = originals.isDirty;
var pipeline = QualitySettings.renderPipeline; var manager = UnityEngine.Rendering.VolumeManager.instance;
var previousStack = manager.stack; var stack = manager.CreateStack(); manager.stack = stack;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapEnvironmentController environment = null;
var originalSkybox = RenderSettings.skybox; var originalReflection = RenderSettings.reflectionIntensity;
ProjectY.Samples.TownSurfaceRenderer surface = null;
var previousTarget = RenderTexture.active; RenderTexture target = null; Texture2D image = null; Texture2D linearImage = null;
var outputs = new System.Collections.Generic.List<string>();
var checks = new System.Collections.Generic.List<object>();
try
{
    var host = new GameObject("Town Art Preview"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var cameraObject = new GameObject("Camera"); cameraObject.transform.SetParent(host.transform, false);
    var camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic = true; camera.nearClipPlane = .1f; camera.farClipPlane = 600; camera.aspect = 1.6f;
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.12f, .17f, .23f);
    var sunObject = new GameObject("Sun"); sunObject.transform.SetParent(host.transform, false);
    var sun = sunObject.AddComponent<Light>(); sun.type = LightType.Directional; sun.intensity = 1.5f; sun.shadows = LightShadows.Soft;
    sun.color = new Color(1, .92f, .81f); sun.transform.rotation = Quaternion.Euler(48, 145, 0);
    environment = new ProjectY.Samples.MapEnvironmentController(lighting, sun, camera, host.transform); environment.SetArea(layout); environment.Running = false;
    // An explicit LDR target also makes URP's intermediate camera target LDR, clipping sunlight before Bloom.
    target = new RenderTexture(1600, 1000, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear); target.Create(); camera.targetTexture = target;
    image = new Texture2D(1600, 1000, TextureFormat.RGB24, false);
    linearImage = new Texture2D(1600, 1000, TextureFormat.RGBAFloat, false, true);
    System.IO.Directory.CreateDirectory("Docs/Previews/Rendering");
    Action<string, Vector3, float, Vector3> capture = (name, center, size, angles) =>
    {
        camera.orthographicSize = size; camera.fieldOfView = 55;
        var rotation = Quaternion.Euler(angles);
        camera.transform.SetPositionAndRotation(center - rotation * Vector3.forward * (camera.orthographic ? 240 : size), rotation);
        foreach (var style in new[] { ProjectY.Rendering.WorldVisualStyle.PixelInk, ProjectY.Rendering.WorldVisualStyle.MedievalFantasy })
        {
            ProjectY.Rendering.FantasyPresentation.ApplyToActive(style);
            environment.Hour = name.StartsWith("sunset") ? 17.5f : 12;
            environment.Tick(3, null); environment.ApplyCameraFocus(center);
            manager.Update(stack, camera.transform, 1);
            ProjectY.Rendering.UrpCameraRendering.Render(camera);
            RenderTexture.active = target; linearImage.ReadPixels(new Rect(0,0,1600,1000),0,0); linearImage.Apply();
            // Tonemapped half-float output is linear. Encode to sRGB only at the PNG boundary.
            var linearPixels = linearImage.GetPixels(); var encoded = new Color32[linearPixels.Length];
            for (int i = 0; i < encoded.Length; i++) encoded[i] = linearPixels[i].gamma;
            image.SetPixels32(encoded); image.Apply();
            var pixels = image.GetPixels32();
            if (pixels.Count(p=>p.r>230 && p.b>230 && p.g<30)>100) throw new System.Exception("Invalid shader render");
            string path = "Docs/Previews/Rendering/daylight-" + style + "-" + name + ".png";
            System.IO.File.WriteAllBytes(path,image.EncodeToPNG()); outputs.Add(path);
            var choices = UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Rendering.WorldVisualStyles>(ProjectY.Editor.WorldVisualStyleAssets.SettingsPath);
            if (!name.StartsWith("sunset") && Mathf.Abs(sun.intensity-(style==ProjectY.Rendering.WorldVisualStyle.PixelInk?1.1f:1.1f*choices.fantasyLighting.daySunMultiplier))>.01f) throw new System.Exception("Incorrect runtime sunlight gain");
            if (camera.clearFlags != (style==ProjectY.Rendering.WorldVisualStyle.PixelInk?CameraClearFlags.SolidColor:CameraClearFlags.Skybox)) throw new System.Exception("Sky style did not switch");
            checks.Add(new{view=name,style=style.ToString(),sun=sun.intensity,skybox=camera.clearFlags.ToString(),reflection=RenderSettings.reflectionIntensity,meanBrightness=pixels.Average(p=>(p.r+p.g+p.b)/3.0)});
        }
    };
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    surface = new ProjectY.Samples.TownSurfaceRenderer(shader, layout);
    var ground = new GameObject("Village Ground", typeof(MeshFilter), typeof(MeshRenderer)); ground.transform.SetParent(host.transform, false);
    ground.GetComponent<MeshFilter>().sharedMesh = surface.Mesh; ground.GetComponent<MeshRenderer>().sharedMaterial = surface.Material;
    foreach (var prop in layout.Props)
    {
        var definition = Array.Find(layout.PropAssets, a => a.Id == prop.AssetId);
        var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(definition.Path);
        if (prefab == null) throw new System.Exception("Missing production asset " + definition.Path);
        var obj = (GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(prefab, scene); obj.transform.SetParent(host.transform, false);
        obj.transform.position = prop.Position; obj.transform.rotation = Quaternion.Euler(0, prop.Rotation, 0); obj.transform.localScale = prop.Scale3;
    }
    var farm = layout.Props.Where(p => p.AssetId >= 113 && p.AssetId <= 115).ToArray();
    if (farm.Select(p => p.AssetId).Distinct().Count() != 3) throw new System.Exception("Village fixture did not place all three new art props");
    var bounds = new Bounds(layout.Props[0].Position, Vector3.zero); foreach (var prop in layout.Props) bounds.Encapsulate(prop.Position);
    var windmill = farm.First(p => p.AssetId == 113);
    capture("noon-village", windmill.Position + Vector3.up * 3, 16, new Vector3(32, windmill.Rotation + 160, 0));
    camera.orthographic = false;
    capture("sunset-street", windmill.Position + Vector3.up * 3, 24, new Vector3(3,145,0));
    environment.Hour = 0; environment.Tick(3,null);
    if (Mathf.Abs(sun.intensity - .22f) > .001f) throw new System.Exception("Daylight gain leaked into night");
    var skyShader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Rendering/FantasySky.shader");
    if (UnityEditor.ShaderUtil.ShaderHasError(skyShader)) throw new System.Exception("Sky shader error");
    var result = new { checks, outputs, nightSunPreserved=true, playMode=false };
    System.IO.File.WriteAllText("Docs/Previews/Rendering/daylight-validation.json", Newtonsoft.Json.JsonConvert.SerializeObject(result, Newtonsoft.Json.Formatting.Indented));
    return result;
}
finally
{
    if (environment != null) environment.Dispose(); if (surface != null) surface.Dispose();
    manager.stack = previousStack; manager.DestroyStack(stack); RenderTexture.active = previousTarget;
    if (image != null) UnityEngine.Object.DestroyImmediate(image); if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    if (linearImage != null) UnityEngine.Object.DestroyImmediate(linearImage);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (QualitySettings.renderPipeline != pipeline || originals.isDirty != dirty || RenderSettings.skybox != originalSkybox || Mathf.Abs(RenderSettings.reflectionIntensity-originalReflection)>.001f) throw new System.Exception("Preview changed scene/pipeline state");
}
