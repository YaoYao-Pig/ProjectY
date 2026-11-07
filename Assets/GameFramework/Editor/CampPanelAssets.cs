using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ProjectY.UI;
using ProjectY.Samples;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    public static partial class CampAssets
    {
        private static TMP_FontAsset serif,sans;
        private static List<LuaReference.LocalizedText> localized;
        private static RectTransform Node(string name,Transform parent)
        {var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);return r;}
        private static void Place(RectTransform r,float x,float y,float w,float h)
        {r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);}
        private static void Stretch(RectTransform r,float left=0,float bottom=0,float right=0,float top=0)
        {r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=new Vector2(left,bottom);r.offsetMax=new Vector2(-right,-top);}
        private static Image Paint(RectTransform rect,Color color,string skin=null,bool hit=false)
        {
            var image=rect.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=hit;
            if(skin!=null){image.sprite=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/DynamicAsset/UI/Skins/GuildMatte/"+skin+".png")??throw new InvalidOperationException("Missing camp UI skin: "+skin);image.type=Image.Type.Sliced;image.pixelsPerUnitMultiplier=.4f;}
            return image;
        }
        private static TMP_Text Text(string name,Transform parent,float x,float y,float w,float h,int size=17,bool heading=false,string key=null)
        {
            var rect=Node(name,parent);Place(rect,x,y,w,h);var text=rect.gameObject.AddComponent<TextMeshProUGUI>();text.font=heading?serif:sans;
            text.fontSize=size;text.color=heading?Gold:Paper;text.raycastTarget=false;text.enableWordWrapping=true;text.overflowMode=TextOverflowModes.Overflow;
            if(key!=null){text.text=LuaLanguage.Get(key);localized.Add(new LuaReference.LocalizedText(text,key));}else text.text="";
            return text;
        }
        private static Text Legacy(string name,Transform parent,int size)
        {var rect=Node(name,parent);var text=rect.gameObject.AddComponent<UnityEngine.UI.Text>();text.font=AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf");text.fontSize=size;text.color=Paper;text.raycastTarget=false;text.text="";return text;}
        private static Button Button(string name,Transform parent,float x,float y,float w,float h,string key,out TMP_Text label,bool primary=false)
        {
            var rect=Node(name,parent);Place(rect,x,y,w,h);var image=Paint(rect,Color.white,primary?"button_primary_normal":"button_secondary",true);
            var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};
            var colors=button.colors;colors.highlightedColor=new Color(1,.96f,.8f);colors.pressedColor=new Color(.75f,.76f,.63f);colors.disabledColor=new Color(.58f,.6f,.56f,.7f);button.colors=colors;
            label=Text(name+"Text",rect,10,3,w-20,h-6,16,false,key);label.alignment=TextAlignmentOptions.Center;return button;
        }
        private static ScrollRect Scroll(string name,Transform parent,float x,float y,float w,float h,out RectTransform content,bool layout=true)
        {
            var viewport=Node(name,parent);Place(viewport,x,y,w,h);Paint(viewport,Color.clear,null,true);viewport.gameObject.AddComponent<RectMask2D>();
            content=Node("Content",viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=new Vector2(0,h);
            if(layout)
            {
                var group=content.gameObject.AddComponent<VerticalLayoutGroup>();group.spacing=7;group.childControlWidth=true;group.childControlHeight=true;group.childForceExpandWidth=true;group.childForceExpandHeight=false;group.padding=new RectOffset(1,7,1,1);
                var fit=content.gameObject.AddComponent<ContentSizeFitter>();fit.verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            }
            var scroll=viewport.gameObject.AddComponent<ScrollRect>();scroll.viewport=viewport;scroll.content=content;scroll.horizontal=false;scroll.vertical=true;scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=42;return scroll;
        }
        private static CampListEntry Entry(Transform parent,bool material)
        {
            var rect=Node(material?"MaterialTemplate":"RecipeTemplate",parent);Place(rect,0,0,material?460:244,material?49:78);
            var image=Paint(rect,new Color(.9f,.91f,.85f),material?"leather_surface":"detail_card",!material);var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};button.interactable=!material;
            var entry=rect.gameObject.AddComponent<CampListEntry>();entry.Button=button;
            var layout=rect.gameObject.AddComponent<LayoutElement>();layout.preferredHeight=material?49:78;
            var select=Node("Selection",rect);Stretch(select,2,2,2,2);entry.Selection=Paint(select,new Color(1,.87f,.57f),"inventory_slot_selected");
            var icon=Node("Icon",rect);Place(icon,12,material?7:13,material?34:48,material?34:48);entry.Icon=Paint(icon,Color.white);entry.Icon.preserveAspect=true;
            entry.Title=Text("Name",rect,material?56:72,material?5:12,material?386:156,material?22:30,material?16:17);
            entry.Subtitle=Text("State",rect,material?56:72,material?27:45,material?386:156,material?18:25,material?12:12);entry.Subtitle.color=Muted;
            rect.gameObject.SetActive(false);return entry;
        }
        private static void BuildPanel()
        {
            serif=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/DynamicAsset/UI/Fonts/SourceHanSerifSC-SemiBold.asset");sans=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc.asset");
            if(serif==null||sans==null)throw new InvalidOperationException("Camp requires the existing project typography assets.");
            var config=PanelAssets.LoadOrCreate();var entry=config.Entries.Find(e=>e.Name=="Camp")??throw new InvalidOperationException("Camp panel registration is missing.");
            Directory.CreateDirectory("Art/CampPresentation/Integration");string backup="Art/CampPresentation/Integration/CampPanel.before.prefab";
            if(!File.Exists(backup))File.Copy(entry.PrefabPath,backup);
            var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                // Replace only the user-requested camp panel. Preserve its asset identity and registration.
                for(int i=root.transform.childCount-1;i>=0;i--)Object.DestroyImmediate(root.transform.GetChild(i).gameObject);
                foreach(var component in root.GetComponents<Component>())
                    if(!(component is Transform)&&!(component is LuaPanel)&&!(component is LuaReference)&&!(component is Canvas)&&!(component is CanvasGroup)&&!(component is CanvasScaler)&&!(component is GraphicRaycaster))Object.DestroyImmediate(component);
                localized=new List<LuaReference.LocalizedText>();var refs=new List<LuaReference.Entry>();var rootRect=(RectTransform)root.transform;
                var layout=new CampPanelView.Layout{Root=rootRect};var catalog=AssetDatabase.LoadAssetAtPath<EquipmentAssetCatalog>(EquipmentAssets.CatalogPath);
                var backdrop=Node("BlurredWorld",rootRect);Stretch(backdrop);var background=backdrop.gameObject.AddComponent<RawImage>();background.color=new Color(.47f,.52f,.46f,1);background.raycastTarget=true;
                var sceneRect=Node("CampScene",rootRect);Stretch(sceneRect,0,38,0,76);var sceneImage=sceneRect.gameObject.AddComponent<RawImage>();sceneImage.raycastTarget=true;
                var sceneView=sceneRect.gameObject.AddComponent<CampSceneView>();layout.Scene=sceneView;
                var labelRoot=Node("Facilities",sceneRect);Stretch(labelRoot);layout.FacilityLabels=labelRoot.gameObject;
                layout.Facilities=new Button[4];layout.FacilityTitles=new TMP_Text[4];layout.FacilityStates=new TMP_Text[4];var labels=new RectTransform[4];
                for(int i=0;i<4;i++)
                {
                    var b=Button("Facility"+i,labelRoot,0,0,168,60,null,out var title);labels[i]=(RectTransform)b.transform;labels[i].pivot=new Vector2(.5f,0);layout.Facilities[i]=b;
                    Place(title.rectTransform,12,8,144,25);title.alignment=TextAlignmentOptions.Center;title.font=serif;title.color=Gold;title.fontSize=19;layout.FacilityTitles[i]=title;
                    var status=Text("State",b.transform,8,35,152,18,12);status.color=Muted;status.alignment=TextAlignmentOptions.Center;layout.FacilityStates[i]=status;
                }
                var header=Node("Header",rootRect);header.anchorMin=new Vector2(0,1);header.anchorMax=Vector2.one;header.pivot=new Vector2(.5f,1);header.sizeDelta=new Vector2(0,83);Paint(header,Color.white,"panel_header");
                layout.Title=Text("Title",header,28,10,280,40,30,true);layout.Caption=Text("Caption",header,29,52,900,22,14);layout.Caption.color=Muted;
                layout.Close=Button("Close",header,0,17,154,42,"CampLeave",out _);var closeRect=(RectTransform)layout.Close.transform;closeRect.anchorMin=closeRect.anchorMax=new Vector2(1,1);closeRect.anchoredPosition=new Vector2(-178,-17);
                var loadout=Button("Loadout",header,0,17,154,42,"CampLoadoutTitle",out _);var loadoutRect=(RectTransform)loadout.transform;loadoutRect.anchorMin=loadoutRect.anchorMax=new Vector2(1,1);loadoutRect.anchoredPosition=new Vector2(-344,-17);
                refs.Add(new LuaReference.Entry("Loadout",loadout));
                var roster=Button("Roster",header,0,17,154,42,"RosterTitle",out _);var rosterRect=(RectTransform)roster.transform;rosterRect.anchorMin=rosterRect.anchorMax=new Vector2(1,1);rosterRect.anchoredPosition=new Vector2(-510,-17);
                refs.Add(new LuaReference.Entry("Roster",roster));
                var footer=Node("Footer",rootRect);footer.anchorMin=Vector2.zero;footer.anchorMax=new Vector2(1,0);footer.pivot=new Vector2(.5f,0);footer.sizeDelta=new Vector2(0,36);Paint(footer,new Color(.06f,.08f,.07f,.94f));
                layout.Status=Text("Status",footer,24,7,1180,24,13);Stretch(layout.Status.rectTransform,24,5,24,5);layout.Status.color=Muted;
                var frame=Node("Overlay",rootRect);frame.anchorMin=frame.anchorMax=frame.pivot=new Vector2(.5f,.5f);frame.sizeDelta=new Vector2(1200,640);layout.Frame=frame;Paint(frame,Color.white,"panel_body",true);
                layout.PanelTitle=Text("PanelTitle",frame,30,17,510,37,27,true);layout.PanelSubtitle=Text("PanelSubtitle",frame,31,59,500,21,13);layout.PanelSubtitle.color=Muted;
                layout.Upgrade=Button("Upgrade",frame,852,24,145,38,"CampUpgradeAction",out _);layout.Back=Button("Back",frame,1012,24,158,38,"CampBackToScene",out _);
                var workshop=Node("Workshop",frame);Stretch(workshop);layout.Workshop=workshop.gameObject;
                var listSurface=Node("ListSurface",workshop);Place(listSurface,22,94,258,436);Paint(listSurface,Color.white,"leather_surface");
                layout.ListScroll=Scroll("RecipeList",workshop,30,102,244,420,out var content);layout.ListContent=content;layout.EntryTemplate=Entry(workshop,false);
                var modelFrame=Node("ModelFrame",workshop);Place(modelFrame,295,96,372,434);Paint(modelFrame,new Color(.77f,.78f,.69f),"detail_card");
                var modelImage=Node("Model",modelFrame);Stretch(modelImage,13,41,13,12);var raw=modelImage.gameObject.AddComponent<RawImage>();raw.raycastTarget=false;
                var preview=modelImage.gameObject.AddComponent<CampItemPreview>();preview.Bind(raw,catalog);layout.Preview=preview;
                var modelNames=new[]{"Workbench","Medical","Warehouse"};preview.BindFacilities(modelNames.SelectMany(name=>Enumerable.Range(0,3).Select(level=>Model(name,level))).ToArray());
                Text("ModelLabel",modelFrame,25,399,322,20,12,false,"CampModelLabel").alignment=TextAlignmentOptions.Center;
                layout.DetailTitle=Text("DetailTitle",workshop,690,101,475,39,25,true);
                layout.DetailScroll=Scroll("Description",workshop,690,148,475,115,out var details,false);
                layout.DetailText=Text("DetailText",details,0,0,466,115,16);layout.DetailText.rectTransform.anchorMin=new Vector2(0,1);layout.DetailText.rectTransform.anchorMax=Vector2.one;layout.DetailText.rectTransform.sizeDelta=Vector2.zero;
                var fit=details.gameObject.AddComponent<ContentSizeFitter>();fit.verticalFit=ContentSizeFitter.FitMode.PreferredSize;var group=details.gameObject.AddComponent<VerticalLayoutGroup>();group.childControlWidth=true;group.childControlHeight=true;group.childForceExpandHeight=false;group.childForceExpandWidth=true;
                layout.Cost=Text("Cost",workshop,690,271,475,25,16);layout.Cost.color=Gold;
                var materialsRect=Node("Materials",workshop);Place(materialsRect,690,306,475,152);var mg=materialsRect.gameObject.AddComponent<VerticalLayoutGroup>();mg.spacing=2;mg.childForceExpandWidth=true;mg.childControlWidth=true;mg.childControlHeight=true;mg.childForceExpandHeight=false;
                layout.MaterialContent=materialsRect;layout.MaterialTemplate=Entry(workshop,true);
                layout.Primary=Button("Primary",workshop,690,470,475,43,null,out layout.ActionLabel,true);layout.Reason=Text("Reason",workshop,690,518,475,23,13);layout.Reason.color=new Color(.83f,.65f,.46f);
                var production=Node("Production",frame);Place(production,26,550,1148,66);Paint(production,Color.white,"leather_surface");layout.Production=production.gameObject;
                layout.OrderTitle=Text("OrderTitle",production,17,8,420,24,17);layout.OrderState=Text("OrderState",production,17,36,420,20,13);layout.OrderState.color=Muted;
                var track=Node("Track",production);Place(track,17,61,420,3);Paint(track,new Color(.16f,.19f,.16f));var progress=Node("Progress",track);Stretch(progress);layout.OrderProgress=Paint(progress,Gold,"leather_surface");layout.OrderProgress.type=Image.Type.Filled;layout.OrderProgress.fillMethod=Image.FillMethod.Horizontal;
                layout.Claim=Button("Claim",production,452,13,139,38,"CampClaim",out _);layout.Wait=new Button[3];string[] waitKeys={"CampWaitOneHour","CampWaitSixHours","CampWaitOneDay"};
                for(int i=0;i<3;i++)layout.Wait[i]=Button("Wait"+i,production,612+i*172,13,163,38,waitKeys[i],out _);
                layout.Secondary=new Button[3];layout.SecondaryTitles=new TMP_Text[3];
                for(int i=0;i<3;i++)layout.Secondary[i]=Button("Secondary"+i,workshop,296+i*290,560,278,43,null,out layout.SecondaryTitles[i]);
                BuildWarehouse(frame,rootRect,catalog,layout);
                var inventoryPrefab=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab");
                var character=inventoryPrefab.GetComponentsInChildren<InventoryCharacterView>(true).Single();var source=new SerializedObject(character);
                var pawn=(PawnView)source.FindProperty("pawnPrefab").objectReferenceValue;var bindings=source.FindProperty("parts");var parts=new MapRuntimeDemo.AssetBinding[bindings.arraySize];
                for(int i=0;i<parts.Length;i++){var p=bindings.GetArrayElementAtIndex(i);parts[i]=new MapRuntimeDemo.AssetBinding{id=p.FindPropertyRelative("id").intValue,path=p.FindPropertyRelative("path").stringValue,prefab=(GameObject)p.FindPropertyRelative("prefab").objectReferenceValue};}
                sceneView.Bind(sceneImage,background,AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Runtime/UI/CampBackdropBlur.shader"),labels,pawn,parts);
                preview.BindPawns(pawn,parts);
                var view=root.AddComponent<CampPanelView>();view.Bind(layout,catalog);
                refs.Add(new LuaReference.Entry("Camp",view));refs.Add(new LuaReference.Entry("Scene",sceneView));refs.Add(new LuaReference.Entry("ItemPreview",preview));refs.Add(new LuaReference.Entry("Inventory",layout.Inventory));refs.Add(new LuaReference.Entry("Warehouse",layout.Warehouse));
                var reference=root.GetComponent<LuaReference>();reference.SetEditorBindings(refs.ToArray());reference.SetEditorLocalizations(localized.ToArray());reference.ValidateBindings();
                frame.gameObject.SetActive(false);
                entry.CloseOnBack=false;entry.ModalDimAlpha=0;entry.Modal=true;entry.PauseWorldOnOpen=true;EditorUtility.SetDirty(config);
                PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                LuaViewHints.Register(typeof(CampPanelView),"CS.ProjectY.UI.CampPanelView");LuaViewHints.Register(typeof(CampSceneView),"CS.ProjectY.UI.CampSceneView");LuaViewHints.Register(typeof(CampItemPreview),"CS.ProjectY.UI.CampItemPreview");LuaViewHints.Register(typeof(CampWarehouseView),"CS.ProjectY.UI.CampWarehouseView");LuaViewHints.Export(reference,entry.ViewType);
            }
            finally{PrefabUtility.UnloadPrefabContents(root);}
        }
        private static void BuildWarehouse(RectTransform frame,RectTransform root,EquipmentAssetCatalog catalog,CampPanelView.Layout layout)
        {
            var storage=Node("Warehouse",frame);Stretch(storage);layout.Storage=storage.gameObject;
            for(int i=0;i<2;i++){var surface=Node(i==0?"BagSurface":"WarehouseSurface",storage);Place(surface,26+i*582,94,566,436);Paint(surface,Color.white,"leather_surface");}
            Text("BagTitle",storage,46,103,320,30,22,true,"CampBagTitle");Text("WarehouseTitle",storage,628,103,320,30,22,true,"CampWarehouseTitle");
            layout.BagCapacity=Text("BagCapacity",storage,46,136,520,22,13);layout.BagCapacity.color=Muted;
            layout.WarehouseCapacity=Text("WarehouseCapacity",storage,628,136,520,22,13);layout.WarehouseCapacity.color=Muted;
            var bagGrid=Node("BagGrid",storage);Place(bagGrid,46,173,520,342);
            var scroll=Scroll("WarehouseGrid",storage,628,173,520,342,out var grid,false);
            var tile=Node("InventoryItemTemplate",storage);Place(tile,0,0,80,80);var bg=Paint(tile,Ink,"inventory_slot",true);var icon=Paint(Node("Icon",tile),Color.white);icon.preserveAspect=true;
            var name=Legacy("Name",tile,15);var amount=Legacy("Amount",tile,12);var template=tile.gameObject.AddComponent<InventoryItemView>();template.Bind(tile,bg,icon,name,amount);LegendaryEquipmentUIAssets.BindTile(template);tile.gameObject.SetActive(false);
            var cell=Paint(Node("CellTemplate",storage),new Color(.17f,.2f,.17f),"inventory_slot");cell.gameObject.SetActive(false);
            var target=Paint(Node("PlacementPreview",frame),Color.clear);target.gameObject.SetActive(false);
            var drag=Legacy("DragLabel",frame,15);drag.rectTransform.anchorMin=drag.rectTransform.anchorMax=new Vector2(.5f,.5f);drag.rectTransform.sizeDelta=new Vector2(450,28);drag.gameObject.SetActive(false);
            var inventory=storage.gameObject.AddComponent<InventoryPanelView>();inventory.Bind(new InventoryPanelView.Layout{Root=root,Frame=frame,Grid=bagGrid,GridSize=new Vector2(520,342),Template=template,CellTemplate=cell,Preview=target,DragLabel=drag,Labels=Array.Empty<Text>(),Slots=Array.Empty<InventoryPanelView.Slot>()},catalog);layout.Inventory=inventory;
            var warehouse=storage.gameObject.AddComponent<CampWarehouseView>();warehouse.Bind(inventory,grid,scroll,template,cell,catalog);layout.Warehouse=warehouse;
            layout.StorageName=Text("StorageName",storage,46,550,390,32,21,true);layout.StorageDetail=Text("StorageDetail",storage,450,550,700,52,15);
            storage.gameObject.SetActive(false);
        }
    }
}
