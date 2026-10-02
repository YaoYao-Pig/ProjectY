// Real navigation snapshots + production meshes/materials/cutaways in a temporary Edit Mode scene.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
const string root = "Art/TownOpenBuildings";
var layouts = new System.Collections.Generic.List<ProjectY.Samples.MapAreaViewData>();
var views = new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData>();
var names = new System.Collections.Generic.List<string>();
var layoutIds = new System.Collections.Generic.List<int>(); var propIds = new System.Collections.Generic.List<int>();
var interiorIds = new System.Collections.Generic.List<int>(); var assetIds = new System.Collections.Generic.List<int>();
ProjectY.Samples.MapEnvironmentData lighting; int navigationFrames;
System.IO.Directory.CreateDirectory(root + "/Previews");
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null); var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
    lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
    try
    {
        var output = lua.DoString(System.IO.File.ReadAllText(root + "/Scripts/preview_open_buildings.lua"));
        using (var result = (XLua.LuaTable)output[0])
        {
            navigationFrames = result.Get<int>("frames");
            using (var environment = result.Get<XLua.LuaTable>("environment")) lighting = ProjectY.Samples.MapEnvironmentData.Read(environment);
            using (var rows = result.Get<XLua.LuaTable>("layouts")) for (var i = 1; i <= rows.Length; i++)
                using (var row = rows.Get<int, XLua.LuaTable>(i)) using (var layout = row.Get<XLua.LuaTable>("layout")) layouts.Add(ProjectY.Samples.MapAreaViewData.Read(layout));
            using (var rows = result.Get<XLua.LuaTable>("captures")) for (var i = 1; i <= rows.Length; i++)
                using (var row = rows.Get<int, XLua.LuaTable>(i)) using (var view = row.Get<XLua.LuaTable>("view"))
                {
                    names.Add(row.Get<string>("name")); views.Add(ProjectY.Samples.AdventureViewData.Read(view));
                    layoutIds.Add(row.Get<int>("layoutIndex") - 1); propIds.Add(row.Get<int>("propIndex") - 1);
                    interiorIds.Add(row.Get<int>("interiorId")); assetIds.Add(row.Get<int>("assetId"));
                }
        }
    }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
