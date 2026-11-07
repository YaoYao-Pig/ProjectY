using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Deterministic screen-space label placement with caller-owned items.</summary>
    public static class MapLabelLayout
    {
        public sealed class Item
        {
            // Id must remain stable and unique within the supplied list.
            public int Id, Priority;
            // Screen pixels, +Y upward. Anchor is the desired rectangle CENTER.
            public Vector2 Anchor, Size;
            public bool Visible;
            public Rect Rect;
            // 0: centered; 1..4: up/down/left/right at 1/3 maxOffset;
            // 5..8: those directions at 2/3; 9..12: at maxOffset.
            public int PreferredSlot;
        }

        private const int SlotCount = 13;
        private sealed class ItemComparer : IComparer<Item>
        {
            internal static readonly ItemComparer Instance = new ItemComparer();
            public int Compare(Item left, Item right)
            {
                int priority = right.Priority.CompareTo(left.Priority);
                return priority != 0 ? priority : left.Id.CompareTo(right.Id);
            }
        }

        /// <summary>
        /// Sorts items IN PLACE by descending Priority, then ascending Id. Reuses
        /// each Item and its previous slot; no per-item objects or lists are created.
        /// The full rectangle must fit the viewport. Gap is an axis-aligned clearance
        /// between labels and between a label and an obstacle, not a viewport margin.
        /// Obstacles may be null. Hidden items keep PreferredSlot but clear Rect.
        /// Zero-area viewports and labels larger than the viewport hide all affected
        /// items; malformed/nonfinite geometry and nonpositive label sizes are errors.
        /// </summary>
        public static void Arrange(List<Item> items, Rect viewport, IList<Rect> obstacles, float gap = 4, float maxOffset = 36)
        {
            if (items == null) throw new ArgumentNullException(nameof(items));
            ValidateRect(viewport, nameof(viewport));
            if (!Finite(gap) || gap < 0) throw new ArgumentOutOfRangeException(nameof(gap));
            if (!Finite(maxOffset) || maxOffset < 0) throw new ArgumentOutOfRangeException(nameof(maxOffset));
            if (obstacles != null)
                for (int i = 0; i < obstacles.Count; i++) ValidateRect(obstacles[i], nameof(obstacles));
            for (int i = 0; i < items.Count; i++)
            {
                var item = items[i];
                if (item == null) throw new ArgumentException("A map label item is null.", nameof(items));
                if (!Finite(item.Anchor.x) || !Finite(item.Anchor.y) || !Finite(item.Size.x) || !Finite(item.Size.y) ||
                    item.Size.x <= 0 || item.Size.y <= 0)
                    throw new ArgumentException("Map label anchors and positive sizes must be finite.", nameof(items));
            }

            items.Sort(ItemComparer.Instance);
            for (int i = 0; i < items.Count; i++)
            {
                var item = items[i];
                item.Visible = false; item.Rect = default(Rect);
                if (viewport.width == 0 || viewport.height == 0 || item.Size.x > viewport.width || item.Size.y > viewport.height) continue;
                int preferred = item.PreferredSlot >= 0 && item.PreferredSlot < SlotCount ? item.PreferredSlot : 0;
                if (TryPlace(items, i, preferred, viewport, obstacles, gap, maxOffset)) continue;
                int count = maxOffset > 0 ? SlotCount : 1;
                for (int slot = 0; slot < count; slot++)
                {
                    if (slot == preferred) continue;
                    if (TryPlace(items, i, slot, viewport, obstacles, gap, maxOffset)) break;
                }
            }
        }

        private static bool TryPlace(List<Item> items, int index, int slot, Rect viewport, IList<Rect> obstacles, float gap, float maxOffset)
        {
            var item = items[index];
            Vector2 center = item.Anchor + Offset(slot, maxOffset);
            var candidate = new Rect(center - item.Size * .5f, item.Size);
            if (candidate.xMin < viewport.xMin || candidate.yMin < viewport.yMin || candidate.xMax > viewport.xMax || candidate.yMax > viewport.yMax) return false;
            if (obstacles != null)
                for (int i = 0; i < obstacles.Count; i++)
                {
                    var obstacle = obstacles[i];
                    if (obstacle.width > 0 && obstacle.height > 0 && Conflicts(candidate, obstacle, gap)) return false;
                }
            // Only earlier (higher priority) accepted labels occupy space. Output
            // from lower priority items in the previous frame never blocks this pass.
            for (int i = 0; i < index; i++)
                if (items[i].Visible && Conflicts(candidate, items[i].Rect, gap)) return false;
            item.Rect = candidate; item.Visible = true; item.PreferredSlot = slot;
            return true;
        }

        private static Vector2 Offset(int slot, float maximum)
        {
            if (slot == 0) return Vector2.zero;
            int direction = (slot - 1) % 4;
            float distance = maximum * (((slot - 1) / 4 + 1) / 3f);
            switch (direction)
            {
                case 0: return new Vector2(0, distance);
                case 1: return new Vector2(0, -distance);
                case 2: return new Vector2(-distance, 0);
                default: return new Vector2(distance, 0);
            }
        }

        private static bool Conflicts(Rect left, Rect right, float gap)
            => left.xMin < right.xMax + gap && left.xMax + gap > right.xMin &&
               left.yMin < right.yMax + gap && left.yMax + gap > right.yMin;

        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private static void ValidateRect(Rect rect, string parameter)
        {
            if (!Finite(rect.xMin) || !Finite(rect.yMin) || !Finite(rect.xMax) || !Finite(rect.yMax) || rect.width < 0 || rect.height < 0)
                throw new ArgumentException("Map label rectangles must be finite and have nonnegative dimensions.", parameter);
        }
    }
}
