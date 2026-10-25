using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    /// <summary>Persistent restoration state for one town's stable dock identity.</summary>
    public sealed class WaterDockData
    {
        public int Id { get; }
        public bool Damaged { get; internal set; }
        public int ThreatRemaining { get; internal set; }
        public bool Accepted { get; internal set; }
        public bool Ready => !Damaged && ThreatRemaining == 0;
        internal WaterDockData(int id, bool damaged, int threat)
        { Id = id; Damaged = damaged; ThreatRemaining = threat; }
    }

    /// <summary>Expedition-owned docks, the owned boat and a paid passenger journey.</summary>
    public sealed class WaterTravelData
    {
        private const int MaximumDocks = 100000;
        private readonly List<WaterDockData> docks = new List<WaterDockData>();
        private readonly Dictionary<int, WaterDockData> byId = new Dictionary<int, WaterDockData>();
        public static WaterTravelData For(AdventureData adventure)
            => (adventure ?? throw new ArgumentNullException(nameof(adventure))).WaterTravel;
        public static WaterTravelData Prepared(PreparedCharacterSave prepared)
        {
            if (prepared == null) throw new ArgumentNullException(nameof(prepared));
            Require(!prepared.Consumed && prepared.Expedition?.preparedWater != null);
            return prepared.Expedition.preparedWater;
        }

        public int Count => docks.Count;
        public int Revision { get; private set; }
        public string Mode { get; private set; } = "walk";
        public bool Owned { get; private set; }
        public bool Aboard => Mode == "owned";
        public int BoatQ { get; private set; }
        public int BoatR { get; private set; }
        public int BoatDockId { get; private set; }
        public int FerryOriginDockId { get; private set; }
        public int FerryTargetDockId { get; private set; }
        public int FerryPaid { get; private set; }
        public int OpenDockId { get; private set; }
        public bool IsOpen => OpenDockId != 0;
        public WaterDockData GetDockAt(int index) => docks[index];
        public WaterDockData FindDock(int id) => byId.TryGetValue(id, out var dock) ? dock : null;
        public WaterDockData GetDock(int id)
        { var dock = FindDock(id); Require(dock != null); return dock; }
        public WaterDockData Get(int id) => GetDock(id);

        private static void Require(bool condition)
        { if (!condition) throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("WaterStateInvalid")); }
        private static void CheckSave(bool condition)
        { SaveCheck.Require(condition, ProjectY.UI.LuaLanguage.Get("WaterSaveInvalid")); }

        public void Reset()
        {
            docks.Clear(); byId.Clear(); Mode = "walk"; Owned = false;
            BoatQ = BoatR = BoatDockId = FerryOriginDockId = FerryTargetDockId = FerryPaid = OpenDockId = 0;
            Revision++;
        }
        public WaterDockData EnsureDock(int id, bool damaged, int threat)
        {
            Require(id > 0 && threat >= 0);
            var existing = FindDock(id);
            if (existing != null) return existing;
            Require(docks.Count < MaximumDocks);
            var dock = new WaterDockData(id, damaged, threat);
            docks.Add(dock); byId.Add(id, dock); Revision++; return dock;
        }
        public void Open(int dockId)
        {
            GetDock(dockId); Require(Mode == "walk");
            if (OpenDockId == dockId) return;
            OpenDockId = dockId; Revision++;
        }
        public void Close()
        { if (OpenDockId == 0) return; OpenDockId = 0; Revision++; }
        public void AcceptRepair(int dockId)
        {
            var dock = GetDock(dockId); Require(!dock.Ready);
            if (dock.Accepted) return;
            dock.Accepted = true; Revision++;
        }
        public void RecordKill(int dockId, int count)
        {
            var dock = GetDock(dockId); Require(count > 0 && dock.Accepted && dock.ThreatRemaining > 0);
            dock.ThreatRemaining = Math.Max(0, dock.ThreatRemaining - count);
            if (dock.Ready) dock.Accepted = false;
            Revision++;
        }
        private WaterDockData RepairableDock(int dockId)
        {
            var dock = GetDock(dockId);
            Require(dock.Accepted && dock.Damaged && dock.ThreatRemaining == 0);
            return dock;
        }
        private void RestoreDock(WaterDockData dock)
        { dock.Damaged = false; dock.Accepted = false; Revision++; }
        public void Repair(int dockId) => RestoreDock(RepairableDock(dockId));
        public bool CompleteRepair(EquipmentData equipment, int dockId, int itemId, int count)
        {
            if (equipment == null) throw new ArgumentNullException(nameof(equipment));
            var dock = RepairableDock(dockId); Require(itemId > 0 && count > 0);
            if (equipment.CountItem(itemId) < count) return false;
            // ConsumeStack validates all source piles before removing anything and does not publish callbacks.
            equipment.ConsumeStack(itemId, count); RestoreDock(dock); return true;
        }

        public bool Purchase(PlayerData player, int price, int dockId, int q, int r)
        {
            if (player == null) throw new ArgumentNullException(nameof(player));
            Require(price > 0 && Mode == "walk" && !Owned && GetDock(dockId).Ready);
            return player.TrySpendWaterTravel(price, () => {
                Owned = true; BoatQ = q; BoatR = r; BoatDockId = dockId; Revision++;
            });
        }
        public void Board(int q, int r)
        {
            Require(Mode == "walk" && Owned && BoatQ == q && BoatR == r);
            Mode = "owned"; BoatDockId = 0; OpenDockId = 0; Revision++;
        }
        /// <summary>The coordinates remain the boat's water cell; the caller validates and relocates the party to land.</summary>
        public void Land(int q, int r, int dockId)
        {
            Require(Mode == "owned" && Owned && BoatQ == q && BoatR == r && dockId >= 0);
            if (dockId > 0) Require(GetDock(dockId).Ready);
            Mode = "walk"; BoatDockId = dockId; Revision++;
        }
        public void SyncBoat(int q, int r)
        {
            Require(Mode == "owned" && Owned);
            if (BoatQ == q && BoatR == r) return;
            BoatQ = q; BoatR = r; Revision++;
        }
        public bool BeginFerry(PlayerData player, int price, int originDockId, int targetDockId)
        {
            if (player == null) throw new ArgumentNullException(nameof(player));
            Require(price > 0 && Mode == "walk" && originDockId != targetDockId &&
                GetDock(originDockId).Ready && GetDock(targetDockId).Ready);
            return player.TrySpendWaterTravel(price, () => {
                Mode = "ferry"; FerryOriginDockId = originDockId; FerryTargetDockId = targetDockId;
                FerryPaid = price; OpenDockId = 0; Revision++;
            });
        }
        public void FinishFerry()
        {
            Require(Mode == "ferry" && FerryOriginDockId > 0 && FerryTargetDockId > 0 && FerryPaid > 0);
            Mode = "walk"; FerryOriginDockId = FerryTargetDockId = FerryPaid = 0; Revision++;
        }

        internal WaterTravelSave Capture() => new WaterTravelSave {
            format = 1, mode = Mode, owned = Owned, boatQ = BoatQ, boatR = BoatR, boatDock = BoatDockId,
            ferryOrigin = FerryOriginDockId, ferryTarget = FerryTargetDockId, ferryPaid = FerryPaid,
            docks = docks.OrderBy(d => d.Id).Select(d => new WaterDockSave {
                id = d.Id, damaged = d.Damaged, threat = d.ThreatRemaining, accepted = d.Accepted }).ToArray() };
        internal static WaterTravelData Prepare(WaterTravelSave saved, WorldTravelData travel)
        {
            var result = new WaterTravelData();
            if (saved == null) return result; // Existing expeditions have no boat or dock restoration records.
            CheckSave(saved.format == 1 && (saved.mode == "walk" || saved.mode == "ferry" || saved.mode == "owned") &&
                saved.boatDock >= 0 && saved.ferryOrigin >= 0 && saved.ferryTarget >= 0 && saved.ferryPaid >= 0 &&
                saved.docks != null && saved.docks.Length <= MaximumDocks);
            foreach (var row in saved.docks)
            {
                CheckSave(row != null && row.id > 0 && row.threat >= 0 && !result.byId.ContainsKey(row.id) &&
                    (!row.accepted || row.damaged || row.threat > 0));
                var dock = new WaterDockData(row.id, row.damaged, row.threat) { Accepted = row.accepted };
                result.docks.Add(dock); result.byId.Add(dock.Id, dock);
            }
            CheckSave(saved.owned || saved.boatQ == 0 && saved.boatR == 0 && saved.boatDock == 0);
            CheckSave(saved.boatDock == 0 || result.FindDock(saved.boatDock)?.Ready == true);
            CheckSave(saved.mode != "owned" || saved.owned && saved.boatDock == 0 &&
                saved.boatQ == travel.Q && saved.boatR == travel.R);
            if (saved.mode == "ferry")
                CheckSave(saved.ferryPaid > 0 && saved.ferryOrigin != saved.ferryTarget &&
                    result.FindDock(saved.ferryOrigin)?.Ready == true && result.FindDock(saved.ferryTarget)?.Ready == true);
            else CheckSave(saved.ferryOrigin == 0 && saved.ferryTarget == 0 && saved.ferryPaid == 0);
            result.Mode = saved.mode; result.Owned = saved.owned; result.BoatQ = saved.boatQ; result.BoatR = saved.boatR;
            result.BoatDockId = saved.boatDock; result.FerryOriginDockId = saved.ferryOrigin;
            result.FerryTargetDockId = saved.ferryTarget; result.FerryPaid = saved.ferryPaid;
            return result;
        }
        internal void TakePrepared(WaterTravelData source)
        {
            docks.Clear(); byId.Clear();
            foreach (var row in source.docks)
            {
                var dock = new WaterDockData(row.Id, row.Damaged, row.ThreatRemaining) { Accepted = row.Accepted };
                docks.Add(dock); byId.Add(dock.Id, dock);
            }
            Mode = source.Mode; Owned = source.Owned; BoatQ = source.BoatQ; BoatR = source.BoatR;
            BoatDockId = source.BoatDockId; FerryOriginDockId = source.FerryOriginDockId;
            FerryTargetDockId = source.FerryTargetDockId; FerryPaid = source.FerryPaid; OpenDockId = 0; Revision++;
        }
    }
    [Serializable] internal sealed class WaterTravelSave
    {
        public int format, boatQ, boatR, boatDock, ferryOrigin, ferryTarget, ferryPaid;
        public string mode; public bool owned; public WaterDockSave[] docks;
    }
    [Serializable] internal sealed class WaterDockSave
    { public int id, threat; public bool damaged, accepted; }
    public sealed partial class AdventureData
    { internal WaterTravelData WaterTravel { get; } = new WaterTravelData(); }
    public sealed partial class PlayerData
    {
        internal bool TrySpendWaterTravel(int amount, Action commit)
        {
            if (amount <= 0 || commit == null) throw new ArgumentException(ProjectY.UI.LuaLanguage.Get("WaterStateInvalid"));
            if (Coins < amount) return false;
            Coins -= amount; commit(); Changed?.Invoke(); return true;
        }
    }
}
