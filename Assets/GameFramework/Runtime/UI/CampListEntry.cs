using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    public sealed class CampListEntry : MonoBehaviour
    {
        public Button Button;
        public Image Icon,Selection;
        public TMP_Text Title,Subtitle;
        private string key;
        private Action<string> selected;
        private RectTransform rect;
        private LayoutElement sizing;
        private float titleHeight,rowHeight;
        private Vector2 subtitlePosition;
        public void Initialize(Action<string> callback)
        {
            selected=callback;Button.onClick.AddListener(Choose);
            rect=(RectTransform)transform;sizing=GetComponent<LayoutElement>();
            titleHeight=Title.rectTransform.sizeDelta.y;rowHeight=rect.sizeDelta.y;subtitlePosition=Subtitle.rectTransform.anchoredPosition;
        }
        private void Choose() => selected(key);
        public void Show(string value,string title,string subtitle,Sprite icon,bool active)
        {
            key=value;Title.text=title;Subtitle.text=subtitle;Icon.sprite=icon;Icon.enabled=icon!=null;Selection.enabled=active;
            float height=Mathf.Max(titleHeight,Title.GetPreferredValues(title,Title.rectTransform.rect.width,Mathf.Infinity).y);
            float extra=height-titleHeight;
            Title.rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical,height);
            Subtitle.rectTransform.anchoredPosition=subtitlePosition+Vector2.down*extra;
            rect.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical,rowHeight+extra);
            if(sizing!=null){sizing.minHeight=rowHeight+extra;sizing.preferredHeight=rowHeight+extra;}
        }
        private void OnDestroy() => Button.onClick.RemoveListener(Choose);
    }
}
