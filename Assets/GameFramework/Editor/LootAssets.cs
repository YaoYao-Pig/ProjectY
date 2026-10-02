using System;
using System.Collections.Generic;
using ProjectY.Samples;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Permanent prefab authoring for the shared chest / battle loot panel.</summary>
    [InitializeOnLoad]
    public static class LootAssets
    {
        private static readonly Color Ink=new Color(.045f,.058f,.063f),Card=new Color(.075f,.095f,.10f),Gold=new Color(.76f,.65f,.41f),Paper=new Color(.87f,.87f,.79f),Muted=new Color(.49f,.59f,.59f);
        static LootAssets() {LuaViewHints.Register(typeof(LootPanelView),"CS.ProjectY.UI.LootPanelView");}
        [MenuItem("Project Y/装备/同步搜刮与结算界面")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("搜刮界面同步需要 Edit Mode。");
            var config=PanelAssets.LoadOrCreate();var entry=config.Entries.Find(row=>row.Name=="Loot");
            if(entry==null) entry=PanelAssets.Save(new PanelDefinition {Name="Loot",Module="Equipment",Kind=UIKind.Panel,Layer="Popup",Modal=true,Cache=true,CloseOnBack=true,PauseWorldOnOpen=true},null);
            PanelAssets.Generate(entry);
            var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                if(root.transform.childCount==0) Build(root);
                UpgradeReadability(root);
                var reference=root.GetComponent<LuaReference>();
                if(root.GetComponent<LootPanelView>()==null) throw new InvalidOperationException("搜刮 Prefab 缺少 LootPanelView。");
                reference.ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
            }
            finally {PrefabUtility.UnloadPrefabContents(root);}
            AssetDatabase.SaveAssets();Debug.Log("Loot panel and LuaReference bindings saved.");
        }
        private static RectTransform Node(string name,Transform parent)
        {var go=new GameObject(name,typeof(RectTransform));go.transform.SetParent(parent,false);return (RectTransform)go.transform;}
        private static void Box(RectTransform r,float x,float y,float w,float h)
        {r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);}
        private static Image Paint(RectTransform r,Color color,bool hit=false)
        {var image=r.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=hit;return image;}
        private static Text Label(string name,Transform parent,string text,int size,float x,float y,float w,float h,List<LuaReference.Entry> refs=null)
        {
            var r=Node(name,parent);Box(r,x,y,w,h);var t=r.gameObject.AddComponent<Text>();
            t.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");t.text=text;t.fontSize=size;t.color=Paper;t.raycastTarget=false;t.supportRichText=false;
            if(refs!=null) refs.Add(new LuaReference.Entry(name,t));return t;
        }
        private static void UpgradeReadability(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var refs=new List<LuaReference.Entry>(reference.GetEditorBindings());
            var inventory=root.GetComponent<InventoryPanelView>();var layout=inventory.EditorLayout;var frame=layout.Frame;
            var bag=(RectTransform)layout.Grid.parent;Box(bag,20,100,664,608);
            layout.GridSize=new Vector2(624,520);Box(layout.Grid,20,74,624,520);
            var bagTitle=bag.Find("BagTitle").GetComponent<Text>();Box(bagTitle.rectTransform,20,12,624,28);bagTitle.fontSize=19;
            var capacity=reference.GetText("Capacity");Box(capacity.rectTransform,20,43,624,24);capacity.fontSize=14;
            var source=(RectTransform)frame.Find("Loot");Box(source,704,100,516,608);
            var sourceTitle=source.Find("LootTitle").GetComponent<Text>();Box(sourceTitle.rectTransform,18,12,480,28);sourceTitle.fontSize=19;
            var search=reference.GetText("SearchStatus");Box(search.rectTransform,18,43,480,24);search.fontSize=13;
            var viewport=(RectTransform)source.Find("Viewport");Box(viewport,18,74,480,408);
            var scroller=viewport.GetComponent<ScrollRect>();scroller.scrollSensitivity=60;
            var empty=reference.GetText("Empty");Box(empty.rectTransform,18,132,444,120);empty.fontSize=18;
            var detail=refs.Find(entry=>entry.Key=="SelectedIcon");Image inspection;
            if(detail.Target==null)
            {
                inspection=Paint(Node("SelectedIcon",source),Color.white);inspection.preserveAspect=true;
                refs.Add(new LuaReference.Entry("SelectedIcon",inspection));
            }
            else inspection=(Image)detail.Target;
            inspection.transform.SetParent(source,false);Box(inspection.rectTransform,18,496,108,100);
            var name=reference.GetText("ItemName");name.transform.SetParent(source,false);Box(name.rectTransform,138,498,360,30);name.fontSize=18;
            var description=reference.GetText("ItemDetail");description.transform.SetParent(source,false);Box(description.rectTransform,138,536,360,60);description.fontSize=14;
            var status=reference.GetText("Status");Box(status.rectTransform,24,714,1192,24);status.fontSize=14;
            var hint=frame.Find("Hint").GetComponent<Text>();Box(hint.rectTransform,24,741,1192,19);hint.fontSize=12;
            var summary=reference.GetText("Summary");Box(summary.rectTransform,40,66,1140,27);summary.fontSize=15;
            frame.Find("Transfer").gameObject.SetActive(false);
            var serialized=new SerializedObject(root.GetComponent<LootPanelView>());
            serialized.FindProperty("detailIcon").objectReferenceValue=inspection;serialized.ApplyModifiedPropertiesWithoutUndo();
            layout.Labels=root.GetComponentsInChildren<Text>(true);EditorUtility.SetDirty(inventory);
            reference.SetEditorBindings(refs.ToArray());
        }
        private static void Build(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var refs=new List<LuaReference.Entry>(reference.GetEditorBindings());
            var rect=(RectTransform)root.transform;Paint(rect,new Color(.015f,.025f,.03f,.96f),true);
            var frame=Node("Frame",rect);frame.anchorMin=frame.anchorMax=frame.pivot=new Vector2(.5f,.5f);frame.sizeDelta=new Vector2(1240,760);Paint(frame,Ink);
            var stripe=Node("Accent",frame);Box(stripe,24,26,4,42);Paint(stripe,Gold);
            Label("Title",frame,"搜刮战利品",27,40,20,850,40,refs).color=Gold;
            Label("Summary",frame,"",14,40,70,1140,46,refs).color=Muted;
            var closeRect=Node("Close",frame);Box(closeRect,1056,26,160,36);var closeImage=Paint(closeRect,new Color(.14f,.18f,.18f),true);
            var close=closeRect.gameObject.AddComponent<Button>();close.targetGraphic=closeImage;close.navigation=new Navigation {mode=Navigation.Mode.None};
            Label("CloseLabel",closeRect,"继续探索  [Esc]",14,4,3,152,30).alignment=TextAnchor.MiddleCenter;refs.Add(new LuaReference.Entry("Close",close));
            var bag=Node("Bag",frame);Box(bag,24,126,548,506);Paint(bag,Card);
            Label("BagTitle",bag,"共 享 背 包",18,22,14,504,28).color=Gold;
            Label("Capacity",bag,"",12,22,44,504,24,refs).color=Muted;
            var bagGrid=Node("Grid",bag);Box(bagGrid,22,76,504,420);
            var source=Node("Loot",frame);Box(source,668,126,548,506);Paint(source,Card);
            Label("LootTitle",source,"战 利 品",18,22,14,504,28).color=Gold;
            Label("SearchStatus",source,"",12,22,44,504,24,refs).color=Muted;
            var viewport=Node("Viewport",source);Box(viewport,22,76,504,420);Paint(viewport,Color.clear,true);viewport.gameObject.AddComponent<RectMask2D>();
            var grid=Node("Grid",viewport);Box(grid,0,0,504,420);
            var scroll=viewport.gameObject.AddComponent<ScrollRect>();scroll.viewport=viewport;scroll.content=grid;scroll.horizontal=false;scroll.vertical=true;scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=32;
            var empty=Label("Empty",viewport,"",17,24,144,456,130,refs);empty.alignment=TextAnchor.MiddleCenter;empty.color=Muted;
            Label("Transfer",frame,"←",32,590,314,60,48).alignment=TextAnchor.MiddleCenter;
            var cell=Paint(Node("CellTemplate",frame),new Color(.12f,.15f,.16f));cell.gameObject.SetActive(false);
            var tile=Node("ItemTemplate",frame);Box(tile,0,0,80,80);var bg=Paint(tile,Card,true);
            var icon=Paint(Node("Icon",tile),Color.white);icon.preserveAspect=true;
            var title=Label("Name",tile,"",13,4,4,72,50);
            var amount=Label("Count",tile,"",10,4,60,72,16);amount.alignment=TextAnchor.MiddleRight;amount.color=Gold;
            var ringRect=Node("SearchRing",tile);ringRect.anchorMin=ringRect.anchorMax=ringRect.pivot=new Vector2(.5f,.5f);ringRect.sizeDelta=new Vector2(26,26);ringRect.anchoredPosition=new Vector2(0,7);
            var ring=ringRect.gameObject.AddComponent<LootSearchGraphic>();ring.color=Gold;ring.raycastTarget=false;ring.gameObject.SetActive(false);
            var template=tile.gameObject.AddComponent<InventoryItemView>();template.Bind(tile,bg,icon,title,amount);template.BindSearch(ring);tile.gameObject.SetActive(false);
            Label("ItemName",frame,"选择物品查看详情",18,28,650,600,30,refs).color=Paper;
            Label("ItemDetail",frame,"",13,28,686,600,38,refs).color=Muted;
            Label("Status",frame,"",14,690,650,504,76,refs).color=Gold;
            Label("Hint",frame,"拖动物品收纳  ·  R 旋转  ·  右键取消  ·  未拿走的物品留在原处",12,28,731,1164,22).color=Muted;
            var preview=Paint(Node("PlacementPreview",frame),Color.clear);preview.gameObject.SetActive(false);
            var drag=Label("DragLabel",frame,"",14,0,0,400,28);drag.rectTransform.anchorMin=drag.rectTransform.anchorMax=new Vector2(.5f,.5f);drag.gameObject.SetActive(false);
            var catalog=AssetDatabase.LoadAssetAtPath<EquipmentAssetCatalog>(EquipmentAssets.CatalogPath);
            if(catalog==null) throw new InvalidOperationException("Missing equipment asset catalog.");
            var inventory=root.AddComponent<InventoryPanelView>();
            inventory.Bind(new InventoryPanelView.Layout {Root=rect,Frame=frame,Grid=bagGrid,Template=template,CellTemplate=cell,Preview=preview,DragLabel=drag,Labels=root.GetComponentsInChildren<Text>(true),Slots=Array.Empty<InventoryPanelView.Slot>()},catalog);
            var inspection=Paint(Node("SelectedIcon",source),Color.white);inspection.preserveAspect=true;refs.Add(new LuaReference.Entry("SelectedIcon",inspection));
            var loot=root.AddComponent<LootPanelView>();loot.Bind(inventory,grid,template,cell,catalog,scroll,inspection);
            refs.Add(new LuaReference.Entry("Inventory",inventory));refs.Add(new LuaReference.Entry("Loot",loot));reference.SetEditorBindings(refs.ToArray());
        }
    }
}
