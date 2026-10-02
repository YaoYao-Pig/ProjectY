using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ProjectY.Samples
{
    /// <summary>按 Lua 给定的顶点高度绘制台地、台阶、坡道和悬空桥面；不推导导航规则。</summary>
    public sealed class TownSurfaceRenderer : IDisposable
    {
        private sealed class CellMesh { public int Start, Count, PickCount; public Bounds Bounds; }
        private struct SpatialNode
        {
            public Bounds Bounds;
            public int Left, Right, Start, Count;
        }
        private sealed class CellAxisComparer : IComparer<int>
        {
            private readonly List<CellMesh> cells;
            private readonly int axis;
            public CellAxisComparer(List<CellMesh> cells, int axis) { this.cells = cells; this.axis = axis; }
            public int Compare(int a, int b)
            {
                var order = cells[a].Bounds.center[axis].CompareTo(cells[b].Bounds.center[axis]);
                return order == 0 ? a.CompareTo(b) : order;
            }
        }
        private readonly List<Vector3> vertices = new List<Vector3>();
        private readonly List<int> triangles = new List<int>();
        private readonly List<int> triangleNeighbors = new List<int>();
        private int occludingNeighbor = -1;
        private readonly List<Color> colors = new List<Color>();
        private readonly List<Vector4> patterns = new List<Vector4>();
        private readonly List<Vector4> finishes = new List<Vector4>();
        private MapAreaViewData.Surface activeSurface;
        private readonly List<CellMesh> cells = new List<CellMesh>();
        private int[] spatialCells;
        private int[] raycastCandidates;
        private SpatialNode[] spatialNodes;
        private readonly List<int> displayedTriangles = new List<int>();
        private readonly bool[] shown;
        private readonly float[] brightness;
        private readonly Color[] displayedColors;
        private readonly Vector4[] displayedFinishes;
        private readonly Mesh mesh;
        private readonly Material material;
        private static readonly Vector3[] Corners = MakeCorners();
        public Mesh Mesh => mesh;
        public Material Material => material;
        private static Vector3[] MakeCorners()
        {
            var values = new Vector3[6];
            for (var i = 0; i < 6; i++) { var angle = (30 + 60 * i) * Mathf.Deg2Rad; values[i] = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)); }
            return values;
        }
        public TownSurfaceRenderer(Shader shader, MapAreaViewData map, Func<MapAreaViewData.Cell, bool> include = null)
        {
            shown = new bool[map.Cells.Length]; brightness = new float[map.Cells.Length];
            material = new Material(shader) { name = "Town_Surface" }; material.SetFloat("_UseVertexColor", 1); material.SetFloat("_UseSurfacePattern", 1);
            var boundaryPatches = new Dictionary<int, List<MapAreaViewData.FloorBoundaryPatch>>();
            var boundaryBuckets = new Dictionary<Vector2Int, List<MapAreaViewData.FloorBoundaryPatch>>();
            foreach (var patch in map.FloorBoundaryPatches)
            {
                if (!boundaryPatches.TryGetValue(patch.OwnerIndex, out var group))
                    boundaryPatches.Add(patch.OwnerIndex, group = new List<MapAreaViewData.FloorBoundaryPatch>());
                group.Add(patch);
                var bounds = new Bounds(patch.Points[0], Vector3.zero);
                foreach (var point in patch.Points) bounds.Encapsulate(point);
                var min = BoundaryBucket(bounds.min, map.Radius); var max = BoundaryBucket(bounds.max, map.Radius);
                for (var x = min.x; x <= max.x; x++) for (var z = min.y; z <= max.y; z++)
                {
                    var key = new Vector2Int(x, z);
                    if (!boundaryBuckets.TryGetValue(key, out var bucket))
                        boundaryBuckets.Add(key, bucket = new List<MapAreaViewData.FloorBoundaryPatch>());
                    bucket.Add(patch);
                }
            }
            foreach (var cell in map.Cells)
            {
                var start = triangles.Count; var points = new Vector3[6];
                if (include != null && !include(cell)) { cells.Add(new CellMesh()); continue; }
                shown[cells.Count] = true; brightness[cells.Count] = 1;
                var groundOffset = cell.ConstructionKind == null ? 0 : cell.GroundHeight - cell.Position.y;
                var center = cell.Position + Vector3.up * groundOffset;
                for (var i = 0; i < 6; i++) { points[i] = center + Corners[i] * map.Radius; points[i].y = cell.Corners[i] + groundOffset; }
                var color = cell.Color;
                if (QualitySettings.activeColorSpace == ColorSpace.Linear) color = color.linear;
                for (var i = 0; i < 6; i++)
                {
                    var j = (i + 1) % 6;
                    activeSurface = map.Surfaces[cell.SurfaceId];
                    Top(new[] { center, points[j], points[i] }, cell.StairRise, color);
                    var bottom = cell.Layer == 0 && cell.DeckThickness <= 0 ? Mathf.Min(-.4f, center.y - .4f) : Mathf.Min(cell.Corners) + groundOffset - cell.DeckThickness;
                    activeSurface = map.Surfaces[cell.SideSurfaceId];
                    var sideColor = QualitySettings.activeColorSpace == ColorSpace.Linear ? activeSurface.Color.linear : activeSurface.Color;
                    occludingNeighbor = SharedGroundNeighbor(map, cell, i);
                    Edge(points[i], points[j], bottom, cell.StairRise, sideColor);
                    occludingNeighbor = -1;
                    if (cell.Layer > 0)
                        Triangle(new Vector3(cell.Position.x, bottom, cell.Position.z), new Vector3(points[i].x, bottom, points[i].z), new Vector3(points[j].x, bottom, points[j].z), color * .65f);
                }
                // Upper interiors have real railings at closed navigation edges, leaving stair mouths open.
                if (cell.InteriorId > 0 && cell.Layer > 0)
                {
                    activeSurface = map.Surfaces[cell.SideSurfaceId];
                    for (var i = 0; i < 6; i++)
                    {
                        var direction = (5 - i + 6) % 6;
                        if ((cell.WalkMask & (1 << direction)) != 0) continue;
                        if (BoundaryCoversEdge(map, boundaryBuckets, cell, points[i], points[(i + 1) % 6])) continue;
                        var a = Vector3.Lerp(points[i], cell.Position, .035f);
                        var b = Vector3.Lerp(points[(i + 1) % 6], cell.Position, .035f);
                        a.y = Step(a.y, cell.StairRise); b.y = Step(b.y, cell.StairRise);
                        Rail(a, b, color * .65f);
                    }
                }
                var pickCount = triangles.Count - start;
                if (boundaryPatches.TryGetValue(cells.Count, out var patches))
                    foreach (var patch in patches) Boundary(patch, map, cell, color);
                var bounds = new Bounds(cell.Position, Vector3.zero);
                for (var i = start; i < triangles.Count; i++) bounds.Encapsulate(vertices[triangles[i]]);
                cells.Add(new CellMesh { Start = start, Count = triangles.Count - start, PickCount = pickCount, Bounds = bounds });
            }
            mesh = new Mesh { name = "Town_TerracesAndDecks", indexFormat = IndexFormat.UInt32 };
            mesh.SetVertices(vertices); mesh.SetTriangles(triangles, 0); mesh.SetColors(colors); mesh.SetUVs(1, patterns); mesh.SetUVs(2, finishes); mesh.RecalculateNormals(); mesh.RecalculateBounds();
            displayedColors = colors.ToArray(); displayedFinishes = finishes.ToArray();
            RebuildTriangles();
            BuildSpatialIndex();
        }
        // Only the outer straight cut is exposed. Keep stairwell railings; remove the
        // old zigzag railing where a cut hex continues the slab towards a wall.
        private static Vector2Int BoundaryBucket(Vector3 point, float radius) =>
            new Vector2Int(Mathf.FloorToInt(point.x / (radius * 2)), Mathf.FloorToInt(point.z / (radius * 2)));
        private static bool BoundaryCoversEdge(MapAreaViewData map, Dictionary<Vector2Int, List<MapAreaViewData.FloorBoundaryPatch>> buckets,
            MapAreaViewData.Cell cell, Vector3 a, Vector3 b)
        {
            var middle = (a + b) * .5f;
            var point = middle + new Vector3(middle.x - cell.Position.x, 0, middle.z - cell.Position.z).normalized * .005f;
            if (!buckets.TryGetValue(BoundaryBucket(point, map.Radius), out var patches)) return false;
            foreach (var patch in patches)
            {
                var owner = map.Cells[patch.OwnerIndex];
                if (owner.Layer != cell.Layer || owner.InteriorId != cell.InteriorId || Mathf.Abs(patch.Points[0].y - point.y) > .001f) continue;
                var inside = true;
                for (var i = 0; i < patch.Points.Length; i++)
                {
                    var p = patch.Points[i]; var next = patch.Points[(i + 1) % patch.Points.Length];
                    if ((next.x - p.x) * (point.z - p.z) - (next.z - p.z) * (point.x - p.x) < -.0001f) { inside = false; break; }
                }
                if (inside) return true;
            }
            return false;
        }
        private void Boundary(MapAreaViewData.FloorBoundaryPatch patch, MapAreaViewData map, MapAreaViewData.Cell owner, Color color)
        {
            var points = patch.Points; var down = Vector3.down * patch.Thickness;
            activeSurface = map.Surfaces[owner.SurfaceId];
            for (var i = 1; i + 1 < points.Length; i++)
            {
                Triangle(points[0], points[i + 1], points[i], color);
                Triangle(points[0] + down, points[i] + down, points[i + 1] + down, color * .65f);
            }
            activeSurface = map.Surfaces[owner.SideSurfaceId];
            var sideColor = QualitySettings.activeColorSpace == ColorSpace.Linear ? activeSurface.Color.linear : activeSurface.Color;
            for (var i = 0; i < points.Length; i++)
                Edge(points[i], points[(i + 1) % points.Length], points[i].y - patch.Thickness, 0, sideColor);
        }
        // Geometry and cell bounds remain static until construction rebuilds this renderer.
        // Fog/cutaway changes only affect leaf filtering; they never require rebuilding the tree.
        private void BuildSpatialIndex()
        {
            var count = 0;
            for (var i = 0; i < cells.Count; i++) if (cells[i].Count > 0) count++;
            spatialCells = new int[count];
            raycastCandidates = new int[count];
            for (int i = 0, next = 0; i < cells.Count; i++) if (cells[i].Count > 0) spatialCells[next++] = i;
            var nodes = new List<SpatialNode>(Math.Max(1, count / 2));
            if (count > 0)
            {
                var comparers = new[] { new CellAxisComparer(cells, 0), new CellAxisComparer(cells, 1), new CellAxisComparer(cells, 2) };
                BuildSpatialNode(nodes, comparers, 0, count);
            }
            spatialNodes = nodes.ToArray();
        }
        private int BuildSpatialNode(List<SpatialNode> nodes, CellAxisComparer[] comparers, int start, int count)
        {
            var bounds = cells[spatialCells[start]].Bounds;
            for (var i = start + 1; i < start + count; i++) bounds.Encapsulate(cells[spatialCells[i]].Bounds);
            // Bounds stores center/extents as floats; keep shared-corner rays inside
            // the broad phase despite rounding when distant cell bounds are merged.
            bounds.Expand(.002f);
            var index = nodes.Count; nodes.Add(default(SpatialNode));
            if (count <= 8)
                nodes[index] = new SpatialNode { Bounds = bounds, Start = start, Count = count };
            else
            {
                var size = bounds.size; var axis = size.x >= size.y && size.x >= size.z ? 0 : size.y >= size.z ? 1 : 2;
                Array.Sort(spatialCells, start, count, comparers[axis]);
                var half = count / 2;
                var left = BuildSpatialNode(nodes, comparers, start, half);
                var right = BuildSpatialNode(nodes, comparers, start + half, count - half);
                nodes[index] = new SpatialNode { Bounds = bounds, Left = left, Right = right };
            }
            return index;
        }
        private static int SharedGroundNeighbor(MapAreaViewData map, MapAreaViewData.Cell cell, int edge)
        {
            if (cell.Layer != 0 || cell.Neighbors == null || cell.Neighbors.Length != 6) return -1;
            var direction = (5 - edge + 6) % 6; var index = cell.Neighbors[direction];
            if (index < 0) return -1;
            var other = map.Cells[index];
            if (other.Layer != 0 || other.Kind == "wall" || cell.ConstructionKind != null || other.ConstructionKind != null) return -1;
            // These faces are buried between touching tiles. Drawing both casts dotted self-shadows on the steps.
            return Mathf.Abs(cell.Corners[edge] - other.Corners[(edge + 4) % 6]) < .001f
                && Mathf.Abs(cell.Corners[(edge + 1) % 6] - other.Corners[(edge + 3) % 6]) < .001f ? index : -1;
        }
        private void Rail(Vector3 a, Vector3 b, Color color)
        {
            var side = Vector3.Cross((b - a).normalized, Vector3.up).normalized * .065f;
            Beam(a + Vector3.up * .78f, b + Vector3.up * .78f, side, .10f, color);
            var middle = Vector3.Lerp(a, b, .5f);
            foreach (var point in new[] { a, middle, b })
                Beam(point + Vector3.up * .38f - side, point + Vector3.up * .38f + side, (b - a).normalized * .055f, .80f, color);
        }
        private void Beam(Vector3 a, Vector3 b, Vector3 side, float height, Color color)
        {
            var up = Vector3.up * (height * .5f);
            var p = new[] { a - side - up, a + side - up, b + side - up, b - side - up,
                a - side + up, a + side + up, b + side + up, b - side + up };
            Quad(p[0], p[1], p[5], p[4], color); Quad(p[1], p[2], p[6], p[5], color);
            Quad(p[2], p[3], p[7], p[6], color); Quad(p[3], p[0], p[4], p[7], color);
            Quad(p[4], p[5], p[6], p[7], color); Quad(p[3], p[2], p[1], p[0], color);
        }
        private void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Color color)
        { Triangle(a, b, c, color); Triangle(a, c, d, color); }
        // Keep the static geometry; only rebuild its index list when fog or the viewed storey changes.
        public void SetVisibility(bool[] selected, bool[] lit = null)
        {
            var geometryChanged = false; var colorsChanged = false;
            for (var i = 0; i < cells.Count; i++)
            {
                var cell = cells[i]; if (cell.Count == 0) continue;
                geometryChanged |= shown[i] != selected[i]; shown[i] = selected[i];
                var value = lit == null || lit[i] ? 1f : .3f;
                if (brightness[i] == value) continue;
                brightness[i] = value; colorsChanged = true;
                for (var offset = cell.Start; offset < cell.Start + cell.Count; offset++)
                {
                    displayedColors[offset] = FogColor(colors[offset], value);
                    var finish = finishes[offset]; var detail = FogColor(new Color(finish.x, finish.y, finish.z, 1), value);
                    displayedFinishes[offset] = new Vector4(detail.r, detail.g, detail.b, finish.w);
                }
            }
            if (geometryChanged)
                RebuildTriangles();
            if (colorsChanged) { mesh.SetColors(displayedColors); mesh.SetUVs(2, displayedFinishes); }
        }
        private void RebuildTriangles()
        {
            displayedTriangles.Clear();
            for (var i = 0; i < cells.Count; i++) if (shown[i])
                for (var offset = cells[i].Start; offset < cells[i].Start + cells[i].Count; offset += 3)
                {
                    var neighbor = triangleNeighbors[offset / 3];
                    // When fog hides the neighboring surface, restore its exposed side to keep the ground closed.
                    if (neighbor >= 0 && shown[neighbor]) continue;
                    displayedTriangles.Add(triangles[offset]); displayedTriangles.Add(triangles[offset + 1]); displayedTriangles.Add(triangles[offset + 2]);
                }
            mesh.SetTriangles(displayedTriangles, 0, false);
        }
        private static Color FogColor(Color color, float amount)
        {
            var linear = QualitySettings.activeColorSpace == ColorSpace.Linear;
            if (linear) color = color.gamma;
            color *= amount; if (linear) color = color.linear; color.a = 1; return color;
        }
        private void Triangle(Vector3 a, Vector3 b, Vector3 c, Color color)
        {
            if (Vector3.Cross(b - a, c - a).sqrMagnitude < .00000001f) return;
            var index = vertices.Count; vertices.Add(a); vertices.Add(b); vertices.Add(c);
            colors.Add(color); colors.Add(color); colors.Add(color); triangles.Add(index); triangles.Add(index + 1); triangles.Add(index + 2);
            triangleNeighbors.Add(occludingNeighbor);
            var detail = QualitySettings.activeColorSpace == ColorSpace.Linear ? activeSurface.DetailColor.linear : activeSurface.DetailColor;
            for (var i = 0; i < 3; i++) { patterns.Add(activeSurface.Pattern); finishes.Add(new Vector4(detail.r, detail.g, detail.b, activeSurface.Smoothness)); }
        }
        private static List<Vector3> Clip(List<Vector3> input, float height, bool above)
        {
            var output = new List<Vector3>(); if (input.Count == 0) return output;
            var previous = input[input.Count - 1]; var previousInside = above ? previous.y >= height : previous.y <= height;
            foreach (var current in input)
            {
                var inside = above ? current.y >= height : current.y <= height;
                if (inside != previousInside) output.Add(Vector3.Lerp(previous, current, (height - previous.y) / (current.y - previous.y)));
                if (inside) output.Add(current);
                previous = current; previousInside = inside;
            }
            return output;
        }
        private void Top(Vector3[] points, float rise, Color color)
        {
            var min = Mathf.Min(points[0].y, Mathf.Min(points[1].y, points[2].y));
            var max = Mathf.Max(points[0].y, Mathf.Max(points[1].y, points[2].y));
            if (rise <= 0 || max - min < .0001f)
            {
                for (var i = 0; i < points.Length; i++) points[i].y = Step(points[i].y, rise);
                Triangle(points[0], points[1], points[2], color); return;
            }
            for (var band = Mathf.FloorToInt(min / rise + .0001f); band < Mathf.CeilToInt(max / rise - .0001f); band++)
            {
                var low = band * rise; var high = low + rise;
                var polygon = Clip(Clip(new List<Vector3>(points), low, true), high, false);
                for (var i = 1; i + 1 < polygon.Count; i++)
                    Triangle(new Vector3(polygon[0].x, low, polygon[0].z), new Vector3(polygon[i].x, low, polygon[i].z), new Vector3(polygon[i + 1].x, low, polygon[i + 1].z), color);
                for (var i = 0; i < polygon.Count; i++)
                {
                    var a = polygon[i]; var b = polygon[(i + 1) % polygon.Count];
                    if (Mathf.Abs(a.y - high) > .0001f || Mathf.Abs(b.y - high) > .0001f) continue;
                    var downA = new Vector3(a.x, low, a.z); var downB = new Vector3(b.x, low, b.z);
                    Triangle(downA, a, b, color * .8f); Triangle(downA, b, downB, color * .8f);
                }
            }
        }
        private void Edge(Vector3 a, Vector3 b, float bottom, float rise, Color color)
        {
            var stops = new List<float> { 0, 1 };
            if (rise > 0 && Mathf.Abs(a.y - b.y) > .0001f)
                for (var y = (Mathf.Floor(Mathf.Min(a.y, b.y) / rise) + 1) * rise; y < Mathf.Max(a.y, b.y) - .0001f; y += rise)
                    stops.Add((y - a.y) / (b.y - a.y));
            stops.Sort();
            for (var i = 1; i < stops.Count; i++)
            {
                var left = Vector3.Lerp(a, b, stops[i - 1]); var right = Vector3.Lerp(a, b, stops[i]);
                if (rise > 0) { var top = Step((left.y + right.y) / 2, rise); left.y = top; right.y = top; }
                var lowA = new Vector3(left.x, bottom, left.z); var lowB = new Vector3(right.x, bottom, right.z);
                Triangle(left, lowB, lowA, color); Triangle(left, right, lowB, color);
            }
        }
        private static float Step(float value, float rise) => rise > 0 ? Mathf.Floor(value / rise + .0001f) * rise : value;
        // Filled overlays use the same fan interpolation and stair bands as the walkable surface.
        public static void AppendOverlay(MapAreaViewData map, int index, float inset, List<Vector3> output, List<int> indices)
        {
            var cell = map.Cells[index]; var radius = 1 - inset;
            for (var i = 0; i < 6; i++)
            {
                var j = (i + 1) % 6;
                var a = OverlayPoint(map, cell, i, radius); var b = OverlayPoint(map, cell, j, radius);
                OverlayTriangle(cell.Position, b, a, cell.StairRise, output, indices);
            }
        }
        private static Vector3 OverlayPoint(MapAreaViewData map, MapAreaViewData.Cell cell, int corner, float radius)
        {
            var point = cell.Position + Corners[corner] * (map.Radius * radius);
            point.y = Mathf.Lerp(cell.Position.y, cell.Corners[corner], radius); return point;
        }
        private static void OverlayTriangle(Vector3 a, Vector3 b, Vector3 c, float rise, List<Vector3> output, List<int> indices)
        {
            var min = Mathf.Min(a.y, Mathf.Min(b.y, c.y)); var max = Mathf.Max(a.y, Mathf.Max(b.y, c.y));
            if (rise <= 0 || max - min < .0001f)
            {
                a.y = Step(a.y, rise); b.y = Step(b.y, rise); c.y = Step(c.y, rise);
                AddOverlayTriangle(a, b, c, output, indices); return;
            }
            for (var band = Mathf.FloorToInt(min / rise + .0001f); band < Mathf.CeilToInt(max / rise - .0001f); band++)
            {
                var low = band * rise; var high = low + rise;
                var polygon = Clip(Clip(new List<Vector3> { a, b, c }, low, true), high, false);
                for (var i = 1; i + 1 < polygon.Count; i++)
                    AddOverlayTriangle(new Vector3(polygon[0].x, low, polygon[0].z), new Vector3(polygon[i].x, low, polygon[i].z),
                        new Vector3(polygon[i + 1].x, low, polygon[i + 1].z), output, indices);
            }
        }
        private static void AddOverlayTriangle(Vector3 a, Vector3 b, Vector3 c, List<Vector3> output, List<int> indices)
        {
            if (Vector3.Cross(b - a, c - a).sqrMagnitude < .00000001f) return;
            var index = output.Count; var offset = Vector3.up * .035f;
            output.Add(a + offset); output.Add(b + offset); output.Add(c + offset);
            indices.Add(index); indices.Add(index + 1); indices.Add(index + 2);
        }
        private static bool Height(MapAreaViewData map, int index, Vector3 position, out float height)
        {
            var cell = map.Cells[index]; var x = (position.x - cell.Position.x) / map.Radius; var z = (position.z - cell.Position.z) / map.Radius;
            for (var i = 0; i < 6; i++)
            {
                var j = (i + 1) % 6; var a = Corners[i]; var b = Corners[j]; var determinant = a.x * b.z - a.z * b.x;
                var u = (x * b.z - z * b.x) / determinant; var v = (a.x * z - a.z * x) / determinant;
                if (u < -.001f || v < -.001f || u + v > 1.001f) continue;
                height = Step(cell.Position.y * (1 - u - v) + cell.Corners[i] * u + cell.Corners[j] * v, cell.StairRise); return true;
            }
            height = 0; return false;
        }
        // 显示位置只采样其真实移动边的两端地面，绝不吸到同坐标的另一层。
        public static Vector3 Ground(MapAreaViewData map, int from, int to, Vector3 position)
        {
            if (!Height(map, to, position, out var height) && !Height(map, from, position, out height))
                throw new InvalidOperationException("棋子显示位置离开了当前导航边。");
            position.y = height + .015f; return position;
        }
        private static bool Hit(Ray ray, Vector3 a, Vector3 b, Vector3 c, out float distance)
        {
            var edge = b - a; var edge2 = c - a; var p = Vector3.Cross(ray.direction, edge2); var det = Vector3.Dot(edge, p);
            distance = 0; if (Mathf.Abs(det) < .000001f) return false;
            var t = ray.origin - a; var u = Vector3.Dot(t, p) / det; if (u < 0 || u > 1) return false;
            var q = Vector3.Cross(t, edge); var v = Vector3.Dot(ray.direction, q) / det; if (v < 0 || u + v > 1) return false;
            distance = Vector3.Dot(edge2, q) / det; return distance >= 0;
        }
        public float Raycast(Ray ray, float limit, out int index)
        {
            index = -1;
            var count = 0;
            if (spatialNodes.Length > 0 && spatialNodes[0].Bounds.IntersectRay(ray, out var near) && near <= limit)
                CollectRaycastCandidates(0, ray, limit, ref count);
            // Preserve the original ascending cell scan, including its dynamic
            // Bounds limit and strict triangle comparison at shared boundaries.
            Array.Sort(raycastCandidates, 0, count);
            for (var i = 0; i < count; i++)
            {
                var cellIndex = raycastCandidates[i]; var cell = cells[cellIndex];
                if (!shown[cellIndex] || !cell.Bounds.IntersectRay(ray, out var cellNear) || cellNear > limit) continue;
                for (var offset = cell.Start; offset < cell.Start + cell.Count; offset += 3)
                    if ((triangleNeighbors[offset / 3] < 0 || !shown[triangleNeighbors[offset / 3]]) &&
                        Hit(ray, vertices[triangles[offset]], vertices[triangles[offset + 1]], vertices[triangles[offset + 2]], out var distance) && distance < limit)
                    { limit = distance; index = offset < cell.Start + cell.PickCount ? cellIndex : -1; }
            }
            return limit;
        }
        private void CollectRaycastCandidates(int nodeIndex, Ray ray, float initialLimit, ref int count)
        {
            var node = spatialNodes[nodeIndex];
            if (node.Count > 0)
            {
                for (var i = node.Start; i < node.Start + node.Count; i++)
                {
                    var cellIndex = spatialCells[i]; var cell = cells[cellIndex];
                    if (shown[cellIndex] && cell.Bounds.IntersectRay(ray, out var near) && near <= initialLimit)
                        raycastCandidates[count++] = cellIndex;
                }
                return;
            }
            // The initial limit is immutable during collection. Pruning with a
            // hit from a differently ordered subtree changes floating-point ties.
            // Both the candidate buffer and the balanced traversal stack are reused.
            if (spatialNodes[node.Left].Bounds.IntersectRay(ray, out var leftNear) && leftNear <= initialLimit)
                CollectRaycastCandidates(node.Left, ray, initialLimit, ref count);
            if (spatialNodes[node.Right].Bounds.IntersectRay(ray, out var rightNear) && rightNear <= initialLimit)
                CollectRaycastCandidates(node.Right, ray, initialLimit, ref count);
        }
        public void Draw(Camera camera) => Graphics.DrawMesh(mesh, Matrix4x4.identity, material, 0, camera, 0, null, ShadowCastingMode.On, true, null, LightProbeUsage.Off);
        private static void Destroy(UnityEngine.Object value) { if (Application.isPlaying) UnityEngine.Object.Destroy(value); else UnityEngine.Object.DestroyImmediate(value); }
        public void Dispose() { Destroy(mesh); Destroy(material); }
    }
}
