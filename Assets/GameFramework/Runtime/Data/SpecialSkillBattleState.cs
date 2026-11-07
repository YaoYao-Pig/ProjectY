using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;

namespace ProjectY.Data
{
    /// <summary>A successful observation retained only until this battle is settled.</summary>
    public sealed class SpecialSkillObservation
    {
        public CombatActorData Learner { get; }
        public int SkillId { get; }
        public double Chance { get; internal set; }
        public string SourceName { get; internal set; }
        internal SpecialSkillObservation(CombatActorData learner, int skillId, double chance, string sourceName)
        { Learner=learner;SkillId=skillId;Chance=chance;SourceName=sourceName; }
    }

    /// <summary>Transient authority for participants, deduplicated observations and settlement consumption.</summary>
    public static class SpecialSkillBattleState
    {
        private sealed class BattleState
        {
            internal bool Open=true;
            internal readonly Dictionary<int,CombatActorData> Participants=new Dictionary<int,CombatActorData>();
            internal readonly Dictionary<long,SpecialSkillObservation> Observations=new Dictionary<long,SpecialSkillObservation>();
        }
        private static readonly ConditionalWeakTable<AdventureData,BattleState> states=new ConditionalWeakTable<AdventureData,BattleState>();
        public static void Reset(AdventureData data) { states.Remove(data); }
        public static void Begin(AdventureData data)
        {
            Reset(data);
            var state=new BattleState();states.Add(data,state);
            for(int i=0;i<data.Battle.UnitCount;i++)
            {
                var actor=data.Battle.GetUnitAt(i);
                if(actor.Team==1 && actor.AnimalOwnerId==0 && DeathDoorState.Alive(actor) && ReferenceEquals(PartyRoster.Find(data,actor.Id),actor))
                    state.Participants.Add(actor.Id,actor);
            }
        }
        public static bool IsParticipant(AdventureData data,CombatActorData actor) => actor!=null && states.TryGetValue(data,out var state) && state.Open &&
            state.Participants.TryGetValue(actor.Id,out var participant) && ReferenceEquals(actor,participant);
        public static void Observe(AdventureData data,CombatActorData learner,int skillId,double chance,string sourceName)
        {
            if(!IsParticipant(data,learner) || skillId<1 || double.IsNaN(chance) || double.IsInfinity(chance) || chance<=0 || chance>1 || string.IsNullOrEmpty(sourceName))
                throw new ArgumentException("Invalid special skill observation.");
            var state=states.GetValue(data,_=>throw new InvalidOperationException("Missing battle observations."));
            long key=((long)learner.Id<<32)|(uint)skillId;
            if(state.Observations.TryGetValue(key,out var observation))
            {
                if(chance>observation.Chance){observation.Chance=chance;observation.SourceName=sourceName;}
            }
            else state.Observations.Add(key,new SpecialSkillObservation(learner,skillId,chance,sourceName));
        }
        public static bool Consume(AdventureData data)
        {
            if(!states.TryGetValue(data,out var state) || !state.Open)return false;
            state.Open=false;return true;
        }
        public static SpecialSkillObservation[] Observations(AdventureData data)
        {
            if(!states.TryGetValue(data,out var state) || state.Open)throw new InvalidOperationException("Consume observations before settlement.");
            return state.Observations.Values.OrderBy(row=>row.Learner.Id).ThenBy(row=>row.SkillId).ToArray();
        }
    }
}
