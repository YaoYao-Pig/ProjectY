using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Resolution-independent leather nameplate, brass rim and anchored pointer.</summary>
    [ExecuteAlways,RequireComponent(typeof(Button))]
    public sealed class CampFacilityTagGraphic : MaskableGraphic,IPointerEnterHandler,IPointerExitHandler,IPointerDownHandler,IPointerUpHandler,ISelectHandler,IDeselectHandler
    {
        [SerializeField] private CampSceneView scene;
        [SerializeField] private int facility;
        private Button button;
        private bool hovered,pressed,selected;
        protected override void OnEnable(){base.OnEnable();button=GetComponent<Button>();raycastTarget=true;SetVerticesDirty();}
        protected override void OnDisable(){hovered=pressed=selected=false;if(scene!=null)scene.HighlightTag(0);base.OnDisable();}
        private void Changed(){SetVerticesDirty();if(scene!=null)scene.HighlightTag(hovered||selected?facility:0);}
        public void OnPointerEnter(PointerEventData e){hovered=true;Changed();}
        public void OnPointerExit(PointerEventData e){hovered=false;pressed=false;Changed();}
        public void OnPointerDown(PointerEventData e){if(e.button==PointerEventData.InputButton.Left){pressed=true;Changed();}}
        public void OnPointerUp(PointerEventData e){pressed=false;Changed();}
        public void OnSelect(BaseEventData e){selected=true;Changed();}
        public void OnDeselect(BaseEventData e){selected=false;Changed();}
        protected override void OnPopulateMesh(VertexHelper vh)
        {
            vh.Clear();var rect=GetPixelAdjustedRect();bool active=button==null||button.IsInteractable();bool hot=active&&(hovered||selected);
            float shift=pressed&&active?-1.3f:0;
            var body=new Rect(rect.xMin+2,rect.yMin+9+shift,rect.width-4,rect.height-12);
            var brass=hot?new Color(.87f,.73f,.43f):new Color(.60f,.46f,.25f);
            if(pressed)brass=new Color(.56f,.46f,.29f);
            var top=pressed?new Color(.16f,.20f,.16f):hot?new Color(.24f,.30f,.22f):new Color(.20f,.25f,.19f);
            var bottom=pressed?new Color(.10f,.13f,.11f):new Color(.105f,.145f,.12f);
            var shadow=body;shadow.y-=3;shadow.x+=1;Plate(vh,shadow,7,new Color(0,0,0,.32f),new Color(0,0,0,.32f));
            Triangle(vh,new Vector2(rect.center.x-10,body.yMin+1),new Vector2(rect.center.x,rect.yMin+1+shift),new Vector2(rect.center.x+10,body.yMin+1),new Color(.13f,.105f,.07f));
            Plate(vh,body,7,new Color(.13f,.105f,.07f),new Color(.13f,.105f,.07f));
            Plate(vh,Inset(body,1),6,brass,new Color(brass.r*.68f,brass.g*.68f,brass.b*.68f));
            Plate(vh,Inset(body,2.5f),5,new Color(.09f,.12f,.10f),new Color(.09f,.12f,.10f));
            Plate(vh,Inset(body,3.6f),4,top,bottom);
            Triangle(vh,new Vector2(rect.center.x-6.8f,body.yMin+1),new Vector2(rect.center.x,rect.yMin+3+shift),new Vector2(rect.center.x+6.8f,body.yMin+1),brass);
            Triangle(vh,new Vector2(rect.center.x-4.3f,body.yMin+1),new Vector2(rect.center.x,rect.yMin+5+shift),new Vector2(rect.center.x+4.3f,body.yMin+1),bottom);
            var rule=new Color(brass.r,brass.g,brass.b,hot?.55f:.32f);
            Line(vh,new Vector2(body.xMin+20,body.yMin+23),new Vector2(body.xMax-20,body.yMin+23),.55f,rule);
            // Sparse stitching remains readable at small UI sizes.
            for(float x=body.xMin+15;x<body.xMax-15;x+=9)
            {
                Line(vh,new Vector2(x,body.yMax-6),new Vector2(x+3.5f,body.yMax-6),.6f,new Color(.72f,.63f,.43f,.26f));
                Line(vh,new Vector2(x,body.yMin+6),new Vector2(x+3.5f,body.yMin+6),.6f,new Color(.72f,.63f,.43f,.19f));
            }
            foreach(float x in new[]{body.xMin+9,body.xMax-9})
            {
                Diamond(vh,new Vector2(x,body.center.y),3.1f,new Color(.08f,.10f,.08f));
                Diamond(vh,new Vector2(x,body.center.y+.3f),1.9f,brass);
                Line(vh,new Vector2(x-.6f,body.center.y+.7f),new Vector2(x+.6f,body.center.y+.7f),.7f,new Color(.95f,.82f,.54f,.65f));
            }
        }
        private static Rect Inset(Rect r,float value)=>new Rect(r.x+value,r.y+value,r.width-value*2,r.height-value*2);
        private void Vertex(VertexHelper vh,Vector2 p,Color value){var v=UIVertex.simpleVert;v.position=p;v.color=value*color;vh.AddVert(v);}
        private void Plate(VertexHelper vh,Rect r,float cut,Color top,Color bottom)
        {
            var points=new[]{new Vector2(r.xMin+cut,r.yMin),new Vector2(r.xMax-cut,r.yMin),new Vector2(r.xMax,r.yMin+cut),new Vector2(r.xMax,r.yMax-cut),new Vector2(r.xMax-cut,r.yMax),new Vector2(r.xMin+cut,r.yMax),new Vector2(r.xMin,r.yMax-cut),new Vector2(r.xMin,r.yMin+cut)};
            int start=vh.currentVertCount;Vertex(vh,r.center,Color.Lerp(bottom,top,.5f));
            foreach(var p in points)Vertex(vh,p,Color.Lerp(bottom,top,Mathf.InverseLerp(r.yMin,r.yMax,p.y)));
            for(int i=0;i<points.Length;i++)vh.AddTriangle(start,start+1+i,start+1+(i+1)%points.Length);
        }
        private void Triangle(VertexHelper vh,Vector2 a,Vector2 b,Vector2 c,Color value){int i=vh.currentVertCount;Vertex(vh,a,value);Vertex(vh,b,value);Vertex(vh,c,value);vh.AddTriangle(i,i+1,i+2);}
        private void Diamond(VertexHelper vh,Vector2 p,float radius,Color value){Triangle(vh,p+Vector2.up*radius,p+Vector2.right*radius,p+Vector2.down*radius,value);Triangle(vh,p+Vector2.up*radius,p+Vector2.down*radius,p+Vector2.left*radius,value);}
        private void Line(VertexHelper vh,Vector2 a,Vector2 b,float width,Color value){var d=(b-a).normalized;var n=new Vector2(-d.y,d.x)*width*.5f;Triangle(vh,a-n,a+n,b+n,value);Triangle(vh,a-n,b+n,b-n,value);}
#if UNITY_EDITOR
        public void Bind(CampSceneView owner,int id){scene=owner;facility=id;SetVerticesDirty();}
#endif
    }
}
