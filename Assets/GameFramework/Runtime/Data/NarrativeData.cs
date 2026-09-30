using System;
using System.Collections.Generic;
using System.Linq;
using XLua;

namespace ProjectY.Data
{
    [Serializable] internal sealed class NarrativeValueSave { public string key; public int value; }
    [Serializable] internal sealed class NarrativeProgressSave { public string kind, state; public int id; public IntEntry[] baseline; }
    [Serializable] internal sealed class NarrativeSave
    { public double minutes; public NarrativeValueSave[] values; public IntEntry[] kills; public NarrativeProgressSave[] progress; }

    [LuaCallCSharp]
    public sealed class NarrativeProgressData
    {
        public string Kind { get; }
        public int Id { get; }
        public string State { get; internal set; } = "active";
        internal readonly Dictionary<int, int> Baseline;
        internal NarrativeProgressData(string kind, int id, Dictionary<int, int> kills)
        { Kind = kind; Id = id; Baseline = new Dictionary<int, int>(kills); }
    }

    [LuaCallCSharp]
    public sealed class DialogueLineData
    {
        public string Speaker { get; }
        public string Text { get; }
        public bool IsChoice { get; }
        internal DialogueLineData(string speaker, string text, bool choice) { Speaker = speaker; Text = text; IsChoice = choice; }
    }

