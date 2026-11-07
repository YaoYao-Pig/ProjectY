using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Daily investment OHLC, rendered from saved samples only. Pointer exposes the selected candle.</summary>
    public sealed class BankChartGraphic : MaskableGraphic, IPointerMoveHandler, IPointerEnterHandler, IPointerExitHandler
    {
        private double[] opens=Array.Empty<double>(),highs=Array.Empty<double>(),lows=Array.Empty<double>(),closes=Array.Empty<double>();
        private int[] days=Array.Empty<int>();
        public int HoverIndex {get;private set;}=-1;
        public int Count=>days.Length;
        public double Minimum {get;private set;}
        public double Maximum {get;private set;}
        public void SetCandles(int[] dates,double[] open,double[] high,double[] low,double[] close)
        {
            if(dates==null || open==null || high==null || low==null || close==null || dates.Length!=open.Length || dates.Length!=high.Length || dates.Length!=low.Length || dates.Length!=close.Length)
                throw new ArgumentException("Candle arrays must match.");
            double min=double.MaxValue,max=double.MinValue;
            for(int i=0;i<dates.Length;i++)
            {
                if(dates[i]<1 || (i>0 && dates[i]<=dates[i-1]) || !(low[i]>0 && high[i]>=Math.Max(open[i],close[i]) && low[i]<=Math.Min(open[i],close[i])))
                    throw new ArgumentException("Invalid OHLC sample.");
                min=Math.Min(min,low[i]);max=Math.Max(max,high[i]);
            }
            days=(int[])dates.Clone();opens=(double[])open.Clone();highs=(double[])high.Clone();lows=(double[])low.Clone();closes=(double[])close.Clone();
            double margin=dates.Length==0?1:Math.Max(.5,(max-min)*.1);
            Minimum=dates.Length==0?99:min-margin;Maximum=dates.Length==0?101:max+margin;HoverIndex=-1;SetVerticesDirty();
        }
        public void OnPointerEnter(PointerEventData e)=>OnPointerMove(e);
        public void OnPointerMove(PointerEventData e)
        {
            if(days.Length==0)return;
            if(!RectTransformUtility.ScreenPointToLocalPointInRectangle(rectTransform,e.position,e.enterEventCamera,out var point))return;
            var rect=rectTransform.rect;int index=Mathf.Clamp((int)((point.x-rect.xMin)/rect.width*days.Length),0,days.Length-1);
            if(index!=HoverIndex){HoverIndex=index;SetVerticesDirty();}
        }
        public void OnPointerExit(PointerEventData e){HoverIndex=-1;SetVerticesDirty();}
        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();var rect=rectTransform.rect;
            for(int i=0;i<=4;i++)Quad(mesh,rect.xMin,rect.yMin+rect.height*i/4,rect.width,1,new Color(.30f,.36f,.35f,.45f));
            if(days.Length==0)return;
            float width=rect.width/days.Length;
            float Y(double value)=>(float)(rect.yMin+(value-Minimum)/(Maximum-Minimum)*rect.height);
            for(int i=0;i<days.Length;i++)
            {
                float x=rect.xMin+width*(i+.5f);float body=Mathf.Clamp(width*.55f,3,24);
                Color c=closes[i]>opens[i]?new Color(.91f,.40f,.32f):closes[i]<opens[i]?new Color(.30f,.73f,.59f):new Color(.85f,.74f,.48f);
                Quad(mesh,x-1,Y(lows[i]),2,Mathf.Max(1,Y(highs[i])-Y(lows[i])),c);
                Quad(mesh,x-body/2,Y(Math.Min(opens[i],closes[i])),body,Mathf.Max(2,Mathf.Abs(Y(opens[i])-Y(closes[i]))),c);
                if(i==HoverIndex)Quad(mesh,x-.5f,rect.yMin,1,rect.height,new Color(1,1,1,.35f));
            }
        }
        private static void Quad(VertexHelper mesh,float x,float y,float width,float height,Color c)
        {
            int i=mesh.currentVertCount;mesh.AddVert(new Vector3(x,y),c,Vector2.zero);mesh.AddVert(new Vector3(x,y+height),c,Vector2.zero);
            mesh.AddVert(new Vector3(x+width,y+height),c,Vector2.zero);mesh.AddVert(new Vector3(x+width,y),c,Vector2.zero);
            mesh.AddTriangle(i,i+1,i+2);mesh.AddTriangle(i,i+2,i+3);
        }
    }
}
