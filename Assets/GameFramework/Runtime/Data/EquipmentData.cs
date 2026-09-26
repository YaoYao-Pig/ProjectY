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
    public sealed class EquipmentWearableData
    {
        public int Id { get; }
        public int ItemId { get; }
        public int OwnerActorId { get; internal set; }
        public string Slot { get; internal set; } = "";
        internal EquipmentWearableData(int id, int itemId) { Id=id; ItemId=itemId; }
    }
    [LuaCallCSharp]
    public sealed class EquipmentWeaponData
    {
        private readonly Dictionary<int, int> runes = new Dictionary<int, int>();
        public int Id { get; }
        public int ItemId { get; }
        public int OwnerActorId { get; internal set; }
        public string Hand { get; internal set; } = "";
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
        private readonly List<EquipmentWearableData> wearables = new List<EquipmentWearableData>();
        public InventoryGridData Grid { get; } = new InventoryGridData();
        private int nextId = 1;
        public int Revision { get; private set; }
        public int StackCount => stacks.Count;
        public int WeaponCount => weapons.Count;
        public int MagazineCount => magazines.Count;
        public int WearableCount => wearables.Count;
        public EquipmentWearableData GetWearableAt(int index) => wearables[index];
        public EquipmentWearableData GetWearable(int id) => wearables.Find(x=>x.Id==id) ?? throw new ArgumentException("Unknown wearable: "+id);
        public EquipmentWearableData Worn(int actorId,string slot) => wearables.Find(x=>x.OwnerActorId==actorId && x.Slot==slot);
        public InventoryStackData GetStackAt(int index) => stacks[index];
        public EquipmentWeaponData GetWeaponAt(int index) => weapons[index];
        public EquipmentMagazineData GetMagazineAt(int index) => magazines[index];
        public EquipmentWeaponData GetWeapon(int id) => weapons.Find(x => x.Id == id) ?? throw new ArgumentException("Unknown weapon: " + id);
        public EquipmentMagazineData GetMagazine(int id) => magazines.Find(x => x.Id == id) ?? throw new ArgumentException("Unknown magazine: " + id);
        public EquipmentWeaponData Equipped(int actorId) => weapons.Find(x => x.OwnerActorId == actorId && x.Hand=="weapon");
        public EquipmentWeaponData Offhand(int actorId) => weapons.Find(x => x.OwnerActorId == actorId && x.Hand=="offhand");
        public int CountItem(int itemId) => stacks.Find(x => x.ItemId == itemId)?.Count ?? 0;
        public int MagazineWeapon(int id) => weapons.Find(x => x.MagazineId == id)?.Id ?? 0;
        public void Clear() { stacks.Clear(); weapons.Clear(); magazines.Clear(); wearables.Clear(); Grid.Clear(); nextId = 1; Revision++; }
        private void Reserve(string key,int itemId)
        {
            if(!Grid.Exchange(Array.Empty<string>(),new[]{key},new[]{itemId},true)) throw new InvalidOperationException("Inventory is full.");
        }
        private bool Exchange(string outgoing,string incoming,int itemId,bool commit=true)
        { return Grid.Exchange(outgoing==null?Array.Empty<string>():new[]{outgoing},incoming==null?Array.Empty<string>():new[]{incoming},incoming==null?Array.Empty<int>():new[]{itemId},commit); }
        public bool Move(string key,int x,int y,bool rotated)
        { if(!Grid.Move(key,x,y,rotated)) return false; Revision++; return true; }
        public bool ReturnToBag(string key,int actorId,int x,int y,bool rotated)
        {
            if(string.IsNullOrEmpty(key) || key.Length<2 || !int.TryParse(key.Substring(1),out int id)) return false;
            if(key[0]=='w')
            {
                var row=GetWeapon(id);
                if(row.OwnerActorId!=actorId || !Grid.Insert(key,row.ItemId,x,y,rotated)) return false;
                row.OwnerActorId=0;row.Hand="";
            }
            else if(key[0]=='g')
            {
                var row=GetWearable(id);
                if(row.OwnerActorId!=actorId || !Grid.Insert(key,row.ItemId,x,y,rotated)) return false;
                row.OwnerActorId=0;row.Slot="";
            }
            else return false;
            Revision++;return true;
        }
        public bool CanGrant(int[] itemIds,int[] counts,string[] kinds)
        {
            if(itemIds.Length!=counts.Length || counts.Length!=kinds.Length) throw new ArgumentException("Grant arrays differ.");
            var keys=new List<string>();var ids=new List<int>();var stacked=new HashSet<int>();
            for(int i=0;i<itemIds.Length;i++)
            {
                if(counts[i]<1) throw new ArgumentOutOfRangeException(nameof(counts));
                bool instance=kinds[i]=="weapon" || kinds[i]=="magazine" || kinds[i]=="wearable";
                if(!instance && (CountItem(itemIds[i])>0 || !stacked.Add(itemIds[i]))) continue;
                for(int j=0;j<(instance?counts[i]:1);j++) {keys.Add("grant:"+i+":"+j);ids.Add(itemIds[i]);}
            }
            return Grid.Exchange(Array.Empty<string>(),keys.ToArray(),ids.ToArray(),false);
        }
        public void AddStack(int itemId, int count)
        {
            if (itemId < 1 || count < 1) throw new ArgumentOutOfRangeException(nameof(count));
            var row = stacks.Find(x => x.ItemId == itemId);
            int total=checked((row?.Count ?? 0)+count);
            if(row==null || row.Count==0) Reserve("s"+itemId,itemId);
            if (row == null) { row = new InventoryStackData(itemId); stacks.Add(row); }
            row.Count = total; Revision++;
        }
        public EquipmentWeaponData AddWeapon(int itemId)
        {
            if (itemId < 1) throw new ArgumentOutOfRangeException(nameof(itemId));
            Reserve("w"+nextId,itemId);
            var row = new EquipmentWeaponData(nextId++, itemId); weapons.Add(row); Revision++; return row;
        }
        public EquipmentMagazineData AddMagazine(int item, int ammo, int capacity, int rounds)
        {
            if (item < 1 || ammo < 1 || capacity < 1 || rounds < 0 || rounds > capacity) throw new ArgumentException("Invalid magazine.");
            Reserve("m"+nextId,item);
            var row = new EquipmentMagazineData(nextId++, item, ammo, capacity, rounds); magazines.Add(row); Revision++; return row;
        }
        public EquipmentWearableData AddWearable(int itemId)
        {
            if(itemId<1) throw new ArgumentOutOfRangeException(nameof(itemId));
            Reserve("g"+nextId,itemId);
            var row=new EquipmentWearableData(nextId++,itemId);wearables.Add(row);Revision++;return row;
        }
        public bool Wear(int actorId,string slot,int wearableId)
        {
            if(actorId<1 || string.IsNullOrEmpty(slot)) throw new ArgumentException("Invalid equipment owner/slot.");
            var next=wearableId==0?null:GetWearable(wearableId);var old=Worn(actorId,slot);
            if(old==next) return true;
            var off=slot=="offhand"?Offhand(actorId):null;
            if(!Exchange(next==null?null:"g"+next.Id,old!=null?"g"+old.Id:off!=null?"w"+off.Id:null,old?.ItemId ?? off?.ItemId ?? 0)) return false;
            if(old!=null) {old.OwnerActorId=0;old.Slot="";}
            if(off!=null) {off.OwnerActorId=0;off.Hand="";}
            if(next!=null) {next.OwnerActorId=actorId;next.Slot=slot;}
            Revision++;return true;
        }
        public bool CanWear(int actorId,string slot,int wearableId)
        {
            var next=wearableId==0?null:GetWearable(wearableId);var old=Worn(actorId,slot);
            var off=slot=="offhand"?Offhand(actorId):null;
            return old==next || Exchange(next==null?null:"g"+next.Id,old!=null?"g"+old.Id:off!=null?"w"+off.Id:null,old?.ItemId ?? off?.ItemId ?? 0,false);
        }
        public bool CanEquipOffhand(int actorId,int weaponId) => SetOffhand(actorId,weaponId,false);
        public bool EquipOffhand(int actorId,int weaponId) => SetOffhand(actorId,weaponId,true);
        private bool SetOffhand(int actorId,int weaponId,bool commit)
        {
            if(actorId<1) throw new ArgumentOutOfRangeException(nameof(actorId));
            var next=weaponId==0?null:GetWeapon(weaponId);var old=Offhand(actorId);var shield=Worn(actorId,"offhand");
            if(old==next && shield==null) return true;
            if(!Exchange(next==null?null:"w"+next.Id,old!=null?"w"+old.Id:shield!=null?"g"+shield.Id:null,old?.ItemId ?? shield?.ItemId ?? 0,commit)) return false;
            if(!commit) return true;
            if(old!=null) {old.OwnerActorId=0;old.Hand="";}
            if(shield!=null) {shield.OwnerActorId=0;shield.Slot="";}
            if(next!=null) {next.OwnerActorId=actorId;next.Hand="offhand";}
            Revision++;return true;
        }
        public bool CanEquip(int actorId,int weaponId)
        {
            var next=weaponId==0?null:GetWeapon(weaponId);var old=Equipped(actorId);
            return old==next || Exchange(next==null?null:"w"+next.Id,old==null?null:"w"+old.Id,old?.ItemId ?? 0,false);
        }
        public bool Equip(int actorId, int weaponId)
        {
            if (actorId < 1) throw new ArgumentOutOfRangeException(nameof(actorId));
            var next = weaponId == 0 ? null : GetWeapon(weaponId);
            var old = Equipped(actorId);
            if (old == next) return true;
            if(!Exchange(next==null?null:"w"+next.Id,old==null?null:"w"+old.Id,old?.ItemId ?? 0)) return false;
            if (old != null) {old.OwnerActorId = 0;old.Hand="";}
            if (next != null) {next.OwnerActorId = actorId;next.Hand="weapon";}
            Revision++; return true;
        }
        public bool SetRune(int weaponId, int socketId, int itemId)
        {
            if (socketId < 1 || itemId < 0) throw new ArgumentOutOfRangeException(nameof(socketId));
            var weapon = GetWeapon(weaponId); var old = weapon.GetRune(socketId);
            if (old == itemId) return true;
            var next = itemId == 0 ? null : stacks.Find(x => x.ItemId == itemId);
            if (itemId != 0 && (next == null || next.Count == 0)) throw new InvalidOperationException("Rune is not in inventory.");
            var previous=old==0?null:stacks.Find(x=>x.ItemId==old);
            // Taking the last rune frees its rectangle before the old component is returned.
            if(!Exchange(next!=null && next.Count==1?"s"+itemId:null,old!=0 && (previous==null || previous.Count==0)?"s"+old:null,old)) return false;
            if(old!=0)
            {
                if(previous==null) {previous=new InventoryStackData(old);stacks.Add(previous);}
                previous.Count++;
            }
            if (next != null) next.Count--;
            weapon.SetRune(socketId, itemId); Revision++; return true;
        }
        public bool CanAttachMagazine(int weaponId,int magazineId)
        {
            var weapon=GetWeapon(weaponId);
            if(weapon.MagazineId==magazineId) return true;
            if(magazineId!=0) {GetMagazine(magazineId);if(MagazineWeapon(magazineId)!=0) return false;}
            return Grid.Exchange(magazineId==0?Array.Empty<string>():new[]{"m"+magazineId},weapon.MagazineId==0?Array.Empty<string>():new[]{"m"+weapon.MagazineId},weapon.MagazineId==0?Array.Empty<int>():new[]{GetMagazine(weapon.MagazineId).ItemId},false);
        }
        public bool AttachMagazine(int weaponId, int magazineId)
        {
            var weapon = GetWeapon(weaponId);
            if (magazineId != 0)
            {
                GetMagazine(magazineId);
                var owner = MagazineWeapon(magazineId);
                if (owner != 0 && owner != weaponId) throw new InvalidOperationException("Magazine is already loaded in another weapon.");
            }
            if(weapon.MagazineId==magazineId) return true;
            var old=weapon.MagazineId==0?null:GetMagazine(weapon.MagazineId);
            if(!Exchange(magazineId==0?null:"m"+magazineId,old==null?null:"m"+old.Id,old?.ItemId ?? 0)) return false;
            weapon.MagazineId = magazineId; Revision++; return true;
        }
        public int FillMagazine(int magazineId)
        {
            var magazine = GetMagazine(magazineId);
            var stock = stacks.Find(x => x.ItemId == magazine.AmmoItemId);
            var count = Math.Min(magazine.Capacity - magazine.Rounds, stock?.Count ?? 0);
            if (count < 1) throw new InvalidOperationException("Magazine is full or loose ammunition is unavailable.");
            magazine.Rounds += count; stock.Count -= count;
            if(stock.Count==0) Grid.Remove("s"+stock.ItemId);
            Revision++; return count;
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
