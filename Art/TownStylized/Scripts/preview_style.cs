// Edit Mode screenshots from production assets and the actual village generator. No Play/session changes.
// Requires the farm config and scene bindings recorded in Integration/integration-status.json.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
ProjectY.Samples.MapAreaViewData layout;
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null); var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
    lua.Global.Set("Services", services); lua.Global.Set("PreviewArea", 3); lua.Global.Set("PreviewRegion", 1);
    try { var result = lua.DoString(System.IO.File.ReadAllText("Art/MapDressingLowPoly/Scripts/preview_dressing.lua")); using (var table = (XLua.LuaTable)result[0]) layout = ProjectY.Samples.MapAreaViewData.Read(table); }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
var originals = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool dirty = originals.isDirty;
var pipeline = QualitySettings.renderPipeline; var manager = UnityEngine.Rendering.VolumeManager.instance;
var previousStack = manager.stack; var stack = manager.CreateStack(); manager.stack = stack;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Rendering.FantasyPresentation presentation = null;
ProjectY.Samples.TownSurfaceRenderer surface = null;
var previousTarget = RenderTexture.active; RenderTexture target = null; Texture2D image = null;
var outputs = new System.Collections.Generic.List<string>();
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
    presentation = new ProjectY.Rendering.FantasyPresentation(camera, host.transform); presentation.SetShadowDistance(400);
    target = new RenderTexture(1600, 1000, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB); target.Create(); camera.targetTexture = target;
    image = new Texture2D(1600, 1000, TextureFormat.RGB24, false);
    System.IO.Directory.CreateDirectory("Art/TownStylized/Previews");
    Action<string, Vector3, float, Vector3> capture = (name, center, size, angles) =>
    {
        camera.orthographicSize = size; var rotation = Quaternion.Euler(angles); camera.transform.SetPositionAndRotation(center - rotation * Vector3.forward * 240, rotation);
        manager.Update(stack, camera.transform, 1); ProjectY.Rendering.UrpCameraRendering.Render(camera);
        RenderTexture.active = target; image.ReadPixels(new Rect(0, 0, 1600, 1000), 0, 0); image.Apply();
        if (image.GetPixels32().Count(c => c.r > 230 && c.b > 230 && c.g < 30) > 100) throw new System.Exception("Missing shader in " + name);
        string path = "Art/TownStylized/Previews/" + name + ".png"; System.IO.File.WriteAllBytes(path, image.EncodeToPNG()); outputs.Add(path);
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
    capture("village-overview", bounds.center + Vector3.up * 2, 56, new Vector3(49, 155, 0));
    var windmill = farm.First(p => p.AssetId == 113);
    capture("village-windmill", windmill.Position + Vector3.up * 3, 16, new Vector3(32, windmill.Rotation + 160, 0));
    // Separate close view of the exact castle asset, including the platform-conforming moat.
    foreach (Transform child in host.transform) if (child.gameObject != cameraObject && child.gameObject != sunObject && child.name != "Warm Fantasy Volume") child.gameObject.SetActive(false);
    var castle = (GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/MapLowPoly/Models/Building_Castle.fbx"), scene);
    castle.transform.SetParent(host.transform, false);
    capture("castle-refined", new Vector3(0, 1.4f, 0), 3.5f, new Vector3(35, 155, 0));
    var result = new { props = layout.Props.Length, farmAssets = farm.Select(p => p.AssetId).ToArray(), outputs, playMode = false };
    System.IO.File.WriteAllText("Art/TownStylized/Integration/preview.json", Newtonsoft.Json.JsonConvert.SerializeObject(result, Newtonsoft.Json.Formatting.Indented));
    return result;
}
finally
{
    if (presentation != null) presentation.Dispose(); if (surface != null) surface.Dispose();
    manager.stack = previousStack; manager.DestroyStack(stack); RenderTexture.active = previousTarget;
    if (image != null) UnityEngine.Object.DestroyImmediate(image); if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (QualitySettings.renderPipeline != pipeline || originals.isDirty != dirty) throw new System.Exception("Preview changed scene/pipeline state");
}
