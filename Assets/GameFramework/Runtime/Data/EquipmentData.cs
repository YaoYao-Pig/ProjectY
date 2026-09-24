using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class InventoryStackData
    {
        public int ItemId { get; }
        public int Count { get; internal set; }
        internal InventoryStackData(int itemId) { ItemId = itemId; }
    }
    [LuaCallCSharp]
    public sealed class EquipmentWeaponData
    {
        private readonly Dictionary<int, int> runes = new Dictionary<int, int>();
        public int Id { get; }
        public int ItemId { get; }
        public int OwnerActorId { get; internal set; }
        public int MagazineId { get; internal set; }
        internal EquipmentWeaponData(int id, int itemId) { Id = id; ItemId = itemId; }
        public int GetRune(int socketId) => runes.TryGetValue(socketId, out var id) ? id : 0;
        internal void SetRune(int socketId, int itemId) { if (itemId == 0) runes.Remove(socketId); else runes[socketId] = itemId; }
    }
    [LuaCallCSharp]
    public sealed class EquipmentMagazineData
    {
        public int Id { get; }
        public int ItemId { get; }
        public int AmmoItemId { get; }
        public int Capacity { get; }
        public int Rounds { get; internal set; }
        internal EquipmentMagazineData(int id, int item, int ammo, int capacity, int rounds)
        { Id = id; ItemId = item; AmmoItemId = ammo; Capacity = capacity; Rounds = rounds; }
    }
    /// <summary>Expedition-owned physical weapons, detachable magazines and shared loose items.</summary>
    [LuaCallCSharp]
    public sealed class EquipmentData
    {
        private readonly List<InventoryStackData> stacks = new List<InventoryStackData>();
        private readonly List<EquipmentWeaponData> weapons = new List<EquipmentWeaponData>();
        private readonly List<EquipmentMagazineData> magazines = new List<EquipmentMagazineData>();
        private int nextId = 1;
        public int Revision { get; private set; }
        public int StackCount => stacks.Count;
        public int WeaponCount => weapons.Count;
        public int MagazineCount => magazines.Count;
        public InventoryStackData GetStackAt(int index) => stacks[index];
        public EquipmentWeaponData GetWeaponAt(int index) => weapons[index];
        public EquipmentMagazineData GetMagazineAt(int index) => magazines[index];
        public EquipmentWeaponData GetWeapon(int id) => weapons.Find(x => x.Id == id) ?? throw new ArgumentException("Unknown weapon: " + id);
        public EquipmentMagazineData GetMagazine(int id) => magazines.Find(x => x.Id == id) ?? throw new ArgumentException("Unknown magazine: " + id);
        public EquipmentWeaponData Equipped(int actorId) => weapons.Find(x => x.OwnerActorId == actorId);
        public int CountItem(int itemId) => stacks.Find(x => x.ItemId == itemId)?.Count ?? 0;
        public int MagazineWeapon(int id) => weapons.Find(x => x.MagazineId == id)?.Id ?? 0;
        public void Clear() { stacks.Clear(); weapons.Clear(); magazines.Clear(); nextId = 1; Revision++; }
        public void AddStack(int itemId, int count)
        {
            if (itemId < 1 || count < 1) throw new ArgumentOutOfRangeException(nameof(count));
            var row = stacks.Find(x => x.ItemId == itemId);
            if (row == null) { row = new InventoryStackData(itemId); stacks.Add(row); }
            row.Count = checked(row.Count + count); Revision++;
        }
        public EquipmentWeaponData AddWeapon(int itemId)
        {
            if (itemId < 1) throw new ArgumentOutOfRangeException(nameof(itemId));
            var row = new EquipmentWeaponData(nextId++, itemId); weapons.Add(row); Revision++; return row;
        }
        public EquipmentMagazineData AddMagazine(int item, int ammo, int capacity, int rounds)
        {
            if (item < 1 || ammo < 1 || capacity < 1 || rounds < 0 || rounds > capacity) throw new ArgumentException("Invalid magazine.");
            var row = new EquipmentMagazineData(nextId++, item, ammo, capacity, rounds); magazines.Add(row); Revision++; return row;
        }
        public void Equip(int actorId, int weaponId)
        {
            if (actorId < 1) throw new ArgumentOutOfRangeException(nameof(actorId));
            var next = weaponId == 0 ? null : GetWeapon(weaponId);
            var old = Equipped(actorId);
            if (old == next) return;
            if (old != null) old.OwnerActorId = 0;
            if (next != null) next.OwnerActorId = actorId;
            Revision++;
        }
        public void SetRune(int weaponId, int socketId, int itemId)
        {
            if (socketId < 1 || itemId < 0) throw new ArgumentOutOfRangeException(nameof(socketId));
            var weapon = GetWeapon(weaponId); var old = weapon.GetRune(socketId);
            if (old == itemId) return;
            var next = itemId == 0 ? null : stacks.Find(x => x.ItemId == itemId);
            if (itemId != 0 && (next == null || next.Count == 0)) throw new InvalidOperationException("Rune is not in inventory.");
            if (old != 0) AddStack(old, 1);
            if (next != null) next.Count--;
            weapon.SetRune(socketId, itemId); Revision++;
        }
        public void AttachMagazine(int weaponId, int magazineId)
        {
            var weapon = GetWeapon(weaponId);
            if (magazineId != 0)
            {
                GetMagazine(magazineId);
                var owner = MagazineWeapon(magazineId);
                if (owner != 0 && owner != weaponId) throw new InvalidOperationException("Magazine is already loaded in another weapon.");
            }
            weapon.MagazineId = magazineId; Revision++;
        }
        public int FillMagazine(int magazineId)
        {
            var magazine = GetMagazine(magazineId);
            var stock = stacks.Find(x => x.ItemId == magazine.AmmoItemId);
            var count = Math.Min(magazine.Capacity - magazine.Rounds, stock?.Count ?? 0);
            if (count < 1) throw new InvalidOperationException("Magazine is full or loose ammunition is unavailable.");
            magazine.Rounds += count; stock.Count -= count; Revision++; return count;
        }
        public void SpendAmmo(int weaponId, int count)
        {
            if (count < 1) throw new ArgumentOutOfRangeException(nameof(count));
            var magazine = GetMagazine(GetWeapon(weaponId).MagazineId);
            if (magazine.Rounds < count) throw new InvalidOperationException("Not enough loaded ammunition.");
            magazine.Rounds -= count; Revision++;
        }
    }
}
