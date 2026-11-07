using System;
using System.Collections.Generic;
using UnityEngine;
using ProjectY.UI;

namespace ProjectY.Samples
{
    public sealed partial class MapPreviewRenderer
    {
        private struct FocusInstance
        {
            public Batch Batch;
            public int Index;
            public Matrix4x4 Matrix;
            public Vector4 Color;
        }
        private struct FocusReference { public Batch Batch; public int Index; }
        private List<FocusReference>[] instancesByCell;
        private readonly List<FocusInstance> focusedInstances = new List<FocusInstance>();
        private readonly HashSet<Batch> focusedBatches = new HashSet<Batch>();
        private readonly HashSet<int> focusedCells = new HashSet<int>();
        private readonly List<int> focusedRoadVertices = new List<int>();
        private readonly Dictionary<int, List<int>> roadVerticesByCell = new Dictionary<int, List<int>>();
        private sealed class MaskGroup
        {
            public Mesh Mesh;
            public int Submesh;
            public readonly List<FocusReference> Entries = new List<FocusReference>();
        }
        private sealed class MaskChunk
        {
            public Bounds Bounds;
            public readonly Dictionary<Mesh, MaskGroup[]> ByMesh = new Dictionary<Mesh, MaskGroup[]>();
            public readonly List<MaskGroup> Groups = new List<MaskGroup>();
        }
        private readonly Dictionary<Vector2Int, MaskChunk> maskChunks = new Dictionary<Vector2Int, MaskChunk>();
        private readonly Matrix4x4[] maskMatrices = new Matrix4x4[1023];
        private readonly Vector4[] maskFlags = new Vector4[1023];
        private readonly MaterialPropertyBlock maskProperties = new MaterialPropertyBlock();
        private readonly Plane[] maskPlanes = new Plane[6];
        private MapPreviewData focusMap;
        private Bounds focusBounds;
        private int maskInstanceCount, maskRenderCount;
        private int[] roadVertexCells;
        private Vector3[] originalRoadVertices, focusRoadVertices;
        private float focusAmount, focusRadius;
        private bool focusMaskDirty = true;
        private Matrix4x4 maskView, maskProjection;
        private Rect maskViewport;
        internal float FocusLift => focusRadius * .24f * Mathf.SmoothStep(0, 1, focusAmount);
        internal float FocusAmount => focusAmount;

