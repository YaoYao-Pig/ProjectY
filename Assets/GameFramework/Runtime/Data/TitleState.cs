using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace ProjectY.Data
{
    [Serializable] internal sealed class TitleCounterSave { public string key; public int value; }
    [Serializable] internal sealed class TitleEffectSave { public int id, rank; }
    [Serializable] internal sealed class CustomTitleSave
    { public int id, cost; public string name; public TitleEffectSave[] effects; }
    [Serializable] internal sealed class TitleSave
    {
        public int format, equipped;
        public int[] owned = Array.Empty<int>();
        public TitleCounterSave[] counters = Array.Empty<TitleCounterSave>();
        public string[] settlements = Array.Empty<string>();
        public CustomTitleSave[] custom;
        public int nextCustomId;
    }
    public sealed partial class CombatActorData
    {
        internal readonly List<int> Titles = new List<int>();
        internal readonly Dictionary<string,int> TitleCounters = new Dictionary<string,int>();
        internal readonly HashSet<string> TitleSettlements = new HashSet<string>();
        internal readonly HashSet<int> TitleBattleKills = new HashSet<int>();
        internal readonly List<CustomTitleSave> CustomTitles = new List<CustomTitleSave>();
        internal int NextCustomTitleId = -1;
        internal int TitleKillBenefitCount;
        internal int EquippedTitle, TitleRevision;
    }
    public sealed partial class BattleData
    {
        internal readonly HashSet<int> TitleDefeated = new HashSet<int>();
    }
    /// <summary>Encounter-only receipts and per-turn benefit caps; none of this state is saved.</summary>
    public static class TitleCombatState
    {
        public static void BeginBattle(BattleData battle)
        {
            battle.TitleDefeated.Clear();
            for(int i=0;i<battle.UnitCount;i++)End(battle.GetUnitAt(i));
        }
        public static bool RecordKill(BattleData battle,int targetId)
        {
            if(targetId<=0)throw new ArgumentOutOfRangeException(nameof(targetId));
            return battle.TitleDefeated.Add(targetId);
        }
        public static void BeginTurn(CombatActorData actor) => actor.TitleKillBenefitCount=0;
        public static bool TryKillBenefit(CombatActorData actor,int limit)
        {
            if(limit<1)throw new ArgumentOutOfRangeException(nameof(limit));
            if(actor.TitleKillBenefitCount>=limit)return false;
            actor.TitleKillBenefitCount++;return true;
        }
        public static void End(CombatActorData actor) => actor.TitleKillBenefitCount=0;
    }
    /// <summary>Per-character titles and achievement facts. Lua owns configuration and eligibility rules.</summary>
    public static class TitleState
    {
        public static int Equipped(CombatActorData actor) => actor.EquippedTitle;
        public static int Revision(CombatActorData actor) => actor.TitleRevision;
        public static int Count(CombatActorData actor) => actor.Titles.Count;
        public static int At(CombatActorData actor,int index) => actor.Titles[index];
        public static int CounterCount(CombatActorData actor) => actor.TitleCounters.Count;
        public static string CounterKeyAt(CombatActorData actor,int index) => actor.TitleCounters.Keys.ElementAt(index);
        public static bool Owns(CombatActorData actor,int id) => id<0 ? actor.CustomTitles.Exists(value=>value.id==id) : actor.Titles.Contains(id);
        public static int CustomCount(CombatActorData actor) => actor.CustomTitles.Count;
        public static int CustomAt(CombatActorData actor,int index) => actor.CustomTitles[index].id;
        public static string CustomName(CombatActorData actor,int id) => Custom(actor,id).name;
        public static int CustomCost(CombatActorData actor,int id) => Custom(actor,id).cost;
        public static int EffectCount(CombatActorData actor,int id) => Custom(actor,id).effects.Length;
        public static int EffectIdAt(CombatActorData actor,int id,int index) => Custom(actor,id).effects[index].id;
        public static int EffectRankAt(CombatActorData actor,int id,int index) => Custom(actor,id).effects[index].rank;
        private static CustomTitleSave Custom(CombatActorData actor,int id)
            => actor.CustomTitles.Find(value=>value.id==id) ?? throw new ArgumentException("Unknown custom title.",nameof(id));
        public static string NormalizeName(string name)
        {
            if(!ValidName(name))throw new ArgumentException("A title name needs 1 to 16 Unicode characters without control or markup characters.",nameof(name));
            return name.Trim();
        }
        public static bool ValidName(string name)
        {
            if(name==null)return false;
            foreach(char value in name)if(char.IsControl(value) || value=='<' || value=='>')return false;
            string trimmed=name.Trim();int count=0;
            for(int i=0;i<trimmed.Length;i++)
            {
                char value=trimmed[i];
                if(char.IsHighSurrogate(value))
                { if(i+1>=trimmed.Length || !char.IsLowSurrogate(trimmed[i+1]))return false;i++; }
                else if(char.IsLowSurrogate(value))return false;
                if(++count>16)return false;
            }
            return count>0;
        }
        public static int Craft(AdventureData data,CombatActorData actor,string name,string effectRanks,int cost)
        {
            if(data==null)throw new ArgumentNullException(nameof(data));
            if(actor==null || !ReferenceEquals(PartyRoster.Find(data,actor.Id),actor))throw new ArgumentException("Custom title owner must belong to the roster.",nameof(actor));
            string normalized=NormalizeName(name);
            if(cost<=0)throw new ArgumentOutOfRangeException(nameof(cost));
            var effects=ParseEffects(effectRanks);
            if(actor.CustomTitles.Count>=10000 || actor.NextCustomTitleId==int.MinValue)throw new InvalidOperationException("Custom title capacity exhausted.");
            var title=new CustomTitleSave{id=actor.NextCustomTitleId,name=normalized,cost=cost,effects=effects};
            if(!data.Reputation.TrySpend(cost))return 0;
            actor.CustomTitles.Add(title);actor.NextCustomTitleId--;actor.TitleRevision++;return title.id;
        }
        private static TitleEffectSave[] ParseEffects(string effectRanks)
        {
            if(string.IsNullOrEmpty(effectRanks) || effectRanks.Length>4096)throw new ArgumentException("Custom title effects are required.",nameof(effectRanks));
            string[] rows=effectRanks.Split(',');
            if(rows.Length>128)throw new ArgumentException("Too many custom title effects.",nameof(effectRanks));
            var ids=new HashSet<int>();var effects=new TitleEffectSave[rows.Length];
            for(int i=0;i<rows.Length;i++)
            {
                var parts=rows[i].Split(':');
                if(parts.Length!=2 || !int.TryParse(parts[0],NumberStyles.None,CultureInfo.InvariantCulture,out int id) || id<=0
                    || !int.TryParse(parts[1],NumberStyles.None,CultureInfo.InvariantCulture,out int rank) || rank<=0 || !ids.Add(id))
                    throw new ArgumentException("Invalid or duplicate custom title effect.",nameof(effectRanks));
                effects[i]=new TitleEffectSave{id=id,rank=rank};
            }
            Array.Sort(effects,(a,b)=>a.id.CompareTo(b.id));return effects;
        }
        public static int Counter(CombatActorData actor,string key) => actor.TitleCounters.TryGetValue(key,out var value)?value:0;
        public static void Increment(CombatActorData actor,string key)
        {
            if(string.IsNullOrEmpty(key))throw new ArgumentException("Title counter needs a key.");
            actor.TitleCounters[key]=checked(Counter(actor,key)+1);actor.TitleRevision++;
        }
        public static void BeginBattle(CombatActorData actor) => actor.TitleBattleKills.Clear();
        public static bool RecordKill(CombatActorData actor,int targetId)
        {
            if(targetId<=0)throw new ArgumentOutOfRangeException(nameof(targetId));
            return actor.TitleBattleKills.Add(targetId);
        }
        public static bool RecordSettlement(CombatActorData actor,string kind,int id)
        {
            if(id<=0 || (kind!="mission" && kind!="quest" && kind!="town"))throw new ArgumentException("Invalid title settlement.");
            return actor.TitleSettlements.Add(kind+":"+id);
        }
        public static bool Award(CombatActorData actor,int id)
        {
            if(id<=0)throw new ArgumentOutOfRangeException(nameof(id));
            if(Owns(actor,id))return false;
            actor.Titles.Add(id);actor.TitleRevision++;return true;
        }
        public static void Equip(CombatActorData actor,int id)
        {
            if(id!=0 && !Owns(actor,id))throw new InvalidOperationException("Cannot equip an unearned title.");
            if(actor.EquippedTitle==id)return;
            actor.EquippedTitle=id;actor.TitleRevision++;
        }
        internal static TitleSave Capture(CombatActorData actor) => new TitleSave
        {
            format=2,equipped=actor.EquippedTitle,owned=actor.Titles.ToArray(),nextCustomId=actor.NextCustomTitleId,
            custom=actor.CustomTitles.Select(value=>new CustomTitleSave{id=value.id,name=value.name,cost=value.cost,
                effects=value.effects.Select(effect=>new TitleEffectSave{id=effect.id,rank=effect.rank}).ToArray()}).ToArray(),
            counters=actor.TitleCounters.OrderBy(p=>p.Key,StringComparer.Ordinal).Select(p=>new TitleCounterSave{key=p.Key,value=p.Value}).ToArray(),
            settlements=actor.TitleSettlements.OrderBy(v=>v,StringComparer.Ordinal).ToArray()
        };
        internal static void Restore(CombatActorData actor,TitleSave row)
        {
            SaveCheck.Require(row!=null && (row.format==1 || row.format==2),"titles.format");
            SaveCheck.PositiveIds(row.owned,"titles.owned");
            if(row.format==2)
            {
                SaveCheck.Require(row.nextCustomId<0,"titles.nextCustomId");
                var customIds=new HashSet<int>();
                foreach(var title in SaveCheck.Rows(row.custom,10000,"titles.custom"))
                {
                    SaveCheck.Require(title!=null && title.id<0 && title.id>row.nextCustomId && customIds.Add(title.id)
                        && title.cost>0 && ValidName(title.name) && title.name==title.name.Trim(),"titles.customTitle");
                    var effectIds=new HashSet<int>();
                    var effects=SaveCheck.Rows(title.effects,128,"titles.customEffects");
                    SaveCheck.Require(effects.Length>0,"titles.customEffects");
                    foreach(var effect in effects)SaveCheck.Require(effect!=null && effect.id>0 && effect.rank>0 && effectIds.Add(effect.id),"titles.customEffect");
                    actor.CustomTitles.Add(new CustomTitleSave{id=title.id,name=title.name,cost=title.cost,
                        effects=effects.OrderBy(effect=>effect.id).Select(effect=>new TitleEffectSave{id=effect.id,rank=effect.rank}).ToArray()});
                }
                actor.NextCustomTitleId=row.nextCustomId;
            }
            SaveCheck.Require(row.equipped==0 || row.owned.Contains(row.equipped) || actor.CustomTitles.Exists(value=>value.id==row.equipped),"titles.equipped");
            foreach(var counter in SaveCheck.Rows(row.counters,10000,"titles.counters"))
            {
                SaveCheck.Require(counter!=null && !string.IsNullOrEmpty(counter.key) && counter.key.Length<=96 && counter.value>0
                    && !actor.TitleCounters.ContainsKey(counter.key),"titles.counter");
                var parts=counter.key.Split(':');
                SaveCheck.Require(parts.Length==2 && (parts[0]=="kill" || parts[0]=="legend" || parts[0]=="mission" || parts[0]=="quest" || parts[0]=="town")
                    && int.TryParse(parts[1],out var target) && target>=0 && parts[1]==target.ToString(),"titles.counterKey");
                actor.TitleCounters.Add(counter.key,counter.value);
            }
            foreach(var receipt in SaveCheck.Rows(row.settlements,100000,"titles.settlements"))
            {
                var parts=receipt?.Split(':');
                SaveCheck.Require(parts!=null && parts.Length==2 && (parts[0]=="mission" || parts[0]=="quest" || parts[0]=="town")
                    && int.TryParse(parts[1],out var id) && id>0 && actor.TitleSettlements.Add(receipt),"titles.settlement");
            }
            actor.Titles.AddRange(row.owned);actor.EquippedTitle=row.equipped;actor.TitleRevision++;
        }
    }
}
