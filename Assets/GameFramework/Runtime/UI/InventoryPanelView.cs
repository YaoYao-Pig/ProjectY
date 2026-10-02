using System;
using System.Collections.Generic;
using ProjectY.Samples;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    [LuaCallCSharp]
    public sealed class InventoryPanelView : MonoBehaviour, IInventoryItemOwner
    {
        [Serializable] public sealed class Slot {public string Key;public int Bit;public RectTransform Rect;}
        [Serializable] public sealed class Layout
        {
            public RectTransform Root,Frame,Grid;
            public Vector2 GridSize=new Vector2(504,420);
            public InventoryItemView Template;
            public Image CellTemplate,Preview;
            public Text DragLabel;
            public Text[] Labels;
            public Slot[] Slots;
        }
        internal sealed class Item
        {
            public string Key,Name,Kind,Detail,Slot,Compatible,IconPath;
            public int ItemId,Count,X,Y,Width,Height,EquipMask;
            public bool Rotated,External;
            public int W(bool rotated) => rotated?Height:Width;
            public int H(bool rotated) => rotated?Width:Height;
            public static Item Read(LuaTable row) => new Item {
                Key=row.Get<string>("key"),Name=row.Get<string>("name"),Kind=row.Get<string>("kind"),Detail=row.Get<string>("detail"),
                Slot=row.Get<string>("slot"),Compatible=row.Get<string>("compatible"),IconPath=row.Get<string>("iconPath"),
                ItemId=row.Get<int>("itemId"),Count=row.Get<int>("count"),X=row.Get<int>("x"),Y=row.Get<int>("y"),
                Width=row.Get<int>("width"),Height=row.Get<int>("height"),EquipMask=row.Get<int>("equipMask"),Rotated=row.Get<bool>("rotated")};
        }
        [SerializeField] private Layout layout;
        [SerializeField] private EquipmentAssetCatalog catalog;
        public UnityEvent<string> Command { get; } = new UnityEvent<string>();
        public string ActionKey { get; private set; }
        public int ActionX { get; private set; }
        public int ActionY { get; private set; }
        public bool ActionRotated { get; private set; }
        private readonly List<InventoryItemView> tiles=new List<InventoryItemView>();
        private readonly List<Image> cells=new List<Image>();
        private readonly List<Item> items=new List<Item>();
        private Font font;
        public Font Font => font??(font=UnityEngine.Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","Noto Sans CJK SC","Arial"},16));
        private Item dragging;
        private Image dragIcon;
        private bool rotated;
        private Vector2 pointer,grab;
        private Camera eventCamera;
        private int columns,rows;
        private float cellSize;
        private Vector2 lastSize;
        void IInventoryItemOwner.Select(string key) => Select(key);
        void IInventoryItemOwner.BeginDrag(InventoryItemView tile,PointerEventData e) => BeginDrag(tile,e);
        void IInventoryItemOwner.Drag(PointerEventData e) => Drag(e);
        void IInventoryItemOwner.EndDrag(PointerEventData e) => EndDrag(e);
        public void Prepare()
        {
            foreach(var label in layout.Labels) label.font=Font;
            CancelDrag();Arrange();
        }
        internal static void Place(RectTransform r,float x,float y,float w,float h)
        {r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);}
        private void Arrange()
        {
            lastSize=layout.Root.rect.size;
            var scale=Mathf.Min((lastSize.x-24)/layout.Frame.sizeDelta.x,(lastSize.y-24)/layout.Frame.sizeDelta.y);
            layout.Frame.localScale=Vector3.one*Mathf.Max(.1f,scale);
        }
        public void Render(LuaTable snapshot)
        {
            CancelDrag();items.Clear();
            columns=snapshot.Get<int>("width");rows=snapshot.Get<int>("height");var selected=snapshot.Get<string>("selected");
            if(columns<1 || rows<1) throw new InvalidOperationException("Invalid backpack dimensions.");
            cellSize=Mathf.Min(layout.GridSize.x/columns,layout.GridSize.y/rows);layout.Grid.sizeDelta=new Vector2(columns*cellSize,rows*cellSize);
            using(var list=snapshot.Get<LuaTable>("items"))
                for(int i=1;i<=list.Length;i++) using(var row=list.Get<int,LuaTable>(i)) items.Add(Item.Read(row));
            for(int i=0;i<Math.Max(cells.Count,columns*rows);i++)
            {
                if(i==cells.Count) cells.Add(Instantiate(layout.CellTemplate,layout.Grid,false));
                cells[i].gameObject.SetActive(i<columns*rows);
                if(i<columns*rows) Place(cells[i].rectTransform,(i%columns)*cellSize,(i/columns)*cellSize,cellSize-1,cellSize-1);
                cells[i].transform.SetAsFirstSibling();
            }
            for(int i=0;i<Math.Max(tiles.Count,items.Count);i++)
            {
                if(i==tiles.Count) tiles.Add(Instantiate(layout.Template,layout.Grid,false));
                var tile=tiles[i];tile.gameObject.SetActive(i<items.Count);if(i>=items.Count) continue;
                var item=items[i];
                tile.Show(this,item,Font,catalog.ItemIcon(item.ItemId,item.IconPath),item.Key==selected);
                if(item.Slot=="")
                {tile.Rect.SetParent(layout.Grid,false);Place(tile.Rect,item.X*cellSize+2,item.Y*cellSize+2,item.W(item.Rotated)*cellSize-4,item.H(item.Rotated)*cellSize-4);}
                else
                {
                    var slot=Array.Find(layout.Slots,s=>s.Key==item.Slot)??throw new InvalidOperationException("Unbound equipment slot: "+item.Slot);
                    tile.Rect.SetParent(slot.Rect,false);Place(tile.Rect,4,24,slot.Rect.rect.width-8,slot.Rect.rect.height-28);
                }
                tile.transform.SetAsLastSibling();
                tile.ArrangeIcon();
            }
        }
        internal void Select(string key) {ActionKey=key;Command.Invoke("select");}
        internal Item FindItem(string key) => items.Find(item=>item.Key==key);
        internal void BeginDrag(InventoryItemView tile,PointerEventData e)
        {
            dragging=tile.Item;rotated=dragging.Rotated;eventCamera=e.pressEventCamera;pointer=e.position;
            RectTransformUtility.ScreenPointToLocalPointInRectangle(tile.Rect,e.position,eventCamera,out var local);
            grab=dragging.Slot==""?new Vector2(Mathf.Clamp01((local.x-tile.Rect.rect.xMin)/tile.Rect.rect.width)*dragging.W(rotated),Mathf.Clamp01((tile.Rect.rect.yMax-local.y)/tile.Rect.rect.height)*dragging.H(rotated)):new Vector2(.5f,.5f);
            if(dragIcon==null)
            {
                // Reuse the bound Image template, outside either grid's clipping region.
                dragIcon=Instantiate(layout.Preview,layout.Frame,false);dragIcon.name="DragIcon";
                dragIcon.raycastTarget=false;dragIcon.preserveAspect=true;dragIcon.color=new Color(1,1,1,.92f);
                var rect=dragIcon.rectTransform;rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(.5f,.5f);
            }
            dragIcon.sprite=catalog.ItemIcon(dragging.ItemId,dragging.IconPath);
            dragIcon.gameObject.SetActive(dragIcon.sprite!=null);
            layout.DragLabel.text=dragging.Name+"  /  R 旋转";layout.DragLabel.gameObject.SetActive(true);Preview();
        }
        internal void Drag(PointerEventData e) {if(dragging==null) return;pointer=e.position;Preview();}
        private Slot HoverSlot()
        {return Array.Find(layout.Slots,s=>RectTransformUtility.RectangleContainsScreenPoint(s.Rect,pointer,eventCamera));}
        private bool Compatible(Slot slot) => (dragging.EquipMask & slot.Bit)!=0;
        private void Coordinates(out int x,out int y)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(layout.Grid,pointer,eventCamera,out var p);
            x=Mathf.FloorToInt((p.x-layout.Grid.rect.xMin)/cellSize-grab.x+.5f);
            y=Mathf.FloorToInt((layout.Grid.rect.yMax-p.y)/cellSize-grab.y+.5f);
            var merge=MergeTarget();
            if(merge!=null)
            {
                int px=Mathf.FloorToInt((p.x-layout.Grid.rect.xMin)/cellSize),py=Mathf.FloorToInt((layout.Grid.rect.yMax-p.y)/cellSize);
                if(px>=merge.X && py>=merge.Y && px<merge.X+merge.W(merge.Rotated) && py<merge.Y+merge.H(merge.Rotated)) {x=merge.X;y=merge.Y;}
            }
        }
        private Item MergeTarget() => dragging.External && dragging.Kind!="weapon" && dragging.Kind!="magazine" && dragging.Kind!="wearable"
            ?items.Find(row=>row.Slot=="" && row.ItemId==dragging.ItemId):null;
        private bool Fits(int x,int y)
        {
            var merge=MergeTarget();
            if(merge!=null) return x==merge.X && y==merge.Y;
            int w=dragging.W(rotated),h=dragging.H(rotated);
            if(x<0||y<0||x+w>columns||y+h>rows) return false;
            foreach(var other in items) if(other.Slot=="" && other.Key!=dragging.Key && x<other.X+other.W(other.Rotated) && x+w>other.X && y<other.Y+other.H(other.Rotated) && y+h>other.Y) return false;
            return true;
        }
        private void Preview()
        {
            var slot=HoverSlot();bool valid;
            if(slot!=null)
            {layout.Preview.transform.SetParent(slot.Rect,false);Place(layout.Preview.rectTransform,1,1,slot.Rect.rect.width-2,slot.Rect.rect.height-2);valid=Compatible(slot);}
            else
            {
                Coordinates(out int x,out int y);valid=Fits(x,y);
                layout.Preview.transform.SetParent(layout.Grid,false);
                var merge=valid?MergeTarget():null;
                Place(layout.Preview.rectTransform,x*cellSize,y*cellSize,(merge?.W(merge.Rotated) ?? dragging.W(rotated))*cellSize,(merge?.H(merge.Rotated) ?? dragging.H(rotated))*cellSize);
            }
            layout.Preview.color=valid?new Color(.35f,.8f,.52f,.42f):new Color(.9f,.28f,.23f,.45f);
            layout.Preview.gameObject.SetActive(slot!=null || RectTransformUtility.RectangleContainsScreenPoint(layout.Grid,pointer,eventCamera));
            layout.Preview.transform.SetAsLastSibling();
            RectTransformUtility.ScreenPointToLocalPointInRectangle(layout.Frame,pointer,eventCamera,out var p);
            var size=new Vector2(dragging.W(rotated),dragging.H(rotated))*cellSize;
            dragIcon.rectTransform.anchoredPosition=p+new Vector2(size.x*.5f-grab.x*cellSize,grab.y*cellSize-size.y*.5f);
            var iconSize=size-new Vector2(8,8);
            dragIcon.rectTransform.sizeDelta=rotated?new Vector2(iconSize.y,iconSize.x):iconSize;
            dragIcon.rectTransform.localRotation=Quaternion.Euler(0,0,rotated?-90:0);
            dragIcon.transform.SetAsLastSibling();
            layout.DragLabel.rectTransform.anchoredPosition=p+new Vector2(14,22);layout.DragLabel.transform.SetAsLastSibling();
        }
        internal void EndDrag(PointerEventData e)
        {
            if(dragging==null) return;
            pointer=e.position;ActionKey=dragging.Key;ActionRotated=rotated;Coordinates(out int x,out int y);ActionX=x;ActionY=y;
            var slot=HoverSlot();string command=slot!=null?"equip:"+slot.Key:RectTransformUtility.RectangleContainsScreenPoint(layout.Grid,pointer,eventCamera)?"move":"cancel";
            CancelDrag();Command.Invoke(command);
        }
        public void CancelDrag()
        {
            dragging=null;layout.Preview.gameObject.SetActive(false);layout.DragLabel.gameObject.SetActive(false);
            if(dragIcon!=null) {dragIcon.gameObject.SetActive(false);dragIcon.sprite=null;}
        }
        private void RotateDrag()
        {
            // Rotate around the point held by the cursor instead of snapping it to a corner.
            grab=rotated?new Vector2(grab.y,dragging.W(rotated)-grab.x):new Vector2(dragging.H(rotated)-grab.y,grab.x);
            rotated=!rotated;Preview();
        }
        private void Update()
        {
            if(lastSize!=layout.Root.rect.size) {CancelDrag();Arrange();}
            if(dragging!=null && Input.GetKeyDown(KeyCode.R)) RotateDrag();
            if(dragging!=null && Input.GetMouseButtonDown(1)) CancelDrag();
        }
        private void OnDisable() {if(layout!=null) CancelDrag();}
        private void OnDestroy() {Command.RemoveAllListeners();if(font!=null) Destroy(font);}
#if UNITY_EDITOR
        [BlackList] public void Bind(Layout value,EquipmentAssetCatalog assets) {layout=value;catalog=assets;}
        [BlackList] public Layout EditorLayout => layout;
#endif
    }
}
