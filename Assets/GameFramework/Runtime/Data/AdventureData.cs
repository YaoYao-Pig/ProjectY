using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    /// <summary>远征会话与事件状态；队伍和战斗共享角色实例，无 Lua 可变状态副本。</summary>
    [LuaCallCSharp]
    public sealed class AdventureData
    {
        private readonly List<CombatActorData> party = new List<CombatActorData>();
        private readonly HashSet<int> visited = new HashSet<int>();
        public BattleData Battle { get; } = new BattleData();
        public MapAreaData Areas { get; } = new MapAreaData();
        public uint Seed { get; private set; }
        public string Phase { get; private set; } = "map";
        public int SiteId { get; private set; }
        public int EventId { get; private set; }
        public int ChoiceId { get; private set; }
        public string ResultText { get; private set; } = "";
        public int PartyCount => party.Count;
        public CombatActorData GetPartyAt(int index) => party[index];
        public bool HasVisited(int siteId) => visited.Contains(siteId);
        public void Reset(uint seed)
        {
            Seed = seed; party.Clear(); visited.Clear(); Battle.Clear(); Areas.Clear();
            Phase = "map"; SiteId = 0; EventId = 0; ChoiceId = 0; ResultText = "";
        }
        private void RequirePhase(string phase)
        {
            if (Phase != phase) throw new InvalidOperationException("Expected adventure phase " + phase + ", got " + Phase);
        }
        public CombatActorData AddPartyActor(int id, int templateId)
        {
            RequirePhase("map");
            if (party.Count >= 4) throw new InvalidOperationException("The adventure squad supports at most four members.");
            if (party.Exists(member => member.Id == id)) throw new InvalidOperationException("Duplicate party actor.");
            var actor = new CombatActorData(id, templateId); party.Add(actor); return actor;
        }
        public void BeginEvent(int siteId, int eventId)
        {
            RequirePhase("map");
            if (siteId < 1 || eventId < 1) throw new ArgumentOutOfRangeException(nameof(siteId));
            SiteId = siteId; EventId = eventId; ChoiceId = 0; ResultText = ""; Phase = "event";
        }
        public void ResolveChoice(int choiceId)
        {
            RequirePhase("event");
            if (choiceId < 1) throw new ArgumentOutOfRangeException(nameof(choiceId));
            ChoiceId = choiceId; visited.Add(SiteId); Phase = "resolving";
        }
        public void BeginBattle() { RequirePhase("resolving"); Phase = "battle"; }
        // 地点探索独立于旧事件的立即开战流程；重复进入保留同地点的探索记录。
        public void BeginArea(int siteId)
        {
            RequirePhase("map");
            if (siteId < 1 || Areas.ActiveSiteId != siteId) throw new InvalidOperationException("MapArea entry is not prepared.");
            SiteId = siteId; EventId = 0; ChoiceId = 0; ResultText = ""; Phase = "area"; visited.Add(siteId);
        }
        public void LeaveArea()
        {
            RequirePhase("area"); Areas.Leave(); SiteId = 0; Phase = "map";
        }
        public void BeginSettlement() { RequirePhase("battle"); Phase = "resolving"; }
        public void Complete(string result)
        {
            RequirePhase("resolving");
            if (string.IsNullOrEmpty(result)) throw new ArgumentException("Missing event result.", nameof(result));
            ResultText = result; Phase = "result";
        }
        public void ReturnToMap()
        {
            RequirePhase("result"); Phase = "map"; Battle.Clear(); SiteId = 0; EventId = 0; ChoiceId = 0; ResultText = "";
        }
    }
}
