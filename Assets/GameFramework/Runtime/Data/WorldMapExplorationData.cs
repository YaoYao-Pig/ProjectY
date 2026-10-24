using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    /// <summary>Expedition-owned discovery. Visibility is rebuilt from the current party position.</summary>
    public sealed class WorldMapExplorationData
    {
        private bool[] known = Array.Empty<bool>(), visible = Array.Empty<bool>();
        private readonly List<int> discovered = new List<int>(), sight = new List<int>();
        public int CellCount => known.Length;
        public int KnownCount => discovered.Count;
        public int VisibleCount => sight.Count;
        public int Revision { get; private set; }
        public static WorldMapExplorationData For(AdventureData adventure) => adventure.WorldExploration;
        public static WorldMapExplorationData Prepared(PreparedCharacterSave save) => save.PreparedWorldFog;
        public int GetKnownAt(int index) => discovered[index];
        public int GetVisibleAt(int index) => sight[index];
        private int Index(int cell)
        { if (cell < 1 || cell > CellCount) throw new ArgumentOutOfRangeException(nameof(cell)); return cell - 1; }
        public bool IsKnown(int cell) => known[Index(cell)];
        public bool IsVisible(int cell) => visible[Index(cell)];
        public void Reset(int cellCount)
        {
            if (cellCount < 1 || cellCount > 100000) throw new ArgumentOutOfRangeException(nameof(cellCount));
            known = new bool[cellCount]; visible = new bool[cellCount]; discovered.Clear(); sight.Clear(); Revision++;
        }
        public void Reveal(int[] cells)
        {
            if (cells == null || cells.Length == 0) throw new ArgumentException("World visibility requires at least one cell.");
            var unique = new HashSet<int>();
            foreach (int cell in cells) { Index(cell); if (!unique.Add(cell)) throw new ArgumentException("Duplicate visible world cell."); }
            if (unique.Count == sight.Count && sight.All(unique.Contains)) return;
            foreach (int cell in sight) visible[cell - 1] = false;
            sight.Clear();
            foreach (int cell in cells)
            {
                visible[cell - 1] = true; sight.Add(cell);
                if (!known[cell - 1]) { known[cell - 1] = true; discovered.Add(cell); }
            }
            Revision++;
        }
        internal WorldFogSave Capture() => new WorldFogSave { version = 1, cells = CellCount, known = discovered.ToArray() };
        internal static WorldMapExplorationData Prepare(WorldFogSave row)
        {
            var result = new WorldMapExplorationData();
            if (row == null) return result; // Explicit pre-v20 migration; layout validation supplies the cell count.
            SaveCheck.Require(row.version == 1 && row.cells > 0 && row.cells <= 100000, "大地图探索范围");
            result.Reset(row.cells);
            foreach (int cell in SaveCheck.Rows(row.known, row.cells, "大地图探索记录"))
            {
                SaveCheck.Require(cell > 0 && cell <= row.cells && !result.known[cell - 1], "重复或越界的大地图探索格");
                result.known[cell - 1] = true; result.discovered.Add(cell);
            }
            return result;
        }
        internal void TakePrepared(WorldMapExplorationData source)
        {
            if(source.CellCount==0)
            {
                // A service-only legacy restore may precede rebuilding its static world layout.
                known=visible=Array.Empty<bool>();discovered.Clear();sight.Clear();Revision++;return;
            }
            Reset(source.CellCount);
            foreach (int cell in source.discovered) { known[cell - 1] = true; discovered.Add(cell); }
            foreach (int cell in source.sight) { visible[cell - 1] = true; sight.Add(cell); }
            Revision++;
        }
    }
    [Serializable] internal sealed class WorldFogSave { public int version, cells; public int[] known; }
    public sealed partial class AdventureData
    { internal WorldMapExplorationData WorldExploration { get; } = new WorldMapExplorationData(); }
}