        private void ResetFocus(MapPreviewData map)
        {
            focusedInstances.Clear(); focusedBatches.Clear(); focusedCells.Clear(); focusedRoadVertices.Clear();
            maskChunks.Clear(); roadVerticesByCell.Clear(); focusMap = map;
            buildingPickInstances.Clear();
            wonderPickInstances.Clear(); // Shared immutable mesh BVHs survive a map rebuild.
            instancesByCell = new List<FocusReference>[map.Cells.Length];
            focusAmount = 0; focusRadius = map.Radius;
            focusMaskDirty = true;
            maskInstanceCount = maskRenderCount = 0;
        }
        private void RegisterFocusInstance(int cell, Batch batch, int index)
        {
            if (cell < 0) throw new ArgumentOutOfRangeException(nameof(cell));
            var entries = instancesByCell[cell];
            if (entries == null) instancesByCell[cell] = entries = new List<FocusReference>();
            entries.Add(new FocusReference { Batch = batch, Index = index });
            var coordinate = focusMap.Cells[cell];
            var key = new Vector2Int(Mathf.FloorToInt(coordinate.Q / 8f), Mathf.FloorToInt(coordinate.R / 8f));
            var bounds = InstanceBounds(batch.Mesh.bounds, batch.Matrices[index]);
            bounds.Expand(new Vector3(0, focusRadius * .48f, 0));
            if (!maskChunks.TryGetValue(key, out var chunk))
            { chunk = new MaskChunk { Bounds = bounds }; maskChunks.Add(key, chunk); }
            else chunk.Bounds.Encapsulate(bounds);
            if (!chunk.ByMesh.TryGetValue(batch.Mesh, out var groups))
            { groups = new MaskGroup[batch.Mesh.subMeshCount]; chunk.ByMesh.Add(batch.Mesh, groups); }
            var group = groups[batch.Submesh];
            if (group == null)
            { groups[batch.Submesh] = group = new MaskGroup { Mesh = batch.Mesh, Submesh = batch.Submesh }; chunk.Groups.Add(group); }
            group.Entries.Add(new FocusReference { Batch = batch, Index = index });
            if (batch.Kind == Kind.Building && batch.Submesh == 0)
                buildingPickInstances.Add(new BuildingPickInstance { Batch = batch, Index = index, Cell = cell });
            if (batch.Kind == Kind.Wonder && batch.Submesh == 0)
            {
                if (coordinate.WonderId <= 0) throw new InvalidOperationException("Wonder model has no owning wonder ID.");
                if (!wonderPickMeshes.TryGetValue(batch.Mesh, out var geometry))
                { geometry = new WonderMeshBvh(batch.Mesh); wonderPickMeshes.Add(batch.Mesh, geometry); }
                wonderPickInstances.Add(new WonderPickInstance { Batch = batch, Index = index, Cell = cell, Geometry = geometry });
            }
        }
        internal void SetFocus(IReadOnlyList<int> cells)
        {
            focusMaskDirty = true;
            // Restore from immutable originals: repeatedly hovering never accumulates translation/tint.
            foreach (var entry in focusedInstances)
            {
                entry.Batch.Matrices[entry.Index] = entry.Matrix;
                entry.Batch.Colors[entry.Index] = entry.Color;
                entry.Batch.FocusFlags[entry.Index] = Vector4.zero;
            }
            foreach (var batch in focusedBatches) batch.Properties.SetVectorArray("_Color", batch.Colors);
            if (focusedRoadVertices.Count > 0) { Array.Copy(originalRoadVertices, focusRoadVertices, originalRoadVertices.Length); roadMesh.vertices = focusRoadVertices; roadMesh.RecalculateBounds(); }
            focusedInstances.Clear(); focusedBatches.Clear(); focusedCells.Clear(); focusedRoadVertices.Clear(); focusAmount = 0;
            var hasBounds = false;
            if (cells != null) foreach (var cell in cells)
            {
                if (!focusedCells.Add(cell)) continue;
                var entries = instancesByCell[cell];
                if (mountainSurface.TryGetCellBounds(cell, out var mountainBounds))
                {
                    if (!hasBounds) { focusBounds = mountainBounds; hasBounds = true; }
                    else focusBounds.Encapsulate(mountainBounds);
                }
                else if (entries == null) throw new InvalidOperationException("World site has no rendered ground.");
                if (entries != null) foreach (var entry in entries)
                {
                    var bounds = InstanceBounds(entry.Batch.Mesh.bounds, entry.Batch.Matrices[entry.Index]);
                    if (!hasBounds) { focusBounds = bounds; hasBounds = true; } else focusBounds.Encapsulate(bounds);
                    focusedInstances.Add(new FocusInstance { Batch = entry.Batch, Index = entry.Index,
                        Matrix = entry.Batch.Matrices[entry.Index], Color = entry.Batch.Colors[entry.Index] });
                    focusedBatches.Add(entry.Batch);
                    if (entry.Batch.FocusFlags == null) entry.Batch.FocusFlags = new Vector4[1023];
                    entry.Batch.FocusFlags[entry.Index] = Vector4.one;
                }
                if (roadVerticesByCell.TryGetValue(cell, out var vertices)) focusedRoadVertices.AddRange(vertices);
            }
            natureRenderer.SetFocusCells(focusedCells);
            mountainSurface.SetFocusCells(focusedCells);
        }
        private void CacheFocusRoadVertices()
        {
            roadVerticesByCell.Clear();
            for (var i = 0; i < roadVertexCells.Length; i++)
            {
                var cell = roadVertexCells[i];
                if (!roadVerticesByCell.TryGetValue(cell, out var vertices))
                { vertices = new List<int>(); roadVerticesByCell.Add(cell, vertices); }
                vertices.Add(i);
            }
        }
        internal void TickFocus(float deltaTime)
        {
            if (focusedCells.Count == 0 || focusAmount >= 1) return;
            focusMaskDirty = true;
            focusAmount = Mathf.MoveTowards(focusAmount, 1, deltaTime / .16f);
            var lift = focusRadius * .24f * Mathf.SmoothStep(0, 1, focusAmount);
            var tintColor = new Color(.98f, .88f, .58f);
            var tint = (Vector4)(QualitySettings.activeColorSpace == ColorSpace.Linear ? tintColor.linear : tintColor);
            foreach (var entry in focusedInstances)
            {
                var matrix = entry.Matrix; matrix.m13 += lift;
                entry.Batch.Matrices[entry.Index] = matrix;
                entry.Batch.Colors[entry.Index] = Vector4.Lerp(entry.Color, tint, focusAmount * .3f);
            }
            foreach (var batch in focusedBatches) batch.Properties.SetVectorArray("_Color", batch.Colors);
            foreach (var index in focusedRoadVertices) focusRoadVertices[index] = originalRoadVertices[index] + Vector3.up * lift;
            if (focusedRoadVertices.Count > 0) { roadMesh.vertices = focusRoadVertices; roadMesh.RecalculateBounds(); }
            natureRenderer.SetFocusLift(lift);
            mountainSurface.SetFocusLift(lift, focusAmount);
        }
        internal void RenderFocusMask(Camera camera, SceneFocusMask mask)
        {
            var view = camera.worldToCameraMatrix; var projection = camera.projectionMatrix; var viewport = camera.pixelRect;
            if (!focusMaskDirty && view == maskView && projection == maskProjection && viewport == maskViewport) return;
            CalculateFocusFrustum(camera);
            var commands = mask.Begin(camera);
            maskInstanceCount = 0; maskRenderCount++;
            // Only chunks inside the selected silhouette's viewing cone can occlude it.
            // They still write black/depth, preserving real hills in front of the place.
            foreach (var chunk in maskChunks.Values)
            {
                if (!GeometryUtility.TestPlanesAABB(maskPlanes, chunk.Bounds)) continue;
                foreach (var group in chunk.Groups)
                    for (var offset = 0; offset < group.Entries.Count; offset += 1023)
                    {
                        var limit = Mathf.Min(1023, group.Entries.Count - offset); var count = 0;
                        for (var i = 0; i < limit; i++)
                        {
                            var entry = group.Entries[offset + i];
                            if (!IsWorldInstanceKnown(entry.Batch.Kind, entry.Batch.CellIndices[entry.Index])) continue;
                            maskMatrices[count] = entry.Batch.Matrices[entry.Index];
                            maskFlags[count] = entry.Batch.FocusFlags == null ? Vector4.zero : entry.Batch.FocusFlags[entry.Index]; count++;
                        }
                        if (count == 0) continue;
                        maskProperties.SetVectorArray("_SiteMask", maskFlags);
                        commands.DrawMeshInstanced(group.Mesh, group.Submesh, mask.SilhouetteMaterial, 0, maskMatrices, count, maskProperties);
                        maskInstanceCount += count;
                    }
            }
            maskInstanceCount += mountainSurface.DrawFocusMask(commands, mask.SilhouetteMaterial, maskPlanes);
            mask.End(.34f * focusAmount);
            focusMaskDirty = false; maskView = view; maskProjection = projection; maskViewport = viewport;
        }
        private void CalculateFocusFrustum(Camera camera)
        {
            var bounds = focusBounds; bounds.center += Vector3.up * FocusLift;
            var min = Vector2.one; var max = Vector2.zero; var depth = camera.nearClipPlane; var clipped = false;
            for (var x = -1; x <= 1; x += 2) for (var y = -1; y <= 1; y += 2) for (var z = -1; z <= 1; z += 2)
            {
                var point = camera.WorldToViewportPoint(bounds.center + Vector3.Scale(bounds.extents, new Vector3(x, y, z)));
                if (point.z <= camera.nearClipPlane) clipped = true;
                min = Vector2.Min(min, point); max = Vector2.Max(max, point); depth = Mathf.Max(depth, point.z);
            }
            var crop = Matrix4x4.identity;
            if (!clipped)
            {
                var pad = new Vector2(4f / Mathf.Max(1, camera.pixelWidth), 4f / Mathf.Max(1, camera.pixelHeight));
                min = Vector2.Max(Vector2.zero, min - pad); max = Vector2.Min(Vector2.one, max + pad);
                var size = Vector2.Max(max - min, new Vector2(.0001f, .0001f));
                crop.m00 = 1 / size.x; crop.m11 = 1 / size.y;
                crop.m03 = (1 - min.x - max.x) / size.x; crop.m13 = (1 - min.y - max.y) / size.y;
            }
            GeometryUtility.CalculateFrustumPlanes(crop * camera.projectionMatrix * camera.worldToCameraMatrix, maskPlanes);
            maskPlanes[5] = new Plane(-camera.transform.forward, camera.transform.position + camera.transform.forward * (depth + focusRadius));
        }
        private static Bounds InstanceBounds(Bounds local, Matrix4x4 matrix)
        {
            var x = matrix.MultiplyVector(new Vector3(local.extents.x, 0, 0));
            var y = matrix.MultiplyVector(new Vector3(0, local.extents.y, 0));
            var z = matrix.MultiplyVector(new Vector3(0, 0, local.extents.z));
            var extent = new Vector3(Mathf.Abs(x.x) + Mathf.Abs(y.x) + Mathf.Abs(z.x),
                Mathf.Abs(x.y) + Mathf.Abs(y.y) + Mathf.Abs(z.y), Mathf.Abs(x.z) + Mathf.Abs(y.z) + Mathf.Abs(z.z));
            return new Bounds(matrix.MultiplyPoint3x4(local.center), extent * 2);
        }
        internal bool PickBuilding(Ray ray, out int cell, out float distance)
        {
            cell = -1; distance = float.PositiveInfinity;
            foreach (var entry in buildingPickInstances)
            {
                var matrix = entry.Batch.Matrices[entry.Index]; var inverse = matrix.inverse;
                var local = new Ray(inverse.MultiplyPoint3x4(ray.origin), inverse.MultiplyVector(ray.direction));
                if (!entry.Batch.Mesh.bounds.IntersectRay(local, out var hit)) continue;
                var world = matrix.MultiplyPoint3x4(local.GetPoint(hit));
                var along = Vector3.Dot(world - ray.origin, ray.direction);
                if (along >= 0 && along < distance) { distance = along; cell = entry.Cell; }
            }
            return cell >= 0;
        }
        private struct BuildingPickInstance { public Batch Batch; public int Index, Cell; }
        private readonly List<BuildingPickInstance> buildingPickInstances = new List<BuildingPickInstance>();

