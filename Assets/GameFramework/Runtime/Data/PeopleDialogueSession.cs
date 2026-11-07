using System;

namespace ProjectY.Data
{
    public sealed partial class NarrativeData
    {
        // A procedural person's identity is persisted by PeopleData; this conversation is transient.
        internal string DialoguePersonKey = string.Empty;
        internal void ClearPeopleDialogue() { DialoguePersonKey = string.Empty; }
        internal void BeginPeopleDialogue(string key, int actorId, int localNpcId)
        {
            if (DialogueOpen || string.IsNullOrWhiteSpace(key) || actorId <= 0 || localNpcId < 0)
                throw new InvalidOperationException("Invalid person dialogue session.");
            ClearAnimalSpeech(); ClearEquipmentSpirit();
            DialoguePersonKey = key;
            DialogueId = -2;
            DialogueNodeId = DialogueNpcId = 0;
            DialogueLocalNpcId = localNpcId;
            DialogueActorId = actorId;
            lines.Clear(); dialogueInterjections.Clear(); DialogueVersion++; Revision++;
        }
        internal void TouchPeopleDialogue()
        {
            if (DialogueId != -2 || string.IsNullOrEmpty(DialoguePersonKey))
                throw new InvalidOperationException("No person dialogue session.");
            DialogueVersion++; Revision++;
        }
    }

    public static class PeopleDialogueSession
    {
        public static string Key(NarrativeData data) => data.DialogueId == -2 ? data.DialoguePersonKey : string.Empty;
        public static void Begin(NarrativeData data, string key, int actorId, int localNpcId)
            => data.BeginPeopleDialogue(key, actorId, localNpcId);
        public static void Touch(NarrativeData data) => data.TouchPeopleDialogue();
    }
}
