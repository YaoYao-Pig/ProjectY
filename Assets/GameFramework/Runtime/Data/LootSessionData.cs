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
        public int Remaining {get {int count=0;foreach(var item in items) if(item.Count>0) count++;return count;}}
        public LootItemData GetAt(int index) => items[index];
        public LootItemData Find(string key) {foreach(var item in items) if(item.Key==key) return item;return null;}
        public bool IsOpened(MapAreaLootData container) => container.Opened || container.Looted;
        public void Prepare(MapAreaLootData container,string[] kinds) => container.PrepareSearch(kinds);
        public void Open(MapAreaStateData area,int[] ids,bool battle,string title,string summary)
        {
            if(area==null || ids==null || string.IsNullOrEmpty(title)) throw new ArgumentException("Invalid loot session.");
            Close();Area=area;Battle=battle;Title=title;Summary=summary;
            var unique=new HashSet<int>();
            foreach(int id in ids)
            {
                if(id<1 || id>area.LootCount || !unique.Add(id)) throw new ArgumentException("Invalid loot container.");
                var container=area.GetLootAt(id-1);
                if(container.Looted || !container.CanSearch || container.SearchItems==null) throw new InvalidOperationException("Loot is unavailable or not prepared.");
                container.Opened=true;containers.Add(container);items.AddRange(container.SearchItems);
                if(container.SearchItems.Length==0) area.Loot(id);
            }
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
            if(!equipment.GrantAt(item.ItemId,item.Kind,item.Count,x,y,rotated,ammo,capacity,rounds)) return false;
            item.Count=0;Revision++;
            bool empty=true;
            foreach(var remaining in item.Container.SearchItems) if(remaining.Count>0) {empty=false;break;}
            if(empty) Area.Loot(item.ContainerId);
            return true;
        }
        public void Close()
        {Active=Pending=false;Area=null;items.Clear();containers.Clear();Revision++;}
    }
}
