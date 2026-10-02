// Unity MCP execute_code method body. Bounded Edit Mode CPU benchmark; no rendering or saved scene changes.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
const int areaId = 6, iterations = 128;
const string outputPath = "Docs/Previews/MapArea/movement-performance-before.json";
ProjectY.Samples.MapAreaViewData layout;
int entry, goal;
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null);
    var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
    lua.AddLoader(loader.Load); lua.Global.Set("Services", services); lua.Global.Set("PerfAreaId", areaId);
    try
    {
        var values = lua.DoString(@"
local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local area=generator:Generate(PerfAreaId,20260925,11,{regionId=7,regionType=1,regionConfigId=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}}})
local reader={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
local snapshot=require('Game.MapArea.MapAreaSystem').LayoutSnapshot(reader)
config:OnShutdown()
return snapshot,area.entryIndex,area.goalIndex
");
        using (var table = (XLua.LuaTable)values[0]) layout = ProjectY.Samples.MapAreaViewData.Read(table);
        entry = System.Convert.ToInt32(values[1]) - 1; goal = System.Convert.ToInt32(values[2]) - 1;
    }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalDirty = originalScene.isDirty;
var preview = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapAreaRenderer renderer = null;
ProjectY.Samples.ExplorationGridRenderer grid = null;
var results = new System.Collections.Generic.List<string>();
var culture = System.Globalization.CultureInfo.InvariantCulture;
System.Action<string, System.Action<int>> measure = (name, action) =>
{
    for (var i = 0; i < 8; i++) action(i);
    var samples = new double[iterations];
    var clock = new System.Diagnostics.Stopwatch();
    for (var i = 0; i < iterations; i++)
    {
        clock.Restart(); action(i); clock.Stop(); samples[i] = clock.Elapsed.TotalMilliseconds;
    }
    double total = 0; foreach (var sample in samples) total += sample;
    System.Array.Sort(samples);
    results.Add("{\"name\":\"" + name + "\",\"iterations\":" + iterations +
        ",\"meanMs\":" + (total / iterations).ToString("F6", culture) +
        ",\"p95Ms\":" + samples[(iterations * 95) / 100].ToString("F6", culture) +
        ",\"maxMs\":" + samples[iterations - 1].ToString("F6", culture) + "}");
};
try
{
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    var ground = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(layout.AssetPath);
    renderer = new ProjectY.Samples.MapAreaRenderer(shader, ground, layout,
        asset => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
    var all = new int[layout.Cells.Length]; var shown = new bool[layout.Cells.Length];
    var publicCells = new System.Collections.Generic.List<int>();
    for (var i = 0; i < all.Length; i++)
    {
        all[i] = i; shown[i] = true;
        if (!layout.Cells[i].Blocked && layout.Cells[i].InteriorId == 0) publicCells.Add(i);
    }
    if (publicCells.Count == 0) throw new System.InvalidOperationException("No public cells for camera samples");
    var state = new ProjectY.Samples.MapAreaViewData.State
    {
        Revision = 1, Known = all, Visible = all, CellIndex = entry, EntryIndex = entry, GoalIndex = goal,
        Route = System.Array.Empty<int>(), Npcs = System.Array.Empty<ProjectY.Samples.MapAreaViewData.NpcState>(),
        Members = new[] { new ProjectY.Samples.MapAreaViewData.Member { ActorId = 1, CellIndex = entry } }
    };
    renderer.UpdateVisibility(state, false);
    var field = typeof(ProjectY.Samples.MapAreaRenderer).GetField("townSurface", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
    var surface = (ProjectY.Samples.TownSurfaceRenderer)field.GetValue(renderer);
    if (surface == null) throw new System.InvalidOperationException("Town surface missing");
    var points = new Vector3[iterations];
    for (var i = 0; i < points.Length; i++) points[i] = layout.Cells[publicCells[(i * 487 + 17) % publicCells.Count]].Position;
    int picked = -1; float hit = 0;
    var backward = -(Quaternion.Euler(50, -35, 0) * Vector3.forward);
    measure("surfaceVerticalPick", i => hit = surface.Raycast(new Ray(points[i] + Vector3.up * 45, Vector3.down), 90, out picked));
    measure("mapAreaVerticalPick", i => picked = renderer.Pick(new Ray(points[i] + Vector3.up * 45, Vector3.down)));
    measure("surfaceCameraClearanceRay", i => hit = surface.Raycast(new Ray(points[i] + Vector3.up * 1.25f, backward), 28, out picked));
    var cameraObject = new GameObject("MapArea CPU Benchmark Camera", typeof(Camera));
    cameraObject.hideFlags = HideFlags.HideAndDontSave;
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, preview);
    var camera = cameraObject.GetComponent<Camera>(); camera.enabled = false; camera.scene = preview;
    int cameraRays = 0;
    var follow = new ProjectY.Samples.TownWalkCamera(layout, state, renderer.CameraObstacles,
        (ray, limit) => { cameraRays++; return renderer.TerrainDistance(ray, limit); });
    measure("townCameraApplyAtPublicCells", i => follow.Apply(camera, points[i]));
    var actualCameraRays = cameraRays;
    // A controlled persistent occluder exercises all six default-pitch candidates.
    // It is a private Bounds list, not a scene object or a change to production obstacles.
    var blocked = new System.Collections.Generic.List<Bounds>();
    cameraRays = 0;
    var constrained = new ProjectY.Samples.TownWalkCamera(layout, state, blocked,
        (ray, limit) => { cameraRays++; return renderer.TerrainDistance(ray, limit); });
    measure("townCameraApplySixCandidates", i =>
    {
        blocked.Clear(); blocked.Add(new Bounds(points[i] + Vector3.up * 4.25f, new Vector3(30, .2f, 30)));
        constrained.Apply(camera, points[i]);
    });
    var constrainedCameraRays = cameraRays;
    measure("surfaceVisibilityUnchanged", i => surface.SetVisibility(shown));
    measure("surfaceVisibilityOneCellToggle", i => { shown[entry] = !shown[entry]; surface.SetVisibility(shown); });
    shown[entry] = true; surface.SetVisibility(shown);
    measure("mapAreaVisibilityRevisionPublicMove", i =>
    {
        state.Members[0].CellIndex = publicCells[(i * 487 + 17) % publicCells.Count];
        state.Revision++; renderer.UpdateVisibility(state, false);
    });
    grid = new ProjectY.Samples.ExplorationGridRenderer(layout, new ProjectY.Samples.ExplorationGridRenderer.Settings(), renderer.IsCellShown);
    measure("explorationGridPublicMove", i =>
    {
        state.Members[0].CellIndex = publicCells[(i * 487 + 17) % publicCells.Count]; state.Revision++;
        grid.SetState(state, true);
    });
    var json = "{\"areaId\":" + areaId + ",\"cellCount\":" + layout.Cells.Length +
        ",\"surfaceVertices\":" + surface.Mesh.vertexCount + ",\"surfaceIndices\":" + surface.Mesh.GetIndexCount(0) +
        ",\"cameraObstacleCount\":" + renderer.CameraObstacles.Count +
        ",\"cameraSamplesIncludingWarmup\":" + (iterations + 8) +
        ",\"actualCameraRays\":" + actualCameraRays + ",\"constrainedCameraRays\":" + constrainedCameraRays +
        ",\"rendered\":false,\"playMode\":false,\"measurements\":[" + string.Join(",", results) + "]}";
    System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(outputPath));
    System.IO.File.WriteAllText(outputPath, json, new System.Text.UTF8Encoding(false));
    Debug.Log(json);
}
finally
{
    grid?.Dispose(); renderer?.Dispose(); UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);
}
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != originalDirty)
    throw new System.InvalidOperationException("Benchmark changed the active scene or its dirty state");
return System.IO.File.ReadAllText(outputPath);
