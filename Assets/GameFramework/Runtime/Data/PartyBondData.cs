using System;
using System.Collections.Generic;
using System.Linq;
using XLua;

namespace ProjectY.Data
{
    [Serializable] internal sealed class PartyBondSave
    { public int first, second, score, battles, rescues, grievance, support, cooperation, friendlyHits, socialDay; public bool romance; }
    [Serializable] internal sealed class PartyHonorSave { public int actorId, honorId; }
    [Serializable] internal sealed class PartyStorySave
    { public int format; public PartyBondSave[] bonds; public IntEntry[] rescues; public PartyHonorSave[] honors; }

    /// <summary>无向队员关系；双方共用一份记录，救援总数与个人救援计数分别保存。</summary>
    [LuaCallCSharp]
    public sealed class PartyBondData
    {
        public int FirstActorId { get; }
        public int SecondActorId { get; }
        public int Score { get; internal set; }
        public int SharedBattles { get; internal set; }
        public int Rescues { get; internal set; }
        internal int Grievance, Support, Cooperation, FriendlyHits, SocialDay;
        internal bool Romance;
        internal PartyBondData(int first, int second) { FirstActorId = first; SecondActorId = second; }
        internal PartyBondSave Capture() => new PartyBondSave { first = FirstActorId, second = SecondActorId, score = Score, battles = SharedBattles, rescues = Rescues,
            grievance=Grievance,support=Support,cooperation=Cooperation,friendlyHits=FriendlyHits,socialDay=SocialDay,romance=Romance };
    }

    [LuaCallCSharp]
    public sealed class PartyHonorData
    {
        public int ActorId { get; }
        public int HonorId { get; }
        internal PartyHonorData(int actorId, int honorId) { ActorId = actorId; HonorId = honorId; }
    }

