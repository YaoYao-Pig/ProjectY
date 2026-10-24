using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Places intact glyphs along the front of an ellipse, without flattening the letters.</summary>
    [ExecuteAlways, DefaultExecutionOrder(1100), DisallowMultipleComponent, RequireComponent(typeof(Text))]
    public sealed class ArcText : BaseMeshEffect
    {
        [SerializeField, Range(.1f, 1.5f)] private float radius = 1;
        [SerializeField] private float lift;
        [SerializeField] private bool worldBillboard;
        private Quaternion previousFacing;
        private void LateUpdate()
        {
            var camera=WorldCamera();
            if(camera==null)return;
            var facing=Quaternion.Inverse(transform.rotation)*camera.transform.rotation;
            if(facing==previousFacing)return;
            previousFacing=facing;graphic.SetVerticesDirty();
        }
        private Camera WorldCamera()
        {
            var canvas=graphic.canvas;
            return worldBillboard && canvas!=null && canvas.renderMode==RenderMode.WorldSpace?canvas.worldCamera:null;
        }
        public override void ModifyMesh(VertexHelper mesh)
        {
            if (!IsActive() || mesh.currentVertCount == 0) return;
            var rect = graphic.rectTransform.rect;
            float rx = rect.width * .5f * radius;
            float ry = rect.height * .5f * radius;
            float left = float.PositiveInfinity, right = float.NegativeInfinity;
            var vertex = new UIVertex();
            for (int i = 0; i < mesh.currentVertCount; i++)
            {
                mesh.PopulateUIVertex(ref vertex, i);
                left = Mathf.Min(left, vertex.position.x); right = Mathf.Max(right, vertex.position.x);
            }
            float middle = (left + right) * .5f;
            var camera=WorldCamera();
            var facing=camera!=null?Quaternion.Inverse(transform.rotation)*camera.transform.rotation:Quaternion.identity;
            float projectedHeight=camera!=null?Mathf.Abs(camera.transform.forward.y):1;
            // Long rider/mount labels stay within the front semicircle.
            float fit = Mathf.Min(1, rx * 2.25f / Mathf.Max(1, right - left));
            for (int i = 0; i + 3 < mesh.currentVertCount; i += 4)
            {
                mesh.PopulateUIVertex(ref vertex, i); var topLeft = vertex.position;
                mesh.PopulateUIVertex(ref vertex, i + 2); var bottomRight = vertex.position;
                var center = (topLeft + bottomRight) * .5f;
                float angle = (center.x - middle) * fit / Mathf.Max(1, rx);
                var position = (Vector3)rect.center + new Vector3(Mathf.Sin(angle) * rx, -Mathf.Cos(angle) * ry,0);
                if(camera!=null)position.z=-(Mathf.Abs(topLeft.y-bottomRight.y)*fit*.5f+3);
                else position.y+=lift;
                float tangent = Mathf.Atan2(ry * projectedHeight * Mathf.Sin(angle), rx * Mathf.Cos(angle)) * Mathf.Rad2Deg;
                var rotation = facing*Quaternion.Euler(0, 0, tangent);
                for (int corner = 0; corner < 4; corner++)
                {
                    mesh.PopulateUIVertex(ref vertex, i + corner);
                    vertex.position = (Vector3)position + rotation * ((vertex.position - center) * fit);
                    mesh.SetUIVertex(vertex, i + corner);
                }
            }
        }
#if UNITY_EDITOR
        public void SetEditorShape(float value, float height)
        { radius = value; lift = height; graphic.SetVerticesDirty(); }
#endif
    }
}
