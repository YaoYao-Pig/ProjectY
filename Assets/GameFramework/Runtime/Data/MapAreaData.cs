using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class MapAreaLootData
    {
        public int Id { get; }
        public int CellIndex { get; }
        public int TableId { get; }
        public bool Looted { get; internal set; }
        internal MapAreaLootData(int id, int cell, int table) { Id = id; CellIndex = cell; TableId = table; }
    }
    /// <summary>地牢敌群与战斗共享角色实例；离开地点不恢复生命或重新生成。</summary>
    [LuaCallCSharp]
    public sealed class MapAreaEncounterData
    {
        private readonly List<CombatActorData> enemies = new List<CombatActorData>();
        public int Id { get; }
        public int EncounterId { get; }
        public int EnemyCount => enemies.Count;
        public bool Defeated => enemies.Count > 0 && enemies.TrueForAll(actor => actor.HP == 0);
        public CombatActorData GetEnemyAt(int index) => enemies[index];
        internal MapAreaEncounterData(int id, int encounterId) { Id = id; EncounterId = encounterId; }
        public CombatActorData AddEnemy(int id, int templateId, int q, int r)
        {
            if (enemies.Count >= 4 || enemies.Exists(actor => actor.Id == id || (actor.Q == q && actor.R == r)))
                throw new InvalidOperationException("Invalid dungeon enemy deployment.");
            var actor = new CombatActorData(id, templateId); actor.Deploy(2, q, r); enemies.Add(actor); return actor;
        }
    }

    /// <summary>城镇居民的权威占格、巡游游标和游戏时钟；外观与路线归静态布局。</summary>
    [LuaCallCSharp]
    public sealed class MapAreaNpcData
    {
        public int Id { get; }
        public int CellIndex { get; private set; }
        public int PatrolCursor { get; private set; }
        private float elapsed;
        internal MapAreaNpcData(int id, int cell) { Id = id; CellIndex = cell; }
        public bool Due(float dt, float interval)
        {
            if (dt < 0 || interval <= 0 || float.IsNaN(dt) || float.IsInfinity(dt)) throw new ArgumentOutOfRangeException(nameof(dt));
            elapsed += dt;
            if (elapsed < interval) return false;
            elapsed = 0; return true;
        }
        internal void Move(int cell, int cursor, float pause)
        { CellIndex = cell; PatrolCursor = cursor; elapsed = -pause; }
    }

    /// <summary>单个地点的探索记录与小队移动锚点；不复制 Lua 的静态地形。</summary>
    [LuaCallCSharp]
    public sealed class MapAreaStateData
    {
        private readonly List<MapAreaLootData> loot = new List<MapAreaLootData>();
        public bool LootInitialized { get; private set; }
        public int LootCount => loot.Count;
        public MapAreaLootData GetLootAt(int index) => loot[index];
        public void AddLoot(int cellIndex, int tableId)
        {
            CheckCell(cellIndex);
            if (LootInitialized || tableId < 1 || loot.Exists(row => row.CellIndex == cellIndex)) throw new InvalidOperationException("Invalid loot placement.");
            loot.Add(new MapAreaLootData(loot.Count + 1, cellIndex, tableId)); Revision++;
        }
        public void CompleteLootInitialization() { LootInitialized = true; }
        public void Loot(int id)
        {
            if (id < 1 || id > loot.Count || loot[id - 1].Looted) throw new InvalidOperationException("Loot is unavailable.");
            loot[id - 1].Looted = true; Revision++;
        }
        private readonly bool[] known;
        private readonly List<int> discovered = new List<int>();
        private int[] visible = Array.Empty<int>();
        private int[] route = Array.Empty<int>();
        private int[] memberIds = Array.Empty<int>();
        private int[] memberCells = Array.Empty<int>();
        private int cursor;
        private float elapsed;
        private readonly List<MapAreaNpcData> npcs = new List<MapAreaNpcData>();
        private readonly List<MapAreaEncounterData> encounters = new List<MapAreaEncounterData>();
        public bool EncountersInitialized { get; private set; }
        public int EncounterCount => encounters.Count;
        public MapAreaEncounterData GetEncounterAt(int index) => encounters[index];
        public MapAreaEncounterData AddEncounter(int id, int encounterId)
        {
            if (EncountersInitialized || id != encounters.Count + 1 || encounterId < 1)
                throw new InvalidOperationException("Invalid dungeon encounter initialization.");
            var encounter = new MapAreaEncounterData(id, encounterId); encounters.Add(encounter); return encounter;
        }
        public void CompleteEncounterInitialization()
        {
            if (EncountersInitialized || encounters.Exists(group => group.EnemyCount == 0))
                throw new InvalidOperationException("Dungeon encounters must be initialized exactly once.");
            EncountersInitialized = true;
        }
        public int NpcCount => npcs.Count;
        public MapAreaNpcData GetNpcAt(int index) => npcs[index];
        public int InteractionKind { get; private set; }
        public int InteractionId { get; private set; }
        public int SiteId { get; }
        public int CellIndex { get; private set; }
        public int CellCount => known.Length;
        public int KnownCount => discovered.Count;
        public int VisibleCount => visible.Length;
        private int RouteWidth => Math.Max(1, memberIds.Length);
        public int RemainingSteps => route.Length / RouteWidth - cursor;
        public int MemberCount => memberIds.Length;
        public int GetMemberIdAt(int index) => memberIds[index];
        public int GetMemberCellAt(int index) => memberCells[index];
        public int Revision { get; private set; }
        public int GetKnownAt(int index) => discovered[index];
        public int GetVisibleAt(int index) => visible[index];
        public int GetRouteAt(int index) => route[(cursor + index) * RouteWidth];
        public bool IsKnown(int cellIndex) { CheckCell(cellIndex); return known[cellIndex - 1]; }
        public MapAreaStateData(int siteId, int cellCount, int entryIndex)
        {
            if (siteId < 1 || cellCount < 1) throw new ArgumentOutOfRangeException(nameof(siteId));
            SiteId = siteId; known = new bool[cellCount]; CheckCell(entryIndex); CellIndex = entryIndex;
        }
        private void CheckCell(int index)
        {
            if (index < 1 || index > CellCount) throw new ArgumentOutOfRangeException(nameof(index));
        }
        public void AddNpc(int id, int cell)
        {
            CheckCell(cell);
            if (id != npcs.Count + 1 || IsNpcOccupied(cell) || IsSquadReserved(cell)) throw new ArgumentException("Invalid NPC spawn.");
            npcs.Add(new MapAreaNpcData(id, cell)); Revision++;
        }
        public bool IsNpcOccupied(int cell) => npcs.Exists(npc => npc.CellIndex == cell);
        public bool IsSquadReserved(int cell)
        {
            if (Array.IndexOf(memberCells, cell) >= 0) return true;
            for (var i = cursor * RouteWidth; i < route.Length; i++) if (route[i] == cell) return true;
            return false;
        }
        public void MoveNpc(int id, int cell, int patrolCursor, float pause)
        {
            CheckCell(cell);
            if (id < 1 || id > npcs.Count || patrolCursor < 0 || pause < 0) throw new ArgumentOutOfRangeException(nameof(id));
            var npc = npcs[id - 1];
            if (cell != npc.CellIndex && (IsNpcOccupied(cell) || IsSquadReserved(cell))) throw new InvalidOperationException("NPC position is occupied or reserved.");
            npc.Move(cell, patrolCursor, pause); Revision++;
        }
        public void SetInteraction(int kind, int id)
        {
            if (kind < 0 || kind > 2 || (kind == 0 ? id != 0 : id < 1)) throw new ArgumentOutOfRangeException(nameof(kind));
            Stop(); InteractionKind = kind; InteractionId = id; Revision++;
        }
        public void Reveal(int[] cells)
        {
            if (cells == null) throw new ArgumentNullException(nameof(cells));
            foreach (var index in cells) CheckCell(index);
            visible = (int[])cells.Clone();
            foreach (var index in cells)
                if (!known[index - 1]) { known[index - 1] = true; discovered.Add(index); }
            Revision++;
        }
        public void SetRoute(int[] cells)
        {
            if (MemberCount > 1) throw new InvalidOperationException("Use a simultaneous squad route for multiple members.");
            if (cells == null) throw new ArgumentNullException(nameof(cells));
            foreach (var index in cells) CheckCell(index);
            route = (int[])cells.Clone(); cursor = 0; elapsed = 0; Revision++;
        }
        // 每个地点保留成员位置；进场只在实际存活名单变化时重新部署。
        public void DeployMembers(int[] ids, int[] cells)
        {
            if (ids == null || cells == null || ids.Length < 1 || ids.Length > 4 || ids.Length != cells.Length)
                throw new ArgumentException("Squad requires 1..4 matching member IDs and cells.");
            var uniqueIds = new HashSet<int>(); var uniqueCells = new HashSet<int>();
            for (var i = 0; i < ids.Length; i++)
            {
                CheckCell(cells[i]);
                if (ids[i] < 1 || !uniqueIds.Add(ids[i]) || !uniqueCells.Add(cells[i]) || IsNpcOccupied(cells[i])) throw new ArgumentException("Squad IDs and occupied cells must be unique and free of NPCs.");
            }
            Stop(); memberIds = (int[])ids.Clone(); memberCells = (int[])cells.Clone(); CellIndex = memberCells[0]; Revision++;
        }
        // 按帧展开的同步路线：[第一帧全体位置，第二帧全体位置……]。
        public void SetSquadRoute(int[] cells)
        {
            if (MemberCount == 0 || cells == null || cells.Length % MemberCount != 0) throw new ArgumentException("Invalid squad route frames.");
            for (var offset = 0; offset < cells.Length; offset += MemberCount)
            {
                var occupied = new HashSet<int>();
                for (var i = 0; i < MemberCount; i++)
                {
                    CheckCell(cells[offset + i]);
                    if (!occupied.Add(cells[offset + i]) || IsNpcOccupied(cells[offset + i])) throw new ArgumentException("Squad route overlaps members or NPCs.");
                    for (var j = 0; j < i; j++)
                    {
                        var oldI = offset == 0 ? memberCells[i] : cells[offset - MemberCount + i];
                        var oldJ = offset == 0 ? memberCells[j] : cells[offset - MemberCount + j];
                        if (cells[offset + i] == oldJ && cells[offset + j] == oldI) throw new ArgumentException("Squad route swaps members head-on.");
                    }
                }
            }
            route = (int[])cells.Clone(); cursor = 0; elapsed = 0; Revision++;
        }
        public void Stop() { route = Array.Empty<int>(); cursor = 0; elapsed = 0; Revision++; }
        public void RetreatToEntry(int entryIndex)
        {
            CheckCell(entryIndex); Stop(); memberIds = Array.Empty<int>(); memberCells = Array.Empty<int>();
            CellIndex = entryIndex; Revision++;
        }
        // Lua 使用游戏时间推进，暂停时不借用 UI 的非缩放时钟继续移动。
        public bool Advance(float deltaTime, float stepSeconds)
        {
            if (deltaTime < 0 || float.IsNaN(deltaTime) || float.IsInfinity(deltaTime) || stepSeconds <= 0 || float.IsNaN(stepSeconds) || float.IsInfinity(stepSeconds))
                throw new ArgumentOutOfRangeException(nameof(deltaTime));
            if (RemainingSteps == 0) return false;
            elapsed += deltaTime;
            if (elapsed < stepSeconds) return false;
            elapsed -= stepSeconds;
            CellIndex = route[cursor * RouteWidth];
            for (var i = 0; i < MemberCount; i++) memberCells[i] = route[cursor * RouteWidth + i];
            cursor++; Revision++;
            if (RemainingSteps == 0) { route = Array.Empty<int>(); cursor = 0; elapsed = 0; }
            return true;
        }
    }

    /// <summary>当前远征中各交互点的探索记录；开始新远征时统一释放。</summary>
    [LuaCallCSharp]
    public sealed class MapAreaData
    {
        private readonly Dictionary<int, MapAreaStateData> areas = new Dictionary<int, MapAreaStateData>();
        public int ActiveSiteId { get; private set; }
        public MapAreaStateData Active => ActiveSiteId == 0 ? null : areas[ActiveSiteId];
        public MapAreaStateData Enter(int siteId, int cellCount, int entryIndex)
        {
            if (ActiveSiteId != 0) throw new InvalidOperationException("A MapArea is already active.");
            if (!areas.TryGetValue(siteId, out var state))
            {
                state = new MapAreaStateData(siteId, cellCount, entryIndex); areas.Add(siteId, state);
            }
            if (state.CellCount != cellCount) throw new InvalidOperationException("MapArea layout changed during the expedition.");
            ActiveSiteId = siteId; return state;
        }
        public void Leave()
        {
            if (Active == null) throw new InvalidOperationException("No active MapArea.");
            Active.SetInteraction(0, 0); ActiveSiteId = 0;
        }
        public void Clear() { areas.Clear(); ActiveSiteId = 0; }
    }
}
