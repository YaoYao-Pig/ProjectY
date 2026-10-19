using System;

namespace ProjectY.Data
{
    public sealed partial class EquipmentData
    {
        internal LootItemData PreviewLootDeposit(MapAreaLootData container,string key)
        {
            var place=Grid.Find(key);
            if(place==null || key.Length<2 || !int.TryParse(key.Substring(1),out int id) || id<1 || key!=key[0].ToString()+id)return null;
            string kind;
            switch(key[0]){case 'w':kind="weapon";break;case 'm':kind="magazine";break;case 'g':kind="wearable";break;case 's':case 'p':kind="stack";break;default:return null;}
            var stack=kind=="stack"?StackByKey(key):null;
            if(kind=="stack")
            {
                if(stack==null) throw new InvalidOperationException("Inventory stack placement has no owner.");
                ValidateStackPlacement(stack);
            }
            int count=kind=="stack"?stack.Count:1;
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
            var place=Grid.Find(key);
            if(item==null || place==null || place.ItemId!=item.ItemId || item.Count<1)
                throw new InvalidOperationException("Loot deposit no longer matches the inventory.");
            InventoryStackData stack=null;
            if(item.StoredWeapon!=null)
            {
                if(key!="w"+item.StoredWeapon.Id || !weapons.Contains(item.StoredWeapon) || item.StoredWeapon.OwnerActorId!=0)
                    throw new InvalidOperationException("Deposited weapon is not in the backpack.");
            }
            else if(item.StoredMagazine!=null)
            {
                if(key!="m"+item.StoredMagazine.Id || !magazines.Contains(item.StoredMagazine) || MagazineWeapon(item.StoredMagazine.Id)!=0)
                    throw new InvalidOperationException("Deposited magazine is not in the backpack.");
            }
            else if(item.StoredWearable!=null)
            {
                if(key!="g"+item.StoredWearable.Id || !wearables.Contains(item.StoredWearable) || item.StoredWearable.OwnerActorId!=0)
                    throw new InvalidOperationException("Deposited wearable is not in the backpack.");
            }
            else
            {
                stack=StackByKey(key);
                if(stack==null || stack.ItemId!=item.ItemId || stack.Count!=item.Count)
                    throw new InvalidOperationException("Deposited pile changed before commit.");
                ValidateStackPlacement(stack);
            }
            Grid.Remove(key);
            if(item.StoredWeapon!=null){weapons.Remove(item.StoredWeapon);if(item.LoadedMagazine!=null)magazines.Remove(item.LoadedMagazine);}
            else if(item.StoredMagazine!=null)magazines.Remove(item.StoredMagazine);
            else if(item.StoredWearable!=null)wearables.Remove(item.StoredWearable);
            else {stack.Count=0;RemoveEmptyPile(stack);}
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
            if(!instance)
            {
                if(!IsLooseItemKind(kind)) throw new ArgumentException("Unknown loot item kind: "+kind);
                int total=CheckedItemTotal(itemId,count);
                var merge=StackAt(itemId,x,y);
                if(merge!=null)
                {
                    int merged=checked(merge.Count+count);merge.Count=merged;Revision++;return true;
                }
                bool canonical=total==count;
                var stack=canonical?CanonicalStack(itemId):null;
                int pileId=canonical?0:nextPileId;
                int next=canonical?nextPileId:checked(nextPileId+1);
                if(!canonical && (pileId<1 || stacks.Exists(row=>row.PileId==pileId)))
                    throw new InvalidOperationException("Duplicate independent inventory pile ID: "+pileId);
                string stackKey=canonical?"s"+itemId:"p"+pileId;
                ValidateEmptyStackKey(stackKey);
                var created=stack ?? new InventoryStackData(itemId){PileId=pileId};
                if(!Grid.Insert(stackKey,itemId,x,y,rotated)) return false;
                if(stack==null) stacks.Add(created);
                created.Count=count;nextPileId=next;Revision++;return true;
            }
            if(nextId<1 || HasInstance(nextId)) throw new InvalidOperationException("Duplicate equipment instance ID: "+nextId);
            int nextInstance=checked(nextId+1);
            string key=(kind=="weapon"?"w":kind=="magazine"?"m":"g")+nextId;
            // Resolve all construction/affix failures before reserving the requested cell.
            var weapon=kind=="weapon"?new EquipmentWeaponData(nextId,itemId){AffixId=RollAffix(itemId,nextId)}:null;
            var wearable=kind=="wearable"?new EquipmentWearableData(nextId,itemId){AffixId=RollAffix(itemId,nextId)}:null;
            var magazine=kind=="magazine"?new EquipmentMagazineData(nextId,itemId,ammo,capacity,rounds):null;
            if(!Grid.Insert(key,itemId,x,y,rotated)) return false;
            if(weapon!=null) weapons.Add(weapon);
            else if(wearable!=null) wearables.Add(wearable);
            else magazines.Add(magazine);
            nextId=nextInstance;
            Revision++;return true;
        }
    }
}
