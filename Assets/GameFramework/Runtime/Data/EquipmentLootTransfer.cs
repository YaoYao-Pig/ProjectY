using System;

namespace ProjectY.Data
{
    public sealed partial class EquipmentData
    {
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
