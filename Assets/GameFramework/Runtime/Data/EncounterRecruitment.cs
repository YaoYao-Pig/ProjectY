using System;

namespace ProjectY.Data
{
    /// <summary>Reflection bridge transferring a surviving scene ally without replacing its equipment or health.</summary>
    public static class EncounterRecruitment
    {
        public static void Validate(AdventureData data, MapAreaEncounterData group, CombatActorData actor)
        {
            if (data == null || group == null || actor == null) throw new ArgumentNullException("Event recruit");
            if ((data.Phase != "map" && data.Phase != "area") || data.PartyCount >= 4 || actor.HP <= 0 ||
                actor.Team != 4 || actor.AnimalOwnerId != 0 || group.PartyId != 0 || group.Detached || group.EnemyCount <= 1)
                throw new InvalidOperationException("The encounter ally cannot join this squad.");
            for (int i = 0; i < data.PartyCount; i++)
                if (data.GetPartyAt(i).Id == actor.Id) throw new InvalidOperationException("Duplicate recruit identity.");
            if (!group.ContainsRecruit(actor) || data.Areas.RecruitEncounterOwner(group) == null || !data.Equipment.CombatInitialized(actor.Id))
                throw new InvalidOperationException("Event recruit must belong to this expedition and retain its combat equipment.");
        }

        public static void Transfer(AdventureData data, MapAreaEncounterData group, CombatActorData actor)
        {
            Validate(data, group, actor);
            if (!actor.Growth.Initialized) throw new InvalidOperationException("Prepare recruit growth before transfer.");
            // All validation precedes the first write. The physical item instances keep their actor owner and durability.
            var area = data.Areas.RecruitEncounterOwner(group);
            group.ReleaseRecruit(actor);
            data.Equipment.TransferCombatOwner(actor.Id);
            actor.Deploy(1, actor.Q, actor.R);
            data.AddPreparedRecruit(actor);
            area.MarkRecruitTransferred();
        }
    }

    public sealed partial class MapAreaEncounterData
    {
        internal bool ContainsRecruit(CombatActorData actor) => enemies.Contains(actor);
        internal void ReleaseRecruit(CombatActorData actor) => enemies.Remove(actor);
    }

    public sealed partial class MapAreaData
    {
        internal MapAreaStateData RecruitEncounterOwner(MapAreaEncounterData group)
        {
            foreach (var area in areas.Values)
                for (int i = 0; i < area.EncounterCount; i++)
                    if (ReferenceEquals(area.GetEncounterAt(i), group)) return area;
            return null;
        }
    }

    public sealed partial class MapAreaStateData
    {
        internal void MarkRecruitTransferred() => Revision++;
    }

    public sealed partial class EquipmentData
    {
        internal void TransferCombatOwner(int actorId) { combatOwners.Remove(actorId); Revision++; }
    }
}