    /// <summary>任务进度、事实、NPC 关系与游戏时钟的唯一可变状态。对话会话不写入磁盘。</summary>
    [LuaCallCSharp]
    public sealed class NarrativeData
    {
        private readonly Dictionary<string, int> values = new Dictionary<string, int>();
        private readonly Dictionary<int, int> kills = new Dictionary<int, int>();
        private readonly List<NarrativeProgressData> progress = new List<NarrativeProgressData>();
        private readonly List<DialogueLineData> lines = new List<DialogueLineData>();
        public int Revision { get; private set; }
        public double Minutes { get; private set; }
        public int ProgressCount => progress.Count;
        public NarrativeProgressData GetProgressAt(int index) => progress[index];
        public int ValueCount => values.Count;
        public string GetValueKeyAt(int index) => values.Keys.ElementAt(index);
        public int GetValue(string key) => values.TryGetValue(key, out var value) ? value : 0;
        public void SetValue(string key, int value)
        {
            if (string.IsNullOrWhiteSpace(key)) throw new ArgumentException("Missing narrative fact key.");
            if (GetValue(key) == value) return;
            values[key] = value; Revision++;
        }
        private static string ProgressKey(string kind, int id)
        {
            if ((kind != "mission" && kind != "quest") || id <= 0) throw new ArgumentException("Invalid narrative progress key.");
            return kind + ":" + id;
        }
        private NarrativeProgressData Find(string kind, int id)
        { ProgressKey(kind, id); return progress.Find(row => row.Kind == kind && row.Id == id); }
        public string Status(string kind, int id) => Find(kind, id)?.State ?? "inactive";
        public void Begin(string kind, int id)
        {
            if (Find(kind, id) != null) throw new InvalidOperationException("Narrative node already accepted.");
            progress.Add(new NarrativeProgressData(kind, id, kills)); Revision++;
        }
        public void Ready(string kind, int id)
        {
            var row = Find(kind, id);
            if (row == null || row.State != "active") throw new InvalidOperationException("Narrative node is not active.");
            row.State = "ready"; Revision++;
        }
        public void Complete(string kind, int id)
        {
            var row = Find(kind, id);
            if (row == null || row.State != "ready") throw new InvalidOperationException("Narrative node is not ready.");
            row.State = "completed"; Revision++;
        }
        public void RecordKill(int templateId)
        {
            if (templateId <= 0) throw new ArgumentOutOfRangeException(nameof(templateId));
            kills[templateId] = checked((kills.TryGetValue(templateId, out var count) ? count : 0) + 1); Revision++;
        }
        public int KillCount(string kind, int id, int templateId)
        {
            var row = Find(kind, id) ?? throw new InvalidOperationException("Kill condition needs an accepted mission/quest context.");
            return (kills.TryGetValue(templateId, out var total) ? total : 0) - (row.Baseline.TryGetValue(templateId, out var initial) ? initial : 0);
        }
        public void AdvanceMinutes(double minutes)
        {
            if (double.IsNaN(minutes) || double.IsInfinity(minutes) || minutes < 0 || Minutes + minutes > 1000000000)
                throw new ArgumentOutOfRangeException(nameof(minutes));
            Minutes += minutes;
        }
        public bool DialogueOpen => DialogueId != 0;
        public int DialogueId { get; private set; }
        public int DialogueNodeId { get; private set; }
        public int DialogueNpcId { get; private set; }
        public int DialogueLocalNpcId { get; private set; }
        public int DialogueActorId { get; private set; }
        public int DialogueVersion { get; private set; }
        public int LineCount => lines.Count;
        public DialogueLineData GetLineAt(int index) => lines[index];
        public void BeginDialogue(int dialogue, int npc, int localNpc, int actor)
        {
            if (DialogueOpen || dialogue <= 0 || npc <= 0 || localNpc <= 0 || actor <= 0) throw new InvalidOperationException("Invalid dialogue session.");
            DialogueId = dialogue; DialogueNpcId = npc; DialogueLocalNpcId = localNpc; DialogueActorId = actor;
            lines.Clear(); DialogueVersion++; Revision++;
        }
        public void EnterDialogueNode(int node)
        {
            if (!DialogueOpen || node <= 0) throw new InvalidOperationException("No dialogue session.");
            DialogueNodeId = node; DialogueVersion++; Revision++;
        }
        public void AddDialogueLine(string speaker, string text, bool choice)
        {
            if (!DialogueOpen || string.IsNullOrEmpty(speaker) || string.IsNullOrEmpty(text)) throw new ArgumentException("Invalid dialogue line.");
            lines.Add(new DialogueLineData(speaker, text, choice)); Revision++;
        }
        public void CloseDialogue()
        {
            DialogueId = DialogueNodeId = DialogueNpcId = DialogueLocalNpcId = DialogueActorId = 0;
            lines.Clear(); DialogueVersion++; Revision++;
        }
        public void Clear()
        { values.Clear(); kills.Clear(); progress.Clear(); Minutes = 0; CloseDialogue(); }
        internal NarrativeSave Capture() => new NarrativeSave {
            minutes = Minutes, values = values.Select(p => new NarrativeValueSave { key = p.Key, value = p.Value }).ToArray(),
            kills = kills.Select(p => new IntEntry { id = p.Key, value = p.Value }).ToArray(),
            progress = progress.Select(p => new NarrativeProgressSave { kind = p.Kind, id = p.Id, state = p.State,
                baseline = p.Baseline.Select(k => new IntEntry { id = k.Key, value = k.Value }).ToArray() }).ToArray() };
        internal static NarrativeData Prepare(NarrativeSave save)
        {
            SaveCheck.Require(save != null && !double.IsNaN(save.minutes) && !double.IsInfinity(save.minutes) && save.minutes >= 0 && save.minutes <= 1000000000, "叙事时间");
            var result = new NarrativeData(); result.Minutes = save.minutes;
            foreach (var row in SaveCheck.Rows(save.values, 20000, "叙事事实"))
            { SaveCheck.Require(row != null && !string.IsNullOrWhiteSpace(row.key) && row.key.Length <= 160 && !result.values.ContainsKey(row.key), "重复叙事事实"); result.values.Add(row.key, row.value); }
            foreach (var row in SaveCheck.Rows(save.kills, 10000, "击杀统计"))
            { SaveCheck.Require(row != null && row.id > 0 && row.value >= 0 && !result.kills.ContainsKey(row.id), "击杀计数"); result.kills.Add(row.id, row.value); }
            var keys = new HashSet<string>();
            foreach (var row in SaveCheck.Rows(save.progress, 20000, "任务进度"))
            {
                SaveCheck.Require(row != null && (row.kind == "mission" || row.kind == "quest") && row.id > 0 &&
                    (row.state == "active" || row.state == "ready" || row.state == "completed") && keys.Add(row.kind + ":" + row.id), "任务身份或状态");
                var baseline = new Dictionary<int, int>();
                foreach (var item in SaveCheck.Rows(row.baseline, 10000, "任务击杀起点"))
                { SaveCheck.Require(item != null && item.id > 0 && item.value >= 0 && result.kills.TryGetValue(item.id, out var total) && item.value <= total && !baseline.ContainsKey(item.id), "任务击杀起点"); baseline.Add(item.id, item.value); }
                result.progress.Add(new NarrativeProgressData(row.kind, row.id, baseline) { State = row.state });
            }
            return result;
        }
        internal void TakePrepared(NarrativeData source)
        {
            Clear(); Minutes = source.Minutes;
            foreach (var value in source.values) values.Add(value.Key, value.Value);
            foreach (var kill in source.kills) kills.Add(kill.Key, kill.Value);
            foreach (var row in source.progress) progress.Add(new NarrativeProgressData(row.Kind, row.Id, row.Baseline) { State = row.State });
            Revision++;
        }
    }
}
