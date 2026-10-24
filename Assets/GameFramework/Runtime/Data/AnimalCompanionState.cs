using System;

namespace ProjectY.Data
{
    public sealed partial class CombatActorData
    {
        internal int CompanionMoveRound=-1,CompanionAttackRound=-1,CompanionRescueRound=-1;
        internal int CompanionScentTarget;
    }
    public sealed partial class MapAreaStateData
    {
        internal void TouchCompanionPresentation() { Revision++; }
    }

    /// <summary>Reflection bridge for the same animal in mounted and independent modes.</summary>
    public static class AnimalCompanionState
    {
        public static CombatActorData Bound(CombatActorData owner) => owner.BoundAnimal;
        public static CombatActorData Partner(CombatActorData owner) => owner.CompanionAnimal;
        public static bool Independent(CombatActorData actor) => actor.IndependentAnimal;
        public static int Layer(CombatActorData animal) => animal.CompanionLayer;
        public static void SetMode(CombatActorData owner,bool independent,int q,int r,int layer=0) => owner.SetCompanionMode(independent,q,r,layer);
        public static void Follow(CombatActorData animal,int q,int r,int layer=0) => animal.FollowCompanion(q,r,layer);
        public static void ReleaseDefeated(CombatActorData owner) => owner.ReleaseDefeatedCompanion();
        public static void Touch(MapAreaStateData area) => area.TouchCompanionPresentation();
        public static void ResetBattle(CombatActorData owner)
        {owner.CompanionMoveRound=-1;owner.CompanionAttackRound=-1;owner.CompanionRescueRound=-1;owner.CompanionScentTarget=0;}
        public static bool CanMove(CombatActorData owner,int round) => owner.CompanionMoveRound!=round;
        public static bool CanAttack(CombatActorData owner,int round) => owner.CompanionRescueRound!=round && owner.CompanionAttackRound!=round;
        public static void Moved(CombatActorData owner,int round)
        {if(!CanMove(owner,round))throw new InvalidOperationException("Companion already moved by command this round.");owner.CompanionMoveRound=round;}
        public static void Attacked(CombatActorData owner,int round)
        {if(!CanAttack(owner,round))throw new InvalidOperationException("Companion attack command exhausted.");owner.CompanionAttackRound=round;}
        public static void Rescued(CombatActorData owner,int round) => owner.CompanionRescueRound=round;
        public static int Scent(CombatActorData owner) => owner.CompanionScentTarget;
        public static void SetScent(CombatActorData owner,int targetId)
        {if(targetId<0)throw new ArgumentOutOfRangeException(nameof(targetId));owner.CompanionScentTarget=targetId;}
    }
}
