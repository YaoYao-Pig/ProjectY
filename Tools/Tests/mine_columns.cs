// Unity MCP execute_code method body; in-memory geometry only, no rendering or scene/asset writes.
// Run after the authorized compilation, independently of the mine traversal/preview fixture.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/ForestAnimals/Models/ForestGround.fbx");
if (shader == null || prefab == null) throw new System.Exception("Mine column resources unavailable");
var map = new ProjectY.Samples.MapAreaViewData
{
    AreaType = 6, Radius = 1, TintMaterial = "M_MapLP_ForestGround",
    Props = System.Array.Empty<ProjectY.Samples.MapAreaViewData.Prop>(),
    PropAssets = System.Array.Empty<ProjectY.Samples.MapAreaViewData.Asset>()
};
map.Surfaces.Add(0, new ProjectY.Samples.MapAreaViewData.Surface { Color = Color.gray, DetailColor = Color.gray });
System.Func<int, int, float, string, int, ProjectY.Samples.MapAreaViewData.Cell> cell = (q, layer, height, kind, group) =>
    new ProjectY.Samples.MapAreaViewData.Cell
    {
        Q = q, R = 0, Layer = layer, Position = new Vector3(q * Mathf.Sqrt(3), height, 0),
        BasePosition = new Vector3(q * Mathf.Sqrt(3), height, 0), GroundHeight = height,
        Kind = kind, Blocked = kind == "wall", RenderGround = kind != "void", WallHeight = 2.8f,
        DeckThickness = group > 0 ? .35f : 0, Corners = new[] { height, height, height, height, height, height },
        BaseCorners = new[] { height, height, height, height, height, height }, Color = Color.gray,
        Neighbors = new[] { -1, -1, -1, -1, -1, -1 }, CutawayGroup = group, CutawayLayer = layer
    };
map.Cells = new[] { cell(0, 0, 0, "floor", 1), cell(0, 1, 5, "wall", 1), cell(2, 1, 5, "floor", 1), cell(4, 0, 0, "void", 0), cell(6, 0, 2, "wall", 0) };
var state = new ProjectY.Samples.MapAreaViewData.State
{
    Revision = 1, Known = new[] { 0, 1, 2, 3, 4 }, Visible = new[] { 0, 1, 2, 3, 4 },
    Members = new[] { new ProjectY.Samples.MapAreaViewData.Member { ActorId = 1, CellIndex = 2 } }
};
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic;
using (var renderer = new ProjectY.Samples.MapAreaRenderer(shader, prefab, map, asset => throw new System.Exception("Unexpected prop lookup")))
{
    renderer.UpdateVisibility(state, false);
    var batches = (System.Collections.IList)typeof(ProjectY.Samples.MapAreaRenderer).GetField("batches", flags).GetValue(renderer);
    var matrices = (Matrix4x4[])batches[0].GetType().GetField("Matrices").GetValue(batches[0]);
    var columns = (System.Collections.Generic.List<int>)typeof(ProjectY.Samples.MapAreaRenderer).GetField("columnCells", flags).GetValue(renderer);
    if (columns.Count != 2 || !columns.Contains(1) || !columns.Contains(4)) throw new System.Exception("Column cache contains voids or surface floors");
    var bounds = prefab.GetComponent<MeshFilter>().sharedMesh.bounds;
    var drawnBottom = matrices[1].MultiplyPoint3x4(new Vector3(0, bounds.min.y, 0)).y;
    var drawnTop = matrices[1].MultiplyPoint3x4(new Vector3(0, bounds.max.y, 0)).y;
    if (Mathf.Abs(drawnBottom - 4.65f) > .001f || Mathf.Abs(drawnTop - 7.8f) > .001f)
        throw new System.Exception("Upper wall mesh does not occupy its own slab-to-wall interval: " + drawnBottom + ".." + drawnTop);
    var under = new Ray(new Vector3(-2, 1, 0), Vector3.right);
    if (renderer.TerrainDistance(under, 4) != 4) throw new System.Exception("Upper wall filled the lower gallery");
    var side = new Ray(new Vector3(-3, 6, 0), Vector3.right);
    var expected = 3 - Mathf.Sqrt(3) / 2;
    if (renderer.Pick(side) != 1 || Mathf.Abs(renderer.TerrainDistance(side, 5) - expected) > .001f)
        throw new System.Exception("Upper wall side picking and camera distance disagree");
    if (renderer.Pick(new Ray(new Vector3(0, 20, 0), Vector3.down)) != 1)
        throw new System.Exception("Upper wall top did not occlude the lower floor");
    // Moving the leader below cuts the upper wall for draw, pick, and camera together.
    state.Revision++; state.Members[0].CellIndex = 0; renderer.UpdateVisibility(state, false);
    if (renderer.IsCellShown(1) || matrices[1].lossyScale.sqrMagnitude > .000001f)
        throw new System.Exception("Known cut wall still renders");
    if (renderer.Pick(new Ray(new Vector3(0, 20, 0), Vector3.down)) != 0 || renderer.TerrainDistance(side, 5) != 5)
        throw new System.Exception("Cut wall still intercepts floor picking or camera distance");
    // Unknown upper wall fog must obey the same cut; base voids must never acquire proxy geometry.
    state.Revision++; state.Known = new[] { 0, 2, 4 }; state.Visible = state.Known; renderer.UpdateVisibility(state, false);
    if (matrices[1].lossyScale.sqrMagnitude > .000001f || matrices[3].lossyScale.sqrMagnitude > .000001f)
        throw new System.Exception("Unknown cut wall or void left an opaque proxy");
    state.Revision++; state.Known = new[] { 0, 1, 2, 3, 4 }; state.Visible = state.Known; state.Members[0].CellIndex = 2; renderer.UpdateVisibility(state, false);
    if (!renderer.IsCellShown(1) || matrices[1].lossyScale.sqrMagnitude <= .000001f || renderer.Pick(side) != 1)
        throw new System.Exception("Upper wall failed to restore after ascending");
    // Legacy layer-zero wall still participates in picking and uses its drawn bottom for collision.
    var legacy = map.Cells[4]; var below = matrices[4].MultiplyPoint3x4(new Vector3(0, bounds.min.y, 0));
    var upward = new Ray(new Vector3(legacy.Position.x, below.y - 1, 0), Vector3.up);
    if (renderer.Pick(upward) != 4 || Mathf.Abs(renderer.TerrainDistance(upward, 10) - 1) > .001f)
        throw new System.Exception("Legacy column drawing and picking have different bottoms");
    for (var i = 0; i < 16; i++) { renderer.Pick(side); renderer.TerrainDistance(under, 4); }
    var method = typeof(System.GC).GetMethod("GetAllocatedBytesForCurrentThread", System.Type.EmptyTypes);
    if (method != null)
    {
        var allocated = (System.Func<long>)System.Delegate.CreateDelegate(typeof(System.Func<long>), method);
        var before = allocated();
        for (var i = 0; i < 256; i++) { renderer.Pick(side); renderer.TerrainDistance(under, 4); }
        var bytes = allocated() - before;
        if (bytes != 0) throw new System.Exception("Column queries allocated managed bytes: " + bytes);
    }
}
return "PASS mine wall interval, lower gallery clearance, side/top picking, cutaway/fog restoration, legacy column agreement, and zero query allocation";
