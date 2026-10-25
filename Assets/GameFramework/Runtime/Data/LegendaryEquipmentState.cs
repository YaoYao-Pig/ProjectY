using System;

namespace ProjectY.Data
{
    public sealed partial class ConstructionData
    {
        internal void RelocateLegendary(ConstructionRecord record,int cell,int author)
        {
            if(record==null||record.Removed||record.MaxHP<=0||cell<1||author<1||record.OwnerActorId!=author
                ||!ReferenceEquals(At(record.SiteId,record.CellIndex),record)||At(record.SiteId,cell)!=null)
                throw new InvalidOperationException("Invalid legendary construction relocation.");
            active.Remove(Key(record.SiteId,record.CellIndex));record.CellIndex=cell;
            active.Add(Key(record.SiteId,cell),record);Revision++;
        }
    }

    // Reflection bridge; ownership survives saves, battle counters use ProfessionMarks.
    public static class LegendaryEquipmentState
    {
        public static void SetConstructionAuthor(ConstructionRecord record,int actorId)
        {if(record==null||actorId<1)throw new ArgumentException("Invalid construction author.");record.OwnerActorId=actorId;}
        public static int ConstructionAuthor(ConstructionRecord record)=>record.OwnerActorId;
        public static void MoveConstruction(ConstructionData data,ConstructionRecord record,int cell,int actorId)
            =>data.RelocateLegendary(record,cell,actorId);
    }
}
