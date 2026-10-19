using System;
using System.Collections.Generic;
using System.Linq;
using XLua;

namespace ProjectY.Data
{
    [Serializable] internal sealed class ChronicleSave
    {
        public int sequence, eventId, choiceId, subjectId, objectId, relationDelta;
        public double minutes;
        public string kind, title, body, location;
        public int[] participants;
    }
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
        public int ObjectId { get; }
        public int RelationDelta { get; }
        public double Minutes { get; }
        public int Day => (int)Math.Floor(Minutes / 1440) + 1;
        public int ParticipantCount => participants.Length;
        public int GetParticipantAt(int index) => participants[index];
        public bool Involves(int actorId) => Array.IndexOf(participants, actorId) >= 0;
        internal ChronicleEntryData(int sequence, string kind, string title, string body, string location,
            int eventId, int choiceId, int subjectId, int[] actorIds)
            : this(sequence, kind, title, body, location, eventId, choiceId, subjectId, 0, 0, 0, actorIds) { }
        internal ChronicleEntryData(int sequence, string kind, string title, string body, string location,
            int eventId, int choiceId, int subjectId, double minutes, int objectId, int relationDelta, int[] actorIds)
        {
            if (string.IsNullOrEmpty(kind) || string.IsNullOrEmpty(title) || string.IsNullOrEmpty(body) || location == null)
                throw new ArgumentException("Chronicle text is incomplete.");
            if (sequence <= 0 || double.IsNaN(minutes) || double.IsInfinity(minutes) || minutes < 0 || minutes > 100000000 ||
                objectId < 0 || subjectId < 0 || relationDelta < -100 || relationDelta > 100 || actorIds == null ||
                actorIds.Length < 1 || actorIds.Length > 4 || actorIds.Any(id => id <= 0) || actorIds.Distinct().Count() != actorIds.Length ||
                (subjectId > 0 && !actorIds.Contains(subjectId)) || (objectId > 0 && (!actorIds.Contains(objectId) || subjectId == objectId)))
                throw new ArgumentException("Chronicle identities or date are invalid.");
            Sequence = sequence; Kind = kind; Title = title; Body = body; Location = location;
            EventId = eventId; ChoiceId = choiceId; SubjectId = subjectId; participants = (int[])actorIds.Clone();
            Minutes = minutes; ObjectId = objectId; RelationDelta = relationDelta;
        }
        internal ChronicleSave Capture() => new ChronicleSave { sequence = Sequence, kind = Kind, title = Title, body = Body,
            location = Location, eventId = EventId, choiceId = ChoiceId, subjectId = SubjectId, objectId = ObjectId,
            minutes = Minutes, relationDelta = RelationDelta, participants = (int[])participants.Clone() };
        internal static ChronicleEntryData Prepare(ChronicleSave row, int sequence, HashSet<int> actors)
        {
            SaveCheck.Require(row != null && row.sequence == sequence && row.eventId >= 0 && row.choiceId >= 0 &&
                !string.IsNullOrEmpty(row.kind) && row.kind.Length <= 64 && !string.IsNullOrEmpty(row.title) && row.title.Length <= 512 &&
                !string.IsNullOrEmpty(row.body) && row.body.Length <= 8192 && row.location != null && row.location.Length <= 512, "经历文字或序号");
            SaveCheck.PositiveIds(row.participants, "经历参与者");
            SaveCheck.Require(row.participants.All(actors.Contains), "经历含未知队员");
            return new ChronicleEntryData(sequence, row.kind, row.title, row.body, row.location,
                row.eventId, row.choiceId, row.subjectId, row.minutes, row.objectId, row.relationDelta, row.participants);
        }
    }
}
