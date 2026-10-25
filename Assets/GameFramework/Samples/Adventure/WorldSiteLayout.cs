using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>World footprint and spatial picking cache, rebuilt only when the world changes.</summary>
    internal sealed class WorldSiteLayout
    {
        private sealed class Chunk { public Bounds Bounds; public readonly List<int> Cells = new List<int>(); }
        private readonly MapPreviewData map;
        private readonly Dictionary<Vector2Int, int> indices = new Dictionary<Vector2Int, int>();
        private readonly Dictionary<int, int[]> townCells = new Dictionary<int, int[]>();
        private readonly Dictionary<int, int[]> regionCells = new Dictionary<int, int[]>();
        private readonly List<Chunk> chunks = new List<Chunk>();
        private readonly float bottom;
        internal WorldSiteLayout(MapPreviewData source)
        {
            map = source; bottom = float.PositiveInfinity;
            foreach (var cell in map.Cells)
            {
                bottom=Mathf.Min(bottom,cell.Position.y);
                if(cell.SurfaceCorners!=null)foreach(var height in cell.SurfaceCorners)bottom=Mathf.Min(bottom,height);
            }
            bottom -= map.Radius * 1.5f;
            var groups = new Dictionary<Vector2Int, Chunk>(); var towns = new Dictionary<int, List<int>>();
            var regions = new Dictionary<int, List<int>>();
            for (var i = 0; i < map.Cells.Length; i++)
            {
                var cell = map.Cells[i]; indices.Add(new Vector2Int(cell.Q, cell.R), i);
                if(cell.RegionId>0)
                {
                    if(!regions.TryGetValue(cell.RegionId,out var cells)){cells=new List<int>();regions.Add(cell.RegionId,cells);}
                    cells.Add(i);
                }
                if (cell.TownId > 0)
                {
                    if (!towns.TryGetValue(cell.TownId, out var cells)) { cells = new List<int>(); towns.Add(cell.TownId, cells); }
                    cells.Add(i);
                }
                var key = new Vector2Int(Mathf.FloorToInt(cell.Q / 16f), Mathf.FloorToInt(cell.R / 16f));
                if (!groups.TryGetValue(key, out var chunk))
                { chunk = new Chunk { Bounds = new Bounds(cell.Position, Vector3.zero) }; groups.Add(key, chunk); chunks.Add(chunk); }
                chunk.Cells.Add(i);
                var top = cell.HasWater ? cell.WaterLevel : cell.Position.y;
                if(cell.SurfaceCorners!=null)foreach(var corner in cell.SurfaceCorners)top=Mathf.Max(top,corner);
                chunk.Bounds.Encapsulate(new Bounds(new Vector3(cell.Position.x, (top + bottom) * .5f, cell.Position.z),
                    new Vector3(map.Radius * 2, top - bottom, map.Radius * 2)));
            }
            foreach (var entry in towns) townCells.Add(entry.Key, entry.Value.ToArray());
            foreach (var entry in regions) regionCells.Add(entry.Key, entry.Value.ToArray());
        }
        internal int[] Footprint(AdventureViewData.Site site)
        {
            if(site.WorldRegionId>0)return regionCells[site.WorldRegionId];
            if (site.WorldTownId > 0) return townCells[site.WorldTownId];
            return new[] { indices[new Vector2Int(site.Q, site.R)] };
        }
        internal int Pick(Ray ray, out float distance)
        {
            var result = -1; distance = float.PositiveInfinity;
            foreach (var chunk in chunks)
            {
                if (!chunk.Bounds.IntersectRay(ray, out var start) || start > distance) continue;
                foreach (var index in chunk.Cells)
                {
                    var cell = map.Cells[index]; var origin = ray.origin - cell.Position; var direction = ray.direction;
                    if(cell.SurfaceCorners!=null)
                    {
                        if(MapMountainSurface.TryRaycastCell(cell,map.Radius,ray,out var hit) && hit<distance)
                        {result=index;distance=hit;}
                        continue;
                    }
                    var near = 0f; var far = distance; var half = map.Radius * .8660254f;
                    var top = cell.HasWater ? cell.WaterLevel : cell.Position.y;
                    if (Clip(origin.x, direction.x, -half, half, ref near, ref far) &&
                        Clip(origin.x * .5f + origin.z * .8660254f, direction.x * .5f + direction.z * .8660254f, -half, half, ref near, ref far) &&
                        Clip(origin.x * .5f - origin.z * .8660254f, direction.x * .5f - direction.z * .8660254f, -half, half, ref near, ref far) &&
                        Clip(ray.origin.y, direction.y, bottom, top, ref near, ref far) && near < distance)
                    { result = index; distance = near; }
                }
            }
            return result;
        }
        private static bool Clip(float origin, float direction, float min, float max, ref float near, ref float far)
        {
            if (Mathf.Abs(direction) < .000001f) return origin >= min && origin <= max;
            var a = (min - origin) / direction; var b = (max - origin) / direction;
            near = Mathf.Max(near, Mathf.Min(a, b)); far = Mathf.Min(far, Mathf.Max(a, b)); return near <= far;
        }
    }
}
