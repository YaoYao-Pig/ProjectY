using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class BattleData
    {
        private readonly List<CombatActorData> units = new List<CombatActorData>();
        private readonly List<int> order = new List<int>();
        private readonly List<string> logs = new List<string>();
        private uint hitState = 1;
        public void SetRandomSeed(uint seed) { hitState = seed == 0 ? 1u : seed; }
        public int RollPercent()
        {
            hitState ^= hitState << 13; hitState ^= hitState >> 17; hitState ^= hitState << 5;
            return (int)(hitState % 100);
        }
        public int EncounterId { get; private set; }
        public int MaxRounds { get; private set; }
        public int Round { get; private set; }
        public int ActiveId { get; private set; }
        public int TurnIndex { get; private set; }
        public string Winner { get; private set; } = "";
        public int UnitCount => units.Count;
        public int TurnCount => order.Count;
        public int LogCount => logs.Count;
        public CombatActorData GetUnitAt(int index) => units[index];
        public int GetTurnAt(int index) => order[index];
        public string GetLogAt(int index) => logs[index];
        public void Clear()
        {
            units.Clear(); order.Clear(); logs.Clear();
            EncounterId = 0; MaxRounds = 0; Round = 0; ActiveId = 0; TurnIndex = 0; Winner = "";
        }
        public void Reset(int encounterId, int maxRounds)
        {
            if (encounterId < 1 || maxRounds < 1) throw new ArgumentOutOfRangeException(nameof(encounterId));
            Clear(); EncounterId = encounterId; MaxRounds = maxRounds;
        }
        public void AddUnit(CombatActorData unit, int team, int q, int r)
        {
            if (unit == null || Round != 0 || EncounterId == 0) throw new InvalidOperationException("Invalid deployment.");
            foreach (var other in units)
                if (other.Id == unit.Id || (other.Q == q && other.R == r)) throw new InvalidOperationException("Duplicate actor or spawn.");
            unit.Deploy(team, q, r); units.Add(unit);
        }
        public CombatActorData AddEnemy(int id, int templateId, int q, int r)
        {
            var unit = new CombatActorData(id, templateId); AddUnit(unit, 2, q, r); return unit;
        }
        public void BeginRound()
        {
            if (Winner != "" || Round >= MaxRounds) throw new InvalidOperationException("Battle cannot advance.");
            Round++; order.Clear();
        }
        public void AddTurn(int id)
        {
            if (order.Contains(id) || !units.Exists(unit => unit.Id == id && unit.HP > 0))
                throw new InvalidOperationException("Invalid turn order actor.");
            order.Add(id);
        }
        public void SelectTurn(int index) { ActiveId = order[index]; TurnIndex = index; }
        public void Finish(string winner)
        {
            if (Winner != "" || (winner != "victory" && winner != "defeat" && winner != "draw"))
                throw new InvalidOperationException("Invalid or duplicate battle result.");
            Winner = winner;
        }
        public void AddLog(string message)
        {
            if (string.IsNullOrEmpty(message)) throw new ArgumentException("Battle log is empty.", nameof(message));
            if (logs.Count == 80) logs.RemoveAt(0);
            logs.Add(message);
        }
    }
}
