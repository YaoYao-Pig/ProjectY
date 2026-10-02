using System;

namespace ProjectY.Data
{
    public sealed partial class EquipmentData
    {
        internal LootItemData PreviewLootDeposit(MapAreaLootData container,string key)
        {
            var place=Grid.Find(key);
            if(place==null || key.Length<2 || !int.TryParse(key.Substring(1),out int id))return null;
            string kind;
            switch(key[0]){case 'w':kind="weapon";break;case 'm':kind="magazine";break;case 'g':kind="wearable";break;case 's':kind="stack";break;default:return null;}
            int count=kind=="stack"?CountItem(place.ItemId):1;
            if(count<1)throw new InvalidOperationException("Empty item occupies an inventory cell.");
            var item=new LootItemData(container,container.SearchItems.Length,container.SourceIndexFor(place.ItemId),place.ItemId,count,kind){Revealed=true,Progress=1};
            if(kind=="weapon")
            {
                item.StoredWeapon=GetWeapon(id);
                if(item.StoredWeapon.OwnerActorId!=0)throw new InvalidOperationException("Equipped weapon occupies the backpack.");
                if(item.StoredWeapon.MagazineId!=0)item.LoadedMagazine=GetMagazine(item.StoredWeapon.MagazineId);
            }
            else if(kind=="magazine")
            {
                item.StoredMagazine=GetMagazine(id);
                if(MagazineWeapon(id)!=0)throw new InvalidOperationException("Loaded magazine occupies the backpack.");
            }
            else if(kind=="wearable")
            {
                item.StoredWearable=GetWearable(id);
                if(item.StoredWearable.OwnerActorId!=0)throw new InvalidOperationException("Worn item occupies the backpack.");
            }
            return item;
        }
        internal void CommitLootDeposit(string key,LootItemData item)
        {
            Grid.Remove(key);
            if(item.StoredWeapon!=null){weapons.Remove(item.StoredWeapon);if(item.LoadedMagazine!=null)magazines.Remove(item.LoadedMagazine);}
            else if(item.StoredMagazine!=null)magazines.Remove(item.StoredMagazine);
            else if(item.StoredWearable!=null)wearables.Remove(item.StoredWearable);
            else stacks.Find(row=>row.ItemId==item.ItemId).Count=0;
            Revision++;
        }
        private bool HasInstance(int id) => weapons.Exists(row=>row.Id==id) || magazines.Exists(row=>row.Id==id) || wearables.Exists(row=>row.Id==id);
        internal bool ReceiveLoot(LootItemData item,int x,int y,bool rotated,int ammo,int capacity,int rounds)
        {
            int id=item.StoredWeapon?.Id ?? item.StoredMagazine?.Id ?? item.StoredWearable?.Id ?? 0;
            if(id==0)return GrantAt(item.ItemId,item.Kind,item.Count,x,y,rotated,ammo,capacity,rounds);
            if(HasInstance(id) || item.LoadedMagazine!=null && HasInstance(item.LoadedMagazine.Id))
                throw new InvalidOperationException("Stored equipment instance already belongs to the backpack.");
            int next=Math.Max(nextId,checked(Math.Max(id,item.LoadedMagazine?.Id ?? 0)+1));
            string key=(item.StoredWeapon!=null?"w":item.StoredMagazine!=null?"m":"g")+id;
            if(!Grid.Insert(key,item.ItemId,x,y,rotated))return false;
            if(item.StoredWeapon!=null){weapons.Add(item.StoredWeapon);if(item.LoadedMagazine!=null)magazines.Add(item.LoadedMagazine);}
            else if(item.StoredMagazine!=null)magazines.Add(item.StoredMagazine);
            else wearables.Add(item.StoredWearable);
            nextId=next;Revision++;return true;
        }
        // Validate first, reserve exactly the requested rectangle, then create ownership.
        internal bool GrantAt(int itemId,string kind,int count,int x,int y,bool rotated,int ammo,int capacity,int rounds)
        {
            bool instance=kind=="weapon" || kind=="magazine" || kind=="wearable";
            if(itemId<1 || count<1 || (instance && count!=1)) throw new ArgumentException("Invalid loot transfer.");
            if(kind=="magazine" && (ammo<1 || capacity<1 || rounds<0 || rounds>capacity)) throw new ArgumentException("Invalid magazine loot.");
            var stack=instance?null:stacks.Find(row=>row.ItemId==itemId);
            int total=checked((stack?.Count ?? 0)+count);
            string key=instance?(kind=="weapon"?"w":kind=="magazine"?"m":"g")+nextId:"s"+itemId;
            var existing=Grid.Find(key);
            if(!instance && existing!=null)
            {
                if(x<existing.X || y<existing.Y || x>=existing.X+existing.Width || y>=existing.Y+existing.Height) return false;
            }
            else if(!Grid.Insert(key,itemId,x,y,rotated)) return false;
            if(kind=="weapon") weapons.Add(new EquipmentWeaponData(nextId++,itemId));
            else if(kind=="magazine") magazines.Add(new EquipmentMagazineData(nextId++,itemId,ammo,capacity,rounds));
            else if(kind=="wearable") wearables.Add(new EquipmentWearableData(nextId++,itemId));
            else
            {
                if(stack==null) {stack=new InventoryStackData(itemId);stacks.Add(stack);}
                stack.Count=total;
            }
            Revision++;return true;
        }
    }
}
