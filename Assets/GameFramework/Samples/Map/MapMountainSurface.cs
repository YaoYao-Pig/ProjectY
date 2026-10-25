using System;
using System.Collections.Generic;
using ProjectY.Data;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    /// <summary>Continuous world mountain fans. Lua owns heights; this class owns mesh, fog and focus presentation.</summary>
    public sealed class MapMountainSurface : IDisposable
    {
        private sealed class Chunk
        {
            public Mesh Mesh;
            public int ShownCellCount;
            public Bounds Bounds;
            public readonly List<int> Cells = new List<int>();
            public readonly List<Vector3> BuildVertices = new List<Vector3>();
            public readonly List<Color> BuildColors = new List<Color>();
            public readonly List<int> ShownIndices = new List<int>();
            public Vector3[] OriginalVertices, Vertices;
            public Color[] OriginalColors, Colors;
        }
        private sealed class Span
        {
            public Chunk Chunk;
            public int Start, Count;
            public Bounds Bounds;
            public readonly int[] Neighbors = new int[6];
        }
        private struct FocusEdge { public Vector3 A, B; public Color Color; }
        private static readonly Vector3[] Corners = MakeCorners();
        private static readonly Vector2Int[] EdgeOffsets = {
            new Vector2Int(0, 1), new Vector2Int(-1, 1), new Vector2Int(-1, 0),
            new Vector2Int(0, -1), new Vector2Int(1, -1), new Vector2Int(1, 0)
        };
        private readonly List<Chunk> chunks = new List<Chunk>();
        private readonly HashSet<int> selected = new HashSet<int>();
        private readonly HashSet<int> focusOwners = new HashSet<int>();
        private readonly HashSet<Chunk> focusChunks = new HashSet<Chunk>();
        private readonly List<Vector3> selectionVertices = new List<Vector3>(), edgeVertices = new List<Vector3>();
        private readonly List<Color> edgeColors = new List<Color>();
        private readonly List<int> selectionIndices = new List<int>(), edgeIndices = new List<int>();
        private readonly List<FocusEdge> focusEdges = new List<FocusEdge>();
        private readonly MaterialPropertyBlock blackMask = new MaterialPropertyBlock(), whiteMask = new MaterialPropertyBlock();
        private readonly Material material;
        private Mesh selectionMesh, focusEdgeMesh;
        private Span[] spans;
        private bool[] known;
        private MapPreviewData map;
        private WorldMapExplorationData exploration;
        private int explorationRevision = -1;
        private float focusLift, focusAmount;
        private bool visible = true;
        public Material Material => material;
        public int ChunkCount => chunks.Count;
        public int SubmittedChunks { get; private set; }
        public int SubmittedCells { get; private set; }

        public MapMountainSurface(Shader shader)
        {
            if (shader == null || !shader.isSupported) throw new ArgumentException("Mountain surface shader is missing.", nameof(shader));
            material = new Material(shader) { name = "World continuous mountain surface", color = Color.white };
            material.SetFloat("_UseVertexColor", 1);
            material.SetFloat("_UseSurfacePattern", 0);
            blackMask.SetVector("_SiteMask", Vector4.zero);
            whiteMask.SetVector("_SiteMask", Vector4.one);
        }

        private static Vector3[] MakeCorners()
        {
            var result = new Vector3[6];
            for (var i = 0; i < 6; i++)
            {
                var angle = (30 + 60 * i) * Mathf.Deg2Rad;
                result[i] = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle));
            }
            return result;
        }
        public static Vector3 Corner(MapPreviewData.Cell cell, float radius, int corner)
        {
            var point = cell.Position + Corners[corner] * radius;
            point.y = cell.SurfaceCorners[corner];
            return point;
        }
        public bool ContainsCell(int cell) => spans != null && cell >= 0 && cell < spans.Length && spans[cell] != null;
        public bool TryGetCellBounds(int cell, out Bounds bounds)
        {
            if (ContainsCell(cell)) { bounds = spans[cell].Bounds; return true; }
            bounds = default; return false;
        }

        public void Build(MapPreviewData source, float bottom)
        {
            ClearMeshes();
            map = source ?? throw new ArgumentNullException(nameof(source));
            spans = new Span[map.Cells.Length]; known = new bool[map.Cells.Length];
            exploration = null; explorationRevision = -1; material.SetFloat("_WorldFogEnabled", 0);
            var indices = new Dictionary<Vector2Int, int>();
            for (var i = 0; i < map.Cells.Length; i++)
            { indices.Add(new Vector2Int(map.Cells[i].Q, map.Cells[i].R), i); known[i] = true; }
            var groups = new Dictionary<Vector3Int, Chunk>();
            for (var index = 0; index < map.Cells.Length; index++)
            {
                var cell = map.Cells[index];
                if (cell.SurfaceCorners == null) continue;
                Validate(cell, map.Radius);
                var key = new Vector3Int(cell.RegionId, Mathf.FloorToInt(cell.Q / 8f), Mathf.FloorToInt(cell.R / 8f));
                if (!groups.TryGetValue(key, out var chunk))
                { chunk = new Chunk(); groups.Add(key, chunk); chunks.Add(chunk); }
                var span = new Span { Chunk = chunk, Start = chunk.BuildVertices.Count };
                spans[index] = span; chunk.Cells.Add(index);
                cell.SurfaceEdgeBottoms = new float[6];
                for (var edge = 0; edge < 6; edge++)
                {
                    span.Neighbors[edge] = indices.TryGetValue(new Vector2Int(cell.Q, cell.R) + EdgeOffsets[edge], out var neighbor) ? neighbor : -1;
                    cell.SurfaceEdgeBottoms[edge] = float.NaN;
                }
                var centerColor = Linear(cell.Color);
                for (var edge = 0; edge < 6; edge++)
                {
                    var next = (edge + 1) % 6;
                    var a = Corner(cell, map.Radius, edge); var b = Corner(cell, map.Radius, next);
                    var colorA = CornerColor(cell, span, edge); var colorB = CornerColor(cell, span, next);
                    Triangle(chunk, cell.Position, b, a, centerColor, colorB, colorA);
                    var neighbor = span.Neighbors[edge];
                    if (neighbor >= 0 && map.Cells[neighbor].SurfaceCorners != null)
                    {
                        var heights = map.Cells[neighbor].SurfaceCorners;
                        if (heights.Length != 6 || Mathf.Abs(a.y - heights[(edge + 4) % 6]) > .002f ||
                            Mathf.Abs(b.y - heights[(edge + 3) % 6]) > .002f)
                            throw new InvalidOperationException("Continuous mountain cells disagree at a shared edge.");
                        continue; // No internal vertical walls, including region/chunk boundaries.
                    }
                    var edgeBottom = neighbor < 0 ? bottom : map.Cells[neighbor].Position.y;
                    cell.SurfaceEdgeBottoms[edge] = edgeBottom;
                    if (ClipEdge(ref a, ref b, edgeBottom))
                        Edge(chunk, a, b, edgeBottom, centerColor * .82f);
                }
                span.Count = chunk.BuildVertices.Count - span.Start;
                span.Bounds = new Bounds(cell.Position, Vector3.zero);
                for (var i = span.Start; i < span.Start + span.Count; i++) span.Bounds.Encapsulate(chunk.BuildVertices[i]);
            }
            foreach (var chunk in chunks)
            {
                chunk.OriginalVertices = chunk.BuildVertices.ToArray(); chunk.Vertices = (Vector3[])chunk.OriginalVertices.Clone();
                chunk.OriginalColors = chunk.BuildColors.ToArray(); chunk.Colors = (Color[])chunk.OriginalColors.Clone();
                chunk.Mesh = new Mesh { name = "Continuous mountain chunk", indexFormat = IndexFormat.UInt32 };
                chunk.Mesh.MarkDynamic(); chunk.Mesh.vertices = chunk.Vertices; chunk.Mesh.colors = chunk.Colors;
                for (var i = 0; i < chunk.Vertices.Length; i++) chunk.ShownIndices.Add(i);
                chunk.Mesh.SetTriangles(chunk.ShownIndices, 0); chunk.Mesh.RecalculateNormals(); chunk.Mesh.RecalculateBounds();
                chunk.Bounds = chunk.Mesh.bounds; chunk.Bounds.Expand(new Vector3(0, map.Radius * .48f, 0));
                chunk.ShownCellCount = chunk.Cells.Count;
                chunk.BuildVertices.Clear(); chunk.BuildVertices.TrimExcess();
                chunk.BuildColors.Clear(); chunk.BuildColors.TrimExcess();
            }
            selectionMesh = new Mesh { name = "Mountain selected silhouette", indexFormat = IndexFormat.UInt32 };
            focusEdgeMesh = new Mesh { name = "Mountain focus boundary", indexFormat = IndexFormat.UInt32 };
            focusEdgeMesh.MarkDynamic();
        }

        private Color CornerColor(MapPreviewData.Cell cell, Span span, int corner)
        {
            var sum = Linear(cell.Color); var count = 1;
            var first = span.Neighbors[corner]; var second = span.Neighbors[(corner + 5) % 6];
            if (first >= 0) { sum += Linear(map.Cells[first].Color); count++; }
            if (second >= 0) { sum += Linear(map.Cells[second].Color); count++; }
            return sum / count;
        }
        private static Color Linear(Color color) => QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color;
        private static void Triangle(Chunk chunk, Vector3 a, Vector3 b, Vector3 c, Color colorA, Color colorB, Color colorC)
        {
            if (Vector3.Cross(b - a, c - a).sqrMagnitude < 1e-12f) return;
            chunk.BuildVertices.Add(a); chunk.BuildVertices.Add(b); chunk.BuildVertices.Add(c);
            chunk.BuildColors.Add(colorA); chunk.BuildColors.Add(colorB); chunk.BuildColors.Add(colorC);
        }
        private static void Edge(Chunk chunk, Vector3 a, Vector3 b, float bottom, Color color)
        {
            var lowA = new Vector3(a.x, bottom, a.z); var lowB = new Vector3(b.x, bottom, b.z);
            Triangle(chunk, a, b, lowB, color, color, color); Triangle(chunk, a, lowB, lowA, color, color, color);
        }
        private static bool ClipEdge(ref Vector3 a, ref Vector3 b, float bottom)
        {
            if (a.y <= bottom && b.y <= bottom) return false;
            if (a.y < bottom) a = Vector3.Lerp(a, b, (bottom - a.y) / (b.y - a.y));
            else if (b.y < bottom) b = Vector3.Lerp(b, a, (bottom - b.y) / (a.y - b.y));
            return true;
        }

        public bool UpdateExploration(WorldMapExplorationData state)
        {
            if (state == null || ReferenceEquals(exploration, state) && explorationRevision == state.Revision) return false;
            if (state.CellCount != map.Cells.Length) throw new InvalidOperationException("Mountain exploration cell count differs.");
            exploration = state; explorationRevision = state.Revision; var geometryChanged = false;
            // Removing unknown triangles also removes their depth, shadow and mask
            // silhouettes; fragment fog alone cannot hide geometry in those passes.
            foreach (var chunk in chunks)
            {
                var changed = false;
                foreach (var index in chunk.Cells)
                {
                    var isKnown = state.IsKnown(index + 1);
                    if (known[index] != isKnown) { known[index] = isKnown; changed = true; }
                }
                if (!changed) continue;
                geometryChanged = true;
                chunk.ShownIndices.Clear(); chunk.ShownCellCount = 0;
                foreach (var index in chunk.Cells)
                {
                    if (!known[index]) continue;
                    chunk.ShownCellCount++;
                    var span = spans[index];
                    for (var i = span.Start; i < span.Start + span.Count; i++) chunk.ShownIndices.Add(i);
                }
                chunk.Mesh.SetTriangles(chunk.ShownIndices, 0, false);
            }
            if (geometryChanged) BuildSelectionGeometry();
            return geometryChanged;
        }

        public void SetFocusCells(IEnumerable<int> cells)
        {
            foreach (var chunk in focusChunks)
            {
                Array.Copy(chunk.OriginalVertices, chunk.Vertices, chunk.Vertices.Length);
                Array.Copy(chunk.OriginalColors, chunk.Colors, chunk.Colors.Length);
                chunk.Mesh.vertices = chunk.Vertices; chunk.Mesh.colors = chunk.Colors;
            }
            selected.Clear(); focusOwners.Clear(); focusChunks.Clear(); focusLift = focusAmount = 0;
            if (cells != null) foreach (var cell in cells)
            {
                focusOwners.Add(cell);
                if (ContainsCell(cell) && selected.Add(cell)) focusChunks.Add(spans[cell].Chunk);
            }
            BuildSelectionGeometry();
        }
        private void BuildSelectionGeometry()
        {
            if (selectionMesh == null) return;
            selectionVertices.Clear(); selectionIndices.Clear(); focusEdges.Clear();
            foreach (var index in selected)
            {
                if (!known[index]) continue;
                var span = spans[index]; var cell = map.Cells[index];
                for (var i = span.Start; i < span.Start + span.Count; i++)
                { selectionIndices.Add(selectionVertices.Count); selectionVertices.Add(span.Chunk.OriginalVertices[i]); }
                for (var edge = 0; edge < 6; edge++)
                {
                    if (focusOwners.Contains(span.Neighbors[edge])) continue;
                    focusEdges.Add(new FocusEdge { A = Corner(cell, map.Radius, edge), B = Corner(cell, map.Radius, (edge + 1) % 6), Color = Linear(cell.Color) * .82f });
                }
            }
            selectionMesh.Clear(); selectionMesh.SetVertices(selectionVertices); selectionMesh.SetTriangles(selectionIndices, 0);
            selectionMesh.RecalculateBounds(); UpdateFocusEdges();
        }
        public void SetFocusLift(float lift, float amount)
        {
            focusLift = lift; focusAmount = amount;
            var tint = Linear(new Color(.98f, .88f, .58f));
            foreach (var index in selected)
            {
                var span = spans[index]; var chunk = span.Chunk;
                for (var i = span.Start; i < span.Start + span.Count; i++)
                {
                    chunk.Vertices[i] = chunk.OriginalVertices[i] + Vector3.up * lift;
                    chunk.Colors[i] = Color.Lerp(chunk.OriginalColors[i], tint, amount * .3f);
                }
            }
            foreach (var chunk in focusChunks)
            {
                chunk.Mesh.vertices = chunk.Vertices; chunk.Mesh.colors = chunk.Colors;
                chunk.Mesh.bounds = chunk.Bounds;
            }
            UpdateFocusEdges();
        }
        private void UpdateFocusEdges()
        {
            edgeVertices.Clear(); edgeColors.Clear(); edgeIndices.Clear();
            if (focusLift > 0)
                foreach (var edge in focusEdges)
                {
                    var a = edge.A + Vector3.up * focusLift; var b = edge.B + Vector3.up * focusLift;
                    var start = edgeVertices.Count;
                    edgeVertices.Add(a); edgeVertices.Add(b); edgeVertices.Add(edge.B);
                    edgeVertices.Add(a); edgeVertices.Add(edge.B); edgeVertices.Add(edge.A);
                    var color = Color.Lerp(edge.Color, Linear(new Color(.98f, .88f, .58f)), focusAmount * .3f);
                    for (var i = 0; i < 6; i++) { edgeIndices.Add(start + i); edgeColors.Add(color); }
                }
            focusEdgeMesh.Clear(); focusEdgeMesh.SetVertices(edgeVertices); focusEdgeMesh.SetColors(edgeColors);
            focusEdgeMesh.SetTriangles(edgeIndices, 0); focusEdgeMesh.RecalculateNormals(); focusEdgeMesh.RecalculateBounds();
        }

        public void SetVisible(bool value) => visible = value;
        public void Draw(Camera camera, MapRenderLod.View lod)
        {
            SubmittedChunks = SubmittedCells = 0;
            if (!visible) return;
            foreach (var chunk in chunks)
            {
                if (chunk.ShownIndices.Count == 0 || !lod.Visible(chunk.Bounds)) continue;
                Graphics.DrawMesh(chunk.Mesh, Matrix4x4.identity, material, 0, camera, 0, null, ShadowCastingMode.On, true, null, LightProbeUsage.Off);
                SubmittedChunks++;
                SubmittedCells += chunk.ShownCellCount;
            }
            if (edgeIndices.Count > 0)
                Graphics.DrawMesh(focusEdgeMesh, Matrix4x4.identity, material, 0, camera, 0, null, ShadowCastingMode.On, true, null, LightProbeUsage.Off);
        }
        public int DrawFocusMask(CommandBuffer commands, Material silhouette, Plane[] planes)
        {
            if (!visible) return 0;
            var count = 0;
            foreach (var chunk in chunks)
            {
                if (chunk.ShownIndices.Count == 0 || !GeometryUtility.TestPlanesAABB(planes, chunk.Bounds)) continue;
                commands.DrawMesh(chunk.Mesh, Matrix4x4.identity, silhouette, 0, 0, blackMask); count++;
            }
            if (selectionIndices.Count > 0)
                commands.DrawMesh(selectionMesh, Matrix4x4.Translate(Vector3.up * focusLift), silhouette, 0, 0, whiteMask);
            if (edgeIndices.Count > 0) commands.DrawMesh(focusEdgeMesh, Matrix4x4.identity, silhouette, 0, 0, whiteMask);
            return count;
        }

        public bool TryPick(Ray ray, out int cell, out float distance)
        {
            cell = -1; distance = float.PositiveInfinity;
            if (!visible) return false;
            foreach (var chunk in chunks)
            {
                if (chunk.ShownIndices.Count == 0 || !chunk.Bounds.IntersectRay(ray, out var chunkNear) || chunkNear > distance) continue;
                foreach (var index in chunk.Cells)
                {
                    if (!known[index]) continue;
                    var localRay = ray;
                    if (selected.Contains(index)) localRay.origin -= Vector3.up * focusLift;
                    if (!spans[index].Bounds.IntersectRay(localRay, out var near) || near > distance) continue;
                    if (TryRaycastCell(map.Cells[index], map.Radius, localRay, out var hit) && hit < distance)
                    { cell = index; distance = hit; }
                }
            }
            return cell >= 0;
        }

        private static void Validate(MapPreviewData.Cell cell, float radius)
        {
            if (radius <= 0 || cell.SurfaceCorners == null || cell.SurfaceCorners.Length != 6)
                throw new ArgumentException("Mountain cells require a positive radius and six corner heights.");
            foreach (var height in cell.SurfaceCorners)
                if (float.IsNaN(height) || float.IsInfinity(height)) throw new ArgumentException("Mountain corner height is not finite.");
        }
        /// <summary>Uses exactly the rendered fan and clipped exterior skirts; no hidden internal prism.</summary>
        public static bool TryRaycastCell(MapPreviewData.Cell cell, float radius, Ray ray, out float distance)
        {
            distance = float.PositiveInfinity;
            if (cell.SurfaceCorners == null) return false;
            Validate(cell, radius);
            if (cell.SurfaceEdgeBottoms != null && cell.SurfaceEdgeBottoms.Length != 6)
                throw new ArgumentException("Mountain edge bottoms must have six entries.");
            for (var edge = 0; edge < 6; edge++)
            {
                var a = Corner(cell, radius, edge); var b = Corner(cell, radius, (edge + 1) % 6);
                Hit(ray, cell.Position, b, a, ref distance);
                if (cell.SurfaceEdgeBottoms == null || float.IsNaN(cell.SurfaceEdgeBottoms[edge])) continue;
                var bottom = cell.SurfaceEdgeBottoms[edge];
                if (!ClipEdge(ref a, ref b, bottom)) continue;
                var lowA = new Vector3(a.x, bottom, a.z); var lowB = new Vector3(b.x, bottom, b.z);
                Hit(ray, a, b, lowB, ref distance); Hit(ray, a, lowB, lowA, ref distance);
            }
            return !float.IsPositiveInfinity(distance);
        }
        public static float HeightAt(MapPreviewData.Cell cell, float radius, Vector3 position)
        {
            if (cell.SurfaceCorners == null) return cell.Position.y;
            Validate(cell, radius);
            var x = (position.x - cell.Position.x) / radius; var z = (position.z - cell.Position.z) / radius;
            for (var i = 0; i < 6; i++)
            {
                var j = (i + 1) % 6; var a = Corners[i]; var b = Corners[j];
                var det = a.x * b.z - a.z * b.x;
                var u = (x * b.z - z * b.x) / det; var v = (a.x * z - a.z * x) / det;
                if (u < -.001f || v < -.001f || u + v > 1.001f) continue;
                return cell.Position.y * (1 - u - v) + cell.SurfaceCorners[i] * u + cell.SurfaceCorners[j] * v;
            }
            throw new ArgumentException("Surface sample lies outside its hex cell.", nameof(position));
        }
        private static void Hit(Ray ray, Vector3 a, Vector3 b, Vector3 c, ref float nearest)
        {
            var edge = b - a; var edge2 = c - a; var p = Vector3.Cross(ray.direction, edge2); var det = Vector3.Dot(edge, p);
            if (Mathf.Abs(det) < .000001f) return;
            var from = ray.origin - a; var u = Vector3.Dot(from, p) / det; if (u < -.000001f || u > 1.000001f) return;
            var q = Vector3.Cross(from, edge); var v = Vector3.Dot(ray.direction, q) / det;
            if (v < -.000001f || u + v > 1.000001f) return;
            var distance = Vector3.Dot(edge2, q) / det;
            if (distance >= 0 && distance < nearest) nearest = distance;
        }
        private void ClearMeshes()
        {
            foreach (var chunk in chunks) Release(chunk.Mesh);
            chunks.Clear(); selected.Clear(); focusOwners.Clear(); focusChunks.Clear(); selectionVertices.Clear(); selectionIndices.Clear();
            edgeVertices.Clear(); edgeColors.Clear(); edgeIndices.Clear(); focusEdges.Clear();
            Release(selectionMesh); Release(focusEdgeMesh); selectionMesh = focusEdgeMesh = null;
            spans = null; known = null; focusLift = focusAmount = 0;
        }
        public void Dispose() { ClearMeshes(); Release(material); map = null; exploration = null; }
        private static void Release(Object value)
        { if (value != null) { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); } }
    }
}
