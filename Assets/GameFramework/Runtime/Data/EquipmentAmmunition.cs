using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    /// <summary>Reflection bridge for homogeneous magazine loads and atomic ammunition exchanges.</summary>
    public static class EquipmentAmmunition
    {
        public static void Define(EquipmentData data, int itemId, int caliberId) => data.DefineAmmunition(itemId, caliberId);
        public static string Refill(EquipmentData data, int magazineId, int ammoItemId) => data.RefillAmmunition(magazineId, ammoItemId);
    }

    public sealed partial class EquipmentData
    {
        private readonly Dictionary<int, int> ammoCalibers = new Dictionary<int, int>();

        internal void DefineAmmunition(int itemId, int caliberId)
        {
            if (itemId < 1 || caliberId < 1 || ammoCalibers.ContainsKey(itemId))
                throw new ArgumentException("Invalid or repeated ammunition definition.");
            ammoCalibers.Add(itemId, caliberId);
        }

        internal string RefillAmmunition(int magazineId, int ammoItemId)
        {
            var magazine = GetMagazine(magazineId);
            if (!ammoCalibers.TryGetValue(magazine.AmmoItemId, out int caliber))
                throw new InvalidOperationException("Magazine ammunition has no caliber definition.");
            if (!ammoCalibers.TryGetValue(ammoItemId, out int incomingCaliber) || incomingCaliber != caliber)
                return "AmmoIncompatible";

            bool switching = magazine.AmmoItemId != ammoItemId;
            int space = switching ? magazine.Capacity : magazine.Capacity - magazine.Rounds;
            if (space == 0) return "AmmoMagazineFull";
            int count = Math.Min(space, CountItem(ammoItemId));
            if (count == 0) return "AmmoUnavailable";
            ValidateStackConsumption(ammoItemId, count);

            int returned = switching ? magazine.Rounds : 0;
            if (returned > 0)
            {
                if ((long)CountItem(magazine.AmmoItemId) + returned > int.MaxValue) return "AmmoCountLimit";
                var oldStack = LiveStack(magazine.AmmoItemId);
                if (oldStack != null) ValidateStackPlacement(oldStack);
                else
                {
                    string incomingKey = "s" + magazine.AmmoItemId;
                    ValidateEmptyStackKey(incomingKey);
                    var released = new List<string>();
                    int remaining = count;
                    foreach (var pile in stacks.Where(row => row.ItemId == ammoItemId && row.Count > 0).OrderBy(row => row.PileId))
                    {
                        int used = Math.Min(remaining, pile.Count);
                        if (used == pile.Count) released.Add(pile.Key);
                        remaining -= used;
                        if (remaining == 0) break;
                    }
                    if (!Grid.Exchange(released.ToArray(), new[] { incomingKey }, new[] { magazine.AmmoItemId }, false))
                        return "AmmoReturnBackpackFull";
                }
            }

            int previousAmmo = magazine.AmmoItemId;
            int rounds = switching ? count : checked(magazine.Rounds + count);
            ConsumeStackRows(ammoItemId, count);
            if (returned > 0) AddStack(previousAmmo, returned);
            magazine.AmmoItemId = ammoItemId;
            magazine.Rounds = rounds;
            Revision++;
            return "";
        }
    }
}
