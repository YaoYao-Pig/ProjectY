using System;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Read-only casting points between the health ring and the status-effect arc.</summary>
    [DisallowMultipleComponent]
    public sealed class CastingPointRing : MaskableGraphic
    {
        [SerializeField] private ArcLayoutGroup effectLayout;
        [SerializeField, Min(1)] private int columns = 12;
        [SerializeField, Min(1)] private float radius = 1.34f;
        [SerializeField, Min(1)] private float rowSpacing = 14;
        [SerializeField] private Color availableColor = new Color(.3f, 1f, .58f, 1);
        [SerializeField] private Color spentColor = new Color(.3f, .34f, .35f, 1);
        private int current, maximum;

        internal void SetPoints(int points, int capacity)
        {
            if (capacity < 0 || points < 0 || points > capacity)
                throw new ArgumentOutOfRangeException(nameof(points), "Invalid casting-point projection.");
            if (effectLayout == null) throw new InvalidOperationException("Casting-point ring needs its status arc binding.");
            int rows = (capacity + columns - 1) / columns;
            effectLayout.SetInnerSpacing(Mathf.Max(0, rows - 2) * rowSpacing);
            gameObject.SetActive(capacity > 0);
            if (current == points && maximum == capacity) return;
            current = points; maximum = capacity;
            SetVerticesDirty();
        }

        protected override void OnPopulateMesh(VertexHelper helper)
        {
            helper.Clear();
            var bounds = rectTransform.rect;
            float rx = bounds.width * .5f * radius, ry = bounds.height * .5f * radius;
            for (int i = 0; i < maximum; i++)
            {
                int row = i / columns, count = Mathf.Min(columns, maximum - row * columns);
                float outer = row * rowSpacing;
                float angle = (i % columns - (count - 1) * .5f) * 11 / (rx + outer);
                var center = new Vector2(bounds.center.x + Mathf.Sin(angle) * (rx + outer),
                    bounds.center.y - Mathf.Cos(angle) * (ry + outer));
                Diamond(helper, center, 5.4f, new Color(.025f, .055f, .045f, 1));
                Diamond(helper, center, 3.9f, i < current ? availableColor : spentColor);
                if (i < current) Diamond(helper, center + new Vector2(-.8f, 1), 1.1f, new Color(.83f, 1f, .88f, 1));
            }
        }

        private static void Diamond(VertexHelper helper, Vector2 center, float size, Color tint)
        {
            int start = helper.currentVertCount;
            helper.AddVert(center + new Vector2(0, size), tint, Vector2.zero);
            helper.AddVert(center + new Vector2(size, 0), tint, Vector2.zero);
            helper.AddVert(center + new Vector2(0, -size), tint, Vector2.zero);
            helper.AddVert(center + new Vector2(-size, 0), tint, Vector2.zero);
            helper.AddTriangle(start, start + 1, start + 2);
            helper.AddTriangle(start, start + 2, start + 3);
        }

#if UNITY_EDITOR
        public void SetEditorBindings(ArcLayoutGroup effects) => effectLayout = effects;
#endif
    }
}