var original = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var dirty = original.isDirty;
var pipeline = QualitySettings.renderPipeline; var skybox = RenderSettings.skybox;
ProjectY.Samples.AdventureRuntimeDemo demo = null;
foreach (var go in original.GetRootGameObjects()) foreach (var found in go.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)) demo = found;
if (demo == null) throw new System.Exception("Adventure scene is not open");
var fields = new UnityEditor.SerializedObject(demo);
var rig = (ProjectY.Samples.PawnView)fields.FindProperty("pawnPrefab").objectReferenceValue;
var shader = (Shader)fields.FindProperty("previewShader").objectReferenceValue;
var bindings = fields.FindProperty("assetBindings"); var bound = new System.Collections.Generic.Dictionary<int, GameObject>();
for (var i = 0; i < bindings.arraySize; i++)
{
    var row = bindings.GetArrayElementAtIndex(i); var model = (GameObject)row.FindPropertyRelative("prefab").objectReferenceValue;
    if (model == null) throw new System.Exception("Missing serialized building asset");
    bound.Add(row.FindPropertyRelative("id").intValue, model);
}
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var manager = UnityEngine.Rendering.VolumeManager.instance; var oldStack = manager.stack; var stack = manager.CreateStack(); manager.stack = stack;
var target = new RenderTexture(1600, 1000, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear); target.Create();
var readback = new Texture2D(1600, 1000, TextureFormat.RGBAFloat, false, true); var image = new Texture2D(1600, 1000, TextureFormat.RGB24, false);
var previous = RenderTexture.active; var outputs = new System.Collections.Generic.List<string>();
ProjectY.Samples.MapEnvironmentController environmentController = null;
ProjectY.Samples.MapAreaRenderer renderer = null; ProjectY.Samples.SquadPawnRenderer squad = null; ProjectY.Samples.TownNpcRenderer npcs = null;
var checks = new System.Collections.Generic.List<object>(); var currentLayout = -1;
try
{
    var host = new GameObject("Open Building Preview"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var cameraObject = new GameObject("Camera", typeof(Camera)); cameraObject.transform.SetParent(host.transform, false);
    var camera = cameraObject.GetComponent<Camera>(); camera.enabled = false; camera.scene = scene; camera.targetTexture = target;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic = true; camera.aspect = 1.6f; camera.nearClipPlane = .1f; camera.farClipPlane = 800;
    var lightObject = new GameObject("Sun", typeof(Light)); lightObject.transform.SetParent(host.transform, false);
    var light = lightObject.GetComponent<Light>(); light.type = LightType.Directional; light.shadows = LightShadows.Soft;
    environmentController = new ProjectY.Samples.MapEnvironmentController(lighting, light, camera, host.transform); environmentController.Running = false; environmentController.Hour = 12;
    System.Func<ProjectY.Samples.PawnAppearanceData.Part, GameObject> pawnAsset = part => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(part.Path);
    for (var n = 0; n < views.Count; n++)
    {
        var layout = layouts[layoutIds[n]]; var view = views[n]; var prop = layout.Props[propIds[n]]; var state = view.Area;
        if (currentLayout != layoutIds[n])
        {
            if (renderer != null) renderer.Dispose();
            foreach (var asset in layout.PropAssets)
                if (UnityEditor.AssetDatabase.GetAssetPath(bound[asset.Id]) != asset.Path) throw new System.Exception("Building scene binding differs from config: " + asset.Id);
            renderer = new ProjectY.Samples.MapAreaRenderer(shader, bound[layout.AssetId], layout, asset => bound[asset.Id]);
            environmentController.SetArea(layout); currentLayout = layoutIds[n];
        }
        // Captures skip hundreds of authoritative movement frames. Instantiate at each captured position.
        if (squad != null) squad.Dispose(); if (npcs != null) npcs.Dispose();
        squad = new ProjectY.Samples.SquadPawnRenderer(host.transform, rig, pawnAsset); npcs = new ProjectY.Samples.TownNpcRenderer(host.transform, rig, layout, pawnAsset);
        renderer.UpdateVisibility(state, false); squad.SetState(state, view.Party, layout); squad.Skip(); npcs.SetState(state, layout); npcs.Tick(1);
        bool inside = names[n].EndsWith("-inside");
        if (renderer.IsInteriorOpen(interiorIds[n]) != inside) throw new System.Exception("Building cover failed to hide/restore: " + names[n]);
        if (inside)
        {
            var leader = layout.Cells[state.CellIndex];
            if (leader.InteriorId != interiorIds[n] || renderer.Pick(new Ray(leader.Position + Vector3.up * 1.8f, Vector3.down)) != state.CellIndex)
                throw new System.Exception("Interior cell could not be picked: " + names[n]);
        }
        var rotation = Quaternion.Euler(50, prop.Rotation + 165, 0);
        var focus = prop.Position + Vector3.up * (inside ? .5f : 2.2f);
        camera.orthographicSize = assetIds[n] == 55 ? 12.5f : assetIds[n] == 56 ? 9f : assetIds[n] >= 113 ? 6.3f : 8.4f;
        camera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * 250, rotation);
        environmentController.Hour = 12; environmentController.Tick(3, state); environmentController.ApplyCameraFocus(focus);
        manager.Update(stack, camera.transform, 1); renderer.Draw(camera); ProjectY.Rendering.UrpCameraRendering.Render(camera);
        RenderTexture.active = target; readback.ReadPixels(new Rect(0, 0, 1600, 1000), 0, 0); readback.Apply();
        var linear = readback.GetPixels(); var encoded = new Color32[linear.Length];
        for (var i = 0; i < linear.Length; i++) encoded[i] = linear[i].gamma;
        if (encoded.Count(c => c.r > 230 && c.b > 230 && c.g < 30) > 100) throw new System.Exception("Missing material shader: " + names[n]);
        image.SetPixels32(encoded); image.Apply();
        var path = root + "/Previews/" + names[n] + ".png"; System.IO.File.WriteAllBytes(path, image.EncodeToPNG()); outputs.Add(path);
        checks.Add(new { name = names[n], asset = assetIds[n], members = state.Members.Length, interiorOpen = inside, cameraPitch = camera.transform.eulerAngles.x });
        System.IO.File.WriteAllText(root + "/Integration/preview-progress.txt", "Rendered " + (n + 1) + "/" + views.Count + ": " + names[n]);
    }
    var result = new { playMode = false, navigationFrames, layoutCount = layouts.Count, checks, images = outputs };
    System.IO.File.WriteAllText(root + "/Integration/preview.json", Newtonsoft.Json.JsonConvert.SerializeObject(result, Newtonsoft.Json.Formatting.Indented));
    return result;
}
finally
{
    if (npcs != null) npcs.Dispose(); if (squad != null) squad.Dispose(); if (renderer != null) renderer.Dispose(); if (environmentController != null) environmentController.Dispose();
    manager.stack = oldStack; manager.DestroyStack(stack); RenderTexture.active = previous;
    target.Release(); UnityEngine.Object.DestroyImmediate(target); UnityEngine.Object.DestroyImmediate(readback); UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (original.isDirty != dirty || UnityEngine.SceneManagement.SceneManager.GetActiveScene() != original || QualitySettings.renderPipeline != pipeline || RenderSettings.skybox != skybox)
        throw new System.Exception("Preview changed the editing scene or render pipeline");
}
