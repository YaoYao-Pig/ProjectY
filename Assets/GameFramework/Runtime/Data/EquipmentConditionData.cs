using System;

namespace ProjectY.Data
{
    /// <summary>Condition belongs to the physical item, including while it is in a map container.</summary>
    public sealed class EquipmentConditionData
    {
        public int Current { get; private set; } = 100;
        public int Maximum { get; private set; } = 100;
        public int BaseMaximum { get; private set; } = 100;
        public bool ThresholdArmed { get; private set; } = true;
        public bool Broken => Current == 0;
        public double Efficiency => Broken ? 0 : (Maximum + Current) / (2.0 * BaseMaximum);
        public static EquipmentConditionData Of(object item)
        {
            if (item is EquipmentWeaponData weapon) return weapon.Condition;
            if (item is EquipmentWearableData wearable) return wearable.Condition;
            if (item is LootItemData loot)
                return loot.StoredWeapon?.Condition ?? loot.StoredWearable?.Condition;
            throw new ArgumentException("Item has no equipment condition.");
        }
        public static EquipmentConditionData Restore(int current, int maximum, int baseMaximum, bool thresholdArmed)
        {
            if (baseMaximum != 100 || maximum < 20 || maximum > baseMaximum || maximum % 5 != 0 || current < 0 || current > maximum
                || thresholdArmed && current * 2 < maximum)
                throw new ArgumentException("Invalid saved equipment condition.");
            return new EquipmentConditionData { Current = current, Maximum = maximum, BaseMaximum = baseMaximum, ThresholdArmed = thresholdArmed };
        }
        internal int Damage(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            int before = Current;
            Current = Math.Max(0, Current - amount);
            if (ThresholdArmed && before * 2 >= Maximum && Current * 2 < Maximum)
            {
                Maximum = Math.Max(BaseMaximum / 5, Maximum - BaseMaximum / 20);
                Current = Math.Min(Current, Maximum); ThresholdArmed = false;
            }
            return before - Current;
        }
        internal void Repair() { Current = Maximum; ThresholdArmed = true; }
    }
}
