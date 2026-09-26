using System;
using System.Collections.Generic;
using ProjectY.Samples;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Persistent authoring entry for the inventory panel and its serialized view bindings.</summary>
    [InitializeOnLoad]
    public static class InventoryAssets
    {
        private static readonly Color Ink=new Color(.045f,.058f,.063f),Card=new Color(.075f,.095f,.10f),Gold=new Color(.76f,.65f,.41f),Paper=new Color(.87f,.87f,.79f),Muted=new Color(.49f,.59f,.59f);
        static InventoryAssets()
        {
            LuaViewHints.Register(typeof(InventoryPanelView),"CS.ProjectY.UI.InventoryPanelView");
            LuaViewHints.Register(typeof(InventoryCharacterView),"CS.ProjectY.UI.InventoryCharacterView");
        }
        [MenuItem("Project Y/装备/同步背包界面")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("背包界面同步需要 Edit Mode。");
            var entry=PanelAssets.LoadOrCreate().Entries.Find(e=>e.Name=="Inventory");
            if(entry==null) entry=PanelAssets.Save(new PanelDefinition {Name="Inventory",Module="Equipment",Kind=UIKind.Panel,Layer="Popup",Modal=true,Cache=true,CloseOnBack=true,PauseWorldOnOpen=true},null);
            PanelAssets.Generate(entry);
            var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                if(root.transform.childCount==0) Build(root);
                if(root.GetComponent<InventoryPanelView>()==null) throw new InvalidOperationException("现有背包 Prefab 缺少 InventoryPanelView，请检查手工编辑。");
                UpgradeCharacter(root);
                root.GetComponent<LuaReference>().ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                LuaViewHints.Export(root.GetComponent<LuaReference>(),entry.ViewType);
            }
            finally {PrefabUtility.UnloadPrefabContents(root);}
            EquipmentAssets.SyncItemIcons();AssetDatabase.SaveAssets();
            Debug.Log("Inventory panel and LuaReference bindings saved.");
        }
        private static RectTransform Node(string name,Transform parent)
        {var go=new GameObject(name,typeof(RectTransform));go.transform.SetParent(parent,false);return (RectTransform)go.transform;}
        private static void Box(RectTransform r,float x,float y,float w,float h)
        {r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);}
        private static void Stretch(RectTransform r,float inset=0)
        {r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=Vector2.one*inset;r.offsetMax=-Vector2.one*inset;}
        private static Image Paint(RectTransform r,Color color,bool hit=false)
        {var image=r.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=hit;return image;}
        private static Text Label(string name,Transform parent,string text,int size,float x,float y,float w,float h)
        {
            var r=Node(name,parent);Box(r,x,y,w,h);var t=r.gameObject.AddComponent<Text>();
            t.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");t.text=text;t.fontSize=size;t.color=Paper;t.raycastTarget=false;t.supportRichText=false;return t;
        }
        private static Button Button(string name,Transform parent,string text,float x,float y,float w,float h,List<LuaReference.Entry> refs)
        {
            var r=Node(name,parent);Box(r,x,y,w,h);var image=Paint(r,new Color(.14f,.18f,.18f),true);
            var button=r.gameObject.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation {mode=Navigation.Mode.None};
            var label=Label("Label",r,text,14,5,2,w-10,h-4);label.alignment=TextAnchor.MiddleCenter;
            refs.Add(new LuaReference.Entry(name,button));refs.Add(new LuaReference.Entry(name+"Text",label));return button;
        }
        [Serializable] private sealed class PartRow {public int id;public string prefabPath;}
        [Serializable] private sealed class PartTable {public PartRow[] rows;}
        private static void UpgradeCharacter(GameObject root)
        {
            if(root.GetComponentInChildren<InventoryCharacterView>(true)!=null) return;
            var reference=root.GetComponent<LuaReference>();var refs=new List<LuaReference.Entry>(reference.GetEditorBindings());
            var view=root.GetComponent<InventoryPanelView>();var layout=view.EditorLayout;
            layout.Frame.sizeDelta=new Vector2(1440,760);
            var equipment=(RectTransform)layout.Slots[0].Rect.parent;Box(equipment,20,144,540,520);
            var portrait=Node("CharacterPreview",equipment);Stretch(portrait);portrait.SetAsFirstSibling();
            var raw=portrait.gameObject.AddComponent<RawImage>();raw.color=Color.white;
            var character=portrait.gameObject.AddComponent<InventoryCharacterView>();
            var slots=new List<InventoryPanelView.Slot>(layout.Slots);
            var off=Button("Slot_offhand",portrait,"",0,0,108,88,refs);
            var offRect=(RectTransform)off.transform;
            Label("SlotName",offRect,"副手",12,6,4,96,20).color=Gold;
            var hint=Label("Empty",offRect,"单手 / 盾牌",12,4,28,100,42);hint.color=Muted;hint.alignment=TextAnchor.MiddleCenter;
            slots.Add(new InventoryPanelView.Slot {Key="offhand",Bit=128,Rect=offRect});
            var links=new List<InventoryCharacterView.Callout>();
            var keys=new[]{"head","body","leftRing","rightRing","legs","feet","weapon","offhand"};
            // Two stable docking columns leave the character unobstructed; leaders follow its rotation.
            float[,] positions={{12,22},{420,22},{420,144},{12,144},{12,388},{420,388},{12,266},{420,266}};
            for(int i=0;i<keys.Length;i++)
            {
                var slot=slots.Find(x=>x.Key==keys[i]);slot.Rect.SetParent(portrait,false);Box(slot.Rect,positions[i,0],positions[i,1],108,88);
                foreach(var label in slot.Rect.GetComponentsInChildren<Text>(true))
                {
                    if(label.name=="SlotName") {Box(label.rectTransform,6,4,96,20);if(slot.Key=="weapon") label.text="主手";}
                    else Box(label.rectTransform,4,28,100,52);
                }
                var dot=Node("Anchor_"+slot.Key,portrait);dot.sizeDelta=new Vector2(5,5);Paint(dot,Gold);
                var lead=Node("Leader_"+slot.Key,portrait);Paint(lead,new Color(Gold.r,Gold.g,Gold.b,.65f));lead.SetAsFirstSibling();
                var tail=Node("Tail_"+slot.Key,portrait);Paint(tail,Gold);tail.SetAsFirstSibling();
                links.Add(new InventoryCharacterView.Callout {Slot=slot.Key,Target=slot.Rect,Dot=dot,Lead=lead,Tail=tail});
            }
            Label("OrbitHint",portrait,"拖动角色旋转  ·  滚轮缩放",12,132,489,276,24).alignment=TextAnchor.MiddleCenter;
            var parts=JsonUtility.FromJson<PartTable>(System.IO.File.ReadAllText("Config/Tables/Adventure/PawnPartTable.json")).rows;
            var bindings=new List<MapRuntimeDemo.AssetBinding>();
            foreach(var part in parts)
            {
                var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(part.prefabPath);
                if(prefab==null) throw new InvalidOperationException("角色预览缺少部件: "+part.prefabPath);
                bindings.Add(new MapRuntimeDemo.AssetBinding {id=part.id,path=part.prefabPath,prefab=prefab});
            }
            var rig=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab");
            if(rig==null) throw new InvalidOperationException("角色 Rig 缺失。");
            character.Bind(raw,rig.GetComponent<PawnView>(),bindings.ToArray(),links.ToArray());
            refs.Add(new LuaReference.Entry("Character",character));
            Box((RectTransform)layout.Grid.parent,578,90,548,502);
            var details=(RectTransform)reference.GetText("ItemName").transform.parent;Box(details,1142,90,278,502);
            foreach(RectTransform child in details) child.sizeDelta=new Vector2(242,child.sizeDelta.y);
            Box(reference.GetText("ActorStats").rectTransform,24,682,532,66);
            Box(reference.GetText("Status").rectTransform,580,606,546,130);
            Box((RectTransform)refs.Find(x=>x.Key=="Workbench").Target.transform,1142,608,278,40);
            Box((RectTransform)refs.Find(x=>x.Key=="Close").Target.transform,1260,26,160,36);
            for(int i=1;i<=4;i++) Box((RectTransform)refs.Find(x=>x.Key=="Actor"+i).Target.transform,20+(i-1)*136,90,128,34);
            layout.Slots=slots.ToArray();layout.Labels=root.GetComponentsInChildren<Text>(true);
            reference.SetEditorBindings(refs.ToArray());EditorUtility.SetDirty(view);
        }
        private static void Build(GameObject root)
        {
            var refs=new List<LuaReference.Entry>(root.GetComponent<LuaReference>().GetEditorBindings());
            var rect=(RectTransform)root.transform;Paint(rect,new Color(.015f,.025f,.03f,.98f),true);
            var frame=Node("Frame",rect);frame.anchorMin=frame.anchorMax=frame.pivot=new Vector2(.5f,.5f);frame.sizeDelta=new Vector2(1240,660);Paint(frame,Ink);
            var stripe=Node("Accent",frame);Box(stripe,20,22,4,45);Paint(stripe,Gold);
            Label("Heading",frame,"远 征 行 囊",26,38,16,400,36).color=Gold;
            Label("Subtitle",frame,"INVENTORY  /  装备与空间管理",12,40,55,600,24).color=Muted;
            Button("Close",frame,"关闭  [ I / Esc ]",1054,26,160,36,refs);
            for(int i=1;i<=4;i++)
            {
                Button("Actor"+i,frame,"",20+(i-1)*79,90,73,34,refs);
                var label=(Text)refs.Find(e=>e.Key=="Actor"+i+"Text").Target;
                // Explicit aliases match the actor selector keys used by the controller.
                refs.Add(new LuaReference.Entry("ActorText"+i,label));
            }
            var equipment=Node("Equipment",frame);Box(equipment,20,144,310,430);Paint(equipment,Card);
            var slots=new List<InventoryPanelView.Slot>();
            var keys=new[]{"head","body","leftRing","rightRing","legs","feet","weapon"};
            var names=new[]{"头部","身体甲","左戒指","右戒指","裤子","鞋子","武器"};
            float[,] positions={{105,8,100,78},{105,96,100,108},{8,104,86,82},{216,104,86,82},{105,214,100,96},{105,322,100,96},{8,218,86,192}};
            for(int i=0;i<keys.Length;i++)
            {
                var b=Button("Slot_"+keys[i],equipment,"",positions[i,0],positions[i,1],positions[i,2],positions[i,3],refs);
                var r=(RectTransform)b.transform;
                Label("SlotName",r,names[i],12,6,4,r.rect.width-12,20).color=Gold;
                var hint=Label("Empty",r,"空槽",13,4,27,r.rect.width-8,r.rect.height-32);hint.color=Muted;hint.alignment=TextAnchor.MiddleCenter;
                slots.Add(new InventoryPanelView.Slot {Key=keys[i],Bit=1<<i,Rect=r});
            }
            var stats=Label("ActorStats",frame,"",12,24,584,310,58);stats.color=Muted;refs.Add(new LuaReference.Entry("ActorStats",stats));
            var bag=Node("Bag",frame);Box(bag,350,90,548,502);Paint(bag,Card);
            Label("BagTitle",bag,"共 享 背 包",17,22,15,260,28).color=Gold;
            var capacity=Label("Capacity",bag,"",12,22,46,504,22);capacity.color=Muted;refs.Add(new LuaReference.Entry("Capacity",capacity));
            var grid=Node("Grid",bag);Box(grid,22,76,504,420);
            var cell=Paint(Node("CellTemplate",frame),new Color(.12f,.15f,.16f));cell.gameObject.SetActive(false);
            var tile=Node("ItemTemplate",frame);Box(tile,0,0,80,80);var bg=Paint(tile,Card,true);
            var icon=Paint(Node("Icon",tile),Color.white);Stretch(icon.rectTransform,7);icon.preserveAspect=true;
            var title=Label("Name",tile,"",13,4,4,72,50);Stretch(title.rectTransform,4);title.rectTransform.offsetMin=new Vector2(4,19);title.alignment=TextAnchor.MiddleCenter;
            var amount=Label("Count",tile,"",10,4,60,72,16);amount.rectTransform.anchorMin=new Vector2(0,0);amount.rectTransform.anchorMax=new Vector2(1,0);amount.rectTransform.pivot=new Vector2(.5f,0);amount.rectTransform.offsetMin=new Vector2(4,2);amount.rectTransform.offsetMax=new Vector2(-4,18);amount.alignment=TextAnchor.MiddleRight;amount.color=Gold;
            var template=tile.gameObject.AddComponent<InventoryItemView>();template.Bind(tile,bg,icon,title,amount);tile.gameObject.SetActive(false);
            var details=Node("Details",frame);Box(details,920,90,300,502);Paint(details,Card);
            Label("DetailHeading",details,"物 品 详 情",14,18,17,264,26).color=Gold;
            var itemName=Label("ItemName",details,"",22,18,57,264,66);refs.Add(new LuaReference.Entry("ItemName",itemName));
            var itemDetail=Label("ItemDetail",details,"",14,18,132,264,194);itemDetail.color=Muted;refs.Add(new LuaReference.Entry("ItemDetail",itemDetail));
            Button("Equip",details,"穿戴到当前角色",18,336,264,40,refs);
            Button("Unequip",details,"卸下并放回背包",18,384,264,40,refs);
            Button("Rotate",details,"旋转选中物品  90°",18,432,264,40,refs);
            Button("Workbench",frame,"武器改装工坊  →",920,608,300,36,refs);
            var status=Label("Status",frame,"",12,352,602,542,46);status.color=Gold;refs.Add(new LuaReference.Entry("Status",status));
            var preview=Paint(Node("PlacementPreview",frame),Color.clear);preview.gameObject.SetActive(false);
            var drag=Label("DragLabel",frame,"",13,0,0,320,26);drag.rectTransform.anchorMin=drag.rectTransform.anchorMax=new Vector2(.5f,.5f);drag.gameObject.SetActive(false);
            var view=root.AddComponent<InventoryPanelView>();
            view.Bind(new InventoryPanelView.Layout {Root=rect,Frame=frame,Grid=grid,Template=template,CellTemplate=cell,Preview=preview,DragLabel=drag,Labels=root.GetComponentsInChildren<Text>(true),Slots=slots.ToArray()},AssetDatabase.LoadAssetAtPath<EquipmentAssetCatalog>(EquipmentAssets.CatalogPath));
            refs.Add(new LuaReference.Entry("Inventory",view));root.GetComponent<LuaReference>().SetEditorBindings(refs.ToArray());
        }
    }
}
