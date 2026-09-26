using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ProjectY.Samples
{
    /// <summary>按 Lua 给定的顶点高度绘制台地、台阶、坡道和悬空桥面；不推导导航规则。</summary>
    public sealed class TownSurfaceRenderer : IDisposable
    {
        private sealed class CellMesh { public int Start, Count; public Bounds Bounds; }
        private readonly List<Vector3> vertices = new List<Vector3>();
        private readonly List<int> triangles = new List<int>();
        private readonly List<Color> colors = new List<Color>();
        private readonly List<Vector4> patterns = new List<Vector4>();
        private readonly List<Vector4> finishes = new List<Vector4>();
        private MapAreaViewData.Surface activeSurface;
        private readonly List<CellMesh> cells = new List<CellMesh>();
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
        public TownSurfaceRenderer(Shader shader, MapAreaViewData map)
        {
            material = new Material(shader) { name = "Town_Surface" }; material.SetFloat("_UseVertexColor", 1); material.SetFloat("_UseSurfacePattern", 1);
            foreach (var cell in map.Cells)
            {
                var start = triangles.Count; var points = new Vector3[6];
                for (var i = 0; i < 6; i++) { points[i] = cell.Position + Corners[i] * map.Radius; points[i].y = cell.Corners[i]; }
                var color = cell.Color;
                if (QualitySettings.activeColorSpace == ColorSpace.Linear) color = color.linear;
                for (var i = 0; i < 6; i++)
                {
                    var j = (i + 1) % 6;
                    activeSurface = map.Surfaces[cell.SurfaceId];
                    Top(new[] { cell.Position, points[j], points[i] }, cell.StairRise, color);
                    var bottom = cell.Layer == 0 ? -.4f : cell.Position.y - cell.DeckThickness;
                    activeSurface = map.Surfaces[cell.SideSurfaceId];
                    var sideColor = QualitySettings.activeColorSpace == ColorSpace.Linear ? activeSurface.Color.linear : activeSurface.Color;
                    Edge(points[i], points[j], bottom, cell.StairRise, sideColor);
                    if (cell.Layer > 0)
                        Triangle(new Vector3(cell.Position.x, bottom, cell.Position.z), new Vector3(points[i].x, bottom, points[i].z), new Vector3(points[j].x, bottom, points[j].z), color * .65f);
                }
                var bounds = new Bounds(cell.Position, Vector3.zero);
                for (var i = start; i < triangles.Count; i++) bounds.Encapsulate(vertices[triangles[i]]);
                cells.Add(new CellMesh { Start = start, Count = triangles.Count - start, Bounds = bounds });
            }
            mesh = new Mesh { name = "Town_TerracesAndDecks", indexFormat = IndexFormat.UInt32 };
            mesh.SetVertices(vertices); mesh.SetTriangles(triangles, 0); mesh.SetColors(colors); mesh.SetUVs(1, patterns); mesh.SetUVs(2, finishes); mesh.RecalculateNormals(); mesh.RecalculateBounds();
        }
        private void Triangle(Vector3 a, Vector3 b, Vector3 c, Color color)
        {
            if (Vector3.Cross(b - a, c - a).sqrMagnitude < .00000001f) return;
            var index = vertices.Count; vertices.Add(a); vertices.Add(b); vertices.Add(c);
            colors.Add(color); colors.Add(color); colors.Add(color); triangles.Add(index); triangles.Add(index + 1); triangles.Add(index + 2);
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
            for (var i = 0; i < cells.Count; i++)
            {
                var cell = cells[i]; if (!cell.Bounds.IntersectRay(ray, out var near) || near > limit) continue;
                for (var offset = cell.Start; offset < cell.Start + cell.Count; offset += 3)
                    if (Hit(ray, vertices[triangles[offset]], vertices[triangles[offset + 1]], vertices[triangles[offset + 2]], out var distance) && distance < limit)
                    { limit = distance; index = i; }
            }
            return limit;
        }
        public void Draw(Camera camera) => Graphics.DrawMesh(mesh, Matrix4x4.identity, material, 0, camera, 0, null, ShadowCastingMode.On, true, null, LightProbeUsage.Off);
        private static void Destroy(UnityEngine.Object value) { if (Application.isPlaying) UnityEngine.Object.Destroy(value); else UnityEngine.Object.DestroyImmediate(value); }
        public void Dispose() { Destroy(mesh); Destroy(material); }
    }
}
