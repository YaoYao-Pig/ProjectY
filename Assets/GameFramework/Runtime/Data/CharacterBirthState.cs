using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    [Serializable] internal sealed class InitialAttributesSave
    {
        internal const int TemplateMode = 1, RolledMode = 2;
        public int mode, professionId;
        public AttributeEntry[] entries;
        internal static InitialAttributesSave Template() => new InitialAttributesSave
            { mode = TemplateMode, professionId = 0, entries = Array.Empty<AttributeEntry>() };
    }

    [Serializable] internal sealed class ProfessionAttributesSave
    {
        public int professionId;
        public AttributeEntry[] entries;
        internal static ProfessionAttributesSave Empty(int professionId) => new ProfessionAttributesSave
            { professionId = professionId, entries = Array.Empty<AttributeEntry>() };
    }

    /// <summary>Reflection bridge for immutable, instance-specific starting attributes.</summary>
    public static class CharacterBirthState
    {
        public static void Initialize(CombatActorData actor, int professionId, string[] names, int[] values)
            => Actor(actor).AssignInitialAttributes(professionId, names, values);
        public static void UseTemplate(CombatActorData actor) => Actor(actor).AssignTemplateAttributes();
        public static void AssignProfession(CombatActorData actor, int professionId, string[] names, int[] values)
            => Actor(actor).AssignProfessionAttributes(professionId, names, values);
        private static CombatActorData Actor(CombatActorData actor)
            => actor ?? throw new ArgumentNullException(nameof(actor));
    }

    public sealed partial class CombatActorData
    {
        private static readonly string[] PrimaryAttributeNames =
            { "vitality", "endurance", "intellect", "strength", "speed", "defense" };
        private readonly Dictionary<string, int> initialAttributes = new Dictionary<string, int>(StringComparer.Ordinal);
        private readonly List<string> initialAttributeNames = new List<string>();
        private sealed class ProfessionAttributeSet
        {
            internal readonly Dictionary<string, int> Values = new Dictionary<string, int>(StringComparer.Ordinal);
            internal readonly List<string> Names = new List<string>();
        }
        private readonly Dictionary<int, ProfessionAttributeSet> professionAttributeSets = new Dictionary<int, ProfessionAttributeSet>();
        private readonly List<int> professionAttributeIds = new List<int>();
        public bool InitialAttributesAssigned { get; private set; }
        public bool HasInitialAttributes => initialAttributes.Count > 0;
        public int InitialProfessionId { get; private set; }
        public int InitialAttributeCount => initialAttributeNames.Count;
        public string GetInitialAttributeNameAt(int index) => initialAttributeNames[index];
        public int GetInitialAttribute(string name) => initialAttributes.TryGetValue(name, out var value) ? value : 0;
        public bool HasProfessionAttributes(int professionId) => professionAttributeSets.ContainsKey(professionId);
        public int GetProfessionAttribute(int professionId, string name)
            => professionAttributeSets.TryGetValue(professionId, out var set) && set.Values.TryGetValue(name, out var value) ? value : 0;
        public int ProfessionAttributeSetCount => professionAttributeIds.Count;
        public int GetProfessionAttributeProfessionAt(int index) => professionAttributeIds[index];
        public int GetProfessionAttributeCount(int professionId) => professionAttributeSets[professionId].Names.Count;
        public string GetProfessionAttributeNameAt(int professionId, int index) => professionAttributeSets[professionId].Names[index];

        internal void AssignProfessionAttributes(int professionId, string[] names, int[] values)
        {
            if (professionId < 1) throw new ArgumentOutOfRangeException(nameof(professionId));
            if (professionAttributeSets.ContainsKey(professionId) || professionAttributeIds.Count >= 10000)
                throw new InvalidOperationException(nameof(professionId));
            if (names == null || values == null || names.Length != values.Length || names.Length > 128)
                throw new ArgumentException(nameof(names));
            var set = new ProfessionAttributeSet();
            for (int i = 0; i < names.Length; i++)
            {
                if (!ValidInitialAttributeName(names[i]) || values[i] < 0 || set.Values.ContainsKey(names[i]))
                    throw new ArgumentException(nameof(names));
                set.Values.Add(names[i], values[i]);
                set.Names.Add(names[i]);
            }
            // An empty set is still an assigned snapshot; switching back must never roll it again.
            professionAttributeSets.Add(professionId, set);
            professionAttributeIds.Add(professionId);
        }

        internal ProfessionAttributesSave[] CaptureProfessionAttributes()
        {
            var rows = new ProfessionAttributesSave[professionAttributeIds.Count];
            for (int i = 0; i < rows.Length; i++)
            {
                int professionId = professionAttributeIds[i];
                var set = professionAttributeSets[professionId];
                var entries = new AttributeEntry[set.Names.Count];
                for (int j = 0; j < entries.Length; j++)
                {
                    string name = set.Names[j];
                    entries[j] = new AttributeEntry { name = name, value = set.Values[name] };
                }
                rows[i] = new ProfessionAttributesSave { professionId = professionId, entries = entries };
            }
            return rows;
        }

        internal void RestoreProfessionAttributes(ProfessionAttributesSave[] rows)
        {
            if (professionAttributeIds.Count != 0) throw new InvalidOperationException(nameof(professionAttributeIds));
            var prepared = new List<KeyValuePair<int, ProfessionAttributeSet>>();
            var ids = new HashSet<int>();
            foreach (var row in SaveCheck.Rows(rows, 10000, "professionAttributes"))
            {
                SaveCheck.Require(row != null && row.professionId > 0 && ids.Add(row.professionId), "professionAttributes.professionId");
                var set = new ProfessionAttributeSet();
                foreach (var entry in SaveCheck.Rows(row.entries, 128, "professionAttributes.entries"))
                {
                    SaveCheck.Require(entry != null && ValidInitialAttributeName(entry.name) && entry.value >= 0 && !set.Values.ContainsKey(entry.name),
                        "professionAttributes.entry");
                    set.Values.Add(entry.name, entry.value);
                    set.Names.Add(entry.name);
                }
                prepared.Add(new KeyValuePair<int, ProfessionAttributeSet>(row.professionId, set));
            }
            // Validate the complete array before committing any profession to this actor.
            foreach (var row in prepared)
            {
                professionAttributeSets.Add(row.Key, row.Value);
                professionAttributeIds.Add(row.Key);
            }
        }

        internal void AssignTemplateAttributes()
        {
            if (InitialAttributesAssigned) throw new InvalidOperationException(nameof(InitialAttributesAssigned));
            InitialAttributesAssigned = true;
        }

        internal void AssignInitialAttributes(int professionId, string[] names, int[] values)
        {
            if (InitialAttributesAssigned) throw new InvalidOperationException(nameof(InitialAttributesAssigned));
            if (professionId < 1) throw new ArgumentOutOfRangeException(nameof(professionId));
            if (names == null || values == null || names.Length != values.Length || names.Length < PrimaryAttributeNames.Length || names.Length > 128)
                throw new ArgumentException(nameof(names));
            var seen = new HashSet<string>(StringComparer.Ordinal);
            for (int i = 0; i < names.Length; i++)
                if (!ValidInitialAttributeName(names[i]) || values[i] < 0 || !seen.Add(names[i]))
                    throw new ArgumentException(nameof(names));
            foreach (var name in PrimaryAttributeNames)
                if (!seen.Contains(name)) throw new ArgumentException(nameof(names));
            // Validate every entry before committing; a failed assignment must not partially initialize the actor.
            for (int i = 0; i < names.Length; i++)
            {
                initialAttributes.Add(names[i], values[i]);
                initialAttributeNames.Add(names[i]);
            }
            InitialProfessionId = professionId;
            InitialAttributesAssigned = true;
        }

        private static bool ValidInitialAttributeName(string name)
        {
            if (string.IsNullOrEmpty(name) || name.Length > 64 || name[0] < 'a' || name[0] > 'z') return false;
            for (int i = 1; i < name.Length; i++)
            {
                char c = name[i];
                if (!(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_')) return false;
            }
            return true;
        }

        internal InitialAttributesSave CaptureInitialAttributes()
        {
            // Pure Data fixtures predate birth assignment; explicitly persist their existing template semantics.
            if (!HasInitialAttributes) return InitialAttributesSave.Template();
            var entries = new AttributeEntry[initialAttributeNames.Count];
            for (int i = 0; i < entries.Length; i++)
            {
                string name = initialAttributeNames[i];
                entries[i] = new AttributeEntry { name = name, value = initialAttributes[name] };
            }
            return new InitialAttributesSave { mode = InitialAttributesSave.RolledMode, professionId = InitialProfessionId, entries = entries };
        }

        internal void RestoreInitialAttributes(InitialAttributesSave row)
        {
            SaveCheck.Require(row != null, "initialAttributes");
            SaveCheck.Require(row.mode == InitialAttributesSave.TemplateMode || row.mode == InitialAttributesSave.RolledMode, "initialAttributes.mode");
            var entries = SaveCheck.Rows(row.entries, 128, "initialAttributes.entries");
            if (row.mode == InitialAttributesSave.TemplateMode)
            {
                SaveCheck.Require(row.professionId == 0 && entries.Length == 0, "initialAttributes.template");
                AssignTemplateAttributes();
                return;
            }
            SaveCheck.Require(row.professionId > 0 && entries.Length >= PrimaryAttributeNames.Length, "initialAttributes.rolled");
            var names = new string[entries.Length];
            var values = new int[entries.Length];
            var seen = new HashSet<string>(StringComparer.Ordinal);
            for (int i = 0; i < entries.Length; i++)
            {
                var entry = entries[i];
                SaveCheck.Require(entry != null && ValidInitialAttributeName(entry.name) && entry.value >= 0 && seen.Add(entry.name), "initialAttributes.entry");
                names[i] = entry.name;
                values[i] = entry.value;
            }
            foreach (var name in PrimaryAttributeNames) SaveCheck.Require(seen.Contains(name), "initialAttributes.primary");
            AssignInitialAttributes(row.professionId, names, values);
        }
    }
}