        private struct WonderPickInstance
        {
            public Batch Batch;
            public int Index, Cell;
            public WonderMeshBvh Geometry;
        }
        private readonly List<WonderPickInstance> wonderPickInstances = new List<WonderPickInstance>();
        private readonly Dictionary<Mesh, WonderMeshBvh> wonderPickMeshes = new Dictionary<Mesh, WonderMeshBvh>();

        internal bool PickWonder(Ray ray, out int cell, out float distance)
        {
            cell = -1; distance = float.PositiveInfinity;
            var worldDirection = ray.direction.normalized;
            if (worldDirection.sqrMagnitude == 0) throw new ArgumentException("Wonder picking requires a nonzero ray direction.", nameof(ray));
            foreach (var entry in wonderPickInstances)
            {
                if (!IsWorldWonderKnown(focusMap.Cells[entry.Cell].WonderId)) continue;
                // Use the current instance transform, including site hover lift.
                // Normalizing the transformed direction changes its distance unit;
                // explicitly convert both the pruning limit and the resulting hit.
                var matrix = entry.Batch.Matrices[entry.Index]; var inverse = matrix.inverse;
                var localDirection = inverse.MultiplyVector(worldDirection);
                var localUnitsPerWorldUnit = localDirection.magnitude;
                if (localUnitsPerWorldUnit <= 0) throw new InvalidOperationException("Wonder instance has a singular transform.");
                var localRay = new Ray(inverse.MultiplyPoint3x4(ray.origin), localDirection / localUnitsPerWorldUnit);
                if (!entry.Geometry.Raycast(localRay, distance * localUnitsPerWorldUnit, out var localDistance)) continue;
                var point = matrix.MultiplyPoint3x4(localRay.GetPoint(localDistance));
                var worldDistance = Vector3.Dot(point - ray.origin, worldDirection);
                if (worldDistance >= 0 && worldDistance < distance)
                { cell = entry.Cell; distance = worldDistance; }
            }
            return cell >= 0;
        }

