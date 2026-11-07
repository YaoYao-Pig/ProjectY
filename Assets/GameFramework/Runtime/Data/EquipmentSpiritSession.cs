using System;

namespace ProjectY.Data
{
    public sealed partial class NarrativeData
    {
        // A spirit is the identity of an equipment instance, never a placed/recruitable NPC.
        internal int SpiritWeaponId;
        internal void ClearEquipmentSpirit() { SpiritWeaponId = 0; }
        internal void BeginEquipmentSpirit(int weaponId, int actorId)
        {
            if (DialogueOpen || weaponId <= 0 || actorId <= 0)
                throw new InvalidOperationException("Invalid equipment spirit dialogue session.");
            ClearAnimalSpeech();
            SpiritWeaponId = weaponId;
            DialogueId = -1;
            DialogueNodeId = DialogueNpcId = DialogueLocalNpcId = 0;
            DialogueActorId = actorId;
            lines.Clear(); dialogueInterjections.Clear(); DialogueVersion++; Revision++;
        }
        internal void TouchEquipmentSpirit()
        {
            if (DialogueId != -1 || SpiritWeaponId <= 0)
                throw new InvalidOperationException("No equipment spirit dialogue session.");
            DialogueVersion++; Revision++;
        }
    }

    // Session state belongs to NarrativeData and is omitted from its saved progress.
    public static class EquipmentSpiritSession
    {
        public static int WeaponId(NarrativeData data) => data.SpiritWeaponId;
        public static void Begin(NarrativeData data, int weaponId, int actorId)
            => data.BeginEquipmentSpirit(weaponId, actorId);
        public static void Touch(NarrativeData data) => data.TouchEquipmentSpirit();
    }
}
