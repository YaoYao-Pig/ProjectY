using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Pure presentation: clipped, raycast-free ornamental equipment frame.</summary>
    [RequireComponent(typeof(CanvasRenderer))]
    public sealed class EquipmentRarityFrame : MaskableGraphic
    {
        [SerializeField] private bool selected;
        public void Configure(bool visible, string htmlColor, bool isSelected)
        {
            if (!visible) { gameObject.SetActive(false); return; }
            Color tint;
            if (!ColorUtility.TryParseHtmlString(htmlColor, out tint))
                throw new System.ArgumentException("Invalid equipment frame color: " + htmlColor);
            bool changed = selected != isSelected || color != tint;
            selected = isSelected; color = tint; raycastTarget = false;
            gameObject.SetActive(true);
            if (changed) SetVerticesDirty();
        }
        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear(); var r = GetPixelAdjustedRect();
            if (r.width < 12 || r.height < 12) return;
            float edge = selected ? 1.8f : 1.2f;
            var gold = color;
            Border(mesh, r, 1, 4.5f, Alpha(gold, .08f));
            Border(mesh, r, 2, edge, Alpha(gold, selected ? 1 : .82f));
            Border(mesh, r, 5, .65f, Alpha(gold, .4f));
            float arm = Mathf.Min(13, Mathf.Min(r.width, r.height) * .22f);
            Corner(mesh, r, 1, 1, arm, gold); Corner(mesh, r, -1, 1, arm, gold);
            Corner(mesh, r, 1, -1, arm, gold); Corner(mesh, r, -1, -1, arm, gold);
            float badge = Mathf.Min(4, r.width * .055f);
            Diamond(mesh, r, new Vector2(r.center.x, r.yMax - 3.5f), badge, gold);
            Diamond(mesh, r, new Vector2(r.center.x, r.yMin + 3.5f), badge * .65f, Alpha(gold, .75f));
        }
        private static Color Alpha(Color value, float alpha) { value.a *= alpha; return value; }
        private static void Border(VertexHelper mesh, Rect r, float inset, float width, Color tint)
        {
            float x=r.xMin+inset,y=r.yMin+inset,w=r.width-inset*2,h=r.height-inset*2;
            Quad(mesh,r,new Rect(x,y,w,width),tint); Quad(mesh,r,new Rect(x,y+h-width,w,width),tint);
            Quad(mesh,r,new Rect(x,y+width,width,h-width*2),tint); Quad(mesh,r,new Rect(x+w-width,y+width,width,h-width*2),tint);
        }
        private static void Corner(VertexHelper mesh, Rect r, int sx, int sy, float arm, Color tint)
        {
            float x=sx>0?r.xMin+2:r.xMax-2,y=sy>0?r.yMin+2:r.yMax-2;
            Quad(mesh,r,new Rect(sx>0?x:x-arm,sy>0?y:y-2.6f,arm,2.6f),tint);
            Quad(mesh,r,new Rect(sx>0?x:x-2.6f,sy>0?y:y-arm,2.6f,arm),tint);
            Diamond(mesh,r,new Vector2(x+sx*4.5f,y+sy*4.5f),2.1f,Alpha(tint,.95f));
        }
        private static void Vertex(VertexHelper mesh, Rect bounds, Vector2 point, Color tint)
        {
            var v=UIVertex.simpleVert;v.position=point;v.color=tint;
            v.uv0=new Vector2((point.x-bounds.xMin)/bounds.width,(point.y-bounds.yMin)/bounds.height);mesh.AddVert(v);
        }
        private static void Quad(VertexHelper mesh, Rect bounds, Rect rect, Color tint)
        {
            int start=mesh.currentVertCount;
            Vertex(mesh,bounds,new Vector2(rect.xMin,rect.yMin),tint);Vertex(mesh,bounds,new Vector2(rect.xMin,rect.yMax),tint);
            Vertex(mesh,bounds,new Vector2(rect.xMax,rect.yMax),tint);Vertex(mesh,bounds,new Vector2(rect.xMax,rect.yMin),tint);
            mesh.AddTriangle(start,start+1,start+2);mesh.AddTriangle(start,start+2,start+3);
        }
        private static void Diamond(VertexHelper mesh, Rect bounds, Vector2 center, float radius, Color tint)
        {
            int start=mesh.currentVertCount;
            Vertex(mesh,bounds,center+Vector2.down*radius,tint);Vertex(mesh,bounds,center+Vector2.left*radius,tint);
            Vertex(mesh,bounds,center+Vector2.up*radius,tint);Vertex(mesh,bounds,center+Vector2.right*radius,tint);
            mesh.AddTriangle(start,start+1,start+2);mesh.AddTriangle(start,start+2,start+3);
        }
    }
}
