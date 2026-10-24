using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>An annular Image mesh; fillAmount remains compatible with health feedback.</summary>
    [DisallowMultipleComponent, RequireComponent(typeof(Image))]
    public sealed class HealthRingMesh : BaseMeshEffect
    {
        [SerializeField, Range(.1f, 1)] private float radius = .9f;
        [SerializeField, Range(.01f, .3f)] private float thickness = .075f;
        [SerializeField, Range(24, 160)] private int segments = 96;

        public override void ModifyMesh(VertexHelper mesh)
        {
            if (!IsActive()) return;
            mesh.Clear();
            var image = (Image)graphic;
            float fill = image.type == Image.Type.Filled ? image.fillAmount : 1;
            if (fill <= 0) return;
            var rect = graphic.rectTransform.rect;
            var half = rect.size * .5f;
            int count = Mathf.Max(1, Mathf.CeilToInt(segments * fill));
            for (int i = 0; i <= count; i++)
            {
                float angle = (90 - 360 * fill * i / count) * Mathf.Deg2Rad;
                var direction = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
                mesh.AddVert(rect.center + Vector2.Scale(direction, half) * radius, graphic.color, Vector2.zero);
                mesh.AddVert(rect.center + Vector2.Scale(direction, half) * (radius - thickness), graphic.color, Vector2.zero);
                if (i == count) continue;
                int start = i * 2;
                mesh.AddTriangle(start, start + 2, start + 1);
                mesh.AddTriangle(start + 1, start + 2, start + 3);
            }
        }
#if UNITY_EDITOR
        public void SetEditorShape(float outerRadius, float width)
        { radius = outerRadius; thickness = width; graphic.SetVerticesDirty(); }
#endif
    }
}
