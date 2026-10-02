// Execute as a Unity MCP method body after the one requested C# compilation. Edit Mode only.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
var layouts = new System.Collections.Generic.List<ProjectY.Samples.MapAreaViewData>();
var views = new System.Collections.Generic.List<ProjectY.Samples.AdventureViewData>();
var names = new System.Collections.Generic.List<string>();
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null); var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
    lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
    try
    {
        var output = lua.DoString(System.IO.File.ReadAllText("Tools/Tests/maparea_multilevel_preview.lua"));
        using (var rows = (XLua.LuaTable)output[0]) for (var i = 1; i <= rows.Length; i++)
        using (var row = rows.Get<int, XLua.LuaTable>(i))
        using (var layout = row.Get<XLua.LuaTable>("layout"))
        using (var view = row.Get<XLua.LuaTable>("view"))
        { names.Add(row.Get<string>("name")); layouts.Add(ProjectY.Samples.MapAreaViewData.Read(layout)); views.Add(ProjectY.Samples.AdventureViewData.Read(view)); }
    }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var wasDirty = originalScene.isDirty;
ProjectY.Samples.AdventureRuntimeDemo demo = null;
foreach (var root in originalScene.GetRootGameObjects()) foreach (var value in root.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)) demo = value;
if (demo == null) throw new System.Exception("Adventure scene is not open");
var fields = new UnityEditor.SerializedObject(demo);
var rig = (ProjectY.Samples.PawnView)fields.FindProperty("pawnPrefab").objectReferenceValue;
var shader = (Shader)fields.FindProperty("previewShader").objectReferenceValue;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var target = new RenderTexture(1600, 1000, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
var pixels = new Texture2D(1600, 1000, TextureFormat.RGBAFloat, false, true);
var image = new Texture2D(1600, 1000, TextureFormat.RGB24, false);
var previousTarget = RenderTexture.active; target.Create();
var checks = new System.Collections.Generic.List<object>(); var paths = new System.Collections.Generic.List<string>();
System.IO.Directory.CreateDirectory("Docs/Previews/MapArea");
try
{
    var host = new GameObject("Multilevel Preview"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var cameraObject = new GameObject("Camera", typeof(Camera)); cameraObject.transform.SetParent(host.transform, false);
    var camera = cameraObject.GetComponent<Camera>(); camera.scene = scene; camera.enabled = false; camera.targetTexture = target;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.10f, .14f, .19f); camera.aspect = 1.6f;
    var lightObject = new GameObject("Sun", typeof(Light)); lightObject.transform.SetParent(host.transform, false);
    var sun = lightObject.GetComponent<Light>(); sun.type = LightType.Directional; sun.intensity = 1.15f;
    sun.color = new Color(1, .95f, .84f); sun.shadows = LightShadows.Soft; lightObject.transform.rotation = Quaternion.Euler(48, -35, 0);
    for (var n = 0; n < layouts.Count; n++)
    {
        var layout = layouts[n]; var view = views[n]; var state = view.Area; var name = names[n];
        System.Func<ProjectY.Samples.MapAreaViewData.Asset, GameObject> resolve = asset => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path);
        using (var renderer = new ProjectY.Samples.MapAreaRenderer(shader, UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(layout.AssetPath), layout, resolve))
        using (var squad = new ProjectY.Samples.SquadPawnRenderer(host.transform, rig, part => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(part.Path)))
        using (var npcs = layout.IsTown ? new ProjectY.Samples.TownNpcRenderer(host.transform, rig, layout, part => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(part.Path)) : null)
        {
            renderer.UpdateVisibility(state, !layout.IsTown); squad.SetState(state, view.Party, layout); squad.Skip();
            if (npcs != null) { npcs.SetState(state, layout); npcs.Tick(1); }
            int upper = 0, hidden = 0, stairCount = 0, samples = 0;
            var leader = layout.Cells[state.CellIndex];
            for (var i = 0; i < layout.Cells.Length; i++)
            {
                var cell = layout.Cells[i];
                if (cell.InteriorId == leader.InteriorId && leader.InteriorId > 0 && cell.Layer > 0 && cell.Kind != "stairs")
                { upper++; if (!renderer.IsCellShown(i)) hidden++; }
                if (cell.StairRise <= 0 || cell.Blocked) continue;
                stairCount++;
                var ground = ProjectY.Samples.TownSurfaceRenderer.Ground(layout, i, i, cell.Position);
                if (Mathf.Abs(ground.y - (Mathf.Floor(cell.Position.y / cell.StairRise + .0001f) * cell.StairRise + .015f)) > .001f)
                    throw new System.Exception("Stair foot height differs");
                for (var d = 0; d < 6; d++)
                {
                    int next = cell.Neighbors[d]; if (next < 0 || (cell.WalkMask & (1 << d)) == 0 || layout.Cells[next].Blocked) continue;
                    for (var k = 0; k <= 8; k++)
                    { ProjectY.Samples.TownSurfaceRenderer.Ground(layout, i, next, Vector3.Lerp(cell.Position, layout.Cells[next].Position, k / 8f)); samples++; }
                }
            }
            if (name.EndsWith("ground") && (upper == 0 || hidden != upper)) throw new System.Exception("Upper floor did not cut away");
            if (name.EndsWith("upper") && (upper == 0 || hidden != 0)) throw new System.Exception("Upper floor was hidden upstairs");
            if (name.EndsWith("upper"))
            {
                var picked = renderer.Pick(new Ray(leader.Position + Vector3.up * 1.8f, Vector3.down));
                if (picked != state.CellIndex) throw new System.Exception("Upper click selected the lower floor: " + picked);
            }
            if (layout.IsTown)
            {
                var walk = new ProjectY.Samples.TownWalkCamera(layout, state, renderer.CameraObstacles, renderer.TerrainDistance);
                walk.Apply(camera, squad.Position(state.Members[0].ActorId));
            }
            else
            {
                var stair = state.CellIndex;
                if (stair < 0) throw new System.Exception("Dungeon contains no stair surface");
                var focus = layout.Cells[stair].Position; var rotation = Quaternion.Euler(50, -35, 0);
                camera.orthographic = true; camera.orthographicSize = layout.Radius * 10; camera.nearClipPlane = .1f; camera.farClipPlane = 800;
                camera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * 400, rotation);
                // A charging pawn crosses every intermediate stair cell, instead of sampling one long edge.
                bool charged = false;
                for (int i = 0; i < layout.Cells.Length && !charged; i++)
                {
                    var cell = layout.Cells[i]; if (cell.Blocked || cell.StairRise <= 0) continue;
                    for (int d = 0; d < 6 && !charged; d++)
                    {
                        int end = i;
                        for (int step = 0; step < 4; step++)
                        { var from = layout.Cells[end]; int next = from.Neighbors[d]; if (next < 0 || (from.WalkMask & (1 << d)) == 0 || layout.Cells[next].Blocked) { end = -1; break; } end = next; }
                        if (end < 0) continue;
                        var pawn = new GameObject("ChargeCheck"); pawn.transform.SetParent(host.transform, false);
                        try
                        {
                            var motion = new ProjectY.Samples.PawnMotion(pawn.transform, i, layout); motion.Speed = 9;
                            motion.SetDestination(end, new System.Collections.Generic.HashSet<int>(), null, "charge");
                            for (int step = 0; step < 200 && motion.Moving; step++) motion.Tick(.02f);
                            if (motion.Moving) throw new System.Exception("Stair charge never finished"); charged = true;
                        }
                        finally { UnityEngine.Object.DestroyImmediate(pawn); }
                    }
                }
                if (!charged) throw new System.Exception("Missing stair charge fixture");
                var known = state.Known; var visible = state.Visible; state.Known = state.Visible = new int[0]; state.Revision++;
                renderer.UpdateVisibility(state, false);
                if (renderer.IsCellShown(stair) || renderer.Pick(new Ray(focus + Vector3.up, Vector3.down)) >= 0) throw new System.Exception("Unknown stair leaked through fog");
                state.Known = known; state.Visible = visible; state.Revision++; renderer.UpdateVisibility(state, true);
            }
            renderer.Draw(camera); ProjectY.Rendering.UrpCameraRendering.Render(camera);
            RenderTexture.active = target; pixels.ReadPixels(new Rect(0, 0, 1600, 1000), 0, 0); pixels.Apply();
            var linear = pixels.GetPixels(); var encoded = new Color32[linear.Length];
            for (int i = 0; i < linear.Length; i++) encoded[i] = linear[i].gamma;
            image.SetPixels32(encoded); image.Apply();
            var path = "Docs/Previews/MapArea/" + name + ".png"; System.IO.File.WriteAllBytes(path, image.EncodeToPNG()); paths.Add(path);
            checks.Add(new { name, members = state.Members.Length, stairCount, surfaceSamples = samples, upperFloorCells = upper, hiddenUpperCells = hidden, cameraPitch = camera.transform.eulerAngles.x, fieldOfView = camera.fieldOfView });
        }
    }
    var result = new { playMode = false, checks, images = paths };
    System.IO.File.WriteAllText("Docs/Previews/MapArea/multilevel-validation.json", Newtonsoft.Json.JsonConvert.SerializeObject(result, Newtonsoft.Json.Formatting.Indented));
    return result;
}
finally
{
    RenderTexture.active = previousTarget; target.Release(); UnityEngine.Object.DestroyImmediate(target);
    UnityEngine.Object.DestroyImmediate(pixels); UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (originalScene.isDirty != wasDirty || UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene) throw new System.Exception("Preview changed the active scene");
}
