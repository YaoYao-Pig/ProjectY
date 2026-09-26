using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class InventoryPlacementData
    {
        public string Key { get; }
        public int ItemId { get; }
        public int X { get; }
        public int Y { get; }
        public int Width { get; }
        public int Height { get; }
        public bool Rotated { get; }
        internal InventoryPlacementData(string key, int itemId, int x, int y, int width, int height, bool rotated)
        { Key=key; ItemId=itemId; X=x; Y=y; Width=width; Height=height; Rotated=rotated; }
    }

    /// <summary>Authoritative placement state. Exchanges are planned on a copy and committed atomically.</summary>
    [LuaCallCSharp]
    public sealed class InventoryGridData
    {
        private readonly Dictionary<int, int[]> shapes = new Dictionary<int, int[]>();
        private List<InventoryPlacementData> placements = new List<InventoryPlacementData>();
        public int Width { get; private set; }
        public int Height { get; private set; }
        public int Count => placements.Count;
        public InventoryPlacementData GetAt(int index) => placements[index];
        public InventoryPlacementData Find(string key) => placements.Find(p => p.Key == key);
        public void Configure(int width, int height)
        {
            if(width<1 || height<1 || placements.Count!=0) throw new InvalidOperationException("Configure an empty inventory with positive dimensions.");
            Width=width; Height=height;
        }
        public void Define(int itemId, int width, int height)
        {
            if(itemId<1 || width<1 || height<1) throw new ArgumentOutOfRangeException(nameof(itemId));
            shapes[itemId]=new[]{width,height};
        }
        internal void Clear() => placements.Clear();
        private InventoryPlacementData Placement(string key, int itemId, int x, int y, bool rotated)
        {
            var shape=shapes[itemId];
            return new InventoryPlacementData(key,itemId,x,y,shape[rotated?1:0],shape[rotated?0:1],rotated);
        }
        private bool Fits(List<InventoryPlacementData> rows, InventoryPlacementData p)
        {
            if(p.X<0 || p.Y<0 || p.X+p.Width>Width || p.Y+p.Height>Height) return false;
            foreach(var other in rows)
                if(other.Key!=p.Key && p.X<other.X+other.Width && p.X+p.Width>other.X && p.Y<other.Y+other.Height && p.Y+p.Height>other.Y) return false;
            return true;
        }
        public bool CanMove(string key, int x, int y, bool rotated)
        { var old=Find(key); return old!=null && Fits(placements,Placement(key,old.ItemId,x,y,rotated)); }
        internal bool Move(string key, int x, int y, bool rotated)
        {
            if(!CanMove(key,x,y,rotated)) return false;
            var index=placements.FindIndex(p=>p.Key==key); var old=placements[index];
            placements[index]=Placement(key,old.ItemId,x,y,rotated); return true;
        }
        internal void Remove(string key) => placements.RemoveAll(p=>p.Key==key);
        internal bool Insert(string key,int itemId,int x,int y,bool rotated)
        {
            if(Find(key)!=null) throw new InvalidOperationException("Item is already in the bag.");
            var row=Placement(key,itemId,x,y,rotated);
            if(!Fits(placements,row)) return false;
            placements.Add(row);return true;
        }
        private InventoryPlacementData AutoPlace(List<InventoryPlacementData> rows, string key, int itemId, InventoryPlacementData preferred)
        {
            for(int rotation=0;rotation<2;rotation++)
            {
                var rotated=rotation==0 ? preferred!=null && preferred.Rotated : preferred==null || !preferred.Rotated;
                if(preferred!=null)
                { var exact=Placement(key,itemId,preferred.X,preferred.Y,rotated); if(Fits(rows,exact)) return exact; }
                for(int y=0;y<Height;y++) for(int x=0;x<Width;x++)
                { var candidate=Placement(key,itemId,x,y,rotated); if(Fits(rows,candidate)) return candidate; }
            }
            return null;
        }
        // A dry run uses exactly the same deterministic placement order as a commit.
        internal bool Exchange(string[] remove, string[] addKeys, int[] itemIds, bool commit)
        {
            if(addKeys.Length!=itemIds.Length) throw new ArgumentException("Inventory exchange arrays differ.");
            var next=new List<InventoryPlacementData>(placements);
            InventoryPlacementData preferred=null;
            foreach(var key in remove)
            { var row=next.Find(p=>p.Key==key); if(row!=null && preferred==null) preferred=row; next.RemoveAll(p=>p.Key==key); }
            for(int i=0;i<addKeys.Length;i++)
            {
                if(next.Exists(p=>p.Key==addKeys[i])) throw new InvalidOperationException("Duplicate inventory key: "+addKeys[i]);
                var row=AutoPlace(next,addKeys[i],itemIds[i],preferred);
                if(row==null) return false;
                next.Add(row); preferred=null;
            }
            if(commit) placements=next;
            return true;
        }
    }
}
