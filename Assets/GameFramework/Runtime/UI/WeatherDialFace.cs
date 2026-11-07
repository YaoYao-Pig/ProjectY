using System;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Static 24-hour dial sectors. Midnight is up; hours advance clockwise.</summary>
    [LuaCallCSharp, RequireComponent(typeof(CanvasRenderer)), DisallowMultipleComponent]
    public sealed class WeatherDialFace : MaskableGraphic
    {
        private const int CircleSegments = 96;
        [SerializeField] private double dayStart = 6;
        [SerializeField] private double duskStart = 18;
        [SerializeField] private double nightStart = 20;
        [SerializeField] private Color dayColor = new Color(.94f, .87f, .68f, 1);
        [SerializeField] private Color duskColor = new Color(.76f, .43f, .22f, 1);
        [SerializeField] private Color nightColor = new Color(.28f, .36f, .45f, 1);
        [SerializeField] private Color tickColor = new Color(.97f, .89f, .70f, .78f);

        public void Configure(double dayStart, double duskStart, double nightStart)
        {
            ValidatePhases(dayStart, duskStart, nightStart);
            raycastTarget = false;
            if (this.dayStart == dayStart && this.duskStart == duskStart && this.nightStart == nightStart) return;
            this.dayStart = dayStart; this.duskStart = duskStart; this.nightStart = nightStart;
            SetVerticesDirty();
        }

        internal static void ValidatePhases(double dayStart, double duskStart, double nightStart)
        {
            if (double.IsNaN(dayStart) || double.IsInfinity(dayStart) || dayStart < 0 || dayStart >= 24)
                throw new ArgumentOutOfRangeException(nameof(dayStart), "Day start must be a finite hour in [0,24).");
            if (double.IsNaN(duskStart) || double.IsInfinity(duskStart) || duskStart <= dayStart || duskStart >= 24)
                throw new ArgumentOutOfRangeException(nameof(duskStart), "Dusk must follow day start and precede hour 24.");
            if (double.IsNaN(nightStart) || double.IsInfinity(nightStart) || nightStart <= duskStart || nightStart >= 24)
                throw new ArgumentOutOfRangeException(nameof(nightStart), "Night must follow dusk and precede hour 24.");
        }

        protected override void OnEnable()
        {
            base.OnEnable(); raycastTarget = false;
        }

        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            ValidatePhases(dayStart, duskStart, nightStart);
            ValidateColor(dayColor); ValidateColor(duskColor); ValidateColor(nightColor); ValidateColor(tickColor);
            mesh.Clear();
            var rect = GetPixelAdjustedRect();
            if (rect.width <= 0 || rect.height <= 0) return;
            if (float.IsNaN(rect.width) || float.IsInfinity(rect.width) || float.IsNaN(rect.height) || float.IsInfinity(rect.height))
                throw new InvalidOperationException("Weather dial dimensions must be finite.");
            float radius = Mathf.Min(rect.width, rect.height) * .5f;
            var center = rect.center;
            Sector(mesh, center, radius, dayStart, duskStart, dayColor * color);
            Sector(mesh, center, radius, duskStart, nightStart, duskColor * color);
            Sector(mesh, center, radius, nightStart, dayStart + 24, nightColor * color);
            // Three sectors need at most 98 triangles (294 vertices), plus 96 tick vertices.
            for (int hour = 0; hour < 24; hour++)
            {
                bool major = hour % 6 == 0;
                var direction = Direction(hour);
                var tangent = new Vector2(direction.y, -direction.x);
                float outer = radius * .94f, inner = radius * (major ? .79f : .86f);
                float halfWidth = radius * (major ? .014f : .008f);
                var tint = tickColor * color; if (!major) tint.a *= .72f;
                int start = mesh.currentVertCount;
                Vertex(mesh, center + direction * inner - tangent * halfWidth, tint);
                Vertex(mesh, center + direction * outer - tangent * halfWidth, tint);
                Vertex(mesh, center + direction * outer + tangent * halfWidth, tint);
                Vertex(mesh, center + direction * inner + tangent * halfWidth, tint);
                mesh.AddTriangle(start, start + 1, start + 2); mesh.AddTriangle(start, start + 2, start + 3);
            }
        }

        private static void Sector(VertexHelper mesh, Vector2 center, float radius, double from, double to, Color tint)
        {
            int segments = Math.Max(1, (int)Math.Ceiling((to - from) * CircleSegments / 24));
            var centerTint = new Color(tint.r * 1.035f, tint.g * 1.035f, tint.b * 1.035f, tint.a);
            var edgeTint = new Color(tint.r * .91f, tint.g * .91f, tint.b * .91f, tint.a);
            for (int i = 0; i < segments; i++)
            {
                int start = mesh.currentVertCount;
                Vertex(mesh, center, centerTint);
                Vertex(mesh, center + Direction(from + (to - from) * i / segments) * radius, edgeTint);
                Vertex(mesh, center + Direction(from + (to - from) * (i + 1) / segments) * radius, edgeTint);
                mesh.AddTriangle(start, start + 1, start + 2);
            }
        }

        private static Vector2 Direction(double hour)
        {
            double angle = hour * Math.PI / 12;
            return new Vector2((float)Math.Sin(angle), (float)Math.Cos(angle));
        }
        private static void Vertex(VertexHelper mesh, Vector2 position, Color tint)
            => mesh.AddVert(position, tint, Vector2.zero);
        private static void ValidateColor(Color value)
        {
            if (!Finite(value.r) || !Finite(value.g) || !Finite(value.b) || !Finite(value.a) || value.a < 0 || value.a > 1)
                throw new InvalidOperationException("Weather dial colors must be finite with alpha in [0,1].");
        }
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
    }
}
