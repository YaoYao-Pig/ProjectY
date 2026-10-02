// Unity MCP execute_code method body. Real layouts, bounded rays, and the former exhaustive algorithm.
// Does not enter Play, render, create a scene object, or modify any saved scene/asset.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var layouts = new System.Collections.Generic.List<ProjectY.Samples.MapAreaViewData>();
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null);
    var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
    lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
    try
    {
        var result = lua.DoString(@"
local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
local result={}
for _,id in ipairs({6,1}) do
    local area=generator:Generate(id,20260925,11,{regionId=7,regionType=1,regionConfigId=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}}})
    local reader={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
    result[#result+1]=require('Game.MapArea.MapAreaSystem').LayoutSnapshot(reader)
end
config:OnShutdown()
return result
");
        using (var values = (XLua.LuaTable)result[0])
            for (var i = 1; i <= values.Length; i++) using (var value = values.Get<int, XLua.LuaTable>(i))
                layouts.Add(ProjectY.Samples.MapAreaViewData.Read(value));
    }
    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
}
var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic;
var surfaceType = typeof(ProjectY.Samples.TownSurfaceRenderer);
var reports = new System.Collections.Generic.List<string>();
var culture = System.Globalization.CultureInfo.InvariantCulture;
var allocationMethod = typeof(System.GC).GetMethod("GetAllocatedBytesForCurrentThread", System.Type.EmptyTypes);
var allocated = allocationMethod == null ? null : (System.Func<long>)System.Delegate.CreateDelegate(typeof(System.Func<long>), allocationMethod);
foreach (var map in layouts)
{
    using (var surface = new ProjectY.Samples.TownSurfaceRenderer(shader, map, cell => cell.RenderGround && (map.IsTown || cell.UsesSurfaceMesh)))
    {
        var vertices = (System.Collections.Generic.List<Vector3>)surfaceType.GetField("vertices", flags).GetValue(surface);
        var triangles = (System.Collections.Generic.List<int>)surfaceType.GetField("triangles", flags).GetValue(surface);
        var neighbors = (System.Collections.Generic.List<int>)surfaceType.GetField("triangleNeighbors", flags).GetValue(surface);
        var meshCells = (System.Collections.IList)surfaceType.GetField("cells", flags).GetValue(surface);
        var starts = new int[meshCells.Count]; var counts = new int[meshCells.Count]; var bounds = new Bounds[meshCells.Count];
        var kind = meshCells[0].GetType(); var startField = kind.GetField("Start"); var countField = kind.GetField("Count"); var boundsField = kind.GetField("Bounds");
        var candidates = new System.Collections.Generic.List<int>(); var upper = new System.Collections.Generic.List<int>();
        for (var i = 0; i < meshCells.Count; i++)
        {
            starts[i] = (int)startField.GetValue(meshCells[i]); counts[i] = (int)countField.GetValue(meshCells[i]); bounds[i] = (Bounds)boundsField.GetValue(meshCells[i]);
            if (counts[i] > 0) { candidates.Add(i); if (map.Cells[i].Layer > 0) upper.Add(i); }
        }
        if (candidates.Count == 0) throw new System.Exception("Expected real surface geometry");
        var shown = new bool[meshCells.Count];
        // Independent copy of the pre-BVH exact triangle test and ascending cell scan.
        System.Func<Ray, Vector3, Vector3, Vector3, float> triangleHit = (ray, a, b, c) =>
        {
            var edge = b - a; var edge2 = c - a; var p = Vector3.Cross(ray.direction, edge2); var det = Vector3.Dot(edge, p);
            if (Mathf.Abs(det) < .000001f) return float.PositiveInfinity;
            var t = ray.origin - a; var u = Vector3.Dot(t, p) / det; if (u < 0 || u > 1) return float.PositiveInfinity;
            var q = Vector3.Cross(t, edge); var v = Vector3.Dot(ray.direction, q) / det; if (v < 0 || u + v > 1) return float.PositiveInfinity;
            var distance = Vector3.Dot(edge2, q) / det; return distance >= 0 ? distance : float.PositiveInfinity;
        };
        int linearIndex = -1;
        System.Func<Ray, float, float> exhaustive = (ray, limit) =>
        {
            linearIndex = -1;
            for (var i = 0; i < counts.Length; i++)
            {
                if (counts[i] == 0 || !shown[i] || !bounds[i].IntersectRay(ray, out var near) || near > limit) continue;
                for (var offset = starts[i]; offset < starts[i] + counts[i]; offset += 3)
                {
                    var neighbor = neighbors[offset / 3]; if (neighbor >= 0 && shown[neighbor]) continue;
                    var hit = triangleHit(ray, vertices[triangles[offset]], vertices[triangles[offset + 1]], vertices[triangles[offset + 2]]);
                    if (hit < limit) { limit = hit; linearIndex = i; }
                }
            }
            return limit;
        };
        const int rayCount = 256;
        var rays = new Ray[rayCount]; var limits = new float[rayCount]; var random = new System.Random(19361);
        for (var i = 0; i < rayCount; i++)
        {
            var cellIndex = upper.Count > 0 && i < 64 ? upper[i % upper.Count] : candidates[random.Next(candidates.Count)];
            var cell = map.Cells[cellIndex]; var point = cell.Position;
            if (i % 5 == 0)
            {
                // Exact hex corners stress coincident-hit cell ordering across neighboring tiles.
                var angle = (30 + 60 * (i % 6)) * Mathf.Deg2Rad;
                point += new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)) * map.Radius;
                rays[i] = new Ray(point + Vector3.up * 40, Vector3.down); limits[i] = 90;
            }
            else if (i % 5 == 1)
            { rays[i] = new Ray(point + Vector3.up * 1.25f, -(Quaternion.Euler(50, -35, 0) * Vector3.forward)); limits[i] = 28; }
            else if (i % 5 == 2)
            { var origin = point + new Vector3(8, 20, -7); rays[i] = new Ray(origin, (point - origin).normalized); limits[i] = float.PositiveInfinity; }
            else if (i % 5 == 3)
            { rays[i] = new Ray(point + new Vector3(20, .15f, 0), Vector3.left); limits[i] = 40; }
            else
            { rays[i] = new Ray(point + Vector3.up * 3, Vector3.down); limits[i] = 4; }
        }
        int checks = 0;
        for (var mode = 0; mode < 3; mode++)
        {
            // Omitted flat dungeon columns never exist in this surface mesh. Their
            // internal shown flag stays false, so adjoining slope side faces remain exposed.
            for (var i = 0; i < shown.Length; i++) shown[i] = counts[i] > 0 &&
                (mode == 0 || (mode == 1 ? i % 5 != 0 : map.IsTown && map.Cells[i].Layer == 0));
            surface.SetVisibility(shown);
            for (var i = 0; i < rayCount; i++)
            {
                var expected = exhaustive(rays[i], limits[i]); var expectedIndex = linearIndex;
                var actual = surface.Raycast(rays[i], limits[i], out var actualIndex);
                if (actualIndex != expectedIndex || !(actual == expected || Mathf.Abs(actual - expected) < .0001f))
                    throw new System.Exception("BVH differs from exhaustive raycast: type=" + map.AreaType + " mode=" + mode + " ray=" + i + " expected=" + expectedIndex + "/" + expected + " actual=" + actualIndex + "/" + actual);
                checks++;
            }
        }
        for (var i = 0; i < shown.Length; i++) shown[i] = true; surface.SetVisibility(shown);
        for (var i = 0; i < 32; i++) surface.Raycast(rays[i], limits[i], out _);
        long allocatedBytes = -1;
        if (allocated != null)
        {
            var before = allocated();
            for (var i = 0; i < 512; i++) surface.Raycast(rays[i % rayCount], limits[i % rayCount], out _);
            allocatedBytes = allocated() - before;
            if (allocatedBytes != 0) throw new System.Exception("BVH ray queries allocated managed bytes: " + allocatedBytes);
        }
        var watch = System.Diagnostics.Stopwatch.StartNew();
        surfaceType.GetMethod("BuildSpatialIndex", flags).Invoke(surface, null); watch.Stop();
        var nodes = (System.Array)surfaceType.GetField("spatialNodes", flags).GetValue(surface);
        reports.Add("{\"areaType\":" + map.AreaType + ",\"cells\":" + map.Cells.Length + ",\"indexedCells\":" + candidates.Count +
            ",\"nodes\":" + nodes.Length + ",\"rayChecks\":" + checks + ",\"queryAllocationBytes\":" + allocatedBytes +
            ",\"indexBuildMs\":" + watch.Elapsed.TotalMilliseconds.ToString("F6", culture) + "}");
    }
}
const string path = "Docs/Previews/MapArea/raycast-bvh-validation.json";
var json = "{\"playMode\":false,\"rendered\":false,\"results\":[" + string.Join(",", reports) + "]}";
System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path)); System.IO.File.WriteAllText(path, json, new System.Text.UTF8Encoding(false));
Debug.Log(json);
return "MapArea BVH comparisons passed; " + path;
