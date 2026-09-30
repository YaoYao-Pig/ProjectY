using System;
using System.Collections.Generic;
using System.Linq;
using XLua;

namespace ProjectY.Data
{
    [Serializable] internal sealed class GameEffectSave
    { public int id,effectId,sourceId,amount,remaining,elapsed,stacks;public string sourceName; }

    [LuaCallCSharp]
    public sealed class GameEffectInstanceData
    {
        public int Id {get;internal set;}
        public int EffectId {get;internal set;}
        public int SourceId {get;internal set;}
        public string SourceName {get;internal set;}
        public int Amount {get;internal set;}
        public int Remaining {get;internal set;}
        public int Elapsed {get;internal set;}
        public int Stacks {get;internal set;}
    }

    /// <summary>Actor-owned active effect instances. Lua owns rules; these records own mutable counters.</summary>
    [LuaCallCSharp]
    public sealed class GameEffectCollectionData
    {
        private readonly List<GameEffectInstanceData> entries=new List<GameEffectInstanceData>();
        private int nextId=1;
        public int Count=>entries.Count;
        public int Revision {get;private set;}
        public GameEffectInstanceData GetAt(int index)=>entries[index];
        public GameEffectInstanceData Find(int effectId)=>entries.Find(e=>e.EffectId==effectId);
        public GameEffectInstanceData Add(int effectId,int sourceId,string sourceName,int amount,int duration)
        {
            Check(effectId,sourceId,sourceName,amount,duration);
            if(entries.Count>=256)throw new InvalidOperationException("Too many active effects on one actor.");
            var row=new GameEffectInstanceData{Id=nextId++,EffectId=effectId,SourceId=sourceId,SourceName=sourceName,Amount=amount,Remaining=duration,Stacks=1};
            entries.Add(row);Revision++;return row;
        }
        public void Refresh(int id,int sourceId,string sourceName,int amount,int duration,int maxStacks,bool stack)
        {
            var row=Require(id);Check(row.EffectId,sourceId,sourceName,amount,duration);
            if(maxStacks<1||maxStacks>100)throw new ArgumentOutOfRangeException(nameof(maxStacks));
            row.SourceId=sourceId;row.SourceName=sourceName;row.Amount=amount;row.Remaining=duration;row.Elapsed=0;
            row.Stacks=stack?Math.Min(maxStacks,row.Stacks+1):1;Revision++;
        }
        public void Advance(int id,int period)
        {
            if(period<0||period>1000000)throw new ArgumentOutOfRangeException(nameof(period));
            var row=Require(id);row.Elapsed=period>0?(row.Elapsed+1)%period:0;if(row.Remaining>0)row.Remaining--;Revision++;
        }
        public void Remove(int id){entries.Remove(Require(id));Revision++;}
        private GameEffectInstanceData Require(int id)=>entries.Find(e=>e.Id==id)??throw new ArgumentException("Unknown effect instance.");
        private static void Check(int effectId,int sourceId,string name,int amount,int duration)
        {
            if(effectId<1||sourceId<1||string.IsNullOrWhiteSpace(name)||name.Length>256||Math.Abs((long)amount)>1000000||(duration!=-1&&(duration<1||duration>1000000)))
                throw new ArgumentException("Invalid game effect instance.");
        }
        internal GameEffectSave[] Capture()=>entries.Select(e=>new GameEffectSave{id=e.Id,effectId=e.EffectId,sourceId=e.SourceId,sourceName=e.SourceName,
            amount=e.Amount,remaining=e.Remaining,elapsed=e.Elapsed,stacks=e.Stacks}).ToArray();
        internal void Restore(GameEffectSave[] saved)
        {
            foreach(var e in SaveCheck.Rows(saved,256,"持续效果"))
            {
                SaveCheck.Require(e!=null&&e.id>0&&e.id<int.MaxValue&&e.elapsed>=0&&e.elapsed<=1000000&&e.stacks>0&&e.stacks<=100&&!entries.Any(x=>x.Id==e.id),"持续效果身份/计时/层数");
                Check(e.effectId,e.sourceId,e.sourceName,e.amount,e.remaining);
                entries.Add(new GameEffectInstanceData{Id=e.id,EffectId=e.effectId,SourceId=e.sourceId,SourceName=e.sourceName,Amount=e.amount,Remaining=e.remaining,Elapsed=e.elapsed,Stacks=e.stacks});
                nextId=Math.Max(nextId,e.id+1);
            }
            Revision++;
        }
    }
    public sealed partial class CombatActorData
    {
        public GameEffectCollectionData Effects {get;}=new GameEffectCollectionData();
    }
}
