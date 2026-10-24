using System;

namespace ProjectY.Data
{
    /// <summary>Updates the actor-owned recovery schedule without duplicating injury state.</summary>
    public static class ProfessionExplorationState
    {
        public static bool CanCare(CombatActorData actor, double now, int workMinutes)
        {
            if (actor == null || double.IsNaN(now) || double.IsInfinity(now) || now < 0 || workMinutes < 1)
                throw new ArgumentException("Invalid profession care request.");
            if (actor.HP <= 0) return false;
            foreach (var part in actor.BodyInjuries)
                if (!part.permanent && part.recoveryAmount > 0 && part.recoveryAt > now + workMinutes) return true;
            return false;
        }

        public static bool Care(CombatActorData actor, EquipmentData equipment, int itemId, int count,
            double now, int workMinutes, int accelerationMinutes)
        {
            if (equipment == null || itemId < 1 || count < 1 || accelerationMinutes < 1)
                throw new ArgumentException("Invalid profession care supplies.");
            if (!CanCare(actor, now, workMinutes) || equipment.CountItem(itemId) < count) return false;
            equipment.ConsumeStack(itemId, count);
            foreach (var part in actor.BodyInjuries)
                if (!part.permanent && part.recoveryAmount > 0 && part.recoveryAt > now + workMinutes)
                    part.recoveryAt = Math.Max(now + workMinutes, part.recoveryAt - accelerationMinutes);
            actor.BodyRevision++;
            return true;
        }
    }
}
