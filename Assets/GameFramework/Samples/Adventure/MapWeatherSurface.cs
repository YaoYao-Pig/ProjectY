using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Hex-column rain landing and shelter lookup; rebuilt only when the displayed layout changes.</summary>
    public sealed class MapWeatherSurface
    {
        private const float Sqrt3 = 1.7320508075688772f;
        private static readonly Vector2[] Corners = CreateCorners();
        private struct Column
        {
            public int Index;
            public float Top;
            public bool Sheltered;
        }

        private readonly Dictionary<Vector2Int, Column> worldColumns = new Dictionary<Vector2Int, Column>();
        private readonly Dictionary<Vector2Int, Column> areaColumns = new Dictionary<Vector2Int, Column>();
        private MapPreviewData world;
        private MapAreaViewData area;
        private Bounds worldBounds, areaBounds;

        public float Radius => area != null ? area.Radius : world != null ? world.Radius : 0;
        public Bounds Bounds => area != null ? areaBounds : worldBounds;

        public void SetWorld(MapPreviewData map)
        {
            if (map == null) throw new ArgumentNullException(nameof(map));
            ValidateRadius(map.Radius);
            world = map; area = null;
            worldColumns.Clear(); areaColumns.Clear();
            worldBounds = areaBounds = default;
            var hasBounds = false;
            for (var i = 0; i < map.Cells.Length; i++)
            {
                var cell = map.Cells[i];
                HeightRange(cell.Position.y, cell.SurfaceCorners, out var low, out var high);
                if (cell.HasWater) high = Mathf.Max(high, cell.WaterLevel);
                worldColumns.Add(new Vector2Int(cell.Q, cell.R), new Column { Index = i, Top = high });
                Encapsulate(ref worldBounds, ref hasBounds, cell.Position, map.Radius, low, high);
            }
        }

        public void SetArea(MapAreaViewData value)
        {
            area = value; areaColumns.Clear(); areaBounds = default;
            if (value == null) return;
            ValidateRadius(value.Radius);
            var hasBounds = false;
            for (var i = 0; i < value.Cells.Length; i++)
            {
                var cell = value.Cells[i]; var key = new Vector2Int(cell.Q, cell.R);
                if (!areaColumns.TryGetValue(key, out var column)) column = new Column { Index = -1 };
                // Shelter belongs to the physical column, even while the roof or upper floor is cut away.
                column.Sheltered |= cell.InteriorId > 0 || cell.CoverInteriorId > 0;
                var water = cell.WaterDepth > 0 || cell.Kind == "water";
                if ((cell.RenderGround && cell.Kind != "void") || water)
                {
                    HeightRange(cell.Position.y, cell.Corners, out var low, out var high);
                    if (cell.Kind == "wall") low = high = cell.GroundHeight + cell.WallHeight;
                    if (water) high = Mathf.Max(high, WaterHeight(cell));
                    if (cell.ConstructionHeight > 0) high = Mathf.Max(high, cell.BasePosition.y + cell.ConstructionHeight);
                    if (column.Index < 0 || high > column.Top)
                    { column.Index = i; column.Top = high; }
                    Encapsulate(ref areaBounds, ref hasBounds, cell.Position, value.Radius, low, high);
                }
                areaColumns[key] = column;
            }
            foreach (var prop in value.Props)
            {
                // TownBuildings explicitly emits building covers with these two semantic flags.
                // CutawayGroup alone also labels exposed ship decks and is not proof of a roof.
                if (!prop.Cutaway || prop.InteriorId <= 0) continue;
                foreach (var index in prop.Cells)
                {
                    var cell = value.Cells[index]; var key = new Vector2Int(cell.Q, cell.R);
                    var column = areaColumns[key]; column.Sheltered = true; areaColumns[key] = column;
                }
            }
        }

        public bool TryGet(float x, float z, out float height, out bool sheltered)
        {
            height = 0; sheltered = false;
            if (world == null && area == null) return false;
            var bounds = Bounds;
            if (float.IsNaN(x) || float.IsNaN(z) || x < bounds.min.x || x > bounds.max.x ||
                z < bounds.min.z || z > bounds.max.z) return false;
            var radius = Radius;
            var q = (Sqrt3 / 3 * x - z / 3) / radius;
            var r = (2f / 3 * z) / radius;
            var s = -q - r;
            // Match HexGrid.FromWorld, including its tie ordering and negative-coordinate rounding.
            var iq = Mathf.FloorToInt(q + .5f); var ir = Mathf.FloorToInt(r + .5f); var iss = Mathf.FloorToInt(s + .5f);
            var dq = Mathf.Abs(iq - q); var dr = Mathf.Abs(ir - r); var ds = Mathf.Abs(iss - s);
            if (dq > dr && dq > ds) iq = -ir - iss;
            else if (dr > ds) ir = -iq - iss;
            var columns = area != null ? areaColumns : worldColumns;
            if (!columns.TryGetValue(new Vector2Int(iq, ir), out var column) || column.Index < 0) return false;
            if (area == null)
            {
                var cell = world.Cells[column.Index];
                if (!FanHeight(cell.Position, cell.SurfaceCorners, radius, x, z, out height)) return false;
                if (cell.HasWater) height = Mathf.Max(height, cell.WaterLevel);
            }
            else
            {
                var cell = area.Cells[column.Index];
                if (cell.Kind == "wall") height = cell.GroundHeight + cell.WallHeight;
                else
                {
                    if (!FanHeight(cell.Position, cell.Corners, radius, x, z, out height)) return false;
                    if (cell.StairRise > 0) height = Mathf.Floor(height / cell.StairRise + .0001f) * cell.StairRise;
                }
                if (cell.WaterDepth > 0 || cell.Kind == "water") height = Mathf.Max(height, WaterHeight(cell));
                if (cell.ConstructionHeight > 0) height = Mathf.Max(height, cell.BasePosition.y + cell.ConstructionHeight);
            }
            sheltered = column.Sheltered;
            return true;
        }

        private static float WaterHeight(MapAreaViewData.Cell cell) => cell.Kind == "water" ? cell.Position.y : cell.WaterLevel;

        private static bool FanHeight(Vector3 center, float[] heights, float radius, float x, float z, out float height)
        {
            height = center.y;
            if (heights == null) return true; // World flat cells deliberately omit corner arrays.
            x = (x - center.x) / radius; z = (z - center.z) / radius;
            for (var i = 0; i < 6; i++)
            {
                var j = (i + 1) % 6; var a = Corners[i]; var b = Corners[j];
                var determinant = a.x * b.y - a.y * b.x;
                var u = (x * b.y - z * b.x) / determinant;
                var v = (a.x * z - a.y * x) / determinant;
                if (u < -.001f || v < -.001f || u + v > 1.001f) continue;
                height = center.y * (1 - u - v) + heights[i] * u + heights[j] * v;
                return true;
            }
            return false;
        }

        private static void HeightRange(float center, float[] heights, out float low, out float high)
        {
            low = high = center;
            if (heights == null) return;
            if (heights.Length != 6) throw new ArgumentException("Weather surface requires six corner heights.");
            for (var i = 0; i < 6; i++) { low = Mathf.Min(low, heights[i]); high = Mathf.Max(high, heights[i]); }
        }

        private static void Encapsulate(ref Bounds bounds, ref bool initialized, Vector3 center, float radius, float low, float high)
        {
            var halfWidth = radius * Sqrt3 * .5f;
            var minimum = new Vector3(center.x - halfWidth, low, center.z - radius);
            var maximum = new Vector3(center.x + halfWidth, high, center.z + radius);
            if (!initialized) { bounds.SetMinMax(minimum, maximum); initialized = true; }
            else { bounds.Encapsulate(minimum); bounds.Encapsulate(maximum); }
        }

        private static void ValidateRadius(float radius)
        {
            if (!(radius > 0) || float.IsInfinity(radius)) throw new ArgumentOutOfRangeException(nameof(radius));
        }

        private static Vector2[] CreateCorners()
        {
            var result = new Vector2[6];
            for (var i = 0; i < 6; i++)
            {
                var angle = (30 + i * 60) * Mathf.Deg2Rad;
                result[i] = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
            }
            return result;
        }
    }
}
