using System;
using UnityEngine;
using UnityEngine.UI;
using XLua;
using TMPro;

namespace ProjectY.UI
{
    [LuaCallCSharp]
    public sealed class NarrativeView : MonoBehaviour
    {
        [SerializeField] private RectTransform page;
        [SerializeField] private ScrollRect scroll;
        [SerializeField] private Text[] labels = Array.Empty<Text>();
        [SerializeField] private bool rightAligned = true;
        [SerializeField] private UITxt[] richLabels = Array.Empty<UITxt>();
        [SerializeField] private TMP_FontAsset richFont;
        [SerializeField] private RectTransform choices;
        private Font font;
        private float width = 440;
        public Font Font => font;
        public float PanelFraction => page.rect.width / ((RectTransform)transform).rect.width;
        public void Prepare(Font value,float panelWidth)
        {
            if(value==null)throw new ArgumentException("Narrative UI requires a font.");
            font=value;width=panelWidth;
            foreach(var text in labels)text.font=font;
            if(richLabels.Length>0)
            {
                if(richFont==null)throw new InvalidOperationException("Narrative TMP font is not bound. Apply the UX layout migration.");
                foreach(var text in richLabels)text.font=richFont;
            }
            Fit();
        }
        private void Fit()
        {
            if(page==null)return;
            var root=((RectTransform)transform).rect;
            if(rightAligned)
            {
                page.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal,Mathf.Min(width,root.width-24));
                if(choices!=null)
                {
                    var height=Mathf.Min(242,Mathf.Max(110,root.height*.32f));
                    choices.sizeDelta=new Vector2(choices.sizeDelta.x,height);
                    scroll.GetComponent<RectTransform>().offsetMin=new Vector2(14,height+72);
                }
            }
            else
            {
                page.sizeDelta=new Vector2(width,640);
                page.localScale=Vector3.one*Mathf.Max(.1f,Mathf.Min(1,Mathf.Min((root.width-32)/width,(root.height-32)/640)));
            }
        }
        private void LateUpdate(){Fit();}
        public void ScrollToEnd(){if(scroll!=null){Canvas.ForceUpdateCanvases();scroll.verticalNormalizedPosition=0;}}
#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(RectTransform value,ScrollRect scroller,Text[] texts,bool right)
        {page=value;scroll=scroller;labels=texts;rightAligned=right;}
#endif
    }
}
