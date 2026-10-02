using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    /// <summary>MapArea 的纯显示快照，静态地形进入时读取一次，探索状态单独更新。</summary>
    public sealed class MapAreaViewData
    {
        public sealed class Cell
        {
            public int Q, R, RoomId, InteriorId, Layer, WalkMask, SurfaceId, SideSurfaceId;
            public int CoverInteriorId, CutawayGroup, CutawayLayer;
            public int[] Neighbors;
            public float[] Corners,BaseCorners;
            public float DeckThickness, StairRise;
            public Vector3 Position;
            public Vector3 BasePosition;
            public float GroundHeight,ConstructionHeight;
            public int ConstructionMoveExtra;
            public string ConstructionKind;
            public bool BaseBlocked;
            public float WallHeight;
            public Color Color;
            public bool Blocked;
            public bool RenderGround = true;
            public string Kind;
            public bool UsesSurfaceMesh
            {
                get
                {
                    if (Kind == "wall") return false;
                    if (StairRise > 0 || DeckThickness > 0) return true;
                    for (var i = 0; i < 6; i++) if (Mathf.Abs(Corners[i] - Position.y) > .001f) return true;
                    return false;
                }
            }
        }
        public sealed class State
        {
            public string Name, Theme;
            public uint Seed;
            public int CellIndex, EntryIndex, GoalIndex, Revision, RoomCount, WalkableCount, SourceRegionId, PropCount;
            public int[] Known, Visible, Route;
            public Member[] Members;
            public NpcState[] Npcs;
            public Loot[] Loots;
            public Obstacle[] Obstacles=Array.Empty<Obstacle>();
            public Construction[] Constructions=Array.Empty<Construction>();
            public int ConstructionRevision;
            public int ContainerRevision;
            public AdventureViewData.Actor[] Enemies, Defeated;
            public int EncounterCount, ClearedEncounters;
            public int InteractionKind, InteractionId;
        }
        public sealed class Member { public int ActorId, CellIndex; }
        public sealed class Loot
        {
            public int Id,CellIndex,Durability,MaxDurability;
            public int[] Cells;
            public string Name,Interaction,DisplayContents;
            public bool Looted,Destroyed,CanSearch,Near,BlocksMovement;
            public float Rotation,Scale,OffsetX,OffsetZ,Height;
            public float DisplayHeight,DisplayItemScale;
            public Vector3 Scale3;
            public DisplayItem[] Items;
            public EquipmentVisualData.Asset Asset;
        }
        public sealed class DisplayItem {public int Index;public EquipmentVisualData.Asset Asset;}
        private static DisplayItem[] ReadDisplayItems(LuaTable row)
        {
            using(var items=row.Get<LuaTable>("items"))
            {
                var result=new DisplayItem[items.Length];
                for(int i=0;i<result.Length;i++)using(var item=items.Get<int,LuaTable>(i+1))using(var asset=item.Get<LuaTable>("asset"))
                    result[i]=new DisplayItem {Index=item.Get<int>("index"),Asset=EquipmentVisualData.Asset.Read(asset)};
                return result;
            }
        }
        public sealed class Obstacle { public int Id;public int[] Cells;public string Name;public bool BlocksMovement;public EquipmentVisualData.Asset Asset; }
        public sealed class Construction { public int Id,CellIndex,SkillId,HP,MaxHP,MoveExtra;public string Kind,Name;public float Height;public bool BlocksMovement,BlocksSight; }
        public sealed class NpcState { public int Id, CellIndex; public bool Present; }
        public sealed class Npc
        {
            public int Id, NarrativeId;
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
            public int AssetId, InteriorId;
            public int Layer = -1, CutawayGroup, CutawayLayer;
            public bool Cutaway;
            public bool CameraObstacle = true;
            public Vector3 Position;
            public float Rotation, Scale;
            public Vector3 Scale3;
            public int[] Cells;
        }
        public sealed class Asset { public int Id; public string Path; }
        public sealed class Surface
        {
            public Vector4 Pattern;
            public float Smoothness;
            public Color Color, DetailColor;
        }
        // Visual cut hexes have an owning floor for visibility, but no navigation identity.
        public sealed class FloorBoundaryPatch
        {
            public int OwnerIndex;
            public Vector3[] Points;
            public float Thickness;
        }
        public FloorBoundaryPatch[] FloorBoundaryPatches = Array.Empty<FloorBoundaryPatch>();
        public readonly System.Collections.Generic.Dictionary<int, Surface> Surfaces = new System.Collections.Generic.Dictionary<int, Surface>();
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
        private readonly List<int> changedConstructionCells=new List<int>();
        public void ApplyConstruction(State state)
        {
            foreach(int index in changedConstructionCells){var cell=Cells[index];cell.Position=cell.BasePosition;cell.GroundHeight=cell.BasePosition.y;cell.Blocked=cell.BaseBlocked;cell.ConstructionHeight=0;cell.ConstructionMoveExtra=0;cell.ConstructionKind=null;Array.Copy(cell.BaseCorners,cell.Corners,6);}
            changedConstructionCells.Clear();
            foreach(var row in state.Constructions)
            {
                var cell=Cells[row.CellIndex];changedConstructionCells.Add(row.CellIndex);cell.Blocked|=row.BlocksMovement;cell.ConstructionMoveExtra=row.MoveExtra;cell.ConstructionKind=row.Kind;
                if(row.Kind=="platform"||row.Kind=="pit"||row.Kind=="trench")
                {cell.Position=cell.BasePosition+Vector3.up*row.Height;for(int i=0;i<6;i++)cell.Corners[i]=cell.BaseCorners[i]+row.Height;}
                if(row.Kind=="pit"||row.Kind=="trench")cell.GroundHeight=cell.Position.y;
                if(row.BlocksMovement)cell.ConstructionHeight=row.Height;
            }
            foreach(var loot in state.Loots)if(loot.BlocksMovement)foreach(int index in loot.Cells)
            {changedConstructionCells.Add(index);Cells[index].Blocked=true;}
        }
        private static int[] Indices(LuaTable root, string key)
        {
            using (var values = root.Get<LuaTable>(key))
            {
                var result = new int[values.Length];
                for (var i = 0; i < result.Length; i++) result[i] = values.Get<int, int>(i + 1) - 1;
                return result;
            }
        }
        // Derived immutable index range, not exploration state. Only retain the most recent map size.
        // Snapshot consumers read these arrays; visibility changes replace the array reference.
        private static int[] fullVisibilityIndices = Array.Empty<int>();
        private static int[] FullVisibilityIndices(int count)
        {
            if (fullVisibilityIndices.Length != count)
            {
                var indices = new int[count];
                for (var i = 0; i < count; i++) indices[i] = i;
                fullVisibilityIndices = indices;
            }
            return fullVisibilityIndices;
        }
        private static float[] Numbers(LuaTable root, string key)
        {
            using (var values = root.Get<LuaTable>(key))
            {
                var result = new float[values.Length];
                for (var i = 0; i < result.Length; i++) result[i] = values.Get<int, float>(i + 1);
                return result;
            }
        }
        // 交互提示沿真实道路图计算，不把桥下居民当成桥上邻居。
        public int StreetDistance(int from, int to, int limit)
        {
            if (from == to) return 0;
            var queue = new System.Collections.Generic.Queue<int>(); var distance = new System.Collections.Generic.Dictionary<int, int>();
            queue.Enqueue(from); distance.Add(from, 0);
            while (queue.Count > 0)
            {
                var index = queue.Dequeue(); if (distance[index] == limit) continue;
                var cell = Cells[index];
                for (var d = 0; d < cell.Neighbors.Length; d++)
                {
                    var next = cell.Neighbors[d];
                    if ((cell.WalkMask & (1 << d)) == 0 || next < 0 || Cells[next].Blocked || distance.ContainsKey(next)) continue;
                    if (next == to) return distance[index] + 1;
                    distance.Add(next, distance[index] + 1); queue.Enqueue(next);
                }
            }
            return int.MaxValue;
        }
        public static State ReadState(LuaTable root)
        {
            using (var area = root.Get<LuaTable>("area"))
            {
                if (area == null) return null; // 探索与原地战斗共用同一局部场景。
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
                        npcs[i] = new NpcState { Id = row.Get<int>("id"), CellIndex = row.Get<int>("cellIndex") - 1, Present = row.Get<bool>("present") };
                }
                AdventureViewData.Actor[] enemies;
                using (var rows = area.Get<LuaTable>("enemies"))
                {
                    enemies = new AdventureViewData.Actor[rows.Length];
                    for (var i = 0; i < enemies.Length; i++) using (var row = rows.Get<int, LuaTable>(i + 1)) enemies[i] = AdventureViewData.ReadActor(row);
                }
                AdventureViewData.Actor[] defeated;
                using (var rows = area.Get<LuaTable>("defeated"))
                {
                    defeated = new AdventureViewData.Actor[rows.Length];
                    for (var i = 0; i < defeated.Length; i++) using (var row = rows.Get<int, LuaTable>(i + 1)) defeated[i] = AdventureViewData.ReadActor(row);
                }
                Loot[] loots;
                using(var rows=area.Get<LuaTable>("loot"))
                {
                    // MapArea-only snapshots do not own inventory; Adventure appends loot.
                    loots=new Loot[rows?.Length??0];
                    for(int i=0;i<loots.Length;i++) using(var row=rows.Get<int,LuaTable>(i+1)) using(var asset=row.Get<LuaTable>("asset"))
                        loots[i]=new Loot {Id=row.Get<int>("id"),CellIndex=row.Get<int>("cellIndex")-1,Cells=Indices(row,"cells"),
                            Name=row.Get<string>("name"),Looted=row.Get<bool>("looted"),Asset=EquipmentVisualData.Asset.Read(asset),
                            Durability=row.Get<int>("durability"),MaxDurability=row.Get<int>("maxDurability"),Destroyed=row.Get<bool>("destroyed"),
                            CanSearch=row.Get<bool>("canSearch"),Near=row.Get<bool>("near"),BlocksMovement=row.Get<bool>("blocksMovement"),Interaction=row.Get<string>("interaction"),
                            Rotation=row.Get<float>("rotation"),Scale=row.Get<float>("scale"),OffsetX=row.Get<float>("offsetX"),OffsetZ=row.Get<float>("offsetZ"),Height=row.Get<float>("height"),
                            Scale3=new Vector3(row.Get<float>("scaleX"),row.Get<float>("scaleY"),row.Get<float>("scaleZ")),Items=ReadDisplayItems(row),
                            DisplayContents=row.Get<string>("displayContents"),DisplayHeight=row.Get<float>("displayHeight"),DisplayItemScale=row.Get<float>("displayItemScale")};
                }
                Obstacle[] obstacles;
                using(var rows=area.Get<LuaTable>("obstacles"))
                {
                    // MapArea-only queries have no Adventure obstacle service.
                    obstacles=new Obstacle[rows?.Length??0];
                    for(int i=0;i<obstacles.Length;i++)using(var row=rows.Get<int,LuaTable>(i+1))using(var asset=row.Get<LuaTable>("asset"))
                        obstacles[i]=new Obstacle {Id=row.Get<int>("id"),Name=row.Get<string>("name"),Cells=Indices(row,"cells"),BlocksMovement=row.Get<bool>("blocksMovement"),Asset=EquipmentVisualData.Asset.Read(asset)};
                }
                Construction[] constructions;
                using(var rows=area.Get<LuaTable>("constructions"))
                {
                    // Independent MapArea snapshots do not include Adventure-owned construction.
                    constructions=new Construction[rows?.Length??0];
                    for(int i=0;i<constructions.Length;i++)using(var row=rows.Get<int,LuaTable>(i+1))
                        constructions[i]=new Construction{Id=row.Get<int>("id"),CellIndex=row.Get<int>("cellIndex")-1,SkillId=row.Get<int>("skillId"),
                            Kind=row.Get<string>("kind"),Name=row.Get<string>("name"),Height=row.Get<float>("height"),MoveExtra=row.Get<int>("moveExtra"),HP=row.Get<int>("hp"),MaxHP=row.Get<int>("maxHP"),
                            BlocksMovement=row.Get<bool>("blocksMovement"),BlocksSight=row.Get<bool>("blocksSight")};
                }
                // Older/partial snapshots carry explicit arrays; fully revealed maps use a compact range.
                var fullRange = area.Get<object>("fullVisibilityCount");
                var fullCount = fullRange == null ? 0 : Convert.ToInt32(fullRange);
                if (fullCount < 0) throw new InvalidOperationException("Invalid full-visibility cell count.");
                var known = fullCount > 0 ? FullVisibilityIndices(fullCount) : Indices(area, "known");
                var visible = fullCount > 0 ? known : Indices(area, "visible");
                return new State { Members = members, Npcs = npcs, Enemies = enemies, Defeated=defeated, Loots=loots, Obstacles=obstacles,
                    Constructions=constructions,ConstructionRevision=area.Get<int>("constructionRevision"),ContainerRevision=area.Get<int>("containerRevision"),
                    EncounterCount = area.Get<int>("encounterCount"), ClearedEncounters = area.Get<int>("clearedEncounters"),
                    InteractionKind = area.Get<int>("interactionKind"), InteractionId = area.Get<int>("interactionId"),
                    Name = area.Get<string>("name"), Theme = area.Get<string>("theme"), Seed = area.Get<uint>("seed"),
                    CellIndex = area.Get<int>("cellIndex") - 1, EntryIndex = area.Get<int>("entryIndex") - 1,
                    GoalIndex = area.Get<int>("goalIndex") - 1, Revision = area.Get<int>("revision"), RoomCount = area.Get<int>("roomCount"),
                    WalkableCount = area.Get<int>("walkableCount"), SourceRegionId = area.Get<int>("sourceRegionId"), PropCount = area.Get<int>("propCount"),
                    Known = known, Visible = visible, Route = Indices(area, "route") };
            }
        }
        public static MapAreaViewData Read(LuaTable root)
        {
            using (var cells = root.Get<LuaTable>("cells"))
            {
                var result = new MapAreaViewData { Radius = root.Get<float>("hexRadius"), AssetId = root.Get<int>("assetId"),
                    AssetPath = root.Get<string>("assetPath"), TintMaterial = root.Get<string>("tintMaterial"), Cells = new Cell[cells.Length],
                    CorridorWidth = root.Get<int>("corridorWidth"), AreaType = root.Get<int>("areaType"), MoveStepSeconds = root.Get<float>("moveStepSeconds") };
                using (var rows = root.Get<LuaTable>("surfaces"))
                    for (var i = 1; i <= rows.Length; i++) using (var row = rows.Get<int, LuaTable>(i))
                    {
                        if (!ColorUtility.TryParseHtmlString(row.Get<string>("color"), out var color)) throw new InvalidOperationException("地表颜色无效");
                        if (!ColorUtility.TryParseHtmlString(row.Get<string>("detailColor"), out var detail)) throw new InvalidOperationException("地表覆盖色无效");
                        result.Surfaces.Add(row.Get<int>("id"), new Surface { Color = color, DetailColor = detail, Smoothness = row.Get<float>("smoothness"),
                            Pattern = new Vector4(row.Get<int>("pattern"), row.Get<float>("tileMeters"), row.Get<float>("contrast"), row.Get<float>("jointWidth")) });
                    }
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
                        result.Npcs[i] = new Npc { Id = row.Get<int>("id"), NarrativeId = row.Get<int>("narrativeId"), Name = row.Get<string>("name"), Description = row.Get<string>("description"),
                            StepSeconds = row.Get<float>("stepSeconds"), Appearance = PawnAppearanceData.Read(appearance) };
                }
                for (var i = 0; i < result.Cells.Length; i++)
                    using (var row = cells.Get<int, LuaTable>(i + 1))
                    using (var color = row.Get<LuaTable>("color"))
                        result.Cells[i] = new Cell { Q = row.Get<int>("q"), R = row.Get<int>("r"), RoomId = row.Get<int>("roomId"),
                            InteriorId = row.Get<int>("interiorId"), CoverInteriorId = row.Get<int>("coverInteriorId"), CutawayGroup = row.Get<int>("cutawayGroup"), CutawayLayer = row.Get<int>("cutawayLayer"), Layer = row.Get<int>("layer"), WalkMask = row.Get<int>("walkMask"), Neighbors = Indices(row, "neighbors"), Corners = Numbers(row, "corners"),BaseCorners=Numbers(row,"corners"),
                            DeckThickness = row.Get<float>("deckThickness"), StairRise = row.Get<float>("stairRise"), SurfaceId = row.Get<int>("surfaceId"), SideSurfaceId = row.Get<int>("sideSurfaceId"),
                            Position = new Vector3(row.Get<float>("x"), row.Get<float>("height"), row.Get<float>("z")),
                            BasePosition = new Vector3(row.Get<float>("x"), row.Get<float>("height"), row.Get<float>("z")),GroundHeight=row.Get<float>("height"),BaseBlocked=row.Get<bool>("blocked"),
                            WallHeight = row.Get<float>("wallHeight"), Blocked = row.Get<bool>("blocked"), Kind = row.Get<string>("kind"), RenderGround = row.Get<bool>("renderGround"),
                            Color = new Color(color.Get<int, float>(1), color.Get<int, float>(2), color.Get<int, float>(3), 1) };
                using (var patches = root.Get<LuaTable>("floorBoundaryPatches"))
                {
                    // Older saved display fixtures may predate the optional boundary geometry.
                    result.FloorBoundaryPatches = new FloorBoundaryPatch[patches?.Length ?? 0];
                    for (var i = 0; i < result.FloorBoundaryPatches.Length; i++) using (var row = patches.Get<int, LuaTable>(i + 1))
                    {
                        var owner = row.Get<int>("ownerIndex") - 1;
                        var values = Numbers(row, "points"); var height = row.Get<float>("height"); var thickness = row.Get<float>("thickness");
                        if (owner < 0 || owner >= result.Cells.Length || values.Length < 6 || values.Length % 2 != 0 || thickness <= 0)
                            throw new InvalidOperationException("楼板封边块数据无效");
                        var points = new Vector3[values.Length / 2];
                        for (var j = 0; j < points.Length; j++) points[j] = new Vector3(values[j * 2], height, values[j * 2 + 1]);
                        result.FloorBoundaryPatches[i] = new FloorBoundaryPatch { OwnerIndex = owner, Points = points, Thickness = thickness };
                    }
                }
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
                            InteriorId = row.Get<int>("interiorId"), Cutaway = row.Get<bool>("cutaway"), CameraObstacle = row.Get<bool>("cameraObstacle"), Layer = row.Get<int?>("layer") ?? -1, CutawayGroup = row.Get<int>("cutawayGroup"), CutawayLayer = row.Get<int>("cutawayLayer"),
                            Position = new Vector3(row.Get<float>("x"), row.Get<float>("y"), row.Get<float>("z")),
                            Rotation = row.Get<float>("rotation"), Scale = row.Get<float>("scale"),
                            Scale3 = new Vector3(row.Get<float>("scaleX"), row.Get<float>("scaleY"), row.Get<float>("scaleZ")) };
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
