using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Bound tile presentation and pointer forwarding; no inventory mutations.</summary>
    public sealed class InventoryItemView : MonoBehaviour, IPointerClickHandler, IBeginDragHandler, IDragHandler, IEndDragHandler
    {
        [SerializeField] private RectTransform rect;
        [SerializeField] private Image background, icon;
        [SerializeField] private Text title, amount;
        private InventoryPanelView owner;
        internal InventoryPanelView.Item Item { get; private set; }
        internal RectTransform Rect => rect;
        internal void Show(InventoryPanelView panel,InventoryPanelView.Item item,Font font,Sprite sprite,bool selected)
        {
            owner=panel;Item=item;title.font=amount.font=font;
            title.text=item.Name;amount.text=item.Count>1?"×"+item.Count:item.Kind=="magazine"?item.Detail:"";
            title.fontSize=item.Kind=="weapon"?13:12;
            title.resizeTextForBestFit=true;title.resizeTextMinSize=9;title.resizeTextMaxSize=title.fontSize;
            background.color=selected?new Color(.34f,.32f,.21f):item.Kind=="wearable"?new Color(.17f,.23f,.26f):item.Kind=="weapon"?new Color(.23f,.24f,.19f):new Color(.18f,.21f,.18f);
            icon.sprite=sprite;icon.enabled=sprite!=null;
        }
        internal void ArrangeIcon()
        {
            bool rotated=Item.Slot==""&&Item.Rotated;
            var size=rect.rect.size-new Vector2(8,26);
            icon.rectTransform.anchorMin=icon.rectTransform.anchorMax=new Vector2(.5f,.5f);
            icon.rectTransform.pivot=new Vector2(.5f,.5f);icon.rectTransform.anchoredPosition=new Vector2(0,8);
            icon.rectTransform.sizeDelta=rotated?new Vector2(size.y,size.x):size;
            icon.rectTransform.localRotation=Quaternion.Euler(0,0,rotated?-90:0);
            title.rectTransform.anchorMin=Vector2.zero;title.rectTransform.anchorMax=new Vector2(1,0);
            title.rectTransform.offsetMin=new Vector2(3,2);title.rectTransform.offsetMax=new Vector2(-3,20);
            title.alignment=TextAnchor.MiddleLeft;title.color=new Color(.94f,.94f,.87f);
            amount.rectTransform.anchorMin=new Vector2(0,1);amount.rectTransform.anchorMax=Vector2.one;
            amount.rectTransform.offsetMin=new Vector2(3,-17);amount.rectTransform.offsetMax=new Vector2(-3,-1);
        }
        public void OnPointerClick(PointerEventData e) {if(e.button==PointerEventData.InputButton.Left && !e.dragging) owner.Select(Item.Key);}
        public void OnBeginDrag(PointerEventData e) {if(e.button==PointerEventData.InputButton.Left) owner.BeginDrag(this,e);}
        public void OnDrag(PointerEventData e) {if(e.button==PointerEventData.InputButton.Left) owner.Drag(e);}
        public void OnEndDrag(PointerEventData e) {if(e.button==PointerEventData.InputButton.Left) owner.EndDrag(e);}
#if UNITY_EDITOR
        public void Bind(RectTransform root,Image bg,Image itemIcon,Text label,Text count)
        {rect=root;background=bg;icon=itemIcon;title=label;amount=count;}
#endif
    }
}
