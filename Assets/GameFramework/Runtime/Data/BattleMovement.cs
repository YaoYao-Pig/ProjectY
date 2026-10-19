using System;

namespace ProjectY.Data
{
    /// <summary>Turn-owned movement distance, exposed without regenerating actor wrappers.</summary>
    public static class BattleMovement
    {
        public static int Spent(CombatActorData actor)
        {
            if(actor==null)throw new ArgumentNullException(nameof(actor));
            return actor.MovementSpent;
        }
        public static int Remaining(CombatActorData actor,int range)
        {
            if(actor==null || range<0)throw new ArgumentException("Invalid movement query.");
            return actor.HP==0 || actor.Moved?0:Math.Max(0,range-actor.MovementSpent);
        }
        public static void Move(CombatActorData actor,int q,int r,int moveAP,int pathCost,int range)
        {
            if(actor==null)throw new ArgumentNullException(nameof(actor));
            actor.MoveSegment(q,r,moveAP,pathCost,range);
        }
    }
}
