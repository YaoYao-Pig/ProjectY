using System;
using System.Collections.Generic;
using ProjectY.Samples;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    [LuaCallCSharp]
    public sealed class LootPanelView : MonoBehaviour,IInventoryItemOwner,IInventoryGridTarget
    {
        [SerializeField] private InventoryPanelView inventory;
        [SerializeField] private RectTransform grid;
        [SerializeField] private InventoryItemView template;
        [SerializeField] private Image cellTemplate;
        [SerializeField] private EquipmentAssetCatalog catalog;
        [SerializeField] private ScrollRect scroll;
        [SerializeField] private Image detailIcon;
        private readonly List<InventoryItemView> tiles=new List<InventoryItemView>();
        private readonly List<Image> cells=new List<Image>();
        private readonly Dictionary<string,bool> revealed=new Dictionary<string,bool>();
        private readonly List<InventoryPanelView.Item> items=new List<InventoryPanelView.Item>();
        private int columns,rows;
        private float cellSize;
        private bool canEdit;
        RectTransform IInventoryGridTarget.Grid => grid;
        RectTransform IInventoryGridTarget.Viewport => scroll.viewport;
        float IInventoryGridTarget.CellSize => cellSize;
        private string draggingKey;
        public void Prepare() {inventory.Prepare();inventory.SetOtherGrid(this);scroll.verticalNormalizedPosition=1;}
        public void Render(LuaTable snapshot)
        {
            columns=snapshot.Get<int>("width");rows=snapshot.Get<int>("height");canEdit=snapshot.Get<bool>("canEdit");items.Clear();
            if(columns<1 || rows<1) throw new InvalidOperationException("Invalid loot grid dimensions.");
            float size=scroll.viewport.rect.width/columns;cellSize=size;
            grid.sizeDelta=new Vector2(scroll.viewport.rect.width,Mathf.Max(scroll.viewport.rect.height,rows*size));
            for(int i=0;i<Math.Max(cells.Count,columns*rows);i++)
            {
                if(i==cells.Count) cells.Add(Instantiate(cellTemplate,grid,false));
                cells[i].gameObject.SetActive(i<columns*rows);
                if(i<columns*rows) InventoryPanelView.Place(cells[i].rectTransform,i%columns*size,i/columns*size,size-1,size-1);
                cells[i].transform.SetAsFirstSibling();
            }
            revealed.Clear();string selected=snapshot.Get<string>("selected");
            using(var list=snapshot.Get<LuaTable>("items"))
            {
                for(int i=0;i<Math.Max(tiles.Count,list.Length);i++)
                {
                    if(i==tiles.Count) tiles.Add(Instantiate(template,grid,false));
                    var tile=tiles[i];tile.gameObject.SetActive(i<list.Length);if(i>=list.Length) continue;
                    using(var row=list.Get<int,LuaTable>(i+1))
                    {
                        var item=InventoryPanelView.Item.Read(row);item.External=true;
                        bool known=row.Get<bool>("revealed");revealed.Add(item.Key,known);
                        tile.gameObject.SetActive(item.Count>0);if(item.Count==0) continue;
                        items.Add(item);
                        tile.Show(this,item,inventory.Font,catalog.ItemIcon(item.ItemId,item.IconPath),item.Key==selected);
                        InventoryPanelView.Place(tile.Rect,item.X*size+2,item.Y*size+2,row.Get<int>("displayWidth")*size-4,row.Get<int>("displayHeight")*size-4);
                        tile.ArrangeIcon();tile.transform.SetAsLastSibling();
                        tile.SearchState(known,false,0);
                    }
                }
            }
            var inspected=inventory.FindItem(selected);bool detailKnown=true;
            if(inspected==null) foreach(var tile in tiles)
                if(tile.gameObject.activeSelf && tile.Item.Key==selected) {inspected=tile.Item;detailKnown=revealed[selected];break;}
            detailIcon.sprite=inspected==null?null:catalog.ItemIcon(inspected.ItemId,inspected.IconPath);
            detailIcon.color=detailKnown?Color.white:new Color(.015f,.023f,.027f,1);
            detailIcon.gameObject.SetActive(detailIcon.sprite!=null);
        }
        public void SearchProgress(string key,float progress)
        {
            foreach(var tile in tiles)
                if(tile.gameObject.activeSelf && tile.Item.Key==key) {tile.SearchState(false,true,progress);return;}
        }
        bool IInventoryGridTarget.Placement(InventoryPanelView.Item item,bool rotated,Vector2 pointer,Camera camera,Vector2 grab,
            out int x,out int y,out int width,out int height)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(grid,pointer,camera,out var point);
            float px=(point.x-grid.rect.xMin)/cellSize,py=(grid.rect.yMax-point.y)/cellSize;
            x=Mathf.FloorToInt(px-grab.x+.5f);y=Mathf.FloorToInt(py-grab.y+.5f);width=item.W(rotated);height=item.H(rotated);
            if(!canEdit)return false;
            if(item.Kind!="weapon" && item.Kind!="magazine" && item.Kind!="wearable")
            {
                foreach(var other in items)
                    if(other.Key!=item.Key && other.ItemId==item.ItemId && revealed[other.Key] &&
                        px>=other.X && py>=other.Y && px<other.X+other.W(other.Rotated) && py<other.Y+other.H(other.Rotated))
                    {x=other.X;y=other.Y;width=other.W(other.Rotated);height=other.H(other.Rotated);return true;}
            }
            if(x<0 || y<0 || x+width>columns || y+height>rows)return false;
            foreach(var other in items)
                if(other.Key!=item.Key && x<other.X+other.W(other.Rotated) && x+width>other.X && y<other.Y+other.H(other.Rotated) && y+height>other.Y)return false;
            return true;
        }
        void IInventoryItemOwner.Select(string key) {inventory.Select(key);}
        void IInventoryItemOwner.BeginDrag(InventoryItemView tile,PointerEventData e)
        {
            if(!revealed[tile.Item.Key]) return;
            draggingKey=tile.Item.Key;scroll.StopMovement();scroll.enabled=false;inventory.BeginDrag(tile,e);
        }
        void IInventoryItemOwner.Drag(PointerEventData e) {if(draggingKey!=null) inventory.Drag(e);}
        void IInventoryItemOwner.EndDrag(PointerEventData e)
        {
            if(draggingKey==null) return;
            draggingKey=null;scroll.enabled=true;inventory.EndDrag(e);
        }
        public void CancelDrag() {draggingKey=null;scroll.enabled=true;inventory.CancelDrag();}
        private void OnDisable() {if(inventory!=null) {CancelDrag();inventory.SetOtherGrid(null);}}
#if UNITY_EDITOR
        [BlackList] public void Bind(InventoryPanelView bag,RectTransform content,InventoryItemView itemTemplate,Image cell,EquipmentAssetCatalog assets,ScrollRect scroller,Image inspection)
        {inventory=bag;grid=content;template=itemTemplate;cellTemplate=cell;catalog=assets;scroll=scroller;detailIcon=inspection;}
#endif
    }
}