        // Giant trees contain hundreds of thousands of opaque wood/leaf triangles.
        // Build once per readable asset mesh; pointer queries only visit intersecting
        // BVH nodes. Empty spaces inside the model bounds remain genuine pick gaps.
        private sealed class WonderMeshBvh
        {
            private const int LeafTriangleLimit = 32;
            private struct Node
            {
                public Bounds Bounds;
                public int Left, Right, Start, Count;
            }
            private sealed class TriangleComparer : IComparer<int>
            {
                private readonly Vector3[] centroids;
                private readonly int axis;
                public TriangleComparer(Vector3[] centroids, int axis) { this.centroids = centroids; this.axis = axis; }
                public int Compare(int first, int second)
                {
                    var value = centroids[first][axis].CompareTo(centroids[second][axis]);
                    return value == 0 ? first.CompareTo(second) : value;
                }
            }
            private readonly Vector3[] vertices;
            private readonly int[] triangles, order;
            private readonly Node[] nodes;
            private readonly int[] pendingNodes;
            private readonly float[] pendingDistances;
            public int TriangleCount => order.Length;
            public int LastTriangleTests { get; private set; }
            public int LastNodeVisits { get; private set; }

            public WonderMeshBvh(Mesh mesh)
            {
                if (!mesh.isReadable)
                    throw new InvalidOperationException("Wonder picking requires Read/Write enabled on the model importer: " + mesh.name);
                for (var submesh = 0; submesh < mesh.subMeshCount; submesh++)
                    if (mesh.GetTopology(submesh) != MeshTopology.Triangles)
                        throw new InvalidOperationException("Wonder picking requires triangle mesh topology: " + mesh.name);
                vertices = mesh.vertices; triangles = mesh.triangles;
                if (triangles.Length == 0 || triangles.Length % 3 != 0)
                    throw new InvalidOperationException("Wonder picking requires nonempty triangles: " + mesh.name);
                var count = triangles.Length / 3;
                order = new int[count];
                var triangleBounds = new Bounds[count]; var centroids = new Vector3[count];
                for (var i = 0; i < count; i++)
                {
                    order[i] = i;
                    var a = vertices[triangles[i * 3]]; var b = vertices[triangles[i * 3 + 1]]; var c = vertices[triangles[i * 3 + 2]];
                    var bounds = new Bounds(a, Vector3.zero); bounds.Encapsulate(b); bounds.Encapsulate(c);
                    triangleBounds[i] = bounds; centroids[i] = (a + b + c) / 3;
                }
                var comparers = new[] { new TriangleComparer(centroids, 0), new TriangleComparer(centroids, 1), new TriangleComparer(centroids, 2) };
                var built = new List<Node>(); var depth = 0;
                BuildNode(built, triangleBounds, centroids, comparers, 0, count, 0, ref depth);
                nodes = built.ToArray();
                // Balanced median splits bound the deferred far-child stack by depth.
                // Both buffers are retained; no query allocates arrays or triangle lists.
                pendingNodes = new int[depth + 1]; pendingDistances = new float[depth + 1];
            }

