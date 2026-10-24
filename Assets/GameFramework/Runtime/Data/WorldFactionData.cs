using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    /// <summary>Reflection entry points for additions to types that already have generated xLua wrappers.</summary>
    public static class FactionPersistence
    {
        public static MapAreaStateData Ensure(MapAreaData areas, int site, int cells, int entry) => areas.Ensure(site, cells, entry);
        public static MapAreaStateData Find(MapAreaData areas, int site) => areas.Find(site);
        public static void AttachParty(MapAreaEncounterData group, WorldPartyData party) => group.AttachParty(party);
        public static void AdoptLegacyParty(MapAreaEncounterData group, WorldPartyData party) => group.AdoptLegacyParty(party);
        public static void DetachParty(MapAreaEncounterData group) => group.DetachParty();
        public static int PartyId(MapAreaEncounterData group) => group.PartyId;
        public static bool Detached(MapAreaEncounterData group) => group.Detached;
        public static void Replenish(CombatActorData actor) => actor.Replenish();
        public static void ApplyShopRecovery(ShopData shops, ShopStock stock, double liberatedAt, double factor)
            => shops.ApplyOccupationRecovery(stock, liberatedAt, factor);
    }
    /// <summary>Mutable diplomacy only; initial values and strategy remain configuration-owned.</summary>
    public sealed class WorldFactionRelationData
    {
        public int FactionA { get; internal set; }
        public int FactionB { get; internal set; }
        public int Value { get; internal set; }
        public double ChangedAt { get; internal set; }
        public string Reason { get; internal set; }
    }

    public sealed class WorldFactionSiteData
    {
        public int SiteId { get; internal set; }
        public int FactionId { get; internal set; }
        public int GuardPartyId { get; internal set; }
        public bool IsTown { get; internal set; }
        public int OccupierId { get; private set; }
        public int OccupierPartyId { get; private set; }
        public double OccupiedAt { get; private set; } = -1;
        public double LiberatedAt { get; private set; } = -1;
        public double ProtectedUntil { get; private set; }
        public int Reserve { get; private set; }
        public double LastRecoveryAt { get; private set; }
        public int Revision { get; private set; }
        public void SetGuardParty(int party)
        {
            if (party < 1) throw new ArgumentOutOfRangeException(nameof(party));
            GuardPartyId = party; Revision++;
        }
        public void SetOccupation(int faction, int party, double minute)
        {
            WorldFactionsData.CheckTime(minute);
            if (faction < 1 || faction == FactionId || party < 1 || minute < Math.Max(OccupiedAt, LiberatedAt))
                throw new ArgumentException("Invalid settlement occupation.");
            OccupierId = faction; OccupierPartyId = party; OccupiedAt = minute; Revision++;
        }
        public void Liberate(double minute, double protectedUntil)
        {
            WorldFactionsData.CheckTime(minute); WorldFactionsData.CheckTime(protectedUntil);
            if (OccupierId == 0 || minute < OccupiedAt || protectedUntil < minute)
                throw new InvalidOperationException("Invalid settlement liberation.");
            OccupierId = OccupierPartyId = 0; LiberatedAt = minute; ProtectedUntil = protectedUntil; Revision++;
        }
        public void AddReserve(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            Reserve = checked(Reserve + amount); Revision++;
        }
        public bool SpendReserve(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            if (amount > Reserve) return false;
            Reserve -= amount; Revision++; return true;
        }
        public void SetRecoveryAt(double minute)
        {
            WorldFactionsData.CheckTime(minute);
            if (minute < LastRecoveryAt) throw new ArgumentOutOfRangeException(nameof(minute));
            LastRecoveryAt = minute; Revision++;
        }
        internal WorldFactionSiteSave Capture() => new WorldFactionSiteSave { site = SiteId, faction = FactionId, guard = GuardPartyId,
            town = IsTown, occupier = OccupierId, occupierParty = OccupierPartyId, occupiedAt = OccupiedAt,
            liberatedAt = LiberatedAt, protectedUntil = ProtectedUntil, reserve = Reserve, recoveredAt = LastRecoveryAt, revision = Revision };
        internal static WorldFactionSiteData Prepare(WorldFactionSiteSave row)
        {
            SaveCheck.Require(row != null && row.site > 0 && row.faction > 0 && row.guard > 0 && row.occupier >= 0 && row.occupierParty >= 0 &&
                (row.occupier == 0) == (row.occupierParty == 0) && row.occupier != row.faction && row.reserve >= 0 && row.revision >= 0 &&
                (row.occupiedAt == -1 || WorldFactionsData.ValidTime(row.occupiedAt)) && (row.liberatedAt == -1 || WorldFactionsData.ValidTime(row.liberatedAt)) &&
                WorldFactionsData.ValidTime(row.protectedUntil) && WorldFactionsData.ValidTime(row.recoveredAt) &&
                (row.occupier == 0 || row.occupiedAt >= 0 && row.occupiedAt >= row.liberatedAt) &&
                (row.liberatedAt < 0 || row.protectedUntil >= row.liberatedAt), "势力据点");
            return new WorldFactionSiteData { SiteId = row.site, FactionId = row.faction, GuardPartyId = row.guard, IsTown = row.town,
                OccupierId = row.occupier, OccupierPartyId = row.occupierParty, OccupiedAt = row.occupiedAt, LiberatedAt = row.liberatedAt,
                ProtectedUntil = row.protectedUntil, Reserve = row.reserve, LastRecoveryAt = row.recoveredAt, Revision = row.revision };
        }
    }

    /// <summary>A world conflict retains actor references through party IDs and owns its random stream.</summary>
    public sealed class WorldFactionConflictData
    {
        private uint random;
        private readonly List<MapAreaLootData> pendingCargo=new List<MapAreaLootData>();
        public int SiteId { get; internal set; }
        public int PartyA { get; internal set; }
        public int PartyB { get; internal set; }
        public int TargetSiteId { get; private set; }
        public double CreatedAt { get; internal set; }
        public double NextTickAt { get; private set; }
        public double MinimumEndAt { get; internal set; }
        public double ExpiresAt { get; private set; }
        public string Phase { get; private set; } = "active";
        public int WinnerPartyId { get; private set; }
        public bool PlayerEngaged { get; private set; }
        public bool Materialized { get; private set; } = true;
        public int PendingCargoCount=>pendingCargo.Count;
        public MapAreaLootData GetPendingCargoAt(int index)=>pendingCargo[index];
        public void MarkMaterialized() { Materialized=true; }
        internal void DeferCargo(MapAreaLootData cargo)
        {
            if(Materialized || Phase=="expired" || cargo==null || pendingCargo.Count>=64)
                throw new InvalidOperationException("Invalid abstract conflict cargo.");
            pendingCargo.Add(cargo);
        }
        internal void RemovePendingCargo()=>pendingCargo.RemoveAt(0);
        public void SetTargetSite(int site)
        {
            if (site < 0 || Phase != "active") throw new ArgumentOutOfRangeException(nameof(site));
            TargetSiteId = site;
        }
        public void TickAt(double minute)
        {
            WorldFactionsData.CheckTime(minute);
            if (Phase != "active" || minute < NextTickAt) throw new InvalidOperationException("Invalid conflict tick.");
            NextTickAt = minute;
        }
        public void Engage(bool value)
        {
            if (value && (Phase == "expired" || !Materialized)) throw new InvalidOperationException("Battlefield is not available for player engagement.");
            PlayerEngaged = value;
        }
        public void Resolve(int winner, double expires)
        {
            WorldFactionsData.CheckTime(expires);
            if (Phase != "active" || (winner != 0 && winner != PartyA && winner != PartyB) || expires < CreatedAt)
                throw new InvalidOperationException("Invalid conflict resolution.");
            WinnerPartyId = winner; ExpiresAt = expires; Phase = "resolved"; PlayerEngaged = false;
        }
        public void Expire()
        {
            if (Phase == "active" || PlayerEngaged) throw new InvalidOperationException("Cannot expire an active battlefield.");
            Phase = "expired";
        }
        public int Roll(int maximum)
        {
            if (maximum < 1 || random == 0) throw new InvalidOperationException("Invalid conflict random stream.");
            random ^= random << 13; random ^= random >> 17; random ^= random << 5;
            return (int)(random % (uint)maximum) + 1;
        }
        internal static WorldFactionConflictData Create(int site, int a, int b, double created, double minimumEnd, double expires, uint seed,bool materialized)
        {
            WorldFactionsData.CheckTime(created); WorldFactionsData.CheckTime(minimumEnd); WorldFactionsData.CheckTime(expires);
            if (site < 1 || a < 1 || b < 0 || a == b || minimumEnd < created || expires < minimumEnd)
                throw new ArgumentException("Invalid world conflict.");
            return new WorldFactionConflictData { SiteId = site, PartyA = a, PartyB = b, CreatedAt = created, NextTickAt = created,
                MinimumEndAt = minimumEnd, ExpiresAt = expires, random = seed == 0 ? 1u : seed,Materialized=materialized };
        }
        internal WorldFactionConflictSave Capture() => new WorldFactionConflictSave { site = SiteId, a = PartyA, b = PartyB, target = TargetSiteId,
            created = CreatedAt, nextTick = NextTickAt, minimumEnd = MinimumEndAt, expires = ExpiresAt,
            phase = Phase, winner = WinnerPartyId, engaged = PlayerEngaged, random = random,materialized=Materialized,pendingCargo=pendingCargo.Select(c=>c.Capture()).ToArray() };
        internal static WorldFactionConflictData Prepare(WorldFactionConflictSave row,bool legacy,EquipmentData equipment,HashSet<int> itemIds)
        {
            SaveCheck.Require(row != null && row.site > 0 && row.a > 0 && row.b >= 0 && row.a != row.b && row.target >= 0 && row.random != 0 &&
                WorldFactionsData.ValidTime(row.created) && WorldFactionsData.ValidTime(row.nextTick) && WorldFactionsData.ValidTime(row.minimumEnd) && WorldFactionsData.ValidTime(row.expires) &&
                row.nextTick >= row.created && row.minimumEnd >= row.created && row.expires >= row.created &&
                (row.phase == "active" || row.phase == "resolved" || row.phase == "expired") &&
                (row.winner == 0 || row.winner == row.a || row.winner == row.b) &&
                (row.phase != "active" || row.winner == 0 && row.expires >= row.minimumEnd) && !row.engaged, "势力战场");
            var conflict=new WorldFactionConflictData { SiteId = row.site, PartyA = row.a, PartyB = row.b, TargetSiteId = row.target, CreatedAt = row.created,
                NextTickAt = row.nextTick, MinimumEndAt = row.minimumEnd, ExpiresAt = row.expires, Phase = row.phase, WinnerPartyId = row.winner, random = row.random,
                Materialized=legacy || row.materialized };
            if(!legacy)foreach(var cargo in SaveCheck.Rows(row.pendingCargo,64,"抽象战场货物"))
            {
                var hold=MapAreaLootData.Prepare(cargo,1,1,equipment,itemIds);
                SaveCheck.Require(hold.SearchItems!=null && hold.SearchItems.Any(item=>item.Count>0),"抽象战场空货物");
                conflict.pendingCargo.Add(hold);
            }
            return conflict;
        }
    }

    public sealed class WorldFactionsData
    {
        public WorldFactionConflictData[] UnexpiredConflicts() => conflicts.Where(c=>c.Phase!="expired").ToArray();
        private readonly List<WorldFactionSiteData> sites = new List<WorldFactionSiteData>();
        private readonly List<WorldFactionRelationData> relations = new List<WorldFactionRelationData>();
        private readonly List<WorldFactionConflictData> conflicts = new List<WorldFactionConflictData>();
        private readonly Dictionary<int, WorldFactionSiteData> siteIndex = new Dictionary<int, WorldFactionSiteData>();
        private readonly Dictionary<int, WorldFactionConflictData> conflictIndex = new Dictionary<int, WorldFactionConflictData>();
        private readonly Dictionary<long, WorldFactionRelationData> relationIndex = new Dictionary<long, WorldFactionRelationData>();
        public static WorldFactionsData For(AdventureData adventure) => adventure.WorldParties.Factions;
        public static WorldFactionsData Prepared(PreparedCharacterSave save) => save.PreparedWorldParties.Factions;
        public bool Initialized { get; private set; }
        public int Revision { get; private set; }
        public int SiteCount => sites.Count;
        public int RelationCount => relations.Count;
        public int ConflictCount => conflicts.Count;
        public WorldFactionSiteData GetSiteAt(int index) => sites[index];
        public WorldFactionRelationData GetRelationAt(int index) => relations[index];
        public WorldFactionConflictData GetConflictAt(int index) => conflicts[index];
        public WorldFactionSiteData FindSite(int site) => siteIndex.TryGetValue(site, out var value) ? value : null;
        public WorldFactionConflictData FindConflict(int site) => conflictIndex.TryGetValue(site, out var value) ? value : null;
        private static long RelationKey(int a, int b) => ((long)Math.Min(a, b) << 32) | (uint)Math.Max(a, b);
        public WorldFactionRelationData FindRelation(int a, int b) => relationIndex.TryGetValue(RelationKey(a, b), out var value) ? value : null;
        internal static bool ValidTime(double value, double minimum = 0) => !double.IsNaN(value) && !double.IsInfinity(value) && value >= minimum;
        internal static void CheckTime(double value) { if (!ValidTime(value)) throw new ArgumentOutOfRangeException(nameof(value)); }
        public WorldFactionSiteData AddSite(int site, int faction, int guard, bool isTown, int reserve)
        {
            if (site < 1 || faction < 1 || guard < 1 || reserve < 0 || siteIndex.ContainsKey(site)) throw new ArgumentException("Invalid faction settlement.");
            var value = new WorldFactionSiteData { SiteId = site, FactionId = faction, GuardPartyId = guard, IsTown = isTown };
            value.AddReserve(reserve); sites.Add(value); siteIndex.Add(site, value); Revision++; return value;
        }
        public WorldFactionSiteData AddSite(int site, int faction, int guard, bool isTown) => AddSite(site, faction, guard, isTown, 0);
        public void SetRelation(int a, int b, int value, double minute, string reason)
        {
            CheckTime(minute);
            if (a < 1 || b < 1 || a == b || value < -100 || value > 100 || string.IsNullOrEmpty(reason) || reason.Length > 512)
                throw new ArgumentException("Invalid faction relation.");
            var row = FindRelation(a, b);
            if (row == null) { row = new WorldFactionRelationData { FactionA = Math.Min(a, b), FactionB = Math.Max(a, b) }; relations.Add(row); relationIndex.Add(RelationKey(a, b), row); }
            else if (minute < row.ChangedAt) throw new ArgumentOutOfRangeException(nameof(minute));
            row.Value = value; row.ChangedAt = minute; row.Reason = reason; Revision++;
        }
        public WorldFactionConflictData AddConflict(int site, int a, int b, double created, double minimumEnd, double expires, uint seed)
            =>AddConflictCore(site,a,b,created,minimumEnd,expires,seed,true);
        public WorldFactionConflictData AddAbstractConflict(int site,int a,int b,double created,double minimumEnd,double expires,uint seed)
            =>AddConflictCore(site,a,b,created,minimumEnd,expires,seed,false);
        private WorldFactionConflictData AddConflictCore(int site,int a,int b,double created,double minimumEnd,double expires,uint seed,bool materialized)
        {
            if (conflictIndex.ContainsKey(site) || conflicts.Any(c => c.Phase == "active" && (c.PartyA == a || c.PartyB == a || b > 0 && (c.PartyA == b || c.PartyB == b))))
                throw new InvalidOperationException("Party or battlefield already engaged.");
            var value = WorldFactionConflictData.Create(site, a, b, created, minimumEnd, expires, seed,materialized);
            conflicts.Add(value); conflictIndex.Add(site, value); Revision++; return value;
        }
        public void Complete() { Initialized = true; Revision++; }
        internal void Clear() { sites.Clear(); relations.Clear(); conflicts.Clear(); siteIndex.Clear(); relationIndex.Clear(); conflictIndex.Clear(); Initialized = false; Revision++; }
        internal void TakePrepared(WorldFactionsData source)
        {
            Clear(); sites.AddRange(source.sites); relations.AddRange(source.relations); conflicts.AddRange(source.conflicts);
            foreach (var site in sites) siteIndex.Add(site.SiteId, site);
            foreach (var relation in relations) relationIndex.Add(RelationKey(relation.FactionA, relation.FactionB), relation);
            foreach (var conflict in conflicts) conflictIndex.Add(conflict.SiteId, conflict);
            Initialized = source.Initialized; Revision++;
        }
        internal WorldFactionsSave Capture() => new WorldFactionsSave { initialized = Initialized,materializationVersion=1, sites = sites.Select(s => s.Capture()).ToArray(),
            relations = relations.Select(r => new WorldFactionRelationSave { a = r.FactionA, b = r.FactionB, value = r.Value, minute = r.ChangedAt, reason = r.Reason }).ToArray(),
            conflicts = conflicts.Select(c => c.Capture()).ToArray() };
        internal static WorldFactionsData Prepare(WorldFactionsSave saved, WorldPartiesData parties,EquipmentData equipment,HashSet<int> itemIds)
        {
            SaveCheck.Require(saved != null && saved.initialized && (saved.materializationVersion==0 || saved.materializationVersion==1), "缺少势力状态");
            var result = new WorldFactionsData();
            foreach (var row in SaveCheck.Rows(saved.sites, 10000, "势力据点"))
            {
                var site = WorldFactionSiteData.Prepare(row); var guard = parties.Find(site.GuardPartyId); var occupier = parties.Find(site.OccupierPartyId);
                SaveCheck.Require(!result.siteIndex.ContainsKey(site.SiteId) && guard != null && guard.FactionId == site.FactionId && guard.Role == "garrison" &&
                    (site.OccupierId == 0 || occupier != null && occupier.FactionId == site.OccupierId), "势力据点队伍引用");
                result.sites.Add(site); result.siteIndex.Add(site.SiteId, site);
            }
            foreach (var row in SaveCheck.Rows(saved.relations, 10000, "势力关系"))
            {
                SaveCheck.Require(row != null && row.a > 0 && row.b > row.a && row.value >= -100 && row.value <= 100 && ValidTime(row.minute) &&
                    !string.IsNullOrEmpty(row.reason) && row.reason.Length <= 512 && result.FindRelation(row.a, row.b) == null, "势力关系");
                result.SetRelation(row.a, row.b, row.value, row.minute, row.reason);
            }
            var engaged = new HashSet<int>();
            foreach (var row in SaveCheck.Rows(saved.conflicts, 10000, "势力战场"))
            {
                var conflict = WorldFactionConflictData.Prepare(row,saved.materializationVersion==0,equipment,itemIds); var a = parties.Find(conflict.PartyA); var b = parties.Find(conflict.PartyB);
                SaveCheck.Require(!result.conflictIndex.ContainsKey(conflict.SiteId) && a != null && (conflict.PartyB == 0 || b != null) &&
                    (conflict.TargetSiteId == 0 || result.FindSite(conflict.TargetSiteId) != null), "势力战场引用");
                if (conflict.Phase == "active") SaveCheck.Require(engaged.Add(a.Id) && a.BattleSiteId == conflict.SiteId && !a.Defeated &&
                    (b == null || engaged.Add(b.Id) && b.BattleSiteId == conflict.SiteId && !b.Defeated), "进行中战场队伍归属");
                result.conflicts.Add(conflict); result.conflictIndex.Add(conflict.SiteId, conflict);
            }
            result.Initialized = true; return result;
        }
    }
    [Serializable] internal sealed class WorldFactionsSave { public bool initialized;public int materializationVersion; public WorldFactionSiteSave[] sites; public WorldFactionRelationSave[] relations; public WorldFactionConflictSave[] conflicts; }
    [Serializable] internal sealed class WorldFactionSiteSave { public int site, faction, guard, occupier, occupierParty, reserve, revision; public bool town; public double occupiedAt, liberatedAt, protectedUntil, recoveredAt; }
    [Serializable] internal sealed class WorldFactionRelationSave { public int a, b, value; public double minute; public string reason; }
    [Serializable] internal sealed class WorldFactionConflictSave { public int site, a, b, target, winner; public double created, nextTick, minimumEnd, expires; public string phase; public bool engaged,materialized; public uint random;public ContainerSave[] pendingCargo; }
}
