using System;
using XLua;

namespace ProjectY.Data
{
    /// <summary>一条已结算的经历快照；文案和参与者固定，后续改特质不会改写过去。</summary>
    [LuaCallCSharp]
    public sealed class ChronicleEntryData
    {
        private readonly int[] participants;
        public int Sequence { get; }
        public string Kind { get; }
        public string Title { get; }
        public string Body { get; }
        public string Location { get; }
        public int EventId { get; }
        public int ChoiceId { get; }
        public int SubjectId { get; }
        public bool Involves(int actorId) => Array.IndexOf(participants, actorId) >= 0;
        internal ChronicleEntryData(int sequence, string kind, string title, string body, string location,
            int eventId, int choiceId, int subjectId, int[] actorIds)
        {
            if (string.IsNullOrEmpty(kind) || string.IsNullOrEmpty(title) || string.IsNullOrEmpty(body) || location == null)
                throw new ArgumentException("Chronicle text is incomplete.");
            Sequence = sequence; Kind = kind; Title = title; Body = body; Location = location;
            EventId = eventId; ChoiceId = choiceId; SubjectId = subjectId; participants = actorIds;
        }
    }
}
