using System;
using System.Collections.Generic;
using ProjectY.Samples;
using TMPro;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    [LuaCallCSharp]
    public sealed class CampPanelView : MonoBehaviour
    {
        [Serializable] public sealed class Layout
        {
            public RectTransform Root,Frame,ListContent,MaterialContent;
            public GameObject Workshop,Storage,Production,FacilityLabels;
            public ScrollRect ListScroll,DetailScroll;
            public CampListEntry EntryTemplate,MaterialTemplate;
            public TMP_Text Title,Caption,PanelTitle,PanelSubtitle,DetailTitle,DetailText,Cost,ActionLabel,Reason,OrderTitle,OrderState,Status,BagCapacity,WarehouseCapacity,StorageName,StorageDetail;
            public Button Close,Back,Upgrade,Primary,Claim;
            public Button[] Facilities,Wait,Secondary;
            public TMP_Text[] FacilityTitles,FacilityStates,SecondaryTitles;
            public Image OrderProgress;
            public CampSceneView Scene;
            public CampItemPreview Preview;
            public InventoryPanelView Inventory;
            public CampWarehouseView Warehouse;
        }
        [SerializeField] private Layout layout;
        [SerializeField] private EquipmentAssetCatalog catalog;
        public UnityEvent<string> Command {get;}=new UnityEvent<string>();
        public string ActionKey {get;private set;}
        public int ActionId {get;private set;}
        private readonly List<CampListEntry> rows=new List<CampListEntry>(),materials=new List<CampListEntry>();
        private string page;
        private Vector2 lastSize;
        private bool initialized;
        private float detailTitleHeight,detailScrollHeight;
        private Vector2 detailScrollPosition;
        public void Prepare()
        {
            if(!initialized)
            {
                initialized=true;
                detailTitleHeight=layout.DetailTitle.rectTransform.sizeDelta.y;
                var detailRect=(RectTransform)layout.DetailScroll.transform;
                detailScrollHeight=detailRect.sizeDelta.y;detailScrollPosition=detailRect.anchoredPosition;
                layout.Close.onClick.AddListener(()=>Emit("close"));layout.Back.onClick.AddListener(()=>Emit("back"));
                layout.Upgrade.onClick.AddListener(()=>Emit("upgrade"));layout.Primary.onClick.AddListener(()=>Emit("primary"));layout.Claim.onClick.AddListener(()=>Emit("claim"));
                int[] ids={1,4,3,2};for(int i=0;i<layout.Facilities.Length;i++){int id=ids[i];layout.Facilities[i].onClick.AddListener(()=>Facility(id));}
                int[] waits={60,360,1440};for(int i=0;i<layout.Wait.Length;i++){int duration=waits[i];layout.Wait[i].onClick.AddListener(()=>{ActionId=duration;Emit("wait");});}
                for(int i=0;i<layout.Secondary.Length;i++){int index=i+1;layout.Secondary[i].onClick.AddListener(()=>{ActionId=index;Emit("secondary");});}
                layout.Scene.FacilityChosen.AddListener(Facility);
            }
            Arrange();
        }
        private void Facility(int id){ActionId=id;Emit("facility");}
        private void Emit(string command)=>Command.Invoke(command);
        private void Select(string key){ActionKey=key;Emit("select");}
        public void Render(LuaTable snapshot)
        {
            string next=snapshot.Get<string>("page");bool changed=next!=page;page=next;
            bool scene=page=="scene",storage=page=="storage",production=page=="production";
            layout.Frame.gameObject.SetActive(!scene);layout.Workshop.SetActive(!scene&&!storage);layout.Storage.SetActive(storage);
            layout.Production.SetActive(production);layout.FacilityLabels.SetActive(scene);layout.Scene.SetExploring(scene);
            layout.Title.text=snapshot.Get<string>("title");layout.Caption.text=snapshot.Get<string>("caption");layout.Status.text=snapshot.Get<string>("status");
            using(var list=snapshot.Get<LuaTable>("facilities"))for(int i=0;i<layout.FacilityTitles.Length;i++)using(var row=list.Get<int,LuaTable>(i+1))
            {layout.FacilityTitles[i].text=row.Get<string>("name");layout.FacilityStates[i].text=row.Get<string>("status");}
            if(scene){layout.Preview.Release();return;}
            layout.PanelTitle.text=snapshot.Get<string>("panelTitle");layout.PanelSubtitle.text=snapshot.Get<string>("panelSubtitle");layout.Upgrade.gameObject.SetActive(page!="upgrade"&&page!="loadout"&&page!="roster");
            if(storage)return;
            layout.DetailTitle.text=snapshot.Get<string>("detailTitle");layout.DetailText.text=snapshot.Get<string>("detailText");
            float headingHeight=Mathf.Max(detailTitleHeight,layout.DetailTitle.GetPreferredValues(layout.DetailTitle.text,layout.DetailTitle.rectTransform.rect.width,Mathf.Infinity).y);
            float headingExtra=headingHeight-detailTitleHeight;
            layout.DetailTitle.rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical,headingHeight);
            var detailRect=(RectTransform)layout.DetailScroll.transform;
            detailRect.anchoredPosition=detailScrollPosition+Vector2.down*headingExtra;
            detailRect.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical,detailScrollHeight-headingExtra);
            layout.Cost.text=snapshot.Get<string>("cost");layout.ActionLabel.text=snapshot.Get<string>("actionLabel");layout.Primary.interactable=snapshot.Get<bool>("actionEnabled");
            layout.Reason.text=snapshot.Get<string>("reason");
            using(var list=snapshot.Get<LuaTable>("rows"))
            {
                for(int i=0;i<Math.Max(rows.Count,list.Length);i++)
                {
                    if(i==rows.Count){var row=Instantiate(layout.EntryTemplate,layout.ListContent,false);row.Initialize(Select);rows.Add(row);}
                    rows[i].gameObject.SetActive(i<list.Length);if(i>=list.Length)continue;
                    using(var row=list.Get<int,LuaTable>(i+1))
                    {
                        int id=row.Get<int>("itemId");var icon=id==0?null:catalog.ItemIcon(id,row.Get<string>("iconPath"));
                        rows[i].Show(row.Get<string>("key"),row.Get<string>("title"),row.Get<string>("subtitle"),icon,row.Get<bool>("selected"));
                    }
                }
            }
            using(var list=snapshot.Get<LuaTable>("materials"))
            {
                for(int i=0;i<Math.Max(materials.Count,list.Length);i++)
                {
                    if(i==materials.Count){var row=Instantiate(layout.MaterialTemplate,layout.MaterialContent,false);materials.Add(row);}
                    materials[i].gameObject.SetActive(i<list.Length);if(i>=list.Length)continue;
                    using(var row=list.Get<int,LuaTable>(i+1))materials[i].Show("",row.Get<string>("title"),row.Get<string>("subtitle"),catalog.ItemIcon(row.Get<int>("itemId"),row.Get<string>("iconPath")),false);
                }
            }
            using(var list=snapshot.Get<LuaTable>("secondary"))for(int i=0;i<layout.Secondary.Length;i++)
            {
                layout.Secondary[i].gameObject.SetActive(i<list.Length);if(i>=list.Length)continue;
                using(var row=list.Get<int,LuaTable>(i+1)){layout.SecondaryTitles[i].text=row.Get<string>("title");layout.Secondary[i].interactable=row.Get<bool>("available");}
            }
            if(production)
            {
                layout.OrderTitle.text=snapshot.Get<string>("orderTitle");layout.OrderState.text=snapshot.Get<string>("orderState");
                layout.OrderProgress.fillAmount=snapshot.Get<float>("progress");layout.Claim.interactable=snapshot.Get<bool>("canClaim");
            }
            if(changed){layout.ListScroll.verticalNormalizedPosition=1;layout.DetailScroll.verticalNormalizedPosition=1;}
        }
        public void StorageDetails(string name,string detail,string bagCapacity,string warehouseCapacity,string status)
        {layout.StorageName.text=name;layout.StorageDetail.text=detail;layout.BagCapacity.text=bagCapacity;layout.WarehouseCapacity.text=warehouseCapacity;layout.Status.text=status;}
        private void Arrange()
        {
            lastSize=layout.Root.rect.size;float scale=Mathf.Min((lastSize.x-24)/layout.Frame.sizeDelta.x,(lastSize.y-24)/layout.Frame.sizeDelta.y);
            layout.Frame.localScale=Vector3.one*Mathf.Max(.1f,scale);
        }
        private void Update()
        {
            if(layout==null||!initialized)return;
            if(lastSize!=layout.Root.rect.size)Arrange();
            if(Input.GetKeyDown(KeyCode.Escape))
            {
                if(layout.Inventory.IsDragging){layout.Warehouse.CancelDrag();return;}
                Emit("back");
            }
        }
        private void OnDisable(){if(layout!=null){layout.Scene.Release();layout.Preview.Release();}}
        private void OnDestroy(){Command.RemoveAllListeners();if(initialized)layout.Scene.FacilityChosen.RemoveListener(Facility);}
#if UNITY_EDITOR
        [BlackList] public void Bind(Layout value,EquipmentAssetCatalog assets){layout=value;catalog=assets;}
        [BlackList] public Layout EditorLayout=>layout;
#endif
    }
}
