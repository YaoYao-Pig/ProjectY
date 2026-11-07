using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    [Serializable] internal sealed class SpellcastingSave
    {
        public bool initialized, clockInitialized;
        public int current, maximum, regeneration;
        public double minute, progress;
    }
    public sealed partial class CombatActorData
    {
        internal SpellcastingSave Spellcasting = new SpellcastingSave();
        internal readonly Dictionary<int,int> CastingBoosts = new Dictionary<int,int>();
    }
    public sealed class SpellFieldData
    {
        public int Id {get;internal set;}
        public int SkillId {get;internal set;}
        public int SourceId {get;internal set;}
        public int Q {get;internal set;}
        public int R {get;internal set;}
        public int Radius {get;internal set;}
        public int Remaining {get;internal set;}
        public int CreatedRound {get;internal set;}
        public string Kind {get;internal set;}
        public double DamageScale {get;internal set;}
        internal readonly Dictionary<int,int> touched = new Dictionary<int,int>();
    }
    public sealed partial class BattleData
    {
        internal readonly List<SpellFieldData> SpellFields = new List<SpellFieldData>();
        internal int NextSpellFieldId;
    }
    /// <summary>Authoritative resources survive encounters; selection and fields do not.</summary>
    public static class SpellcastingState
    {
        public static int Current(CombatActorData actor) => actor.Spellcasting.current;
        public static int Maximum(CombatActorData actor) => actor.Spellcasting.maximum;
        public static int Regen(CombatActorData actor) => actor.Spellcasting.regeneration;
        public static void Configure(CombatActorData actor,int maximum,int regeneration)
        {
            if(maximum<0 || maximum>256 || regeneration<0 || regeneration>256) throw new ArgumentOutOfRangeException(nameof(maximum));
            var value=actor.Spellcasting;
            if(!value.initialized && maximum>0) {value.initialized=true;value.current=maximum;}
            // Raising a cap never fills it, so swapping equipment cannot generate points.
            value.maximum=maximum;value.regeneration=regeneration;value.current=Math.Min(value.current,maximum);
        }
        public static void Spend(CombatActorData actor,int amount)
        {
            var value=actor.Spellcasting;
            if(amount<0 || amount>value.current) throw new InvalidOperationException("Insufficient casting points.");
            value.current-=amount;
        }
        public static int Recover(CombatActorData actor,int amount)
        {
            if(amount<0)throw new ArgumentOutOfRangeException(nameof(amount));
            if(!DeathDoorState.Alive(actor))return 0;
            var value=actor.Spellcasting;int recovered=Math.Min(amount,value.maximum-value.current);value.current+=recovered;return recovered;
        }
        public static int Advance(CombatActorData actor,double now,double minutesPerPoint,bool outsideBattle)
        {
            if(double.IsNaN(now)||double.IsInfinity(now)||now<0||minutesPerPoint<=0||double.IsNaN(minutesPerPoint)||double.IsInfinity(minutesPerPoint))throw new ArgumentOutOfRangeException(nameof(now));
            var value=actor.Spellcasting;
            if(!value.clockInitialized){value.clockInitialized=true;value.minute=now;return 0;}
            double elapsed=Math.Max(0,now-value.minute);value.minute=now;
            if(!outsideBattle||!DeathDoorState.Alive(actor)||value.maximum==0)return 0;
            if(value.current==value.maximum){value.progress=0;return 0;}
            value.progress+=elapsed*value.regeneration/minutesPerPoint;
            int amount=(int)Math.Min(value.maximum-value.current,Math.Floor(value.progress));
            value.progress-=amount;int result=Recover(actor,amount);
            if(value.current==value.maximum)value.progress=0;
            return result;
        }
        public static int Boost(CombatActorData actor,int skillId) => actor.CastingBoosts.TryGetValue(skillId,out int value)?value:0;
        public static void SetBoost(CombatActorData actor,int skillId,int value)
        {
            if(skillId<=0 || value<0 || value>256)throw new ArgumentOutOfRangeException(nameof(value));
            if(value==0)actor.CastingBoosts.Remove(skillId);else actor.CastingBoosts[skillId]=value;
        }
        public static void ClearBoosts(CombatActorData actor)=>actor.CastingBoosts.Clear();
        public static int FieldCount(BattleData battle)=>battle.SpellFields.Count;
        public static SpellFieldData FieldAt(BattleData battle,int index)=>battle.SpellFields[index];
        public static void ClearFields(BattleData battle){battle.SpellFields.Clear();battle.NextSpellFieldId=0;}
        public static void AddField(BattleData battle,int skillId,int sourceId,int q,int r,int radius,int turns,string kind,double damageScale)
        {
            if(skillId<1||sourceId<1||radius<0||radius>8||turns<1||turns>20||damageScale<=0||double.IsNaN(damageScale)||double.IsInfinity(damageScale)||(kind!="fire"&&kind!="mist"&&kind!="mud"))throw new ArgumentException("Invalid spell field.");
            var previous=battle.SpellFields.Find(x=>x.Q==q&&x.R==r&&x.Kind==kind);
            if(previous==null&&battle.SpellFields.Count>=64)throw new InvalidOperationException("Spell field limit reached.");
            if(previous!=null)battle.SpellFields.Remove(previous);
            battle.SpellFields.Add(new SpellFieldData{Id=++battle.NextSpellFieldId,SkillId=skillId,SourceId=sourceId,Q=q,R=r,Radius=radius,Remaining=turns,CreatedRound=battle.Round,Kind=kind,DamageScale=damageScale});
        }
        public static void AdvanceFields(BattleData battle)
        {
            for(int i=battle.SpellFields.Count-1;i>=0;i--){var field=battle.SpellFields[i];if(--field.Remaining<=0)battle.SpellFields.RemoveAt(i);}
        }
        public static void RemoveField(BattleData battle,int id)
        {if(battle.SpellFields.RemoveAll(x=>x.Id==id)!=1)throw new ArgumentException("Missing spell field.");}
        public static bool Touch(SpellFieldData field,int actorId,int round)
        {
            if(field.touched.TryGetValue(actorId,out int last)&&last==round)return false;
            field.touched[actorId]=round;return true;
        }
        internal static SpellcastingSave Capture(CombatActorData actor)
        {
            var v=actor.Spellcasting;
            return new SpellcastingSave{initialized=v.initialized,current=v.current,maximum=v.maximum,regeneration=v.regeneration,clockInitialized=v.clockInitialized,minute=v.minute,progress=v.progress};
        }
        internal static void Restore(CombatActorData actor,SpellcastingSave value)
        {
            if(value==null)return; // Pre-resource saves initialize once on their first rules sync.
            SaveCheck.Require(value.current>=0&&value.maximum>=0&&value.maximum<=256&&value.current<=value.maximum&&value.regeneration>=0&&value.regeneration<=256&&value.minute>=0&&!double.IsNaN(value.minute)&&!double.IsInfinity(value.minute)&&value.progress>=0&&value.progress<1,"spellcasting resource");
            SaveCheck.Require(value.initialized||value.current==0&&value.maximum==0,"spellcasting initialization");
            actor.Spellcasting=value;
        }
    }
}
