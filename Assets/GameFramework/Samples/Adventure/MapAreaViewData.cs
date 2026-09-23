using System;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    /// <summary>MapArea 的纯显示快照，静态地形进入时读取一次，探索状态单独更新。</summary>
    public sealed class MapAreaViewData
    {
        public sealed class Cell
        {
            public int Q, R, RoomId;
            public Vector3 Position;
            public float WallHeight;
            public Color Color;
            public bool Blocked;
            public string Kind;
        }
        public sealed class State
        {
            public string Name, Theme;
            public uint Seed;
            public int CellIndex, EntryIndex, GoalIndex, Revision, RoomCount, WalkableCount, SourceRegionId, PropCount;
            public int[] Known, Visible, Route;
            public Member[] Members;
            public NpcState[] Npcs;
            public int InteractionKind, InteractionId;
        }
        public sealed class Member { public int ActorId, CellIndex; }
        public sealed class NpcState { public int Id, CellIndex; }
        public sealed class Npc
        {
            public int Id;
            public string Name, Description;
            public float StepSeconds;
            public PawnAppearanceData Appearance;
        }
        public sealed class Facility
        {
            public int Id, EntryIndex, InteractionRadius;
            public string Name, Description;
        }
        public sealed class Room
        {
            public int Id, Tier, PresetId, CenterIndex;
            public string Name;
        }
        public sealed class Prop
        {
            public int AssetId;
            public Vector3 Position;
            public float Rotation, Scale;
            public int[] Cells;
        }
        public sealed class Asset { public int Id; public string Path; }
        public Cell[] Cells;
        public Room[] Rooms;
        public Prop[] Props;
        public Asset[] PropAssets;
        public Facility[] Facilities;
        public Npc[] Npcs;
        public int AreaType;
        public bool IsTown => AreaType == 2;
        public float MoveStepSeconds;
        public float Radius;
        public int AssetId, CorridorWidth;
        public string AssetPath, TintMaterial;
        private static int[] Indices(LuaTable root, string key)
        {
            using (var values = root.Get<LuaTable>(key))
            {
                var result = new int[values.Length];
                for (var i = 0; i < result.Length; i++) result[i] = values.Get<int, int>(i + 1) - 1;
                return result;
            }
        }
        public static State ReadState(LuaTable root)
        {
            using (var area = root.Get<LuaTable>("area"))
            {
                if (area == null) return null; // 只有 area 阶段提供局部地图状态。
                Member[] members;
                using (var rows = area.Get<LuaTable>("members"))
                {
                    members = new Member[rows.Length];
                    for (var i = 0; i < members.Length; i++) using (var row = rows.Get<int, LuaTable>(i + 1))
                        members[i] = new Member { ActorId = row.Get<int>("actorId"), CellIndex = row.Get<int>("cellIndex") - 1 };
                }
                NpcState[] npcs;
                using (var rows = area.Get<LuaTable>("npcs"))
                {
                    npcs = new NpcState[rows.Length];
                    for (var i = 0; i < npcs.Length; i++) using (var row = rows.Get<int, LuaTable>(i + 1))
                        npcs[i] = new NpcState { Id = row.Get<int>("id"), CellIndex = row.Get<int>("cellIndex") - 1 };
                }
                return new State { Members = members, Npcs = npcs, InteractionKind = area.Get<int>("interactionKind"), InteractionId = area.Get<int>("interactionId"),
                    Name = area.Get<string>("name"), Theme = area.Get<string>("theme"), Seed = area.Get<uint>("seed"),
                    CellIndex = area.Get<int>("cellIndex") - 1, EntryIndex = area.Get<int>("entryIndex") - 1,
                    GoalIndex = area.Get<int>("goalIndex") - 1, Revision = area.Get<int>("revision"), RoomCount = area.Get<int>("roomCount"),
                    WalkableCount = area.Get<int>("walkableCount"), SourceRegionId = area.Get<int>("sourceRegionId"), PropCount = area.Get<int>("propCount"),
                    Known = Indices(area, "known"), Visible = Indices(area, "visible"), Route = Indices(area, "route") };
            }
        }
        public static MapAreaViewData Read(LuaTable root)
        {
            using (var cells = root.Get<LuaTable>("cells"))
            {
                var result = new MapAreaViewData { Radius = root.Get<float>("hexRadius"), AssetId = root.Get<int>("assetId"),
                    AssetPath = root.Get<string>("assetPath"), TintMaterial = root.Get<string>("tintMaterial"), Cells = new Cell[cells.Length],
                    CorridorWidth = root.Get<int>("corridorWidth"), AreaType = root.Get<int>("areaType"), MoveStepSeconds = root.Get<float>("moveStepSeconds") };
                using (var rows = root.Get<LuaTable>("facilities"))
                {
                    result.Facilities = new Facility[rows.Length];
                    for (var i = 0; i < rows.Length; i++) using (var row = rows.Get<int, LuaTable>(i + 1))
                        result.Facilities[i] = new Facility { Id = row.Get<int>("id"), Name = row.Get<string>("name"), Description = row.Get<string>("description"),
                            EntryIndex = row.Get<int>("entryIndex") - 1, InteractionRadius = row.Get<int>("interactionRadius") };
                }
                using (var rows = root.Get<LuaTable>("npcs"))
                {
                    result.Npcs = new Npc[rows.Length];
                    for (var i = 0; i < rows.Length; i++) using (var row = rows.Get<int, LuaTable>(i + 1))
                    using (var appearance = row.Get<LuaTable>("appearance"))
                        result.Npcs[i] = new Npc { Id = row.Get<int>("id"), Name = row.Get<string>("name"), Description = row.Get<string>("description"),
                            StepSeconds = row.Get<float>("stepSeconds"), Appearance = PawnAppearanceData.Read(appearance) };
                }
                for (var i = 0; i < result.Cells.Length; i++)
                    using (var row = cells.Get<int, LuaTable>(i + 1))
                    using (var color = row.Get<LuaTable>("color"))
                        result.Cells[i] = new Cell { Q = row.Get<int>("q"), R = row.Get<int>("r"), RoomId = row.Get<int>("roomId"),
                            Position = new Vector3(row.Get<float>("x"), row.Get<float>("height"), row.Get<float>("z")),
                            WallHeight = row.Get<float>("wallHeight"), Blocked = row.Get<bool>("blocked"), Kind = row.Get<string>("kind"),
                            Color = new Color(color.Get<int, float>(1), color.Get<int, float>(2), color.Get<int, float>(3), 1) };
                using (var rooms = root.Get<LuaTable>("rooms"))
                {
                    result.Rooms = new Room[rooms.Length];
                    for (var i = 0; i < result.Rooms.Length; i++) using (var row = rooms.Get<int, LuaTable>(i + 1))
                        result.Rooms[i] = new Room { Id = row.Get<int>("id"), Name = row.Get<string>("name"), Tier = row.Get<int>("tier"),
                            PresetId = row.Get<int>("presetId"), CenterIndex = row.Get<int>("centerIndex") - 1 };
                }
                using (var props = root.Get<LuaTable>("props"))
                {
                    result.Props = new Prop[props.Length];
                    for (var i = 0; i < result.Props.Length; i++) using (var row = props.Get<int, LuaTable>(i + 1))
                        result.Props[i] = new Prop { AssetId = row.Get<int>("assetId"), Cells = Indices(row, "cells"),
                            Position = new Vector3(row.Get<float>("x"), row.Get<float>("y"), row.Get<float>("z")),
                            Rotation = row.Get<float>("rotation"), Scale = row.Get<float>("scale") };
                }
                using (var assets = root.Get<LuaTable>("propAssets"))
                {
                    result.PropAssets = new Asset[assets.Length];
                    for (var i = 0; i < result.PropAssets.Length; i++) using (var row = assets.Get<int, LuaTable>(i + 1))
                        result.PropAssets[i] = new Asset { Id = row.Get<int>("id"), Path = row.Get<string>("path") };
                }
                return result;
            }
        }
    }
}
