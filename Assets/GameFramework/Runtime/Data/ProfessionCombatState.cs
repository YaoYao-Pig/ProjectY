using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    // Encounter-only counters belong to the authoritative actor/battle, never a Lua cache.
    public sealed partial class CombatActorData
    {
        internal readonly Dictionary<string,int> ProfessionMarks=new Dictionary<string,int>();
        internal void StopProfessionMovement(){Moved=true;}
        internal void RelocateProfession(int q,int r)
        {if(HP<=0)throw new InvalidOperationException("A defeated actor cannot relocate.");Q=q;R=r;Moved=true;MovementStyle="walk";MovementSequence++;}
    }
    public sealed class ProfessionTrapData
    {
        public int Q {get;internal set;}
        public int R {get;internal set;}
        public int SourceId {get;internal set;}
        public int EffectId {get;internal set;}
    }
    public static class ProfessionCombatState
    {
        public static int Mark(CombatActorData actor,string key)=>actor.ProfessionMarks.TryGetValue(key,out var value)?value:0;
        public static void SetMark(CombatActorData actor,string key,int value)
        {if(string.IsNullOrEmpty(key))throw new ArgumentException("Empty profession counter.");actor.ProfessionMarks[key]=value;}
        public static bool Once(CombatActorData actor,string key,int stamp)
        {if(stamp<1)throw new ArgumentOutOfRangeException(nameof(stamp));if(Mark(actor,key)==stamp)return false;SetMark(actor,key,stamp);return true;}
        public static void Clear(CombatActorData actor)=>actor.ProfessionMarks.Clear();
        public static void StopMovement(CombatActorData actor)=>actor.StopProfessionMovement();
        public static void Move(CombatActorData actor,int q,int r)
        {actor.RelocateProfession(q,r);}
        public static void AddUnit(BattleData battle,CombatActorData actor,int team,int q,int r)=>battle.AddUnit(actor,team,q,r);
        public static void SetLifetime(GameEffectInstanceData instance,int remaining)
        {if(remaining<1)throw new ArgumentOutOfRangeException(nameof(remaining));instance.Remaining=remaining;}
        public static GameEffectInstanceData Transfer(GameEffectCollectionData source,GameEffectCollectionData target,int instanceId,int maximumStacks)
        {
            GameEffectInstanceData current=null;
            for(int i=0;i<source.Count;i++)if(source.GetAt(i).Id==instanceId){current=source.GetAt(i);break;}
            if(current==null||maximumStacks<1||ReferenceEquals(source,target))throw new ArgumentException("Invalid status transfer.");
            var existing=target.Find(current.EffectId);
            int stacks=Math.Min(maximumStacks,current.Stacks+(existing?.Stacks??0));
            if(existing!=null)target.Remove(existing.Id);
            var result=target.Add(current.EffectId,current.SourceId,current.SourceName,current.Amount,current.Remaining);
            result.Elapsed=current.Elapsed;result.Stacks=stacks;
            GameBuffState.Configure(result,current.SnapshotIds,current.SnapshotAmounts,current.ExpiresAt,current.NextTickAt);
            source.Remove(current.Id);return result;
        }
        public static int TrapCount(BattleData battle)=>battle.ProfessionTraps.Count;
        public static ProfessionTrapData TrapAt(BattleData battle,int index)=>battle.ProfessionTraps[index];
        public static ProfessionTrapData Trap(BattleData battle,int q,int r)=>battle.ProfessionTraps.Find(x=>x.Q==q&&x.R==r);
        public static void PlaceTrap(BattleData battle,int q,int r,int sourceId,int effectId)
        {
            if(Trap(battle,q,r)!=null||sourceId<1||effectId<1)throw new ArgumentException("Invalid trap placement.");
            battle.ProfessionTraps.Add(new ProfessionTrapData{Q=q,R=r,SourceId=sourceId,EffectId=effectId});
        }
        public static void RemoveTrap(BattleData battle,int q,int r)
        {if(battle.ProfessionTraps.RemoveAll(x=>x.Q==q&&x.R==r)!=1)throw new ArgumentException("Missing trap.");}
        public static ConstructionRecord PlaceConstruction(ConstructionData data,int site,int cell,int skill,int hp,EquipmentData inventory,int[] ids,int[] counts,int ownerTeam)
        {
            if(ownerTeam<1||ownerTeam>64)throw new ArgumentOutOfRangeException(nameof(ownerTeam));
            var record=data.Place(site,cell,skill,hp,inventory,ids,counts);
            record.OwnerTeam=ownerTeam;record.PaidMaterialIds=(int[])ids.Clone();record.PaidMaterialCounts=(int[])counts.Clone();return record;
        }
        public static int ConstructionOwner(ConstructionRecord record)=>record.OwnerTeam;
        public static int ConstructionRefund(ConstructionRecord record,int itemId)
        {int index=Array.IndexOf(record.PaidMaterialIds,itemId);return index<0?0:record.PaidMaterialCounts[index]/2;}
        public static void Salvage(ConstructionData data,ConstructionRecord record,EquipmentData inventory,int itemId)
        {
            if(record.Removed||record.MaxHP<=0||record.OwnerTeam!=1)throw new InvalidOperationException("Invalid salvage target.");
            int count=ConstructionRefund(record,itemId);
            if(count>0)inventory.AddStack(itemId,count);
            data.Damage(record.SiteId,record.CellIndex,record.HP);
        }
    }
}
