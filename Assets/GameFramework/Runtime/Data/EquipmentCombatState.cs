using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    /// <summary>Reflection bridge for physical equipment operations shared by both combat teams.</summary>
    public static class EquipmentCombatState
    {
        public static bool IsInitialized(EquipmentData data, int actorId) => data.CombatInitialized(actorId);
        public static void Initialize(EquipmentData data, int actorId, int main, int off, int[] wearables, string[] slots)
            => data.InitializeCombatEquipment(actorId, main, off, wearables, slots);
        public static void RemoveActor(EquipmentData data, int actorId) => data.RemoveCombatEquipment(actorId);
        public static int DamageArmor(EquipmentData data, int actorId, int amount) => data.DamageCombatArmor(actorId, amount);
        public static int DamageWeapon(EquipmentData data, int weaponId, int amount) => data.DamageCombatWeapon(weaponId, amount);
        public static void RefreshMaximum(CombatActorData actor, int maximum) => actor.SetEquipmentMaximum(maximum);
        public static void DropWeapon(EquipmentData data, MapAreaStateData area, int containerId, int actorId, int weaponId)
            => data.DropCombatEquipment(area, containerId, actorId, weaponId, false);
        public static void DropActor(EquipmentData data, MapAreaStateData area, int containerId, int actorId)
            => data.DropCombatEquipment(area, containerId, actorId, 0, true);
        public static EquipmentWeaponData GroundWeapon(MapAreaLootData container)
        {
            if (container.SearchItems == null) return null;
            foreach (var item in container.SearchItems)
                if (item.Count > 0 && item.StoredWeapon != null && !item.StoredWeapon.Condition.Broken) return item.StoredWeapon;
            return null;
        }
        public static bool RecoverWeapon(EquipmentData data, MapAreaStateData area, int containerId, int actorId, int weaponId)
            => data.RecoverCombatWeapon(area, containerId, actorId, weaponId);
        public static int RepairMaterials(EquipmentConditionData condition) => (condition.Maximum - condition.Current + 24) / 25;
        public static int RepairCoins(EquipmentConditionData condition) => condition.Maximum - condition.Current;
        public static bool Repair(EquipmentData data, PlayerData player, string key, int materialId) => data.RepairEquipment(player, key, materialId);
    }

    public sealed partial class CombatActorData
    {
        internal void SetEquipmentMaximum(int maximum)
        { int hp = HP; SetMaxHP(maximum); HP = Math.Min(hp, HP); }
    }

    public sealed partial class EquipmentData
    {
        private readonly HashSet<int> combatOwners = new HashSet<int>();
        internal bool CombatInitialized(int actorId) => combatOwners.Contains(actorId);
        internal void InitializeCombatEquipment(int actorId, int main, int off, int[] items, string[] slots)
        {
            if (actorId < 1 || main < 0 || off < 0 || items == null || slots == null || items.Length != slots.Length)
                throw new ArgumentException("Invalid combat equipment loadout.");
            if (combatOwners.Contains(actorId)) throw new InvalidOperationException("Combat equipment was already initialized.");
            if (weapons.Exists(w => w.OwnerActorId == actorId) || wearables.Exists(w => w.OwnerActorId == actorId))
                throw new InvalidOperationException("Combat owner already has equipment.");
            var occupied = new HashSet<string>();
            foreach (var slot in slots) if (string.IsNullOrEmpty(slot) || !occupied.Add(slot) || slot == "offhand" && off != 0)
                throw new ArgumentException("Overlapping combat wearable slots.");
            foreach (int item in items) if (item < 1) throw new ArgumentException("Invalid combat wearable.");
            if (main != 0) { var item = CreateWeapon(main); item.OwnerActorId = actorId; item.Hand = "weapon"; weapons.Add(item); }
            if (off != 0) { var item = CreateWeapon(off); item.OwnerActorId = actorId; item.Hand = "offhand"; weapons.Add(item); }
            for (int i = 0; i < items.Length; i++) { var item = CreateWearable(items[i]); item.OwnerActorId = actorId; item.Slot = slots[i]; wearables.Add(item); }
            combatOwners.Add(actorId); Revision++;
        }
        internal void RemoveCombatEquipment(int actorId)
        {
            if (!combatOwners.Remove(actorId)) return;
            var loaded = weapons.Where(w => w.OwnerActorId == actorId && w.MagazineId != 0).Select(w => w.MagazineId).ToArray();
            weapons.RemoveAll(w => w.OwnerActorId == actorId); wearables.RemoveAll(w => w.OwnerActorId == actorId);
            magazines.RemoveAll(m => loaded.Contains(m.Id)); Revision++;
        }
        internal int DamageCombatArmor(int actorId, int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            int total = 0;
            foreach (var item in wearables) if (item.OwnerActorId == actorId && (item.Slot == "body" || item.Slot == "head" || item.Slot == "offhand"))
                total += item.Condition.Damage(amount);
            if (total > 0) Revision++;
            return total;
        }
        internal int DamageCombatWeapon(int id, int amount)
        { int changed = GetWeapon(id).Condition.Damage(amount); if (changed > 0) Revision++; return changed; }
        internal void DropCombatEquipment(MapAreaStateData area, int containerId, int actorId, int weaponId, bool all)
        {
            var container = area.GetLootAt(containerId - 1);
            if (container.SearchItems == null) throw new InvalidOperationException("Prepare the destination loot grid first.");
            var selectedWeapons = weapons.Where(w => w.OwnerActorId == actorId && (all || w.Id == weaponId)).ToArray();
            var selectedWearables = all ? wearables.Where(w => w.OwnerActorId == actorId).ToArray() : Array.Empty<EquipmentWearableData>();
            if (!all && selectedWeapons.Length != 1) throw new InvalidOperationException("The disarmed weapon is no longer equipped.");
            var pending = new List<LootItemData>();
            foreach (var weapon in selectedWeapons)
                pending.Add(new LootItemData(container, container.SearchItems.Length + pending.Count, 0, weapon.ItemId, 1, "weapon")
                { StoredWeapon = weapon, LoadedMagazine = weapon.MagazineId == 0 ? null : GetMagazine(weapon.MagazineId) });
            foreach (var wearable in selectedWearables)
                pending.Add(new LootItemData(container, container.SearchItems.Length + pending.Count, 0, wearable.ItemId, 1, "wearable") { StoredWearable = wearable });
            // Corpses receive their full loadout in one plan. A newly generated drop may grow, unlike a player storage deposit.
            InventoryGridData planned = null;
            for (int height = container.SearchGrid.Height; height <= 1024; height *= 2)
            {
                var candidate = new InventoryGridData(); Grid.CopyDefinitionsTo(candidate); candidate.Configure(container.SearchGrid.Width, height);
                for (int i = 0; i < container.SearchGrid.Count; i++)
                {
                    var position = container.SearchGrid.GetAt(i);
                    if (!candidate.Insert(position.Key, position.ItemId, position.X, position.Y, position.Rotated)) throw new InvalidOperationException("Existing drop placement is invalid.");
                }
                if (candidate.Exchange(Array.Empty<string>(), pending.Select(x => x.Key).ToArray(), pending.Select(x => x.ItemId).ToArray(), true)) { planned = candidate; break; }
            }
            if (planned == null) throw new InvalidOperationException("Physical equipment exceeds its drop container.");
            planned.CopyDefinitionsTo(container.SearchGrid); container.SearchGrid.TakePlacements(planned);
            foreach (var item in pending)
            {
                var entry = new LootItemData(container, container.SearchItems.Length, container.SourceIndexFor(item.ItemId), item.ItemId, 1, item.Kind)
                { StoredWeapon = item.StoredWeapon, StoredWearable = item.StoredWearable, LoadedMagazine = item.LoadedMagazine };
                if (entry.StoredWeapon != null) { entry.StoredWeapon.OwnerActorId = 0; entry.StoredWeapon.Hand = ""; weapons.Remove(entry.StoredWeapon); if (entry.LoadedMagazine != null) magazines.Remove(entry.LoadedMagazine); }
                else { entry.StoredWearable.OwnerActorId = 0; entry.StoredWearable.Slot = ""; wearables.Remove(entry.StoredWearable); }
                container.AddSearchItem(entry);
            }
            area.UpdateLootContents(containerId); if (pending.Count > 0) Revision++;
        }
        internal bool RecoverCombatWeapon(MapAreaStateData area, int containerId, int actorId, int weaponId)
        {
            if (Equipped(actorId) != null) return false;
            var container = area.GetLootAt(containerId - 1);
            var entry = container.SearchItems?.FirstOrDefault(x => x.Count > 0 && x.StoredWeapon?.Id == weaponId);
            if (entry == null || entry.StoredWeapon.Condition.Broken) return false;
            if (HasInstance(weaponId) || entry.LoadedMagazine != null && HasInstance(entry.LoadedMagazine.Id)) throw new InvalidOperationException("Ground equipment already has an inventory owner.");
            var weapon = entry.StoredWeapon; weapon.OwnerActorId = actorId; weapon.Hand = "weapon";
            weapons.Add(weapon); if (entry.LoadedMagazine != null) magazines.Add(entry.LoadedMagazine);
            nextId = Math.Max(nextId, checked(Math.Max(weapon.Id, entry.LoadedMagazine?.Id ?? 0) + 1));
            entry.Count = 0; entry.ReleaseStored(); container.SearchGrid.Remove(entry.Key); area.UpdateLootContents(containerId); Revision++;
            return true;
        }
        internal bool RepairEquipment(PlayerData player, string key, int materialId)
        {
            if (key == null || key.Length < 2 || !int.TryParse(key.Substring(1), out int id)) return false;
            var condition = key[0] == 'w' ? GetWeapon(id).Condition : key[0] == 'g' ? GetWearable(id).Condition : null;
            if (condition == null || condition.Current == condition.Maximum) return false;
            int materials = EquipmentCombatState.RepairMaterials(condition), coins = EquipmentCombatState.RepairCoins(condition);
            if (CountItem(materialId) < materials || player.Coins < coins) return false;
            ValidateStackConsumption(materialId,materials);
            // Every possible failure is checked before the first write; all three resources commit together.
            ConsumeStack(materialId, materials); condition.Repair(); Revision++;
            if (!player.TrySpendCoins(coins)) throw new InvalidOperationException("Repair coin budget changed during commit.");
            return true;
        }
    }
}
