using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    /// <summary>One physical item or loose-item stack, owned by its original map container.</summary>
    [LuaCallCSharp]
    public sealed class LootItemData
    {
        internal MapAreaLootData Container { get; }
        internal int SourceIndex { get; }
        public string Key { get; }
        public int ContainerId => Container.Id;
        public int ItemId { get; }
        public string Kind { get; }
        public int Count { get; internal set; }
        public bool Revealed { get; internal set; }
        public float Progress { get; internal set; }
        internal EquipmentWeaponData StoredWeapon;
        internal EquipmentMagazineData StoredMagazine,LoadedMagazine;
        internal EquipmentWearableData StoredWearable;
        internal bool IsStack => Kind!="weapon" && Kind!="magazine" && Kind!="wearable";
        internal void ReleaseStored() {StoredWeapon=null;StoredMagazine=LoadedMagazine=null;StoredWearable=null;}
        internal LootItemData(MapAreaLootData container,int index,int source,int itemId,int count,string kind)
        {Container=container;SourceIndex=source;Key="loot:"+container.Id+":"+index;ItemId=itemId;Count=count;Kind=kind;}
    }

    /// <summary>Visible search scope only. Closing releases the scope, never the container contents.</summary>
    [LuaCallCSharp]
    public sealed class LootSessionData
    {
        private readonly List<LootItemData> items=new List<LootItemData>();
        private readonly List<MapAreaLootData> containers=new List<MapAreaLootData>();
        public MapAreaStateData Area { get; private set; }
        public bool Active { get; private set; }
        public bool Pending { get; private set; }
        public bool Battle { get; private set; }
        public string Title { get; private set; }="";
        public string Summary { get; private set; }="";
        public int Revision { get; private set; }
        public int Count => items.Count;
        public int ContainerCount => containers.Count;
        public MapAreaLootData GetContainerAt(int index) => containers[index];
        public int SelectedContainerId { get; private set; }
        private MapAreaLootData Selected => containers.Find(container=>container.Id==SelectedContainerId);
        public InventoryGridData Grid => Selected?.SearchGrid;
        public int Remaining {get {int count=0;foreach(var item in items) if(item.Count>0) count++;return count;}}
        public LootItemData GetAt(int index) => items[index];
        public LootItemData Find(string key) {foreach(var item in items) if(item.Key==key) return item;return null;}
        public bool IsOpened(MapAreaLootData container) => container.Opened || container.Looted;
        public void Prepare(MapAreaLootData container,string[] kinds,int[] widths,int[] heights) => container.PrepareSearch(kinds,widths,heights);
        public void SelectContainer(int id)
        {
            if(!Active || id!=0 && !Contains(id))throw new ArgumentException("Container is not in this search session.");
            SelectedContainerId=id;Revision++;
        }
        public void Open(MapAreaStateData area,int[] ids,bool battle,string title,string summary)
        {
            if(area==null || ids==null || string.IsNullOrEmpty(title)) throw new ArgumentException("Invalid loot session.");
            Close();Area=area;Battle=battle;Title=title;Summary=summary;
            var unique=new HashSet<int>();
            foreach(int id in ids)
            {
                if(id<1 || id>area.LootCount || !unique.Add(id)) throw new ArgumentException("Invalid loot container.");
                var container=area.GetLootAt(id-1);
                if(!container.CanSearch || container.SearchItems==null) throw new InvalidOperationException("Loot is unavailable or not prepared.");
                container.Opened=true;containers.Add(container);items.AddRange(container.SearchItems);
                if(container.SearchItems.Length==0 && !container.Looted) area.Loot(id);
            }
            SelectedContainerId=containers.Count==1?containers[0].Id:0;
            Active=Pending=true;Revision++;
        }
        public void Present() {if(!Active) throw new InvalidOperationException("No loot session.");Pending=false;}
        public bool Contains(int containerId) => containers.Exists(row=>row.Id==containerId);
        public bool Advance(string key,float dt,float seconds)
        {
            if(dt<0 || float.IsNaN(dt) || float.IsInfinity(dt) || seconds<=0 || float.IsNaN(seconds) || float.IsInfinity(seconds))
                throw new ArgumentOutOfRangeException(nameof(dt));
            var item=Find(key);
            if(!Active || item==null || item.Count==0 || item.Revealed) return false;
            item.Progress=Math.Min(1,item.Progress+dt/seconds);
            if(item.Progress<1) return false;
            item.Revealed=true;Revision++;return true;
        }
        public bool Take(EquipmentData equipment,string key,int x,int y,bool rotated,int ammo,int capacity,int rounds)
        {
            var item=Find(key);
            if(!Active || item==null || item.Count==0 || !item.Revealed || item.Container.Looted) return false;
            if(!equipment.ReceiveLoot(item,x,y,rotated,ammo,capacity,rounds)) return false;
            item.Count=0;item.ReleaseStored();item.Container.SearchGrid.Remove(item.Key);Revision++;
            Area.UpdateLootContents(item.ContainerId);
            return true;
        }
        private static LootItemData MergeAt(MapAreaLootData container,LootItemData item,int x,int y)
        {
            if(!item.IsStack)return null;
            foreach(var other in container.SearchItems)
            {
                if(other==item || other.Count==0 || !other.Revealed || other.ItemId!=item.ItemId || !other.IsStack)continue;
                var place=container.SearchGrid.Find(other.Key);
                if(x>=place.X && y>=place.Y && x<place.X+place.Width && y<place.Y+place.Height)return other;
            }
            return null;
        }
        public bool Move(string key,int x,int y,bool rotated)
        {
            var item=Find(key);var container=Selected;
            if(!Active || container==null || item==null || item.Container!=container || item.Count==0 || !item.Revealed)return false;
            var merge=MergeAt(container,item,x,y);
            if(merge!=null)
            {
                int total=checked(merge.Count+item.Count);container.SearchGrid.Remove(item.Key);merge.Count=total;item.Count=0;
                Area.UpdateLootContents(container.Id);
            }
            else if(!container.SearchGrid.Move(key,x,y,rotated))return false;
            Revision++;return true;
        }
        public bool Put(EquipmentData equipment,string key,int x,int y,bool rotated)
        {
            var container=Selected;
            if(!Active || container==null || !container.CanSearch)return false;
            var item=equipment.PreviewLootDeposit(container,key);
            if(item==null)return false;
            var merge=MergeAt(container,item,x,y);
            if(merge!=null)
            {
                int total=checked(merge.Count+item.Count);equipment.CommitLootDeposit(key,item);merge.Count=total;
            }
            else
            {
                container.SearchGrid.CopyShape(equipment.Grid,item.ItemId);
                if(!container.SearchGrid.Insert(item.Key,item.ItemId,x,y,rotated))return false;
                equipment.CommitLootDeposit(key,item);container.AddSearchItem(item);items.Add(item);
            }
            Area.UpdateLootContents(container.Id);Revision++;return true;
        }
        public void Close()
        {Active=Pending=false;Area=null;SelectedContainerId=0;items.Clear();containers.Clear();Revision++;}
    }
}
