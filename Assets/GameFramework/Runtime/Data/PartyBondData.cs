using System;
using System.Collections.Generic;
using System.Linq;
using XLua;

namespace ProjectY.Data
{
    [Serializable] internal sealed class PartyBondSave { public int first, second, score, battles, rescues; }
    [Serializable] internal sealed class PartyHonorSave { public int actorId, honorId; }
    [Serializable] internal sealed class PartyStorySave
    { public PartyBondSave[] bonds; public IntEntry[] rescues; public PartyHonorSave[] honors; }

    /// <summary>无向队员关系；双方共用一份记录，救援总数与个人救援计数分别保存。</summary>
    [LuaCallCSharp]
    public sealed class PartyBondData
    {
        public int FirstActorId { get; }
        public int SecondActorId { get; }
        public int Score { get; internal set; }
        public int SharedBattles { get; internal set; }
        public int Rescues { get; internal set; }
        internal PartyBondData(int first, int second) { FirstActorId = first; SecondActorId = second; }
        internal PartyBondSave Capture() => new PartyBondSave { first = FirstActorId, second = SecondActorId, score = Score, battles = SharedBattles, rescues = Rescues };
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
        private bool battleOpen;
        public int Revision { get; private set; }
        public int BondCount => bonds.Count;
        public int HonorCount => honors.Count;
        public int ParticipantCount => participants.Count;
        public PartyBondData GetBondAt(int index) => bonds[index];
        public PartyHonorData GetHonorAt(int index) => honors[index];
        public CombatActorData GetParticipantAt(int index) => participants[index];
        private static string PairKey(int first, int second) => Math.Min(first, second) + ":" + Math.Max(first, second);
        private static void CheckPair(int first, int second)
        { if (first <= 0 || second <= 0 || first == second) throw new ArgumentException("A party bond needs two different actors."); }
        public PartyBondData Find(int first, int second)
        {
            CheckPair(first, second); int a = Math.Min(first, second), b = Math.Max(first, second);
            return bonds.Find(row => row.FirstActorId == a && row.SecondActorId == b);
        }
        private PartyBondData GetOrAdd(int first, int second)
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
        public void ResetBattle() { participants.Clear(); rescuedPairs.Clear(); battleOpen = false; }
        public void BeginBattle() { ResetBattle(); battleOpen = true; }
        public void AddParticipant(CombatActorData actor)
        {
            if (!battleOpen || actor == null || actor.Team != 1 || actor.HP <= 0 || IsParticipant(actor.Id))
                throw new InvalidOperationException("Invalid party story battle participant.");
            participants.Add(actor);
        }
        public bool IsParticipant(int actorId) => participants.Exists(actor => actor.Id == actorId);
        public bool TryRescue(int sourceId, int targetId, int amount)
        {
            CheckPair(sourceId, targetId);
            if (!battleOpen || !IsParticipant(sourceId) || !IsParticipant(targetId) || amount <= 0 || amount > 100)
                throw new InvalidOperationException("Rescue is outside the current party battle.");
            if (!rescuedPairs.Add(PairKey(sourceId, targetId))) return false;
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
                    if (participants[i].HP <= 0 || participants[j].HP <= 0) continue;
                    var row = GetOrAdd(participants[i].Id, participants[j].Id);
                    row.Score = Math.Min(100, row.Score + amount); row.SharedBattles++; Revision++;
                }
            return true;
        }
        public void Clear() { bonds.Clear(); rescueCounts.Clear(); honors.Clear(); ResetBattle(); Revision++; }
        internal PartyStorySave Capture() => new PartyStorySave
        {
            bonds = bonds.Select(row => row.Capture()).ToArray(),
            rescues = rescueCounts.Select(row => new IntEntry { id = row.Key, value = row.Value }).ToArray(),
            honors = honors.Select(row => new PartyHonorSave { actorId = row.ActorId, honorId = row.HonorId }).ToArray()
        };
        internal static PartyStoryData Prepare(PartyStorySave saved, HashSet<int> actors)
        {
            SaveCheck.Require(saved != null, "缺少同行关系"); var data = new PartyStoryData();
            foreach (var row in SaveCheck.Rows(saved.bonds, 6, "同行关系数量"))
            {
                SaveCheck.Require(row != null && actors.Contains(row.first) && actors.Contains(row.second) && row.first < row.second &&
                    row.score >= 0 && row.score <= 100 && row.battles >= 0 && row.rescues >= 0 && row.battles <= 1000000 && row.rescues <= 1000000, "同行关系数据");
                SaveCheck.Require(data.Find(row.first, row.second) == null, "重复同行关系");
                data.bonds.Add(new PartyBondData(row.first, row.second) { Score = row.score, SharedBattles = row.battles, Rescues = row.rescues });
            }
            foreach (var row in SaveCheck.Rows(saved.rescues, 4, "个人救援数量"))
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
