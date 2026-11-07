using System;

namespace ProjectY.Data
{
    /// <summary>Reflection-only bridge: reforge the same item through the camp's existing cost transaction.</summary>
    public static class EquipmentForgeState
    {
        public static string Forge(AdventureData adventure, PlayerData player, int weaponId, int campRevision, int equipmentRevision,
            int facilityId, int requiredLevel, int coins, int[] items, int[] counts)
        {
            if (adventure == null || player == null) throw new ArgumentNullException(nameof(adventure));
            if (facilityId < 1 || requiredLevel < 1) throw new ArgumentException("Invalid forge facility requirement.");
            if (adventure.Phase != "map") return "ForgeMapRequired";
            return adventure.Camp.Forge(adventure, player, weaponId, campRevision, equipmentRevision, facilityId, requiredLevel, coins, items, counts);
        }
    }
    public sealed partial class CampData
    {
        internal string Forge(AdventureData adventure, PlayerData player, int weaponId, int campRevision, int equipmentRevision,
            int facilityId, int requiredLevel, int coins, int[] items, int[] counts)
        {
            string session = Session(campRevision);
            if (session != "") return session == "UICampText6" ? "ForgeCampClosed" : "ForgeStateChanged";
            var equipment = adventure.Equipment;
            if (equipment.Revision != equipmentRevision) return "ForgeStateChanged";
            if (GetLevel(facilityId) < requiredLevel) return "ForgeFacilityRequired";
            EquipmentWeaponData weapon = null;
            for (int i = 0; i < equipment.WeaponCount; i++) if (equipment.GetWeaponAt(i).Id == weaponId) { weapon = equipment.GetWeaponAt(i); break; }
            if (weapon == null) return "ForgeWeaponUnavailable";
            bool owned = weapon.OwnerActorId == 0 && weapon.Hand == "" && equipment.Grid.Find("w" + weapon.Id) != null;
            if (weapon.OwnerActorId != 0 && (weapon.Hand == "weapon" || weapon.Hand == "offhand"))
                for (int i = 0; i < adventure.PartyCount; i++) if (adventure.GetPartyAt(i).Id == weapon.OwnerActorId) { owned = true; break; }
            if (!owned) return "ForgeWeaponUnavailable";
            if (weapon.Legacy.Forged && weapon.Condition.Current == 100 && weapon.Condition.Maximum == 100) return "ForgeAlreadyWhole";
            string reason = Cost(coins, items, counts, equipment, player);
            if (reason != "") return reason == "CampInsufficientCoins" ? "ForgeInsufficientCoins" : "ForgeInsufficientMaterials";
            weapon.Legacy.CheckRevision();
            SpendMaterials(items, counts, equipment);
            equipment.Reforge(weapon); Revision++;
            // Publish the player notification only after equipment, legacy and camp revisions are committed.
            SpendCoins(player, coins); return "";
        }
    }
    public sealed partial class EquipmentData
    {
        internal void Reforge(EquipmentWeaponData weapon) { weapon.Legacy.MarkForged(); weapon.Condition.Reforge(); Revision++; }
    }
}
