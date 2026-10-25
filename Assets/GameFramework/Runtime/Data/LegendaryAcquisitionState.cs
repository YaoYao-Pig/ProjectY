using System;

namespace ProjectY.Data
{
    /// <summary>Append a new fixed identity's container to an already visited area; existing loot is never regenerated.</summary>
    public static class LegendaryAcquisitionState
    {
        public static void AppendContainer(MapAreaStateData area, NarrativeData narrative, int cellIndex, int tableId,
            int itemId, string name, int durability, bool requiresBreaking, int encounter, int rotation, int[] cells)
        {
            if (area == null || narrative == null || itemId < 1 ||
                narrative.GetValue("flag:legendary_equipment_issued_" + itemId) != 0)
                throw new InvalidOperationException("Named legendary was already issued or has no valid owner.");
            area.AppendLegendaryContainer(cellIndex, tableId, itemId, name, durability, requiresBreaking, encounter, rotation, cells);
        }
    }

    public sealed partial class MapAreaStateData
    {
        internal void AppendLegendaryContainer(int cellIndex, int tableId, int itemId, string name,
            int durability, bool requiresBreaking, int encounter, int rotation, int[] cells)
        {
            CheckCell(cellIndex);
            if (!LootInitialized || tableId < 1 || string.IsNullOrEmpty(name) || encounter < 0 || encounter > encounters.Count ||
                cells == null || cells.Length == 0 || cells[0] != cellIndex)
                throw new ArgumentException("Invalid legendary container migration.");
            foreach (var old in loot)
            {
                if (old.TableId == tableId) throw new InvalidOperationException("Legendary container already exists in this area.");
                foreach (int cell in cells)
                {
                    CheckCell(cell);
                    for (int i = 0; i < old.Physical.CellCount; i++)
                        if (old.Physical.GetCellAt(i) == cell) throw new InvalidOperationException("Legendary container overlaps existing loot.");
                }
            }
            foreach (int cell in cells) CheckCell(cell);
            var added = new MapAreaLootData(loot.Count + 1, cellIndex, tableId, name, new[] { itemId }, new[] { 1 });
            added.Physical.Configure(durability, requiresBreaking, encounter, rotation, cells);
            loot.Add(added);
            Revision++;
            ContainerRevision++;
        }
    }
}
