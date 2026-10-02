using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Unscaled search progress with a revolving highlight; requires no runtime textures.</summary>
    [RequireComponent(typeof(CanvasRenderer))]
    public sealed class LootSearchGraphic : MaskableGraphic
    {
        private float progress;
        public void SetProgress(float value) {progress=value;SetVerticesDirty();}
        private void Update() {SetVerticesDirty();}
        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();const int segments=48;
            float radius=Mathf.Min(rectTransform.rect.width,rectTransform.rect.height)*.5f;
            float rotation=Time.unscaledTime*220;
            Vector2 center=rectTransform.rect.center;
            for(int i=0;i<segments;i++)
            {
                float a=(i*360f/segments+rotation)*Mathf.Deg2Rad,b=((i+1)*360f/segments+rotation)*Mathf.Deg2Rad;
                var tint=color;tint.a*=i<Mathf.Max(6,progress*segments)?1:.16f;
                int start=mesh.currentVertCount;
                mesh.AddVert(center+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*radius,tint,Vector2.zero);
                mesh.AddVert(center+new Vector2(Mathf.Cos(b),Mathf.Sin(b))*radius,tint,Vector2.zero);
                mesh.AddVert(center+new Vector2(Mathf.Cos(b),Mathf.Sin(b))*(radius-3),tint,Vector2.zero);
                mesh.AddVert(center+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*(radius-3),tint,Vector2.zero);
                mesh.AddTriangle(start,start+1,start+2);mesh.AddTriangle(start,start+2,start+3);
            }
        }
    }
}
