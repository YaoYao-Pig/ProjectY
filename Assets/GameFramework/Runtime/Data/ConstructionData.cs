using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class ConstructionRecord
    {
        public int Id { get; }
        public int SiteId { get; }
        public int CellIndex { get; }
        public int SkillId { get; }
        public int HP { get; internal set; }
        public int MaxHP { get; }
        public bool Removed { get; internal set; }
        internal ConstructionRecord(int id,int site,int cell,int skill,int hp)
        {Id=id;SiteId=site;CellIndex=cell;SkillId=skill;HP=MaxHP=hp;}
    }

    /// <summary>远征内的动态工事与挖掘结果。离开地点不清除，Lua 只保存本对象的引用。</summary>
    [LuaCallCSharp]
    public sealed class ConstructionData
    {
        private readonly List<ConstructionRecord> records=new List<ConstructionRecord>();
        private readonly Dictionary<long,ConstructionRecord> active=new Dictionary<long,ConstructionRecord>();
        public int Revision { get; private set; }
        public int Count => records.Count;
        public ConstructionRecord GetAt(int index) => records[index];
        private static long Key(int site,int cell) => ((long)site<<32)|(uint)cell;
        public ConstructionRecord At(int site,int cell)
        {active.TryGetValue(Key(site,cell),out var value);return value;}
        public ConstructionRecord Place(int site,int cell,int skill,int hp,EquipmentData inventory,int[] itemIds,int[] counts)
        {
            if(site<1||cell<1||skill<1||hp<0||inventory==null)throw new ArgumentException("Invalid construction.");
            if(At(site,cell)!=null)throw new InvalidOperationException("Cell already contains a construction.");
            // 校验所有材料后才统一扣除；失败不会占格、消耗一部分材料或更改版本。
            inventory.ConsumeMaterials(itemIds,counts);
            var record=new ConstructionRecord(records.Count+1,site,cell,skill,hp);
            records.Add(record);active.Add(Key(site,cell),record);Revision++;return record;
        }
        public int Damage(int site,int cell,int amount)
        {
            var record=At(site,cell);
            if(record==null||record.MaxHP==0||amount<1)throw new ArgumentException("Invalid construction damage.");
            int actual=Math.Min(record.HP,amount);record.HP-=actual;
            if(record.HP==0){record.Removed=true;active.Remove(Key(site,cell));}
            Revision++;return actual;
        }
        public void Clear(){records.Clear();active.Clear();Revision++;}
    }

    public sealed partial class EquipmentData
    {
        internal void ConsumeMaterials(int[] itemIds,int[] counts)
        {
            if(itemIds==null||counts==null||itemIds.Length!=counts.Length)throw new ArgumentException("Material arrays differ.");
            var seen=new HashSet<int>();
            for(int i=0;i<itemIds.Length;i++)
                if(itemIds[i]<1||counts[i]<1||!seen.Add(itemIds[i])||CountItem(itemIds[i])<counts[i]||Grid.Find("s"+itemIds[i])==null)
                    throw new InvalidOperationException("Required construction materials are unavailable.");
            for(int i=0;i<itemIds.Length;i++)
            {
                var stack=stacks.Find(row=>row.ItemId==itemIds[i]);stack.Count-=counts[i];
                if(stack.Count==0)Grid.Remove("s"+itemIds[i]);
            }
            if(itemIds.Length>0)Revision++;
        }
    }
}
