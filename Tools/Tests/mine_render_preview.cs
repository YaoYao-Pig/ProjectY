// Unity MCP execute_code 方法体；当前 Editor 的独立数据和 PreviewScene，不进入 Play。
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
var layouts = new System.Collections.Generic.List<ProjectY.Samples.MapAreaViewData>();
var views = new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData>();
var names = new System.Collections.Generic.List<string>();
var focusIndices = new System.Collections.Generic.List<int>();
var lowerIndices = new System.Collections.Generic.List<int>();
System.IO.Directory.CreateDirectory("Docs/Previews/Mine");
var cached = System.AppDomain.CurrentDomain.GetData("ProjectY.MineReview") as object[];
if (cached != null)
{
    layouts = (System.Collections.Generic.List<ProjectY.Samples.MapAreaViewData>)cached[0];
    views = (System.Collections.Generic.List<ProjectY.Samples.AdventureViewData>)cached[1];
    names = (System.Collections.Generic.List<string>)cached[2];
    focusIndices = (System.Collections.Generic.List<int>)cached[3]; lowerIndices = (System.Collections.Generic.List<int>)cached[4];
}
else
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null);
    var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
    try
    {
        var output = lua.DoString(System.IO.File.ReadAllText("Tools/Tests/mine_integration_preview.lua"));
        using (var rows = (XLua.LuaTable)output[0]) for (int i = 1; i <= rows.Length; i++)
        using (var row = rows.Get<int, XLua.LuaTable>(i))
        using (var layout = row.Get<XLua.LuaTable>("layout"))
        using (var view = row.Get<XLua.LuaTable>("view"))
        {
            names.Add(row.Get<string>("name")); focusIndices.Add(row.Get<int>("focusIndex") - 1); lowerIndices.Add(row.Get<int>("lowerTargetIndex") - 1);
            layouts.Add(ProjectY.Samples.MapAreaViewData.Read(layout)); views.Add(ProjectY.Samples.AdventureViewData.Read(view));
        }
    }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
// 只缓存本次检查的托管显示快照；改 Lua 后清除此键，不持有 LuaEnv 或场景对象。
System.AppDomain.CurrentDomain.SetData("ProjectY.MineReview", new object[] { layouts, views, names, focusIndices, lowerIndices });
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var wasDirty = originalScene.isDirty;
ProjectY.Samples.AdventureRuntimeDemo demo = null;
foreach (var root in originalScene.GetRootGameObjects()) foreach (var value in root.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)) demo = value;
if (demo == null) throw new System.Exception("Adventure scene required");
var fields = new UnityEditor.SerializedObject(demo);
var rig = (ProjectY.Samples.PawnView)fields.FindProperty("pawnPrefab").objectReferenceValue;
var shader = (Shader)fields.FindProperty("previewShader").objectReferenceValue;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var target = new RenderTexture(1440, 1000, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
var pixels = new Texture2D(1440, 1000, TextureFormat.RGBAFloat, false, true);
var image = new Texture2D(1440, 1000, TextureFormat.RGB24, false);
var previousTarget = RenderTexture.active; target.Create();
var checks = new System.Collections.Generic.List<object>(); var paths = new System.Collections.Generic.List<string>();
try
{
    var host = new GameObject("Mine Preview"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var cameraObject = new GameObject("Camera", typeof(Camera)); cameraObject.transform.SetParent(host.transform, false);
    var camera = cameraObject.GetComponent<Camera>(); camera.scene = scene; camera.enabled = false; camera.targetTexture = target;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.055f, .065f, .073f); camera.aspect = 1.44f;
    var lightObject = new GameObject("Sun", typeof(Light)); lightObject.transform.SetParent(host.transform, false);
    var sun = lightObject.GetComponent<Light>(); sun.type = LightType.Directional; sun.intensity = 1.2f;
    sun.color = new Color(1, .90f, .75f); sun.shadows = LightShadows.Soft; lightObject.transform.rotation = Quaternion.Euler(55, -25, 0);
    for (int n = 0; n < layouts.Count; n++)
    {
        var layout = layouts[n]; var view = views[n]; var state = view.Area; var leader = layout.Cells[state.CellIndex];
        System.Func<ProjectY.Samples.MapAreaViewData.Asset, GameObject> resolve = asset => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path);
        using (var renderer = new ProjectY.Samples.MapAreaRenderer(shader, UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(layout.AssetPath), layout, resolve))
        using (var squad = new ProjectY.Samples.SquadPawnRenderer(host.transform, rig, part => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(part.Path)))
        {
            renderer.UpdateVisibility(state, false); squad.SetState(state, view.Party, layout); squad.Skip();
            int hidden = 0, shownLower = 0;
            for (int i = 0; i < layout.Cells.Length; i++)
            {
                var cell = layout.Cells[i];
                if (cell.CutawayGroup == leader.CutawayGroup && cell.CutawayLayer > leader.Layer)
                { if (renderer.IsCellShown(i)) throw new System.Exception("Upper layer did not cut away"); hidden++; }
                if (cell.Layer < leader.Layer && renderer.IsCellShown(i) && !cell.Blocked) shownLower++;
            }
            if (renderer.Pick(new Ray(leader.Position + Vector3.up * 1.6f, Vector3.down)) != state.CellIndex)
                throw new System.Exception("Leader floor picked wrong layer");
            if (lowerIndices[n] >= 0)
            {
                var lower = layout.Cells[lowerIndices[n]];
                if (!renderer.IsCellShown(lowerIndices[n]) || shownLower == 0) throw new System.Exception("Collapsed opening did not expose a lower floor");
                if (renderer.Pick(new Ray(new Vector3(lower.Position.x, leader.Position.y + 4, lower.Position.z), Vector3.down)) != lowerIndices[n])
                    throw new System.Exception("Opening ray did not reach lower floor");
            }
            var focus = layout.Cells[focusIndices[n]].Position;
            if (lowerIndices[n] >= 0) focus.y = (focus.y + leader.Position.y) * .5f;
            var rotation = Quaternion.Euler(56, -28, 0);
            camera.orthographic = true; camera.orthographicSize = lowerIndices[n] >= 0 ? 13 : 15;
            camera.nearClipPlane = .1f; camera.farClipPlane = 600;
            camera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * 300, rotation);
            renderer.Draw(camera); ProjectY.Rendering.UrpCameraRendering.Render(camera);
            RenderTexture.active = target; pixels.ReadPixels(new Rect(0, 0, 1440, 1000), 0, 0); pixels.Apply();
            var linear = pixels.GetPixels(); var encoded = new Color32[linear.Length];
            for (int i = 0; i < linear.Length; i++) encoded[i] = linear[i].gamma;
            image.SetPixels32(encoded); image.Apply();
            var path = "Docs/Previews/Mine/" + names[n] + ".png"; System.IO.File.WriteAllBytes(path, image.EncodeToPNG()); paths.Add(path);
            checks.Add(new { name = names[n], layer = leader.Layer, members = state.Members.Length, hiddenUpper = hidden, shownLower });
        }
    }
    var result = new { playMode = false, checks, images = paths };
    System.IO.File.WriteAllText("Docs/Previews/Mine/render-validation.json", Newtonsoft.Json.JsonConvert.SerializeObject(result, Newtonsoft.Json.Formatting.Indented));
    return result;
}
finally
{
    RenderTexture.active = previousTarget; target.Release(); UnityEngine.Object.DestroyImmediate(target);
    UnityEngine.Object.DestroyImmediate(pixels); UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (originalScene.isDirty != wasDirty || UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene) throw new System.Exception("Mine preview changed active scene");
}
