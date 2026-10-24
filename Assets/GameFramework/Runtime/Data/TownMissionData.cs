using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    [Serializable] internal sealed class TownMissionSave
    {
        public int format, nextId, attachedId;
        public IntEntry[] days;
        public TownMissionInstanceSave[] missions;
    }

    [Serializable] internal sealed class TownMissionInstanceSave
    {
        public int id, definitionId, siteId, npcId, day, targetId, requiredCount, progress, destinationSiteId, partyId;
        public string state;
    }

    /// <summary>A repeatable commission has a stable instance identity independent of its definition and local NPC index.</summary>
    public sealed class TownMissionInstance
    {
        public int Id { get; }
        public int DefinitionId { get; }
        public int SiteId { get; }
        public int NpcId { get; }
        public int Day { get; }
        public int TargetId { get; }
        public int RequiredCount { get; }
        public int Progress { get; internal set; }
        public int DestinationSiteId { get; internal set; }
        public int PartyId { get; internal set; }
        public string State { get; internal set; } = "offered";

        internal TownMissionInstance(int id, int definitionId, int siteId, int npcId, int day, int targetId, int requiredCount)
        {
            Id = id; DefinitionId = definitionId; SiteId = siteId; NpcId = npcId; Day = day;
            TargetId = targetId; RequiredCount = requiredCount;
        }

        internal TownMissionInstanceSave Capture() => new TownMissionInstanceSave {
            id = Id, definitionId = DefinitionId, siteId = SiteId, npcId = NpcId, day = Day, targetId = TargetId,
            requiredCount = RequiredCount, progress = Progress, destinationSiteId = DestinationSiteId, partyId = PartyId, state = State };

        internal static TownMissionInstance FromSave(TownMissionInstanceSave row)
            => new TownMissionInstance(row.id, row.definitionId, row.siteId, row.npcId, row.day, row.targetId, row.requiredCount) {
                Progress = row.progress, DestinationSiteId = row.destinationSiteId, PartyId = row.partyId, State = row.state };
    }

    /// <summary>Persistent town commissions; static accessors use the existing reflection bridge convention.</summary>
    public sealed class TownMissionData
    {
        private const int MaximumMissions = 20000, MaximumSites = 100000, MaximumDay = 1000000;
        private readonly List<TownMissionInstance> missions = new List<TownMissionInstance>();
        private readonly Dictionary<int, TownMissionInstance> byId = new Dictionary<int, TownMissionInstance>();
        private readonly Dictionary<int, int> days = new Dictionary<int, int>();
        private readonly Action changed;
        private int nextId = 1;

        internal TownMissionData(Action onChanged = null) { changed = onChanged; }
        public static TownMissionData For(NarrativeData narrative)
            => (narrative ?? throw new ArgumentNullException(nameof(narrative))).TownMissions;
        public static TownMissionData Prepared(PreparedCharacterSave prepared)
        {
            if (prepared == null) throw new ArgumentNullException(nameof(prepared));
            if (prepared.Consumed || prepared.Narrative == null)
                throw new InvalidOperationException("Town commissions have not been prepared or were already committed.");
            return prepared.Narrative.TownMissions;
        }

        public int Revision { get; private set; }
        public int Count => missions.Count;
        public int AttachedId { get; private set; }
        public TownMissionInstance GetAt(int index) => missions[index];
        public TownMissionInstance Find(int id) => byId.TryGetValue(id, out var row) ? row : null;
        public int GetDay(int siteId)
        {
            if (siteId <= 0) throw new ArgumentOutOfRangeException(nameof(siteId));
            return days.TryGetValue(siteId, out var day) ? day : -1;
        }
        private void Changed() { Revision++; changed?.Invoke(); }
        private TownMissionInstance RequireState(int id, string state)
        {
            var row = Find(id);
            if (row == null || row.State != state) throw new InvalidOperationException("Town commission is not " + state + ".");
            return row;
        }
        private static bool ValidDay(int day) => day >= 0 && day <= MaximumDay;
        private static bool ValidState(string state)
            => state == "offered" || state == "active" || state == "ready" || state == "completed" || state == "failed";

        public void BeginDay(int siteId, int day)
        {
            if (siteId <= 0 || !ValidDay(day)) throw new ArgumentOutOfRangeException(nameof(day));
            int previous = GetDay(siteId);
            if (day < previous) throw new InvalidOperationException("Town commission day cannot move backwards.");
            if (day == previous) return;
            if (previous < 0 && days.Count >= MaximumSites) throw new InvalidOperationException("Too many commission towns.");
            for (int index = missions.Count - 1; index >= 0; index--)
            {
                var row = missions[index];
                if (row.SiteId != siteId || row.State != "offered") continue;
                byId.Remove(row.Id); missions.RemoveAt(index);
            }
            days[siteId] = day; Changed();
        }

        public TownMissionInstance Add(int definitionId, int siteId, int npcId, int day, int targetId, int requiredCount)
        {
            if (definitionId <= 0 || siteId <= 0 || npcId <= 0 || !ValidDay(day) || targetId < 0 || requiredCount <= 0)
                throw new ArgumentException("Invalid town commission definition.");
            if (GetDay(siteId) != day || missions.Count >= MaximumMissions || nextId == int.MaxValue)
                throw new InvalidOperationException("Town commission day is not initialized or capacity is exhausted.");
            if (missions.Count(row => row.SiteId == siteId && row.Day == day) >= 5)
                throw new InvalidOperationException("A town can offer at most five commissions each day.");
            var instance = new TownMissionInstance(nextId++, definitionId, siteId, npcId, day, targetId, requiredCount);
            missions.Add(instance); byId.Add(instance.Id, instance); Changed(); return instance;
        }

        public void Accept(int id) { RequireState(id, "offered").State = "active"; Changed(); }

        public void SetEscort(int id, int partyId, int destinationSiteId)
        {
            var row = RequireState(id, "active");
            if (partyId <= 0 || destinationSiteId <= 0 || destinationSiteId == row.SiteId)
                throw new ArgumentException("An escort needs a caravan and another destination town.");
            if (row.PartyId == partyId && row.DestinationSiteId == destinationSiteId) return;
            if (row.PartyId != 0 || missions.Any(other => other.Id != id && other.PartyId == partyId &&
                    (other.State == "active" || other.State == "ready")))
                throw new InvalidOperationException("The caravan is already assigned to a commission.");
            row.PartyId = partyId; row.DestinationSiteId = destinationSiteId; Changed();
        }

        public void AddProgress(int id, int count)
        {
            var row = RequireState(id, "active");
            if (count <= 0) throw new ArgumentOutOfRangeException(nameof(count));
            int progress = (int)Math.Min(row.RequiredCount, (long)row.Progress + count);
            if (progress == row.Progress) return;
            row.Progress = progress; Changed();
        }

        public void Ready(int id)
        {
            var row = RequireState(id, "active");
            if (row.Progress != row.RequiredCount) throw new InvalidOperationException("Town commission objectives are incomplete.");
            row.State = "ready"; if (AttachedId == id) AttachedId = 0; Changed();
        }

        public void Fail(int id)
        {
            var row = RequireState(id, "active");
            row.State = "failed"; if (AttachedId == id) AttachedId = 0; Changed();
        }

        public void Complete(int id)
        {
            var row = RequireState(id, "ready");
            row.State = "completed"; if (AttachedId == id) AttachedId = 0; Changed();
        }

        public void SetAttached(int id)
        {
            if (id != 0)
            {
                var row = RequireState(id, "active");
                if (row.PartyId <= 0 || row.DestinationSiteId <= 0) throw new InvalidOperationException("Only an active escort can be attached.");
            }
            if (AttachedId == id) return;
            AttachedId = id; Changed();
        }

        internal void Clear()
        { missions.Clear(); byId.Clear(); days.Clear(); nextId = 1; AttachedId = 0; Changed(); }

        internal TownMissionSave Capture() => new TownMissionSave {
            format = 1, nextId = nextId, attachedId = AttachedId,
            days = days.OrderBy(row => row.Key).Select(row => new IntEntry { id = row.Key, value = row.Value }).ToArray(),
            missions = missions.Select(row => row.Capture()).ToArray() };

        internal static TownMissionData Prepare(TownMissionSave saved, int currentDay)
        {
            var data = new TownMissionData();
            // Missing inline classes may deserialize as an empty object in JsonUtility; accept only the old empty shape.
            if (saved == null) return data;
            if (saved.format == 0)
            {
                SaveCheck.Require(saved.nextId == 0 && saved.attachedId == 0 &&
                    (saved.days == null || saved.days.Length == 0) && (saved.missions == null || saved.missions.Length == 0), "旧版城镇委托记录");
                return data;
            }
            SaveCheck.Require(saved.format == 1 && saved.nextId > 0 && saved.attachedId >= 0, "城镇委托格式或序号");
            foreach (var row in SaveCheck.Rows(saved.days, MaximumSites, "城镇委托日期"))
            {
                SaveCheck.Require(row != null && row.id > 0 && ValidDay(row.value) && row.value <= currentDay && !data.days.ContainsKey(row.id), "城镇委托日期重复或越界");
                data.days.Add(row.id, row.value);
            }
            var escortParties = new HashSet<int>();
            var dailyCounts = new Dictionary<long, int>();
            foreach (var row in SaveCheck.Rows(saved.missions, MaximumMissions, "城镇委托数量"))
            {
                SaveCheck.Require(row != null && row.id > 0 && row.id < saved.nextId && !data.byId.ContainsKey(row.id) &&
                    row.definitionId > 0 && row.siteId > 0 && row.npcId > 0 && ValidDay(row.day) && row.targetId >= 0 &&
                    row.requiredCount > 0 && row.progress >= 0 && row.progress <= row.requiredCount && ValidState(row.state), "城镇委托身份、状态或进度");
                SaveCheck.Require(data.days.TryGetValue(row.siteId, out var day) && row.day <= day &&
                    (row.state != "offered" || row.day == day && row.progress == 0), "城镇委托日期归属");
                SaveCheck.Require(row.partyId >= 0 && row.destinationSiteId >= 0 &&
                    (row.partyId == 0 ? row.destinationSiteId == 0 : row.destinationSiteId > 0 && row.destinationSiteId != row.siteId && row.state != "offered"), "护送商队引用");
                SaveCheck.Require((row.state != "ready" && row.state != "completed") || row.progress == row.requiredCount, "已达成委托进度不足");
                if (row.partyId > 0 && (row.state == "active" || row.state == "ready"))
                    SaveCheck.Require(escortParties.Add(row.partyId), "重复护送商队");
                long dailyKey = ((long)row.siteId << 32) | (uint)row.day;
                int count = dailyCounts.TryGetValue(dailyKey, out var prior) ? prior + 1 : 1;
                SaveCheck.Require(count <= 5, "同日城镇委托超过上限"); dailyCounts[dailyKey] = count;
                var instance = TownMissionInstance.FromSave(row); data.missions.Add(instance); data.byId.Add(instance.Id, instance);
            }
            if (saved.attachedId != 0)
            {
                var attached = data.Find(saved.attachedId);
                SaveCheck.Require(attached != null && attached.State == "active" && attached.PartyId > 0 && attached.DestinationSiteId > 0, "无效的护送附身引用");
            }
            data.nextId = saved.nextId; data.AttachedId = saved.attachedId; return data;
        }

        internal void TakePrepared(TownMissionData source)
        {
            if (source == null || ReferenceEquals(this, source)) throw new ArgumentException("Invalid prepared town commissions.");
            missions.Clear(); byId.Clear(); days.Clear();
            foreach (var day in source.days) days.Add(day.Key, day.Value);
            foreach (var row in source.missions)
            {
                var instance = TownMissionInstance.FromSave(row.Capture());
                missions.Add(instance); byId.Add(instance.Id, instance);
            }
            nextId = source.nextId; AttachedId = source.AttachedId; Changed();
        }
    }
}
