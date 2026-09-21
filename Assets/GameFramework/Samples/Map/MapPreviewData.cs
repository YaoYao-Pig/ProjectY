using System;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    // 测试场景持有普通 C# 渲染数据；转换结束立即释放全部 LuaTable 句柄。
    public sealed class MapPreviewData
    {
        public sealed class Asset { public int Id; public string Path, TintMaterial; public float ReferenceHeight; }
        public sealed class Cell
        {
            public Vector3 Position; public Color Color; public bool HasWater; public float WaterLevel;
            public int TerrainAssetId, WaterAssetId; public int[] Neighbors;
        }
        public sealed class Decoration { public int Cell, AssetId; public float Scale, Yaw; }
        public sealed class Waterfall { public int From, To; public float Drop; }
        public sealed class Town { public string Name; public int Center; public Color GroundColor; }
        public sealed class Building
        {
            public int ConfigId, TownId, Center, Entrance, FootprintRadius, AssetId, PlatformAssetId;
            public int[] Cells;
            public float BaseHeight, Height;
        }
        public sealed class Road { public string Kind; public int[] Cells; }
        public Cell[] Cells;
        public Town[] Towns;
        public Building[] Buildings;
        public Road[] Roads;
        public Asset[] Assets;
        public Decoration[] Decorations;
        public Waterfall[] Waterfalls;
        public float Radius;
        public int RegionCount, GenerationVersion, RiverCount;
        public uint Seed;

        private static T[] ReadArray<T>(LuaTable parent, string key, Func<LuaTable, T> read)
        {
            using (var array = parent.Get<LuaTable>(key))
            {
                var result = new T[array.Length];
                for (var i = 0; i < result.Length; i++)
                    using (var row = array.Get<int, LuaTable>(i + 1)) result[i] = read(row);
                return result;
            }
        }

        private static int[] ReadIndices(LuaTable row, string key = "cells")
        {
            using (var array = row.Get<LuaTable>(key))
            {
                var result = new int[array.Length];
                for (var i = 0; i < result.Length; i++) result[i] = array.Get<int, int>(i + 1) - 1;
                return result;
            }
        }

        private static Color ParseColor(string html)
        {
            if (!ColorUtility.TryParseHtmlString(html, out var color)) throw new InvalidOperationException("Invalid map color: " + html);
            return color;
        }

        private static Cell ReadCell(LuaTable row)
        {
            // 边界混色由真实配置和 Lua 地貌权重统一计算，渲染层不维护另一套调色板。
            Color color;
            using (var rgb = row.Get<LuaTable>("groundColor"))
                color = new Color(rgb.Get<int, float>(1), rgb.Get<int, float>(2), rgb.Get<int, float>(3), 1);
            return new Cell { Position = new Vector3(row.Get<float>("x"), row.Get<float>("y"), row.Get<float>("z")),
                HasWater = row.Get<bool>("hasWater"), WaterLevel = row.Get<float>("waterLevel"), Color = color,
                TerrainAssetId = row.Get<int>("terrainAssetId"), WaterAssetId = row.Get<int>("waterAssetId"),
                Neighbors = ReadIndices(row, "neighbors") };
        }

        public static MapPreviewData Generate(GameBootstrap bootstrap, uint seed, string recipe)
        {
            var values = bootstrap.CallModule("Game.Map.GenerateRenderMap", (double)seed, recipe);
            using (var root = (LuaTable)values[0])
                return new MapPreviewData {
                    Seed = root.Get<uint>("seed"), Radius = root.Get<float>("hexRadius"),
                    GenerationVersion = root.Get<int>("generationVersion"), RegionCount = root.Get<int>("regionCount"),
                    RiverCount = ReadArray(root, "rivers", row => row.Get<string>("kind")).Length,
                    Assets = ReadArray(root, "assets", row => new Asset { Id = row.Get<int>("id"),
                        Path = row.Get<string>("prefabPath"), ReferenceHeight = row.Get<float>("referenceHeight"),
                        TintMaterial = row.Get<string>("tintMaterial") }),
                    Decorations = ReadArray(root, "decorations", row => new Decoration { Cell = row.Get<int>("cell") - 1,
                        AssetId = row.Get<int>("assetId"), Scale = row.Get<float>("scale"), Yaw = row.Get<float>("yaw") }),
                    Waterfalls = ReadArray(root, "waterfalls", row => new Waterfall { From = row.Get<int>("from") - 1,
                        To = row.Get<int>("to") - 1, Drop = row.Get<float>("drop") }),
                    Cells = ReadArray(root, "cells", ReadCell),
                    Towns = ReadArray(root, "towns", row => new Town { Name = row.Get<string>("name"),
                        Center = row.Get<int>("center") - 1, GroundColor = ParseColor(row.Get<string>("groundColor")) }),
                    Buildings = ReadArray(root, "buildings", row => new Building { ConfigId = row.Get<int>("configId"),
                        TownId = row.Get<int>("townId") - 1, Center = row.Get<int>("center") - 1,
                        Entrance = row.Get<int>("entrance") - 1, Cells = ReadIndices(row),
                        BaseHeight = row.Get<float>("baseHeight"), Height = row.Get<float>("height") + row.Get<float>("roofHeight"),
                        FootprintRadius = row.Get<int>("footprintRadius"), AssetId = row.Get<int>("assetId"),
                        PlatformAssetId = row.Get<int>("platformAssetId") }),
                    Roads = ReadArray(root, "roads", row => new Road { Kind = row.Get<string>("kind"), Cells = ReadIndices(row) })
                };
        }
    }
}
