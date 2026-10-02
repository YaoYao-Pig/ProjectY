using System;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>图谱的几何表现与 Cell 锚定浮窗；不保存技能或学习状态。</summary>
    [LuaCallCSharp,DisallowMultipleComponent]
    public sealed class SkillAtlasView:MonoBehaviour
    {
        [SerializeField] private RectTransform page,viewport,popup;
        [SerializeField] private ScrollRect graphScroll;
        private RectTransform anchor;
        private readonly Vector3[] corners=new Vector3[4];
        public bool PopupVisible => popup.gameObject.activeSelf;
        public bool BackPressed => Input.GetKeyDown(KeyCode.Escape);
        public void Follow(RectTransform cell){anchor=cell;popup.gameObject.SetActive(true);PositionPopup();}
        public void Dismiss(){anchor=null;popup.gameObject.SetActive(false);}
        public void Place(RectTransform cell,float x,float y)
        {cell.anchorMin=cell.anchorMax=new Vector2(0,1);cell.pivot=new Vector2(.5f,.5f);cell.anchoredPosition=new Vector2(x,-y);}
        public void Focus(float x,float y)
        {
            Canvas.ForceUpdateCanvases();var content=graphScroll.content;
            float dx=Mathf.Max(0,content.rect.width-viewport.rect.width),dy=Mathf.Max(0,content.rect.height-viewport.rect.height);
            graphScroll.StopMovement();graphScroll.horizontalNormalizedPosition=dx>0?Mathf.Clamp01((x-viewport.rect.width*.5f)/dx):0;
            graphScroll.verticalNormalizedPosition=dy>0?1-Mathf.Clamp01((y-viewport.rect.height*.5f)/dy):1;
        }
        private void LateUpdate(){if(anchor!=null&&popup.gameObject.activeSelf)PositionPopup();}
        private void PositionPopup()
        {
            if(anchor==null||!anchor.gameObject.activeInHierarchy){Dismiss();return;}
            anchor.GetWorldCorners(corners);
            var lower=(Vector2)viewport.InverseTransformPoint(corners[0]);var upper=(Vector2)viewport.InverseTransformPoint(corners[2]);
            if(!viewport.rect.Overlaps(Rect.MinMaxRect(lower.x,lower.y,upper.x,upper.y))){Dismiss();return;}
            var right=(Vector2)page.InverseTransformPoint(corners[2]);var left=(Vector2)page.InverseTransformPoint(corners[1]);
            var bounds=page.rect;var size=popup.rect.size;
            float x=right.x+12;if(x+size.x>bounds.xMax-12)x=left.x-size.x-12;
            x=Mathf.Clamp(x,bounds.xMin+12,bounds.xMax-size.x-12);
            float y=Mathf.Clamp(right.y+8,bounds.yMin+size.y+12,bounds.yMax-12);
            popup.localPosition=new Vector3(x,y,0);popup.SetAsLastSibling();
        }
        private void OnDisable(){if(popup!=null)Dismiss();}
#if UNITY_EDITOR
        [BlackList] public void Bind(RectTransform frame,RectTransform clip,RectTransform tip,ScrollRect scroll)
        {page=frame;viewport=clip;popup=tip;graphScroll=scroll;}
#endif
    }
}
