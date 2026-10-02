using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class MapObstacleRecord
    {
        private readonly int[] cells, itemIds, counts;
        public int Id { get; }
        public int RuleId { get; }
        public bool BlocksMovement { get; }
        public bool Cleared { get; internal set; }
        public int Attempts { get; internal set; }
        public int CellCount => cells.Length;
        public int ItemCount => itemIds.Length;
        public int GetCellAt(int index) => cells[index];
        public int GetItemAt(int index) => itemIds[index];
        public int GetCountAt(int index) => counts[index];
        internal bool Contains(int index) => Array.IndexOf(cells,index)>=0;
        internal MapObstacleRecord(int id,int rule,bool blocks,int[] occupied,int[] items,int[] amounts)
        {
            if(rule<1||occupied==null||occupied.Length==0||items==null||amounts==null||items.Length!=amounts.Length)
                throw new ArgumentException("Invalid obstacle definition.");
            var unique=new HashSet<int>();foreach(var cell in occupied)if(cell<1||!unique.Add(cell))throw new ArgumentException("Invalid obstacle cells.");
            for(int i=0;i<items.Length;i++)if(items[i]<1||amounts[i]<1)throw new ArgumentException("Invalid obstacle reward.");
            Id=id;RuleId=rule;BlocksMovement=blocks;cells=(int[])occupied.Clone();itemIds=(int[])items.Clone();counts=(int[])amounts.Clone();
        }
    }
    /// <summary>一次远征的临时障碍状态；静态地图保持只读，离开地点不清除记录。</summary>
    [LuaCallCSharp]
    public sealed class MapObstacleData
    {
        private readonly Dictionary<int,List<MapObstacleRecord>> sites=new Dictionary<int,List<MapObstacleRecord>>();
        private readonly HashSet<int> initialized=new HashSet<int>();
        public int CurrentSiteId { get; private set; }
        public int CurrentId { get; private set; }
        public int RequestedId { get; private set; }
        public int Exert(CombatActorData actor,int amount) => actor.ApplyExertion(amount);
        public bool IsInitialized(int site) => initialized.Contains(site);
        public int Count(int site) => sites.ContainsKey(site)?sites[site].Count:0;
        public MapObstacleRecord Get(int site,int id) => sites[site][id-1];
        public void Add(int site,int rule,bool blocks,int[] cells,int[] items,int[] counts)
        {
            if(site<1||initialized.Contains(site))throw new InvalidOperationException("Obstacle site is already initialized.");
            if(!sites.TryGetValue(site,out var rows))sites.Add(site,rows=new List<MapObstacleRecord>());
            foreach(var cell in cells)if(rows.Exists(row=>row.Contains(cell)))throw new InvalidOperationException("Obstacles overlap.");
            rows.Add(new MapObstacleRecord(rows.Count+1,rule,blocks,cells,items,counts));
        }
        public void CompleteInitialization(int site) { if(!initialized.Add(site))throw new InvalidOperationException("Duplicate obstacle initialization."); }
        public int AtCell(int site,int cell)
        {
            if(sites.TryGetValue(site,out var rows))foreach(var row in rows)if(!row.Cleared&&row.Contains(cell))return row.Id;
            return 0;
        }
        public bool IsBlocked(int site,int cell)
        {var id=AtCell(site,cell);return id!=0&&Get(site,id).BlocksMovement;}
        public void Request(int site,int id)
        {if(Get(site,id).Cleared)throw new InvalidOperationException("Obstacle already cleared.");CurrentSiteId=site;RequestedId=id;CurrentId=0;}
        public void Begin(int site,int id) {Request(site,id);CurrentId=id;RequestedId=0;}
        public void Resolve(bool success)
        {if(CurrentId==0)throw new InvalidOperationException("No obstacle interaction.");var row=Get(CurrentSiteId,CurrentId);row.Attempts++;row.Cleared=success;Cancel();}
        public void Cancel() {CurrentSiteId=0;CurrentId=0;RequestedId=0;}
        public void Clear() {sites.Clear();initialized.Clear();Cancel();}
    }
}
