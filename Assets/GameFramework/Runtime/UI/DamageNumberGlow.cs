using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Soft coloured glyph halo and a crisp dark stroke, including on overlay canvases.</summary>
    [DisallowMultipleComponent, RequireComponent(typeof(Text))]
    public sealed class DamageNumberGlow : BaseMeshEffect
    {
        private readonly List<UIVertex> source = new List<UIVertex>();
        private readonly List<UIVertex> output = new List<UIVertex>();
        private Color halo = new Color(1, .29f, .08f);
        private bool critical;

        internal void SetCritical(bool value)
        {
            critical = value;
            halo = value ? new Color(1, .65f, .08f) : new Color(1, .29f, .08f);
            graphic.SetVerticesDirty();
        }

        public override void ModifyMesh(VertexHelper mesh)
        {
            if (!IsActive() || mesh.currentVertCount == 0) return;
            source.Clear(); output.Clear(); mesh.GetUIVertexStream(source);
            float width = critical ? 1.3f : 1;
            AddRing(6 * width, new Color(halo.r, halo.g, halo.b, .06f));
            AddRing(4 * width, new Color(halo.r, halo.g, halo.b, .12f));
            AddRing(2.5f * width, new Color(halo.r, halo.g, halo.b, .24f));
            AddRing(1, new Color(.12f, .025f, .015f, .95f));
            output.AddRange(source);
            mesh.Clear(); mesh.AddUIVertexTriangleStream(output);
        }

        private void AddRing(float radius, Color tint)
        {
            for (int step = 0; step < 8; step++)
            {
                float angle = step * Mathf.PI / 4;
                var offset = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle)) * radius;
                foreach (var original in source)
                {
                    var vertex = original;
                    vertex.position += offset;
                    var color = tint; color.a *= original.color.a / 255f;
                    vertex.color = color; output.Add(vertex);
                }
            }
        }
    }
}
