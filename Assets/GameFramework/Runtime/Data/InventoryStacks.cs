using System;

namespace ProjectY.Data
{
    /// <summary>Reflection bridge for stable loose-item pile identities.</summary>
    public static class InventoryStacks
    {
        public static string Key(InventoryStackData row)
        {
            if(row==null) throw new ArgumentNullException(nameof(row));
            return row.Key;
        }
    }

    public sealed partial class EquipmentData
    {
        private static bool IsLooseItemKind(string kind)
            => kind=="stack" || kind=="rune" || kind=="ammo" || kind=="module" || kind=="material" || kind=="consumable";

        private InventoryStackData CanonicalStack(int itemId)
            => stacks.Find(row=>row.ItemId==itemId && row.PileId==0);

        // Canonical first, then the lowest independent pile ID, including after a save reload.
        private InventoryStackData LiveStack(int itemId)
        {
            InventoryStackData selected=null;
            foreach(var row in stacks)
                if(row.ItemId==itemId && row.Count>0 && (selected==null || row.PileId<selected.PileId)) selected=row;
            return selected;
        }

        private InventoryStackData StackByKey(string key)
        {
            if(string.IsNullOrEmpty(key) || key.Length<2 || (key[0]!='s' && key[0]!='p') ||
                !int.TryParse(key.Substring(1),out int id) || id<1 || key!=key[0].ToString()+id) return null;
            return key[0]=='s'?CanonicalStack(id):stacks.Find(row=>row.PileId==id);
        }

        private void ValidateStackPlacement(InventoryStackData row)
        {
            var place=Grid.Find(row.Key);
            if(row.Count<1 || row.PileId<0 || place==null || place.ItemId!=row.ItemId)
                throw new InvalidOperationException("Loose-item pile has no matching inventory placement: "+row.Key);
        }

        private void ValidateEmptyStackKey(string key)
        {
            if(Grid.Find(key)!=null) throw new InvalidOperationException("Inventory key is already occupied: "+key);
            var row=StackByKey(key);
            if(row!=null && row.Count!=0) throw new InvalidOperationException("Inventory key already owns a live pile: "+key);
        }

        private int CheckedItemTotal(int itemId,int amount) => checked(CountItem(itemId)+amount);

        private void RemoveEmptyPile(InventoryStackData row)
        {
            if(row.Count==0 && row.PileId>0) stacks.Remove(row);
        }

        private InventoryStackData StackAt(int itemId,int x,int y,string ignoredKey=null)
        {
            for(int i=0;i<Grid.Count;i++)
            {
                var place=Grid.GetAt(i);
                if(place.Key==ignoredKey || place.ItemId!=itemId || x<place.X || y<place.Y ||
                    x>=place.X+place.Width || y>=place.Y+place.Height) continue;
                var row=StackByKey(place.Key);
                if(row==null) return null;
                ValidateStackPlacement(row);return row;
            }
            return null;
        }

        internal void ValidateStackConsumption(int itemId,int count)
        {
            if(itemId<1 || count<1) throw new ArgumentOutOfRangeException(nameof(count));
            if(CountItem(itemId)<count) throw new InvalidOperationException("Loose items are unavailable in the shared inventory.");
            foreach(var row in stacks) if(row.ItemId==itemId && row.Count>0) ValidateStackPlacement(row);
        }

        // Callers may validate a whole transaction first. This helper never changes Revision.
        internal void ConsumeStackRows(int itemId,int count)
        {
            ValidateStackConsumption(itemId,count);
            int remaining=count;
            while(remaining>0)
            {
                var row=LiveStack(itemId);
                int used=Math.Min(remaining,row.Count);row.Count-=used;remaining-=used;
                if(row.Count==0) {Grid.Remove(row.Key);RemoveEmptyPile(row);}
            }
        }
    }
}
