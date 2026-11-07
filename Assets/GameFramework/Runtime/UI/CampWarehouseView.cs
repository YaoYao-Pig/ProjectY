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
    public sealed class CampWarehouseView : MonoBehaviour,IInventoryItemOwner,IInventoryGridTarget
    {
        [SerializeField] private InventoryPanelView inventory;
        [SerializeField] private RectTransform grid;
        [SerializeField] private ScrollRect scroll;
        [SerializeField] private InventoryItemView template;
        [SerializeField] private Image cellTemplate;
        [SerializeField] private EquipmentAssetCatalog catalog;
        private readonly List<InventoryItemView> tiles=new List<InventoryItemView>();
        private readonly List<Image> cells=new List<Image>();
        private readonly List<InventoryPanelView.Item> items=new List<InventoryPanelView.Item>();
        private int columns,rows;
        private float cellSize;
        RectTransform IInventoryGridTarget.Grid => grid;
        RectTransform IInventoryGridTarget.Viewport => scroll.viewport;
        float IInventoryGridTarget.CellSize => cellSize;
        public void Prepare() {inventory.Prepare();inventory.SetOtherGrid(this);scroll.verticalNormalizedPosition=1;}
        public void Render(LuaTable snapshot)
        {
            columns=snapshot.Get<int>("width");rows=snapshot.Get<int>("height");
            if(columns<1||rows<1)throw new InvalidOperationException("Invalid camp warehouse dimensions.");
            cellSize=scroll.viewport.rect.width/columns;grid.sizeDelta=new Vector2(scroll.viewport.rect.width,Mathf.Max(scroll.viewport.rect.height,rows*cellSize));
            items.Clear();string selected=snapshot.Get<string>("selected");
            for(int i=0;i<Math.Max(cells.Count,columns*rows);i++)
            {
                if(i==cells.Count)cells.Add(Instantiate(cellTemplate,grid,false));
                cells[i].gameObject.SetActive(i<columns*rows);
                if(i<columns*rows)InventoryPanelView.Place(cells[i].rectTransform,i%columns*cellSize,i/columns*cellSize,cellSize-1,cellSize-1);
                cells[i].transform.SetAsFirstSibling();
            }
            using(var list=snapshot.Get<LuaTable>("items"))
            for(int i=0;i<Math.Max(tiles.Count,list.Length);i++)
            {
                if(i==tiles.Count)tiles.Add(Instantiate(template,grid,false));
                var tile=tiles[i];tile.gameObject.SetActive(i<list.Length);if(i>=list.Length)continue;
                using(var row=list.Get<int,LuaTable>(i+1))
                {
                    var item=InventoryPanelView.Item.Read(row);item.External=true;items.Add(item);
                    tile.Show(this,item,inventory.Font,catalog.ItemIcon(item.ItemId,item.IconPath),item.Key==selected);
                    InventoryPanelView.Place(tile.Rect,item.X*cellSize+2,item.Y*cellSize+2,item.W(item.Rotated)*cellSize-4,item.H(item.Rotated)*cellSize-4);
                    tile.ArrangeIcon();tile.transform.SetAsLastSibling();
                }
            }
        }
        bool IInventoryGridTarget.Placement(InventoryPanelView.Item item,bool rotated,Vector2 pointer,Camera camera,Vector2 grab,out int x,out int y,out int width,out int height)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(grid,pointer,camera,out var local);
            float px=(local.x-grid.rect.xMin)/cellSize,py=(grid.rect.yMax-local.y)/cellSize;
            x=Mathf.FloorToInt(px-grab.x+.5f);y=Mathf.FloorToInt(py-grab.y+.5f);width=item.W(rotated);height=item.H(rotated);
            bool stack=ProjectY.Data.CampData.StackKind(item.Kind);
            if(!stack&&item.Kind!="weapon"&&item.Kind!="wearable"&&item.Kind!="magazine")return false;
            if(stack)foreach(var other in items)
                if(other.Key!=item.Key&&other.ItemId==item.ItemId&&px>=other.X&&py>=other.Y&&px<other.X+other.W(other.Rotated)&&py<other.Y+other.H(other.Rotated))
                {x=other.X;y=other.Y;width=other.W(other.Rotated);height=other.H(other.Rotated);return true;}
            if(x<0||y<0||x+width>columns||y+height>rows)return false;
            foreach(var other in items)
                if(other.Key!=item.Key&&x<other.X+other.W(other.Rotated)&&x+width>other.X&&y<other.Y+other.H(other.Rotated)&&y+height>other.Y)return false;
            return true;
        }
        void IInventoryItemOwner.Select(string key) => inventory.Select(key);
        void IInventoryItemOwner.BeginDrag(InventoryItemView tile,PointerEventData e) {scroll.StopMovement();scroll.enabled=false;inventory.BeginDrag(tile,e);}
        void IInventoryItemOwner.Drag(PointerEventData e) => inventory.Drag(e);
        void IInventoryItemOwner.EndDrag(PointerEventData e) {scroll.enabled=true;inventory.EndDrag(e);}
        public void CancelDrag() {scroll.enabled=true;inventory.CancelDrag();}
        private void OnDisable() {if(inventory!=null){CancelDrag();inventory.SetOtherGrid(null);}}
#if UNITY_EDITOR
        [BlackList] public void Bind(InventoryPanelView bag,RectTransform content,ScrollRect scroller,InventoryItemView tile,Image cell,EquipmentAssetCatalog assets)
        {inventory=bag;grid=content;scroll=scroller;template=tile;cellTemplate=cell;catalog=assets;}
#endif
    }
}
