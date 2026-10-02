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
    public sealed class LootPanelView : MonoBehaviour,IInventoryItemOwner
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
        private string draggingKey;
        public void Prepare() {inventory.Prepare();scroll.verticalNormalizedPosition=1;}
        public void Render(LuaTable snapshot)
        {
            int columns=snapshot.Get<int>("width"),rows=snapshot.Get<int>("height");
            if(columns<1 || rows<1) throw new InvalidOperationException("Invalid loot grid dimensions.");
            float size=scroll.viewport.rect.width/columns;
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
        private void OnDisable() {if(inventory!=null) CancelDrag();}
#if UNITY_EDITOR
        [BlackList] public void Bind(InventoryPanelView bag,RectTransform content,InventoryItemView itemTemplate,Image cell,EquipmentAssetCatalog assets,ScrollRect scroller,Image inspection)
        {inventory=bag;grid=content;template=itemTemplate;cellTemplate=cell;catalog=assets;scroll=scroller;detailIcon=inspection;}
#endif
    }
}