            private int BuildNode(List<Node> built, Bounds[] triangleBounds, Vector3[] centroids, TriangleComparer[] comparers,
                int start, int count, int depth, ref int maximumDepth)
            {
                maximumDepth = Mathf.Max(maximumDepth, depth);
                var bounds = triangleBounds[order[start]];
                var centroidBounds = new Bounds(centroids[order[start]], Vector3.zero);
                for (var i = start + 1; i < start + count; i++)
                { bounds.Encapsulate(triangleBounds[order[i]]); centroidBounds.Encapsulate(centroids[order[i]]); }
                var index = built.Count;
                var node = new Node { Bounds = bounds, Start = start, Count = count, Left = -1, Right = -1 };
                built.Add(node);
                if (count > LeafTriangleLimit)
                {
                    var size = centroidBounds.size;
                    var axis = size.x >= size.y && size.x >= size.z ? 0 : size.y >= size.z ? 1 : 2;
                    // Source triangle index breaks equal-centroid ties, making every
                    // partition deterministic without changing source index buffers.
                    Array.Sort(order, start, count, comparers[axis]);
                    var leftCount = count / 2;
                    node.Left = BuildNode(built, triangleBounds, centroids, comparers, start, leftCount, depth + 1, ref maximumDepth);
                    node.Right = BuildNode(built, triangleBounds, centroids, comparers, start + leftCount, count - leftCount, depth + 1, ref maximumDepth);
                    node.Count = 0; built[index] = node;
                }
                return index;
            }

