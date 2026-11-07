using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    /// <summary>Reflection entry point; inspection knowledge belongs to the current campaign.</summary>
    public static class UnitInspections
    {
        public static UnitInspectionData Get(AdventureData adventure)
            => (adventure ?? throw new ArgumentNullException(nameof(adventure))).Inspections;
        public static UnitInspectionData Prepared(PreparedCharacterSave prepared)
        {
            if (prepared == null) throw new ArgumentNullException(nameof(prepared));
            if (prepared.Consumed || prepared.Inspections == null)
                throw new InvalidOperationException("Inspection data is not prepared or has already been committed.");
            return prepared.Inspections;
        }
        public static bool NeedsTraitMigration(PreparedCharacterSave prepared)
        { Prepared(prepared); return prepared.LegacyInspectionTraits; }
        public static void CompleteTraitMigration(PreparedCharacterSave prepared)
        {
            Prepared(prepared);
            if (!prepared.LegacyInspectionTraits) throw new InvalidOperationException("Innate trait migration is not pending.");
            prepared.LegacyInspectionTraits = false;
        }
    }

    [Serializable] internal sealed class UnitInspectionSave
    {
        public int format;
        public uint random;
        public UnitInspectionRecordSave[] records;
    }

    [Serializable] internal sealed class UnitInspectionRecordSave
    {
        public string key;
        public int observerId, observerRoll, targetRoll, margin;
        public string[] fields;
    }

    /// <summary>An immutable snapshot of shared discoveries and the optional one-time scouting result.</summary>
    public sealed class UnitInspectionRecord
    {
        private readonly string[] fields;
        private readonly HashSet<string> known;
        public string Key { get; }
        public int ObserverId { get; }
        public int ObserverRoll { get; }
        public int TargetRoll { get; }
        public int Margin { get; }
        public bool Observed => ObserverId > 0;
        public int FieldCount => fields.Length;
        public string GetFieldAt(int index) => fields[index];
        public bool HasField(string key) => known.Contains(key);

        internal UnitInspectionRecord(string key, int observerId, int observerRoll, int targetRoll, int margin, string[] fieldKeys)
        {
            Key = key; ObserverId = observerId; ObserverRoll = observerRoll; TargetRoll = targetRoll; Margin = margin;
            fields = (string[])fieldKeys.Clone();
            known = new HashSet<string>(fields, StringComparer.Ordinal);
        }

        internal UnitInspectionRecordSave Capture() => new UnitInspectionRecordSave
        {
            key = Key, observerId = ObserverId, observerRoll = ObserverRoll, targetRoll = TargetRoll,
            margin = Margin, fields = (string[])fields.Clone()
        };
    }

    /// <summary>Once per target, with a separate saved random stream; no world or combat RNG is consumed.</summary>
    public sealed class UnitInspectionData
    {
        private const int MaximumRecords = 100000;
        private const int MaximumFields = 256;
        private const int MaximumSides = 1000000;
        private const uint SeedSalt = 0x6e624eb7;
        private readonly Dictionary<string, UnitInspectionRecord> byKey = new Dictionary<string, UnitInspectionRecord>(StringComparer.Ordinal);
        private readonly List<UnitInspectionRecord> records = new List<UnitInspectionRecord>();
        private uint random = SeedSalt;
        public int Count => records.Count;
        public int Revision { get; private set; }
        public UnitInspectionRecord GetAt(int index) => records[index];

        public UnitInspectionRecord Find(string key)
        {
            if (!ValidKey(key)) throw new ArgumentException("Invalid inspection target key.", nameof(key));
            return byKey.TryGetValue(key, out var record) ? record : null;
        }

        public UnitInspectionRecord Record(string key, int observerId, int observerRoll, int targetRoll, int margin, string[] fieldKeys)
        {
            if (observerId < 1 || !ValidRecord(key, observerId, observerRoll, targetRoll, margin, fieldKeys))
                throw new ArgumentException("Invalid inspection result.");
            var previous = Find(key);
            if (previous != null && previous.Observed) throw new InvalidOperationException("This target has already been inspected.");
            fieldKeys = Merge(previous, fieldKeys);
            var record = new UnitInspectionRecord(key, observerId, observerRoll, targetRoll, margin, fieldKeys);
            Store(record, previous);
            return record;
        }

        // Passive discoveries never spend the target's one scouting attempt or advance its RNG.
        public UnitInspectionRecord Reveal(string key, string[] fieldKeys)
        {
            if (!ValidKey(key) || !ValidFields(fieldKeys) || fieldKeys.Length == 0) throw new ArgumentException("Invalid unit discovery.");
            foreach (string field in fieldKeys)
                if (!PassiveField(field)) throw new ArgumentException("This field requires scouting.");
            var previous = Find(key);
            if (previous != null)
            {
                bool complete = true;
                foreach (string field in fieldKeys) if (!previous.HasField(field)) { complete = false; break; }
                if (complete) return previous;
            }
            var merged = Merge(previous, fieldKeys);
            var record = new UnitInspectionRecord(key, previous?.ObserverId ?? 0, previous?.ObserverRoll ?? 0,
                previous?.TargetRoll ?? 0, previous?.Margin ?? 0, merged);
            Store(record, previous);
            return record;
        }

        private static string[] Merge(UnitInspectionRecord previous, string[] fields)
        {
            var merged = new List<string>();
            if (previous != null)
                for (int i = 0; i < previous.FieldCount; i++) merged.Add(previous.GetFieldAt(i));
            foreach (string field in fields)
                if (previous == null || !previous.HasField(field)) merged.Add(field);
            if (merged.Count > MaximumFields) throw new InvalidOperationException("Inspection field limit exceeded.");
            return merged.ToArray();
        }

        private void Store(UnitInspectionRecord record, UnitInspectionRecord previous)
        {
            if (previous == null)
            {
                if (records.Count >= MaximumRecords) throw new InvalidOperationException("Inspection record limit exceeded.");
                byKey.Add(record.Key, record); records.Add(record);
            }
            else { byKey[record.Key] = record; records[records.IndexOf(previous)] = record; }
            Revision++;
        }

        public int Roll(int sides)
        {
            if (sides < 1 || sides > MaximumSides) throw new ArgumentOutOfRangeException(nameof(sides));
            uint bound = (uint)sides, limit = uint.MaxValue - uint.MaxValue % bound, sample;
            // Xorshift visits every nonzero uint. Subtract one before rejection sampling to avoid modulo bias.
            do
            {
                random ^= random << 13; random ^= random >> 17; random ^= random << 5;
                sample = random - 1;
            } while (sample >= limit);
            Revision++;
            return (int)(sample % bound) + 1;
        }

        public void Clear(uint seed)
        {
            byKey.Clear(); records.Clear();
            random = seed ^ SeedSalt;
            if (random == 0) random = SeedSalt;
            Revision++;
        }

        private static bool ValidKey(string key)
        {
            if (string.IsNullOrEmpty(key) || key.Length > 128) return false;
            foreach (char c in key)
                if (!(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == ':' || c == '_' || c == '-')) return false;
            return true;
        }

        private static bool ValidField(string key)
        {
            if (string.IsNullOrEmpty(key) || key.Length > 64) return false;
            switch (key)
            {
                case "health": case "actionPoints": case "guard": case "casting": return true;
            }
            if (key.StartsWith("trait:", StringComparison.Ordinal) || key.StartsWith("skill:", StringComparison.Ordinal))
            {
                string id = key.Substring(6);
                return int.TryParse(id, out int value) && value > 0 && value.ToString(System.Globalization.CultureInfo.InvariantCulture) == id;
            }
            if (!key.StartsWith("attribute:", StringComparison.Ordinal) || key.Length == 10) return false;
            for (int i = 10; i < key.Length; i++)
            {
                char c = key[i];
                if (!(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || i > 10 && c >= '0' && c <= '9')) return false;
            }
            return true;
        }

        private static bool PassiveField(string field)
        {
            return field == "health" || field == "actionPoints" || field == "guard" || field == "casting"
                || field.StartsWith("skill:", StringComparison.Ordinal);
        }

        private static bool ValidFields(string[] fields)
        {
            if (fields == null || fields.Length > MaximumFields) return false;
            var unique = new HashSet<string>(StringComparer.Ordinal);
            foreach (string field in fields) if (!ValidField(field) || !unique.Add(field)) return false;
            return true;
        }

        private static bool ValidRecord(string key, int observerId, int observerRoll, int targetRoll, int margin, string[] fields)
        {
            if (!ValidKey(key) || !ValidFields(fields)) return false;
            if (observerId == 0)
            {
                if (observerRoll != 0 || targetRoll != 0 || margin != 0 || fields.Length == 0) return false;
                foreach (string field in fields) if (!PassiveField(field)) return false;
                return true;
            }
            return observerId > 0 && observerRoll >= 1 && observerRoll <= MaximumSides && targetRoll >= 1 && targetRoll <= MaximumSides;
        }

        internal UnitInspectionSave Capture()
        {
            var saved = new UnitInspectionRecordSave[records.Count];
            for (int i = 0; i < records.Count; i++) saved[i] = records[i].Capture();
            return new UnitInspectionSave { format = 2, random = random, records = saved };
        }

        internal static UnitInspectionData Prepare(UnitInspectionSave saved)
        {
            SaveCheck.Require(saved != null && (saved.format == 1 || saved.format == 2) && saved.random != 0, "inspection.format");
            var rows = SaveCheck.Rows(saved.records, MaximumRecords, "inspection.records");
            var result = new UnitInspectionData { random = saved.random };
            foreach (var row in rows)
            {
                SaveCheck.Require(row != null && ValidRecord(row.key, row.observerId, row.observerRoll, row.targetRoll, row.margin, row.fields)
                    && (saved.format != 1 || row.observerId > 0), "inspection.record");
                SaveCheck.Require(!result.byKey.ContainsKey(row.key), "inspection.duplicateTarget");
                result.Store(new UnitInspectionRecord(row.key, row.observerId, row.observerRoll, row.targetRoll, row.margin, row.fields), null);
            }
            return result;
        }

        internal static UnitInspectionData Empty(uint seed)
        {
            var result = new UnitInspectionData(); result.Clear(seed); return result;
        }

        internal void TakePrepared(UnitInspectionData prepared)
        {
            if (prepared == null || ReferenceEquals(this, prepared)) throw new ArgumentException("Invalid prepared inspection data.", nameof(prepared));
            byKey.Clear(); records.Clear();
            foreach (var record in prepared.records) { byKey.Add(record.Key, record); records.Add(record); }
            random = prepared.random;
            prepared.byKey.Clear(); prepared.records.Clear();
            Revision++;
        }
    }

    public sealed partial class AdventureData
    {
        internal readonly UnitInspectionData Inspections = new UnitInspectionData();
    }
}
