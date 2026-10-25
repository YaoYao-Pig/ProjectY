using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Serialized TMP terminology input. It only queues links; Lua owns navigation and game rules.</summary>
    [DisallowMultipleComponent]
    public sealed class TMPTermLinkView : MonoBehaviour, IPointerEnterHandler, IPointerExitHandler,
        IPointerDownHandler, IPointerUpHandler, IPointerClickHandler
    {
        [SerializeField] private TMP_Text sourceText;
        [SerializeField] private RectTransform viewport;
        [SerializeField] private RectTransform anchor;
        private readonly Queue<string> links=new Queue<string>();
        private PointerEventData pointer;
        private bool inside,pressed,cancelled;
        private Vector2 pressPosition;
        private Vector3 sourcePosition;
        private string queuedText;

        public TMP_Text SourceText { get { ValidateBindings();return sourceText; } }
        public RectTransform Anchor { get { ValidateBindings();return anchor; } }

        private void ValidateBindings()
        {
            if(sourceText==null||viewport==null||anchor==null||sourceText.transform!=transform)
                throw new InvalidOperationException("TMPTermLinkView requires serialized text, clipping viewport and anchor bindings on the text node.");
        }

        public void Clear()
        {links.Clear();queuedText=null;pointer=null;inside=false;pressed=false;cancelled=false;}

        public string TakeLink()
        {
            ValidateBindings();
            if(queuedText!=sourceText.text){links.Clear();queuedText=null;}
            return links.Count==0?"":links.Dequeue();
        }

        public bool IsHovered()
        {
            ValidateBindings();
            if(inside&&pointer!=null&&(!UIPointerState.HasCurrentHit(pointer,sourceText.transform)
                ||!RectTransformUtility.RectangleContainsScreenPoint(viewport,pointer.position,pointer.enterEventCamera)))
            {inside=false;pointer=null;}
            return isActiveAndEnabled&&sourceText.gameObject.activeInHierarchy&&inside;
        }

        public void OnPointerEnter(PointerEventData data){pointer=data;inside=true;}
        public void OnPointerExit(PointerEventData data){pointer=null;inside=false;}
        public void OnPointerDown(PointerEventData data)
        {
            ValidateBindings();
            pressed=data.button==PointerEventData.InputButton.Left;cancelled=false;
            if(pressed){pressPosition=data.position;sourcePosition=sourceText.rectTransform.position;}
        }
        private bool Moved(PointerEventData data)
        {
            float threshold=EventSystem.current==null?6:EventSystem.current.pixelDragThreshold;
            return (data.position-pressPosition).sqrMagnitude>threshold*threshold
                ||(sourceText.rectTransform.position-sourcePosition).sqrMagnitude>.25f;
        }
        public void OnPointerUp(PointerEventData data)
        {if(pressed&&(data.dragging||!data.eligibleForClick||Moved(data)))cancelled=true;}
        public void OnPointerClick(PointerEventData data)
        {
            bool accept=pressed&&!cancelled&&data.button==PointerEventData.InputButton.Left
                &&!data.dragging&&data.eligibleForClick&&!Moved(data);
            pressed=false;cancelled=false;
            if(accept){pointer=data;inside=true;ClickAt(data.position,data.pressEventCamera);}
        }

        /// <summary>Deterministic hit test, also used by isolated native UI checks.</summary>
        public bool ClickAt(Vector2 screenPosition,Camera camera)
        {
            ValidateBindings();
            if(!isActiveAndEnabled||!sourceText.gameObject.activeInHierarchy
                ||!RectTransformUtility.RectangleContainsScreenPoint(viewport,screenPosition,camera))return false;
            sourceText.ForceMeshUpdate();
            int index=TMP_TextUtilities.FindIntersectingLink(sourceText,screenPosition,camera);
            if(index<0)return false;
            string link=sourceText.textInfo.linkInfo[index].GetLinkID();
            if(!link.StartsWith("term:",StringComparison.Ordinal)||link.Length==5)return false;
            if(!RectTransformUtility.ScreenPointToWorldPointInRectangle(anchor,screenPosition,camera,out var position))return false;
            anchor.position=position;
            if(queuedText!=sourceText.text)links.Clear();
            queuedText=sourceText.text;links.Enqueue(link);return true;
        }

        private void OnDisable()=>Clear();
#if UNITY_EDITOR
        [BlackList] public RectTransform EditorViewport=>viewport;
        [BlackList] public void SetEditorBindings(TMP_Text text,RectTransform clip,RectTransform linkAnchor)
        {sourceText=text;viewport=clip;anchor=linkAnchor;ValidateBindings();}
#endif
    }
}