            public bool Raycast(Ray ray, float limit, out float distance)
            {
                distance = limit; LastTriangleTests = LastNodeVisits = 0;
                if (!nodes[0].Bounds.IntersectRay(ray, out var near) || near > limit) return false;
                var pending = 1; var hitTriangle = -1;
                pendingNodes[0] = 0; pendingDistances[0] = near;
                while (pending > 0)
                {
                    pending--;
                    var index = pendingNodes[pending];
                    if (pendingDistances[pending] > distance) continue;
                    LastNodeVisits++;
                    var node = nodes[index];
                    if (node.Count > 0)
                    {
                        for (var i = node.Start; i < node.Start + node.Count; i++)
                        {
                            var triangle = order[i]; var offset = triangle * 3; LastTriangleTests++;
                            if (!HitTriangle(ray, vertices[triangles[offset]], vertices[triangles[offset + 1]], vertices[triangles[offset + 2]], out var hit)) continue;
                            if (hit < distance || hit == distance && (hitTriangle < 0 || triangle < hitTriangle))
                            { distance = hit; hitTriangle = triangle; }
                        }
                        continue;
                    }
                    var left = nodes[node.Left].Bounds.IntersectRay(ray, out var leftNear) && leftNear <= distance;
                    var right = nodes[node.Right].Bounds.IntersectRay(ray, out var rightNear) && rightNear <= distance;
                    if (left && right)
                    {
                        var first = leftNear <= rightNear ? node.Left : node.Right;
                        var second = leftNear <= rightNear ? node.Right : node.Left;
                        pendingNodes[pending] = second; pendingDistances[pending++] = Mathf.Max(leftNear, rightNear);
                        pendingNodes[pending] = first; pendingDistances[pending++] = Mathf.Min(leftNear, rightNear);
                    }
                    else if (left) { pendingNodes[pending] = node.Left; pendingDistances[pending++] = leftNear; }
                    else if (right) { pendingNodes[pending] = node.Right; pendingDistances[pending++] = rightNear; }
                }
                return hitTriangle >= 0;
            }

            private static bool HitTriangle(Ray ray, Vector3 a, Vector3 b, Vector3 c, out float distance)
            {
                distance = 0;
                var edge = b - a; var edge2 = c - a; var cross = Vector3.Cross(ray.direction, edge2);
                var determinant = Vector3.Dot(edge, cross);
                if (Mathf.Abs(determinant) < .0000001f) return false;
                var from = ray.origin - a; var u = Vector3.Dot(from, cross) / determinant;
                if (u < -.000001f || u > 1.000001f) return false;
                var q = Vector3.Cross(from, edge); var v = Vector3.Dot(ray.direction, q) / determinant;
                if (v < -.000001f || u + v > 1.000001f) return false;
                distance = Vector3.Dot(edge2, q) / determinant;
                return distance >= 0;
            }
        }

        private void DisposeFocus()
        {
            focusedInstances.Clear(); focusedBatches.Clear(); maskChunks.Clear(); roadVerticesByCell.Clear(); buildingPickInstances.Clear();
            wonderPickInstances.Clear(); wonderPickMeshes.Clear();
            instancesByCell = null; focusMap = null;
        }
    }
}
