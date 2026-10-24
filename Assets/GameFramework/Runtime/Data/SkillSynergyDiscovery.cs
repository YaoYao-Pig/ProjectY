using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    /// <summary>Campaign-shared discovery; callers mark only successfully installed party rune combinations.</summary>
    public static class SkillSynergyDiscovery
    {
        public const int MaximumId = 65535;
        public static bool Has(AdventureData adventure, int id) => State(adventure).Has(id);
        public static bool Discover(AdventureData adventure, int id) => State(adventure).Discover(id);
        public static int Revision(AdventureData adventure) => State(adventure).Revision;
        public static int[] PreparedIds(PreparedCharacterSave prepared)
        {
            if (prepared == null) throw new ArgumentNullException(nameof(prepared));
            if (prepared.Consumed || prepared.SynergyDiscovery == null)
                throw new InvalidOperationException("Skill synergy discoveries have not been prepared or were already committed.");
            return prepared.SynergyDiscovery.Ids();
        }
        private static SkillSynergyDiscoveryData State(AdventureData adventure)
            => (adventure ?? throw new ArgumentNullException(nameof(adventure))).SynergyDiscovery;
    }

    [Serializable] internal sealed class SkillSynergyDiscoverySave
    {
        public int format;
        public string bits;
    }

    internal sealed class SkillSynergyDiscoveryData
    {
        private const int MaximumBytes = (SkillSynergyDiscovery.MaximumId + 7) / 8;
        private byte[] bits = Array.Empty<byte>();
        internal int Revision { get; private set; }

        private static int Index(int id)
        {
            if (id < 1 || id > SkillSynergyDiscovery.MaximumId) throw new ArgumentOutOfRangeException(nameof(id));
            return id - 1;
        }
        internal bool Has(int id)
        {
            int index = Index(id), offset = index >> 3;
            return offset < bits.Length && (bits[offset] & (1 << (index & 7))) != 0;
        }
        internal bool Discover(int id)
        {
            int index = Index(id), offset = index >> 3;
            byte mask = (byte)(1 << (index & 7));
            if (offset < bits.Length && (bits[offset] & mask) != 0) return false;
            if (offset >= bits.Length) Array.Resize(ref bits, offset + 1);
            bits[offset] |= mask;
            Revision++;
            return true;
        }
        internal void Clear()
        {
            bits = Array.Empty<byte>();
            Revision++;
        }
        internal int[] Ids()
        {
            var ids = new List<int>();
            for (int offset = 0; offset < bits.Length; offset++)
                for (int bit = 0; bit < 8; bit++)
                    if ((bits[offset] & (1 << bit)) != 0) ids.Add(offset * 8 + bit + 1);
            return ids.ToArray();
        }
        internal SkillSynergyDiscoverySave Capture()
            => new SkillSynergyDiscoverySave { format = 1, bits = Convert.ToBase64String(bits) };

        internal static SkillSynergyDiscoveryData Prepare(SkillSynergyDiscoverySave saved)
        {
            SaveCheck.Require(saved != null && saved.format == 1 && saved.bits != null, "缺少协同发现记录或格式无效");
            SaveCheck.Require(saved.bits.Length <= ((MaximumBytes + 2) / 3) * 4, "协同发现记录过大");
            byte[] decoded;
            try { decoded = Convert.FromBase64String(saved.bits); }
            catch (FormatException) { throw new System.IO.InvalidDataException("角色存档无效：协同发现 bitset 编码无效"); }
            SaveCheck.Require(decoded.Length <= MaximumBytes && Convert.ToBase64String(decoded) == saved.bits, "协同发现 bitset 编码无效");
            SaveCheck.Require(decoded.Length == 0 || decoded[decoded.Length - 1] != 0, "协同发现 bitset 含多余尾部");
            // ID 65536 is outside the stable positive-ID range; the top bit must stay unused.
            SaveCheck.Require(decoded.Length != MaximumBytes || (decoded[MaximumBytes - 1] & 128) == 0, "协同发现编号越界");
            return new SkillSynergyDiscoveryData { bits = decoded };
        }
        internal void TakePrepared(SkillSynergyDiscoveryData prepared)
        {
            bits = prepared.bits;
            prepared.bits = Array.Empty<byte>();
            Revision++;
        }
    }

    public sealed partial class AdventureData
    {
        internal readonly SkillSynergyDiscoveryData SynergyDiscovery = new SkillSynergyDiscoveryData();
    }
}
