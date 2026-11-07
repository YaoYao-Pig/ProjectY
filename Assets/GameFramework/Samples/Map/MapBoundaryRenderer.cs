using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    /// <summary>Extends displayed water beyond the map; no navigation or exploration state.</summary>
    internal sealed class MapBoundaryRenderer : IDisposable
    {
        private struct Sample { public Vector3 Position; public bool Water; public float Level, Depth; }
        private readonly Texture2D field;
        private readonly Mesh mesh;
        private readonly Material material;
        private readonly Vector4 bounds;
        private Camera depthCamera;

        internal MapBoundaryRenderer(MapPreviewData map) : this(map.Radius, Samples(map)) { }
        internal MapBoundaryRenderer(MapAreaViewData map) : this(map.Radius, Samples(map)) { }
        private static IEnumerable<Sample> Samples(MapPreviewData map)
        {
            foreach (var cell in map.Cells)
            {
                float level = cell.Position.y;
                if (cell.SurfaceCorners != null)
                    foreach (float corner in cell.SurfaceCorners) level = Mathf.Min(level, corner);
                yield return new Sample { Position = cell.Position, Water = cell.HasWater,
                    Level = cell.HasWater ? cell.WaterLevel : level, Depth = cell.WaterDepth };
            }
        }
        private static IEnumerable<Sample> Samples(MapAreaViewData map)
        {
            foreach (var cell in map.Cells)
                if (cell.RenderGround && cell.Kind != "void" || cell.WaterDepth > 0)
                    yield return new Sample { Position = cell.Position, Water = cell.WaterDepth > 0 || cell.Kind == "water",
                        Level = cell.WaterDepth > 0 ? cell.WaterLevel : cell.Position.y,
                        Depth = cell.WaterDepth > 0 ? cell.WaterDepth : -1 };
        }
        private MapBoundaryRenderer(float radius, IEnumerable<Sample> samples)
        {
            if (radius <= 0) throw new ArgumentOutOfRangeException(nameof(radius));
            var cells = new Dictionary<Vector2Int, Sample>();
            var box = new Bounds(); bool first = true;
            foreach (var sample in samples)
            {
                var key = CellAt(sample.Position.x, sample.Position.z, radius);
                // A bridge above water must not become an artificial shoreline.
                if (!cells.TryGetValue(key, out var previous) || sample.Water) cells[key] = sample;
                if (first) { box = new Bounds(sample.Position, Vector3.zero); first = false; }
                else box.Encapsulate(sample.Position);
            }
            if (first) throw new ArgumentException("Map boundary requires a non-empty map.");
            box.Expand(radius * 12);
            bounds = new Vector4(box.min.x, box.min.z, 1 / box.size.x, 1 / box.size.z);
            int width = Mathf.Clamp(Mathf.CeilToInt(box.size.x / radius * 3), 32, 1024);
            int height = Mathf.Clamp(Mathf.CeilToInt(box.size.z / radius * 3), 32, 1024);
            float dx = box.size.x / width, dz = box.size.z / height;
            var occupied = new bool[width * height]; var land = new bool[occupied.Length];
            var levels = new float[occupied.Length];
            var depths = new float[occupied.Length];
            var queue = new Queue<int>();
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
            {
                int i = y * width + x; depths[i] = .35f;
                var key = CellAt(box.min.x + (x + .5f) * dx, box.min.z + (y + .5f) * dz, radius);
                if (!cells.TryGetValue(key, out var cell)) continue;
                occupied[i] = true; land[i] = !cell.Water;
                levels[i] = cell.Water ? cell.Level : cell.Level - radius * .5f;
                if (cell.Water)
                    depths[i] = cell.Depth < 0 ? -1 : cell.Depth / radius;
            }
            // Enclosed voids do not turn courtyards and shafts into map edges.
            var exterior = new bool[occupied.Length];
            Action<int> visit = i => { if (!occupied[i] && !exterior[i]) { exterior[i] = true; queue.Enqueue(i); } };
            for (int x = 0; x < width; x++) { visit(x); visit((height - 1) * width + x); }
            for (int y = 0; y < height; y++) { visit(y * width); visit(y * width + width - 1); }
            while (queue.Count > 0)
            {
                int i = queue.Dequeue(), x = i % width, y = i / width;
                if (x > 0) visit(i - 1); if (x + 1 < width) visit(i + 1);
                if (y > 0) visit(i - width); if (y + 1 < height) visit(i + width);
            }
            // Every actual coastline sets its local water height. Inland pits/lakes and enclosed holes
            // are not sources; occupied pixels block propagation between unrelated coasts.
            float lowestWater = float.PositiveInfinity, highestWater = float.NegativeInfinity;
            for (int i = 0; i < occupied.Length; i++)
            {
                if (!occupied[i]) continue;
                int x = i % width, y = i / width;
                if (!(x > 0 && exterior[i - 1] || x + 1 < width && exterior[i + 1]
                    || y > 0 && exterior[i - width] || y + 1 < height && exterior[i + width])) continue;
                lowestWater = Mathf.Min(lowestWater, levels[i]); highestWater = Mathf.Max(highestWater, levels[i]);
                queue.Enqueue(i);
            }
            var assigned = (bool[])occupied.Clone();
            while (queue.Count > 0)
            {
                int i = queue.Dequeue(), x = i % width, y = i / width;
                if (x > 0) ExtendLevel(i, i - 1, levels, depths, assigned, queue);
                if (x + 1 < width) ExtendLevel(i, i + 1, levels, depths, assigned, queue);
                if (y > 0) ExtendLevel(i, i - width, levels, depths, assigned, queue);
                if (y + 1 < height) ExtendLevel(i, i + width, levels, depths, assigned, queue);
            }
            // Soften boundaries between differently elevated coasts without changing real water/land.
            var smoothed = new float[levels.Length];
            for (int pass = 0; pass < 8; pass++)
            {
                for (int i = 0; i < levels.Length; i++)
                {
                    if (!exterior[i]) { smoothed[i] = levels[i]; continue; }
                    int x = i % width, y = i / width, weight = 4;
                    float sum = levels[i] * weight;
                    if (x > 0) { sum += levels[i - 1]; weight++; }
                    if (x + 1 < width) { sum += levels[i + 1]; weight++; }
                    if (y > 0) { sum += levels[i - width]; weight++; }
                    if (y + 1 < height) { sum += levels[i + width]; weight++; }
                    smoothed[i] = sum / weight;
                }
                var swap = levels; levels = smoothed; smoothed = swap;
            }
            var shore = DistanceTo(land, width, height, dx, dz, radius * 16);
            var seaward = DistanceTo(occupied, width, height, dx, dz, radius * 16);
            var pixels = new Color[occupied.Length];
            for (int i = 0; i < pixels.Length; i++)
            {
                // Legacy water planes have no bed data: use an explicit presentation-only depth profile.
                float depth = depths[i] < 0 ? .5f + Mathf.Min(shore[i] / radius * .25f, 3) : depths[i];
                if (exterior[i]) depth += seaward[i] / radius * .35f;
                pixels[i] = new Color(exterior[i] ? -seaward[i] / radius : 1, levels[i], shore[i] / radius, depth);
            }
            // Float height avoids quantized ledges where real water meets its extension.
            field = new Texture2D(width, height, TextureFormat.RGBAFloat, false, true)
            { name = "Map ocean coverage / elevation / shore / optical depth", wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
            field.SetPixels(pixels); field.Apply(false, true);
            var shader = Resources.Load<Shader>("MapOcean");
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("Map ocean shader is missing or unsupported.");
            material = new Material(shader) { name = "Map exterior ocean" };
            BindWater(material);
            material.SetVector("_OceanParameters", new Vector4(lowestWater, radius, highestWater - lowestWater < .0001f ? 1 : 0, highestWater));
            mesh = new Mesh { name = "Map ocean viewport" };
            mesh.vertices = new[] { new Vector3(-1, -1, 0), new Vector3(-1, 1, 0), new Vector3(1, 1, 0), new Vector3(1, -1, 0) };
            mesh.triangles = new[] { 0, 1, 2, 0, 2, 3 }; mesh.RecalculateBounds();
        }
        private static void ExtendLevel(int from, int to, float[] levels, float[] depths, bool[] assigned, Queue<int> queue)
        {
            if (assigned[to]) return;
            assigned[to] = true; levels[to] = levels[from]; depths[to] = depths[from]; queue.Enqueue(to);
        }
        private static float[] DistanceTo(bool[] source, int width, int height, float dx, float dz, float reach)
        {
            float diagonal = Mathf.Sqrt(dx * dx + dz * dz);
            var distance = new float[source.Length];
            for (int i = 0; i < distance.Length; i++) distance[i] = source[i] ? 0 : reach;
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
            {
                int i = y * width + x;
                if (x > 0) distance[i] = Mathf.Min(distance[i], distance[i - 1] + dx);
                if (y > 0)
                {
                    distance[i] = Mathf.Min(distance[i], distance[i - width] + dz);
                    if (x > 0) distance[i] = Mathf.Min(distance[i], distance[i - width - 1] + diagonal);
                    if (x + 1 < width) distance[i] = Mathf.Min(distance[i], distance[i - width + 1] + diagonal);
                }
            }
            for (int y = height - 1; y >= 0; y--) for (int x = width - 1; x >= 0; x--)
            {
                int i = y * width + x;
                if (x + 1 < width) distance[i] = Mathf.Min(distance[i], distance[i + 1] + dx);
                if (y + 1 < height)
                {
                    distance[i] = Mathf.Min(distance[i], distance[i + width] + dz);
                    if (x > 0) distance[i] = Mathf.Min(distance[i], distance[i + width - 1] + diagonal);
                    if (x + 1 < width) distance[i] = Mathf.Min(distance[i], distance[i + width + 1] + diagonal);
                }
            }
            return distance;
        }
        internal void BindWater(Material target)
        {
            target.SetTexture("_WaterBoundaryField", field); target.SetVector("_WaterBoundaryBounds", bounds);
            target.SetFloat("_WaterBoundaryEnabled", 1);
        }
        private static Vector2Int CellAt(float x, float z, float radius)
        {
            float q = x / (1.7320508075688772f * radius) - z / (3 * radius), r = z / (1.5f * radius), s = -q - r;
            int iq = Mathf.RoundToInt(q), ir = Mathf.RoundToInt(r), isum = Mathf.RoundToInt(s);
            float dq = Mathf.Abs(iq - q), dr = Mathf.Abs(ir - r), ds = Mathf.Abs(isum - s);
            if (dq > dr && dq > ds) iq = -ir - isum; else if (dr > ds) ir = -iq - isum;
            return new Vector2Int(iq, ir);
        }
        internal void Draw(Camera camera)
        {
            if (depthCamera != camera) { camera.GetUniversalAdditionalCameraData().requiresDepthTexture = true; depthCamera = camera; }
            float depth = camera.nearClipPlane + 1;
            float halfHeight = camera.orthographic ? camera.orthographicSize : Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * .5f) * depth;
            var matrix = Matrix4x4.TRS(camera.transform.position + camera.transform.forward * depth, camera.transform.rotation,
                new Vector3(halfHeight * camera.aspect, halfHeight, 1));
            Graphics.DrawMesh(mesh, matrix, material, 0, camera, 0, null, ShadowCastingMode.Off, false, null, LightProbeUsage.Off);
        }
        public void Dispose() { Release(mesh); Release(material); Release(field); }
        private static void Release(Object value) { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); }
    }
}
