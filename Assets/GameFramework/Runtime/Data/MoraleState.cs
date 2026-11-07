using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    public sealed partial class CombatActorData
    {
        internal int MoraleCurrent, MoraleMaximum, MoraleStage;
        internal bool MoraleActive;
    }
    public sealed partial class BattleData
    {
        internal readonly HashSet<int> MoraleDefeated = new HashSet<int>();
    }
    /// <summary>Encounter-local morale; capacity and stage thresholds are supplied by configured Lua rules.</summary>
    public static class MoraleState
    {
        public static bool Active(CombatActorData actor) => actor.MoraleActive;
        public static int Current(CombatActorData actor) => actor.MoraleCurrent;
        public static int Maximum(CombatActorData actor) => actor.MoraleMaximum;
        public static int Stage(CombatActorData actor) => actor.MoraleStage;
        public static void BeginBattle(BattleData battle) => battle.MoraleDefeated.Clear();
        public static bool RecordDefeat(BattleData battle,int id) => battle.MoraleDefeated.Add(id);
        public static void Begin(CombatActorData actor,int maximum,int current,int stage)
        {
            Validate(maximum,current,stage);
            actor.MoraleMaximum=maximum;actor.MoraleCurrent=current;actor.MoraleStage=stage;actor.MoraleActive=true;
        }
        public static void Set(CombatActorData actor,int maximum,int current,int stage)
        {
            if(!actor.MoraleActive)throw new InvalidOperationException("Morale is not active.");
            Validate(maximum,current,stage);
            actor.MoraleMaximum=maximum;actor.MoraleCurrent=current;actor.MoraleStage=stage;
        }
        public static void End(CombatActorData actor)
        {actor.MoraleActive=false;actor.MoraleCurrent=0;actor.MoraleMaximum=0;actor.MoraleStage=0;}
        private static void Validate(int maximum,int current,int stage)
        {
            if(maximum<1 || maximum>1000000 || current<0 || current>maximum || stage< -3 || stage>1)
                throw new ArgumentOutOfRangeException(nameof(current),"Invalid morale state.");
        }
    }
}
