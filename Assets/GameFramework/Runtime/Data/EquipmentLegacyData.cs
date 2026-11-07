using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    public sealed class EquipmentDeedData
    {
        public int RuleId { get; internal set; }
        public int ActorId { get; internal set; }
        public int TargetId { get; internal set; }
        public int SiteId { get; internal set; }
        public double Minutes { get; internal set; }
    }

    /// <summary>The history and personality belong to the physical weapon, wherever it is stored.</summary>
    public sealed class EquipmentLegacyData
    {
        private const int MaximumDeeds = 10000;
        private readonly List<EquipmentDeedData> deeds = new List<EquipmentDeedData>();
        public static EquipmentLegacyData Of(EquipmentWeaponData weapon) => (weapon ?? throw new ArgumentNullException(nameof(weapon))).Legacy;
        public bool Forged { get; private set; }
        public int PathId { get; private set; }
        public bool Awakened { get; private set; }
        public int WishState { get; private set; }
        public int Revision { get; private set; }
        public int DeedCount => deeds.Count;
        public EquipmentDeedData GetDeedAt(int index) => deeds[index];
        private static bool ValidTime(double value) => !double.IsNaN(value) && !double.IsInfinity(value) && value >= 0 && value <= 1000000000;
        internal void CheckRevision() { if (Revision == int.MaxValue) throw new InvalidOperationException("Equipment legacy revision exhausted."); }
        internal void MarkForged() { CheckRevision(); Forged = true; Revision++; }
        public bool RecordDeed(int ruleId, int actorId, int targetId, int siteId, double minutes)
        {
            if (ruleId < 1 || actorId < 1 || targetId < 1 || siteId < 0 || !ValidTime(minutes)) throw new ArgumentException("Invalid equipment deed.");
            if (!Forged || deeds.Any(row => row.RuleId == ruleId && row.TargetId == targetId)) return false;
            if (deeds.Count == MaximumDeeds || deeds.Count > 0 && minutes < deeds[deeds.Count - 1].Minutes)
                throw new InvalidOperationException("Equipment deeds exceed their count or chronological limits.");
            CheckRevision();
            deeds.Add(new EquipmentDeedData { RuleId = ruleId, ActorId = actorId, TargetId = targetId, SiteId = siteId, Minutes = minutes });
            Revision++; return true;
        }
        public bool ChoosePath(int pathId, int requiredDeedId)
        {
            if (pathId < 1 || requiredDeedId < 1) throw new ArgumentOutOfRangeException(nameof(pathId));
            if (!Forged || PathId != 0 || !deeds.Any(row => row.RuleId == requiredDeedId)) return false;
            CheckRevision(); PathId = pathId; Revision++; return true;
        }
        public bool Awaken()
        {
            if (PathId == 0 || Awakened) return false;
            CheckRevision(); Awakened = true; Revision++; return true;
        }
        public bool AcceptWish()
        {
            if (!Awakened || WishState != 0) return false;
            CheckRevision(); WishState = 1; Revision++; return true;
        }
        public bool FulfillWish()
        {
            if (WishState != 1) return false;
            CheckRevision(); WishState = 2; Revision++; return true;
        }
        internal EquipmentLegacySave Capture() => new EquipmentLegacySave {
            format = 1, forged = Forged, pathId = PathId, awakened = Awakened, wishState = WishState, revision = Revision,
            deeds = deeds.Select(row => new EquipmentDeedSave { ruleId = row.RuleId, actorId = row.ActorId, targetId = row.TargetId, siteId = row.SiteId, minutes = row.Minutes }).ToArray() };
        private static void Check(bool valid) { if (!valid) SaveCheck.Require(false, ProjectY.UI.LuaLanguage.Get("ForgeSaveInvalid")); }
        internal static EquipmentLegacyData Prepare(EquipmentLegacySave row)
        {
            Check(row != null && row.format == 1 && row.pathId >= 0 && row.wishState >= 0 && row.wishState <= 2 && row.revision >= 0 && row.deeds != null && row.deeds.Length <= MaximumDeeds);
            Check((row.forged || row.pathId == 0 && !row.awakened && row.wishState == 0 && row.deeds.Length == 0 && row.revision == 0)
                && (!row.awakened || row.pathId > 0) && (row.wishState == 0 || row.awakened) && (row.pathId == 0 || row.deeds.Length > 0));
            int minimumRevision = row.deeds.Length + (row.forged ? 1 : 0) + (row.pathId > 0 ? 1 : 0) + (row.awakened ? 1 : 0) + row.wishState;
            Check(row.revision >= minimumRevision);
            var result = new EquipmentLegacyData { Forged = row.forged, PathId = row.pathId, Awakened = row.awakened, WishState = row.wishState, Revision = row.revision };
            var unique = new HashSet<(int, int)>(); double previous = 0;
            foreach (var deed in row.deeds)
            {
                Check(deed != null && deed.ruleId > 0 && deed.actorId > 0 && deed.targetId > 0 && deed.siteId >= 0 && ValidTime(deed.minutes)
                    && deed.minutes >= previous && unique.Add((deed.ruleId, deed.targetId)));
                result.deeds.Add(new EquipmentDeedData { RuleId = deed.ruleId, ActorId = deed.actorId, TargetId = deed.targetId, SiteId = deed.siteId, Minutes = deed.minutes });
                previous = deed.minutes;
            }
            return result;
        }
        internal static void MigrateAndValidate(CharacterSaveDocument document)
        {
            double now = document.narrative?.minutes ?? 0;
            foreach (var weapon in AllWeapons(document))
            {
                if (document.version < 27) weapon.legacy = new EquipmentLegacyData().Capture();
                var legacy = Prepare(weapon.legacy);
                Check(legacy.deeds.All(deed => deed.Minutes <= now));
            }
        }
        private static IEnumerable<WeaponSave> ContainerWeapons(ContainerSave container)
        {
            if (container?.search == null) yield break;
            foreach (var item in container.search) if (item?.weapon != null && item.weapon.id != 0) yield return item.weapon;
        }
        private static IEnumerable<WeaponSave> AllWeapons(CharacterSaveDocument document)
        {
            if (document.equipment?.weapons != null) foreach (var weapon in document.equipment.weapons) if (weapon != null) yield return weapon;
            var expedition = document.expedition;
            if (expedition?.areas != null) foreach (var area in expedition.areas)
                if (area?.loot != null) foreach (var container in area.loot) foreach (var weapon in ContainerWeapons(container)) yield return weapon;
            if (expedition?.parties?.parties != null) foreach (var party in expedition.parties.parties)
                if (party != null) foreach (var weapon in ContainerWeapons(party.cargo)) yield return weapon;
            if (expedition?.parties?.factions?.conflicts != null) foreach (var conflict in expedition.parties.factions.conflicts)
                if (conflict?.pendingCargo != null) foreach (var container in conflict.pendingCargo) foreach (var weapon in ContainerWeapons(container)) yield return weapon;
        }
    }
    [Serializable] internal sealed class EquipmentDeedSave { public int ruleId, actorId, targetId, siteId; public double minutes; }
    [Serializable] internal sealed class EquipmentLegacySave
    { public int format, pathId, wishState, revision; public bool forged, awakened; public EquipmentDeedSave[] deeds; }

    public sealed class EquipmentLegacyBattleEntry
    {
        public EquipmentWeaponData Weapon { get; internal set; }
        public CombatActorData Actor { get; internal set; }
        public CombatActorData Target { get; internal set; }
        public int LegendaryTargetId { get; internal set; }
        public bool WishEligible { get; internal set; }
    }
    /// <summary>Transient damage evidence retains physical item references until battle settlement.</summary>
    public sealed class EquipmentLegacyBattleData
    {
        private readonly List<EquipmentLegacyBattleEntry> entries = new List<EquipmentLegacyBattleEntry>();
        private readonly HashSet<CombatActorData> defeated = new HashSet<CombatActorData>();
        private readonly HashSet<EquipmentWeaponData> wishWeapons = new HashSet<EquipmentWeaponData>();
        public static EquipmentLegacyBattleData For(AdventureData adventure) => (adventure ?? throw new ArgumentNullException(nameof(adventure))).LegacyBattle;
        public bool Active { get; private set; }
        public int Count => entries.Count;
        public EquipmentLegacyBattleEntry GetAt(int index) => entries[index];
        public void Begin() { Reset(); Active = true; }
        public void Reset() { entries.Clear(); defeated.Clear(); wishWeapons.Clear(); Active = false; }
        public void AdmitWish(EquipmentWeaponData weapon)
        {
            if (weapon == null) throw new ArgumentNullException(nameof(weapon));
            if (Active && weapon.Legacy.WishState == 1) wishWeapons.Add(weapon);
        }
        public bool IsWishEligible(EquipmentWeaponData weapon) => weapon != null && wishWeapons.Contains(weapon);
        public bool Record(EquipmentWeaponData weapon, CombatActorData actor, CombatActorData target, int legendaryTargetId, bool wishEligible)
        {
            if (weapon == null || actor == null || target == null || legendaryTargetId < 0) throw new ArgumentException("Invalid equipment battle evidence.");
            if (!Active || entries.Any(row => ReferenceEquals(row.Weapon, weapon) && ReferenceEquals(row.Actor, actor) && ReferenceEquals(row.Target, target))) return false;
            entries.Add(new EquipmentLegacyBattleEntry { Weapon = weapon, Actor = actor, Target = target, LegendaryTargetId = legendaryTargetId, WishEligible = wishEligible }); return true;
        }
        public void MarkDefeated(CombatActorData target)
        {
            if (target == null) throw new ArgumentNullException(nameof(target));
            if (Active && !DeathDoorState.Alive(target)) defeated.Add(target);
        }
        public bool WasDefeated(CombatActorData target) => target != null && defeated.Contains(target);
        public bool Finish() { if (!Active) return false; Active = false; return true; }
    }
    public sealed partial class AdventureData { internal EquipmentLegacyBattleData LegacyBattle { get; } = new EquipmentLegacyBattleData(); }
}