    /// <summary>队员关系、救援挑战和荣誉的权威状态；战斗参与者和本场去重不进入探索存档。</summary>
    [LuaCallCSharp]
    public sealed class PartyStoryData
    {
        private readonly List<PartyBondData> bonds = new List<PartyBondData>();
        private readonly Dictionary<int, int> rescueCounts = new Dictionary<int, int>();
        private readonly List<PartyHonorData> honors = new List<PartyHonorData>();
        private readonly List<CombatActorData> participants = new List<CombatActorData>();
        private readonly HashSet<string> rescuedPairs = new HashSet<string>();
        internal bool battleOpen;
        internal readonly Dictionary<string,int> interactions = new Dictionary<string,int>();
        internal readonly Dictionary<int,int> friendlyDamage = new Dictionary<int,int>();
        internal readonly Dictionary<int,HashSet<int>> attackers = new Dictionary<int,HashSet<int>>();
        internal int attackRound;
        public int Revision { get; private set; }
        public int BondCount => bonds.Count;
        public int HonorCount => honors.Count;
        public int ParticipantCount => participants.Count;
        public PartyBondData GetBondAt(int index) => bonds[index];
        public PartyHonorData GetHonorAt(int index) => honors[index];
        public CombatActorData GetParticipantAt(int index) => participants[index];
        internal static string PairKey(int first, int second) => Math.Min(first, second) + ":" + Math.Max(first, second);
        private static void CheckPair(int first, int second)
        { if (first <= 0 || second <= 0 || first == second) throw new ArgumentException("A party bond needs two different actors."); }
        public PartyBondData Find(int first, int second)
        {
            CheckPair(first, second); int a = Math.Min(first, second), b = Math.Max(first, second);
            return bonds.Find(row => row.FirstActorId == a && row.SecondActorId == b);
        }
        internal PartyBondData GetOrAdd(int first, int second)
        {
            var row = Find(first, second);
            if (row != null) return row;
            row = new PartyBondData(Math.Min(first, second), Math.Max(first, second)); bonds.Add(row); return row;
        }
        public int Score(int first, int second) => Find(first, second)?.Score ?? 0;
        public int RescueCount(int actorId) => rescueCounts.TryGetValue(actorId, out int count) ? count : 0;
        public bool HasHonor(int actorId, int honorId) => honors.Exists(row => row.ActorId == actorId && row.HonorId == honorId);
        public void AwardHonor(int actorId, int honorId)
        {
            if (actorId <= 0 || honorId <= 0 || HasHonor(actorId, honorId)) throw new InvalidOperationException("Invalid or duplicate party honor.");
            honors.Add(new PartyHonorData(actorId, honorId)); Revision++;
        }
        public void ResetBattle() { participants.Clear(); rescuedPairs.Clear(); interactions.Clear();friendlyDamage.Clear();attackers.Clear();attackRound=0;battleOpen = false; }
        public void BeginBattle() { ResetBattle(); battleOpen = true; }
        public void AddParticipant(CombatActorData actor)
        {
            if (!battleOpen || actor == null || actor.Team != 1 || !DeathDoorState.Alive(actor) || IsParticipant(actor.Id))
                throw new InvalidOperationException("Invalid party story battle participant.");
            participants.Add(actor);
        }
        public bool IsParticipant(int actorId) => participants.Exists(actor => actor.Id == actorId);
        public bool TryRescue(int sourceId, int targetId, int amount)
        {
            CheckPair(sourceId, targetId);
            if (!battleOpen || !IsParticipant(sourceId) || !IsParticipant(targetId) || amount <= 0 || amount > 100)
                throw new InvalidOperationException("Rescue is outside the current party battle.");
            if (PartyRelationshipState.Count(this,sourceId,targetId,"harm")>0 || !rescuedPairs.Add(PairKey(sourceId, targetId))) return false;
            var row = GetOrAdd(sourceId, targetId); row.Score = Math.Min(100, row.Score + amount); row.Rescues++;
            rescueCounts[sourceId] = RescueCount(sourceId) + 1; Revision++; return true;
        }
        public bool SettleBattle(bool victory, int amount)
        {
            if (amount <= 0 || amount > 100) throw new ArgumentOutOfRangeException(nameof(amount));
            if (!battleOpen) return false;
            battleOpen = false;
            if (!victory) return true;
            for (int i = 0; i < participants.Count; i++)
                for (int j = i + 1; j < participants.Count; j++)
                {
                    if (!DeathDoorState.Alive(participants[i]) || !DeathDoorState.Alive(participants[j])) continue;
                    var row = GetOrAdd(participants[i].Id, participants[j].Id);
                    if(PartyRelationshipState.Count(this,participants[i].Id,participants[j].Id,"harm")==0)
                    { row.Score = Math.Min(100, row.Score + amount);row.Grievance=Math.Max(0,row.Grievance-1); }
                    row.SharedBattles++; Revision++;
                }
            return true;
        }
        public void Clear() { bonds.Clear(); rescueCounts.Clear(); honors.Clear(); ResetBattle(); Revision++; }
        internal PartyStorySave Capture() => new PartyStorySave
        {
            format = 2,
            bonds = bonds.Select(row => row.Capture()).ToArray(),
            rescues = rescueCounts.Select(row => new IntEntry { id = row.Key, value = row.Value }).ToArray(),
            honors = honors.Select(row => new PartyHonorSave { actorId = row.ActorId, honorId = row.HonorId }).ToArray()
        };
        internal static PartyStoryData Prepare(PartyStorySave saved, HashSet<int> actors, bool legacy = false, double minutes = 1000000000)
        {
            SaveCheck.Require(saved != null, "缺少同行关系"); var data = new PartyStoryData();
            SaveCheck.Require(legacy || saved.format==2,"partyStory.format");
            foreach (var row in SaveCheck.Rows(saved.bonds, actors.Count*(actors.Count-1)/2, "同行关系数量"))
            {
                SaveCheck.Require(row != null && actors.Contains(row.first) && actors.Contains(row.second) && row.first < row.second &&
                    row.score >= (legacy?0:-100) && row.score <= 100 && row.battles >= 0 && row.rescues >= 0 && row.battles <= 1000000 && row.rescues <= 1000000, "同行关系数据");
                SaveCheck.Require(data.Find(row.first, row.second) == null, "重复同行关系");
                SaveCheck.Require(legacy || (row.grievance>=0 && row.grievance<=100 && row.support>=0 && row.support<=1000000 &&
                    row.cooperation>=0 && row.cooperation<=1000000 && row.friendlyHits>=0 && row.friendlyHits<=1000000 &&
                    row.socialDay>=0 && row.socialDay<=Math.Floor(minutes/1440)+1),"partyStory.relationship");
                data.bonds.Add(new PartyBondData(row.first, row.second) { Score = row.score, SharedBattles = row.battles, Rescues = row.rescues,
                    Grievance=legacy?0:row.grievance,Support=legacy?0:row.support,Cooperation=legacy?0:row.cooperation,
                    FriendlyHits=legacy?0:row.friendlyHits,SocialDay=legacy?0:row.socialDay,Romance=!legacy&&row.romance });
            }
            foreach (var row in data.bonds.Where(value=>value.Romance))
                SaveCheck.Require(data.bonds.Count(value=>value.Romance && (value.FirstActorId==row.FirstActorId || value.SecondActorId==row.FirstActorId))==1 &&
                    data.bonds.Count(value=>value.Romance && (value.FirstActorId==row.SecondActorId || value.SecondActorId==row.SecondActorId))==1,"partyStory.romance.duplicate");
            foreach (var row in SaveCheck.Rows(saved.rescues, actors.Count, "个人救援数量"))
            {
                SaveCheck.Require(row != null && actors.Contains(row.id) && row.value > 0 && row.value <= 1000000 && !data.rescueCounts.ContainsKey(row.id), "个人救援计数");
                data.rescueCounts.Add(row.id, row.value);
            }
            SaveCheck.Require(data.rescueCounts.Values.Sum() == data.bonds.Sum(row => row.Rescues), "救援记录合计不一致");
            foreach (var row in SaveCheck.Rows(saved.honors, 10000, "荣誉数量"))
            {
                SaveCheck.Require(row != null && actors.Contains(row.actorId) && row.honorId > 0 && !data.HasHonor(row.actorId, row.honorId), "荣誉身份或重复记录");
                data.honors.Add(new PartyHonorData(row.actorId, row.honorId));
            }
            return data;
        }
        internal void Touch() { Revision++; }
        internal void TakePrepared(PartyStoryData prepared)
        {
            if (prepared == null || ReferenceEquals(this, prepared)) throw new ArgumentException("Invalid prepared party story.");
            Clear(); bonds.AddRange(prepared.bonds); honors.AddRange(prepared.honors);
            foreach (var row in prepared.rescueCounts) rescueCounts.Add(row.Key, row.Value);
            prepared.Clear();
        }
    }

    public sealed partial class AdventureData
    {
        public PartyStoryData PartyBonds { get; } = new PartyStoryData();
    }
}
