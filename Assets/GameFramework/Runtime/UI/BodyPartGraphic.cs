using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Resolution-independent body silhouette. Color and selection are display-only.</summary>
    [RequireComponent(typeof(CanvasRenderer))]
    public sealed class BodyPartGraphic : MaskableGraphic
    {
        [SerializeField] private int part;
        public void Configure(int value) { part = value; SetVerticesDirty(); }
        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();
            var rect = GetPixelAdjustedRect();
            Vector2[] points;
            if (part == 0)
            {
                points = new Vector2[24];
                for (int i = 0; i < points.Length; i++)
                {
                    float angle = 2 * Mathf.PI * i / points.Length;
                    points[i] = new Vector2(.5f + .49f * Mathf.Cos(angle), .5f + .49f * Mathf.Sin(angle));
                }
            }
            else if (part == 1)
                points = new[] { new Vector2(.22f,0),new Vector2(.78f,0),new Vector2(1,.88f),new Vector2(.67f,1),new Vector2(.33f,1),new Vector2(0,.88f) };
            else if (part < 4)
                points = new[] { new Vector2(.25f,0),new Vector2(.75f,0),new Vector2(.9f,.16f),new Vector2(1,.92f),new Vector2(.65f,1),new Vector2(.15f,.9f),new Vector2(0,.15f) };
            else
                points = new[] { new Vector2(.04f,0),new Vector2(.92f,0),new Vector2(.92f,.12f),new Vector2(.75f,.22f),new Vector2(1,1),new Vector2(0,1),new Vector2(.18f,.22f) };
            mesh.AddVert(new Vector3(rect.center.x,rect.center.y,0), color, Vector2.zero);
            foreach (var point in points)
                mesh.AddVert(new Vector3(rect.xMin+point.x*rect.width,rect.yMin+point.y*rect.height,0), color, Vector2.zero);
            for (int i = 0; i < points.Length; i++) mesh.AddTriangle(0,i+1,(i+1)%points.Length+1);
        }
    }
}
