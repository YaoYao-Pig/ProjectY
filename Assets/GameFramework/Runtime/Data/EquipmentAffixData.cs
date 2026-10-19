using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    /// <summary>Reflection bridge; an affix belongs to the physical equipment instance.</summary>
    public static class EquipmentAffixData
    {
        public static int Of(object item)
        {
            if (item is EquipmentWeaponData weapon) return weapon.AffixId;
            if (item is EquipmentWearableData wearable) return wearable.AffixId;
            if (item is LootItemData loot)
            {
                if (loot.StoredWeapon != null) return loot.StoredWeapon.AffixId;
                if (loot.StoredWearable != null) return loot.StoredWearable.AffixId;
            }
            throw new ArgumentException("Item has no physical equipment affix.");
        }
        public static void Define(EquipmentData data, int itemId, int[] ids, int[] weights)
            => data.DefineAffixes(itemId, ids, weights);
        public static void PrepareLoot(EquipmentData data, MapAreaLootData container)
            => data.PrepareAffixLoot(container);
    }

    public sealed partial class EquipmentData
    {
        private sealed class AffixPool
        {
            internal readonly int[] Ids, Weights;
            internal readonly int Total;
            internal AffixPool(int[] ids, int[] weights)
            {
                if (ids == null || weights == null || ids.Length == 0 || ids.Length != weights.Length)
                    throw new ArgumentException("Invalid equipment affix pool.");
                var unique = new HashSet<int>();
                for (int i = 0; i < ids.Length; i++)
                {
                    if (ids[i] < 1 || weights[i] < 0 || !unique.Add(ids[i])) throw new ArgumentException("Invalid affix ID/weight.");
                    Total = checked(Total + weights[i]);
                }
                if (Total == 0) throw new ArgumentException("Affix pool has no positive weights.");
                Ids = (int[])ids.Clone(); Weights = (int[])weights.Clone();
            }
            internal int Roll(uint seed, int instanceId, int itemId)
            {
                uint value;
                unchecked
                {
                    value = seed ^ (uint)instanceId * 0x9e3779b9u ^ (uint)itemId * 0x85ebca6bu;
                    value ^= value >> 16; value *= 0x7feb352du;
                    value ^= value >> 15; value *= 0x846ca68bu; value ^= value >> 16;
                }
                int roll = (int)(value % (uint)Total);
                for (int i = 0; i < Ids.Length; i++) { roll -= Weights[i]; if (roll < 0) return Ids[i]; }
                throw new InvalidOperationException("Invalid affix weight total.");
            }
        }
        private readonly Dictionary<int, AffixPool> affixPools = new Dictionary<int, AffixPool>();
        internal uint AffixSeed;
        internal void DefineAffixes(int itemId, int[] ids, int[] weights)
        {
            if (itemId < 1 || affixPools.ContainsKey(itemId)) throw new ArgumentException("Invalid or repeated equipment affix definition.");
            affixPools.Add(itemId, new AffixPool(ids, weights));
        }
        private int RollAffix(int itemId, int instanceId)
        {
            if (!affixPools.TryGetValue(itemId, out var pool)) throw new InvalidOperationException("Missing equipment affix pool: " + itemId);
            return pool.Roll(AffixSeed, instanceId, itemId);
        }
        private EquipmentWeaponData CreateWeapon(int itemId)
        {
            int affix = RollAffix(itemId, nextId);
            return new EquipmentWeaponData(nextId++, itemId) { AffixId = affix };
        }
        private EquipmentWearableData CreateWearable(int itemId)
        {
            int affix = RollAffix(itemId, nextId);
            return new EquipmentWearableData(nextId++, itemId) { AffixId = affix };
        }
        internal void PrepareAffixLoot(MapAreaLootData container)
        {
            if (container.SearchItems == null) throw new InvalidOperationException("Prepare the loot grid before its equipment.");
            foreach (var item in container.SearchItems)
            {
                if (item.Count == 0) continue;
                if (item.Kind == "weapon" && item.StoredWeapon == null) item.StoredWeapon = CreateWeapon(item.ItemId);
                else if (item.Kind == "wearable" && item.StoredWearable == null) item.StoredWearable = CreateWearable(item.ItemId);
            }
        }
    }
}
