using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    // Layout belongs to Lua. This renderer owns only shared geometry, batches and their culling tree.
    public sealed class MapNatureRenderer : IDisposable
    {
        private const int Variants = 3, KindCount = 5, BatchSize = 1023, CreatureBudget = 96;
        private sealed class Batch
        {
            public Matrix4x4[] Matrices = new Matrix4x4[16];
            public Vector4[] Tints = new Vector4[16];
            public Vector4[] Data = new Vector4[16];
            public readonly MaterialPropertyBlock Properties = new MaterialPropertyBlock();
            public int MeshIndex, Count;
            public void EnsureCapacity()
            {
                if (Count < Matrices.Length) return;
                Resize(Mathf.Min(BatchSize, Matrices.Length * 2));
            }
            public void Resize(int count)
            {
                Array.Resize(ref Matrices, count); Array.Resize(ref Tints, count); Array.Resize(ref Data, count);
            }
        }
        private sealed class Bucket
        {
            public Bounds Bounds;
            public readonly List<Batch> Batches = new List<Batch>();
            public readonly Batch[] LastByMesh = new Batch[KindCount * Variants];
        }
        private sealed class Node
        {
            public Bounds Bounds;
            public Node Left, Right;
            public Bucket Bucket;
        }
        private sealed class BucketComparer : IComparer<Bucket>
        {
            public int Axis;
            public int Compare(Bucket a, Bucket b) => a.Bounds.center[Axis].CompareTo(b.Bounds.center[Axis]);
        }
        private readonly Mesh[] meshes = new Mesh[KindCount * Variants];
        private readonly Bounds[] authoredBounds = new Bounds[KindCount * Variants];
        private readonly Plane[] planes = new Plane[6];
        private readonly Material material;
        private readonly int layer;
        private Node root;
        private float radius;
        private bool visible = true;
        private bool disposed;

        // A negative value follows Unity time; previews may set _NaturePreviewTime on this material.
        public Material SharedMaterial => material;

        public MapNatureRenderer(Transform owner)
        {
            if (owner == null) throw new ArgumentNullException(nameof(owner));
            if (!SystemInfo.supportsInstancing) throw new NotSupportedException("地图地被需要 GPU Instancing。");
            var shader = Resources.Load<Shader>("MapNature");
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("地图地被 Shader 缺失或不受支持。");
            layer = owner.gameObject.layer;
            material = new Material(shader) { name = "地图_地被与小生物", enableInstancing = true };
            for (var kind = 1; kind <= KindCount; kind++)
                for (var variant = 0; variant < Variants; variant++)
                {
                    var index = (kind - 1) * Variants + variant;
                    meshes[index] = CreateMesh(kind, variant);
                    authoredBounds[index] = meshes[index].bounds;
                }
        }

        public void Build(MapPreviewData map)
        {
            if (disposed) throw new ObjectDisposedException(nameof(MapNatureRenderer));
            if (map == null) throw new ArgumentNullException(nameof(map));
            if (map.Radius <= 0) throw new InvalidOperationException("地图半径必须为正。");
            root = null;
            radius = map.Radius;
            var surfaces = new Dictionary<int, MapPreviewData.Surface>();
            foreach (var surface in map.Surfaces) surfaces.Add(surface.Id, surface);
            var buckets = new Dictionary<Vector2Int, Bucket>();
            var minimumScale = 1f;
            foreach (var cover in map.Groundcover)
            {
                if (cover.Kind < 1 || cover.Kind > KindCount || cover.Scale <= 0)
                    throw new InvalidOperationException("地被种类或缩放不符合显示契约。");
                var cell = map.Cells[cover.Cell];
                if (cell.HasWater) throw new InvalidOperationException("地被不能生成在水格。");
                var first = surfaces[cell.SurfaceA];
                var second = surfaces[cell.SurfaceB];
                var wind = Mathf.Lerp(first.WindStrength, second.WindStrength, cell.SurfaceBlend);
                var ground = Color.Lerp(first.Color, second.Color, cell.SurfaceBlend);
                var variant = Mathf.FloorToInt(Mathf.Repeat(cover.Phase / (Mathf.PI * 2), 1) * Variants);
                var meshIndex = (cover.Kind - 1) * Variants + variant;
                var position = cell.Position + new Vector3(cover.OffsetX, radius * .008f, cover.OffsetZ);
                if (cover.Kind >= 4) position.y += radius * (cover.Kind == 4 ? .40f : .23f);
                var scale = cover.Scale * radius;
                minimumScale = Mathf.Min(minimumScale, cover.Scale);
                var key = new Vector2Int(Mathf.FloorToInt(position.x / (radius * 8)), Mathf.FloorToInt(position.z / (radius * 8)));
                if (!buckets.TryGetValue(key, out var bucket))
                {
                    bucket = new Bucket { Bounds = new Bounds(position, Vector3.zero) };
                    buckets.Add(key, bucket);
                }
                var batch = bucket.LastByMesh[meshIndex];
                if (batch == null || batch.Count == BatchSize)
                {
                    batch = new Batch { MeshIndex = meshIndex };
                    bucket.Batches.Add(batch); bucket.LastByMesh[meshIndex] = batch;
                }
                batch.EnsureCapacity();
                var tint = Tint(cover.Kind, cover.Phase, ground, cell.Color);
                batch.Tints[batch.Count] = QualitySettings.activeColorSpace == ColorSpace.Linear ? tint.linear : tint;
                batch.Data[batch.Count] = new Vector4(cover.Phase, Mathf.Clamp(wind, 0, 2), cover.Kind, radius);
                batch.Matrices[batch.Count++] = Matrix4x4.TRS(position, Quaternion.Euler(0, cover.Yaw, 0), Vector3.one * scale);
                // Rotation-independent envelope includes the world-space flight and wind displacement.
                var envelope = authoredBounds[meshIndex].center.magnitude + authoredBounds[meshIndex].extents.magnitude;
                bucket.Bounds.Encapsulate(new Bounds(position, Vector3.one * (envelope * scale + radius * .25f) * 2));
            }
            foreach (var bucket in buckets.Values)
                foreach (var batch in bucket.Batches)
                {
                    batch.Resize(batch.Count);
                    batch.Properties.SetVectorArray("_NatureTint", batch.Tints);
                    batch.Properties.SetVectorArray("_NatureData", batch.Data);
                }
            // DrawMeshInstanced also performs internal bounds checks. Include shader movement even
            // for the smallest authored instance, independently of the CPU bucket envelope.
            for (var i = 0; i < meshes.Length; i++)
            {
                var bounds = authoredBounds[i]; bounds.Expand(.5f / minimumScale); meshes[i].bounds = bounds;
            }
            if (buckets.Count == 0) return;
            var ordered = new Bucket[buckets.Count]; buckets.Values.CopyTo(ordered, 0);
            root = BuildTree(ordered, 0, ordered.Length, new BucketComparer());
        }

        private static Color Tint(int kind, float phase, Color surface, Color cell)
        {
            if (kind == 4)
            {
                var palette = Mathf.FloorToInt(Mathf.Repeat(phase * .618f, 1) * 3);
                return palette == 0 ? new Color(.92f, .66f, .24f) : palette == 1
                    ? new Color(.71f, .84f, .93f) : new Color(.90f, .79f, .66f);
            }
            if (kind == 5) return Color.white;
            var natural = Color.Lerp(surface, cell, .35f);
            var green = Color.Lerp(new Color(.34f, .47f, .19f), natural, .28f);
            green *= .85f + .13f * Mathf.Sin(phase * 1.71f);
            green.a = 1;
            return green;
        }

        private static Node BuildTree(Bucket[] buckets, int start, int count, BucketComparer comparer)
        {
            var bounds = buckets[start].Bounds;
            for (var i = start + 1; i < start + count; i++) bounds.Encapsulate(buckets[i].Bounds);
            if (count == 1) return new Node { Bounds = bounds, Bucket = buckets[start] };
            comparer.Axis = bounds.size.x >= bounds.size.z ? 0 : 2;
            Array.Sort(buckets, start, count, comparer);
            var half = count / 2;
            return new Node { Bounds = bounds, Left = BuildTree(buckets, start, half, comparer),
                Right = BuildTree(buckets, start + half, count - half, comparer) };
        }

        public void SetVisible(bool value) { visible = value; }

        public void Draw(Camera camera, bool enabled)
        {
            if (!visible || !enabled || root == null || disposed) return;
            if (camera == null) throw new ArgumentNullException(nameof(camera));
            if (camera.orthographic && radius * camera.pixelHeight / (2 * camera.orthographicSize) < 4) return;
            GeometryUtility.CalculateFrustumPlanes(camera, planes);
            var remainingCreatures = CreatureBudget;
            DrawNode(root, camera, ref remainingCreatures);
        }

        private void DrawNode(Node node, Camera camera, ref int remainingCreatures)
        {
            if (!GeometryUtility.TestPlanesAABB(planes, node.Bounds)) return;
            var pixels = ProjectedRadius(camera, node.Bounds);
            if (pixels < 4) return;
            if (node.Bucket == null)
            {
                // Visit nearer space first so the bounded small-creature budget serves the close view.
                var leftFirst = (node.Left.Bounds.center - camera.transform.position).sqrMagnitude
                    <= (node.Right.Bounds.center - camera.transform.position).sqrMagnitude;
                DrawNode(leftFirst ? node.Left : node.Right, camera, ref remainingCreatures);
                DrawNode(leftFirst ? node.Right : node.Left, camera, ref remainingCreatures);
                return;
            }
            foreach (var batch in node.Bucket.Batches)
            {
                var kind = batch.MeshIndex / Variants + 1;
                var minimum = kind == 5 ? 48f : kind == 4 ? 24f : 4f;
                var fade = Mathf.Clamp01((pixels - minimum) / minimum);
                if (fade <= 0 || (kind >= 4 && remainingCreatures == 0)) continue;
                var count = kind >= 4 ? Mathf.Min(batch.Count, remainingCreatures) : batch.Count;
                if (kind >= 4) remainingCreatures -= count;
                batch.Properties.SetFloat("_NatureFade", fade);
                Graphics.DrawMeshInstanced(meshes[batch.MeshIndex], 0, material, batch.Matrices, count,
                    batch.Properties, ShadowCastingMode.Off, true, layer, camera, LightProbeUsage.Off);
            }
        }

        private float ProjectedRadius(Camera camera, Bounds bounds)
        {
            if (camera.orthographic) return radius * camera.pixelHeight / (2 * camera.orthographicSize);
            var depth = Vector3.Dot(bounds.center - camera.transform.position, camera.transform.forward) - bounds.extents.magnitude;
            depth = Mathf.Max(camera.nearClipPlane, depth);
            return radius * camera.pixelHeight / (2 * depth * Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * .5f));
        }

        private static Mesh CreateMesh(int kind, int variant)
        {
            var mesh = new Shape();
            switch (kind)
            {
                case 1: Grass(mesh, variant); break;
                case 2: Shrub(mesh, variant); break;
                case 3: Flower(mesh, variant); break;
                case 4: Butterfly(mesh, variant); break;
                case 5: Insects(mesh, variant); break;
            }
            return mesh.Finish("地图自然_" + kind + "_" + variant);
        }

        private static void Grass(Shape mesh, int variant)
        {
            for (var i = 0; i < 5 + variant; i++)
            {
                var angle = i * 2.39996f + variant * .71f;
                var along = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle));
                var side = Vector3.Cross(Vector3.up, along);
                var root = along * (.018f + .007f * (i % 3));
                var height = .20f + .035f * ((i * 3 + variant) % 5);
                var width = .014f + .003f * (i % 2);
                var bend = along * (.045f + .015f * variant);
                var middle = root + Vector3.up * height * .58f + bend * .32f;
                var tip = root + Vector3.up * height + bend;
                var tint = new Color(.85f + i % 3 * .07f, 1, .82f, 1);
                mesh.Quad(root - side * width, root + side * width,
                    middle + side * width * .58f, middle - side * width * .58f, tint);
                mesh.Triangle(middle - side * width * .58f, middle + side * width * .58f, tip, tint);
            }
        }

        private static void Shrub(Shape mesh, int variant)
        {
            var branch = new Color(.28f, .20f, .11f, 0);
            for (var i = 0; i < 4 + variant; i++)
            {
                var angle = i * 2.39996f + variant;
                var spread = i == 0 ? .02f : .11f + (i % 2) * .035f;
                var center = new Vector3(Mathf.Cos(angle) * spread, .17f + .047f * ((i + variant) % 3), Mathf.Sin(angle) * spread);
                mesh.Stem(new Vector3(0, 0, 0), center, .011f, branch);
                mesh.Crown(center, new Vector3(.14f + .02f * (i % 2), .14f + .02f * variant, .12f),
                    new Color(.88f + .04f * (i % 3), .96f, .79f, 1), i * .9f);
            }
        }

        private static void Flower(Shape mesh, int variant)
        {
            var stem = new Color(.28f, .39f, .15f, 0);
            var petal = variant == 0 ? new Color(.84f, .79f, .92f, 0) : variant == 1
                ? new Color(.96f, .86f, .52f, 0) : new Color(.89f, .71f, .71f, 0);
            for (var i = 0; i < 2 + (variant == 2 ? 1 : 0); i++)
            {
                var root = new Vector3((i - .5f) * .066f, 0, i % 2 * .043f);
                var top = root + new Vector3(.018f * (i + 1), .27f + .045f * ((i + variant) % 3), 0);
                mesh.Stem(root, top, .006f, stem);
                var leaf = Vector3.Lerp(root, top, .48f);
                mesh.Triangle(leaf, leaf + new Vector3(-.065f, .025f, .013f), leaf + Vector3.up * .055f,
                    new Color(.85f, 1, .8f, 1));
                var petals = 5 + (variant % 2);
                for (var p = 0; p < petals; p++)
                {
                    var angle = p * Mathf.PI * 2 / petals + i;
                    var along = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle));
                    var side = Vector3.Cross(Vector3.up, along);
                    var outer = top + along * .045f + Vector3.up * .009f;
                    mesh.Quad(top, outer - side * .021f, outer + along * .014f, outer + side * .021f, petal);
                }
                mesh.Crown(top + Vector3.up * .008f, new Vector3(.015f, .012f, .015f), new Color(.84f, .56f, .14f, 0), 0);
            }
        }

        private static void Butterfly(Shape mesh, int variant)
        {
            var wing = new Color(.97f, .96f, .92f, 1);
            var tipColor = new Color(.36f, .28f, .20f, 0);
            for (var sign = -1; sign <= 1; sign += 2)
            {
                var span = .080f + variant * .013f;
                var root = new Vector3(sign * .007f, 0, 0);
                var front = new Vector3(sign * span, .002f, .040f + variant * .006f);
                var tip = new Vector3(sign * (span + .015f), 0, -.015f);
                var back = new Vector3(sign * span * .68f, 0, -.065f);
                mesh.Triangle(root, front, tip, wing, sign);
                mesh.Triangle(root, tip, back, wing, sign);
                mesh.Triangle(front, tip, Vector3.Lerp(front, root, .22f), tipColor, sign);
            }
            mesh.Crown(Vector3.zero, new Vector3(.008f, .010f, .048f), new Color(.20f, .16f, .12f, 0), 0);
        }

        private static void Insects(Shape mesh, int variant)
        {
            for (var i = 0; i < 2 + variant; i++)
            {
                var center = new Vector3(Mathf.Sin(i * 2.3f + variant) * .052f, (i % 2) * .035f, Mathf.Cos(i * 2.3f) * .046f);
                mesh.Crown(center, new Vector3(.009f, .012f, .009f), new Color(.35f, .31f, .18f, 0), i);
                mesh.Triangle(center + new Vector3(-.017f, .007f, 0), center + new Vector3(.017f, .007f, 0),
                    center + new Vector3(0, .012f, .013f), new Color(.83f, .84f, .67f, 0));
            }
        }

        private sealed class Shape
        {
            private readonly List<Vector3> vertices = new List<Vector3>();
            private readonly List<Color> colors = new List<Color>();
            private readonly List<Vector2> uv = new List<Vector2>();
            private readonly List<int> triangles = new List<int>();
            public void Triangle(Vector3 a, Vector3 b, Vector3 c, Color color, float wing = 0)
            {
                var start = vertices.Count;
                Add(a, color, wing); Add(b, color, wing); Add(c, color, wing);
                triangles.Add(start); triangles.Add(start + 1); triangles.Add(start + 2);
            }
            private void Add(Vector3 position, Color color, float wing)
            {
                vertices.Add(position);
                var tint = QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color;
                tint.a = color.a; colors.Add(tint);
                uv.Add(new Vector2(wing, Mathf.Clamp01(position.y / .42f)));
            }
            public void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Color color)
            { Triangle(a, b, c, color); Triangle(a, c, d, color); }
            public void Stem(Vector3 root, Vector3 top, float width, Color color)
            {
                Quad(root - Vector3.right * width, root + Vector3.right * width, top + Vector3.right * width, top - Vector3.right * width, color);
                Quad(root - Vector3.forward * width, root + Vector3.forward * width, top + Vector3.forward * width, top - Vector3.forward * width, color);
            }
            public void Crown(Vector3 center, Vector3 extent, Color color, float yaw)
            {
                const int sides = 5;
                var top = center + Vector3.up * extent.y;
                var bottom = center - Vector3.up * extent.y * .55f;
                for (var i = 0; i < sides; i++)
                {
                    var a = i * Mathf.PI * 2 / sides + yaw;
                    var b = (i + 1) * Mathf.PI * 2 / sides + yaw;
                    var first = center + new Vector3(Mathf.Cos(a) * extent.x, 0, Mathf.Sin(a) * extent.z);
                    var second = center + new Vector3(Mathf.Cos(b) * extent.x, 0, Mathf.Sin(b) * extent.z);
                    Triangle(top, second, first, color); Triangle(bottom, first, second, color);
                }
            }
            public Mesh Finish(string name)
            {
                var mesh = new Mesh { name = name };
                mesh.SetVertices(vertices); mesh.SetColors(colors); mesh.SetUVs(0, uv); mesh.SetTriangles(triangles, 0);
                mesh.RecalculateNormals(); mesh.RecalculateBounds();
                return mesh;
            }
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true; visible = false; root = null;
            foreach (var mesh in meshes) Release(mesh);
            Release(material);
        }

        private static void Release(Object value)
        {
            if (value == null) return;
            if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value);
        }
    }
}
