using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    [InitializeOnLoad]
    public static class EquipmentAssets
    {
        public const string CatalogPath="Assets/DynamicAsset/EquipmentDemo/EquipmentAssets.asset";
        private const string Root="Assets/DynamicAsset/EquipmentDemo";
        [Serializable] private sealed class AssetRow {public int id;public string modelPath,prefabPath;}
        [Serializable] private sealed class AssetTable {public AssetRow[] rows;}
        [Serializable] private sealed class SocketRow {public int id,weaponItemId;public float[] position,rotation;}
        [Serializable] private sealed class SocketTable {public SocketRow[] rows;}
        [Serializable] private sealed class ItemRow {public int id,assetId;public string kind,iconPath;}
        [Serializable] private sealed class ItemTable {public ItemRow[] rows;}
        private static readonly Color Ink=new Color(.055f,.067f,.065f),Tile=new Color(.095f,.116f,.106f),Gold=new Color(.71f,.59f,.35f),Paper=new Color(.87f,.85f,.76f);
        static EquipmentAssets() {LuaViewHints.Register(typeof(EquipmentWorkbenchView),"CS.ProjectY.UI.EquipmentWorkbenchView");}
        private static T Read<T>(string table) => JsonUtility.FromJson<T>(File.ReadAllText("Config/Tables/Equipment/"+table+".json"));
        private static void Folder(string path)
        {
            if(AssetDatabase.IsValidFolder(path)) return;
            var parent=Path.GetDirectoryName(path).Replace('\\','/');Folder(parent);AssetDatabase.CreateFolder(parent,Path.GetFileName(path));
        }
        [MenuItem("Project Y/装备/同步模型与改装界面")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("装备资源同步需要 Edit Mode。");
            Folder(Root+"/Materials");Folder(Root+"/Weapons");
            var template=AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/MapLowPoly/Materials/M_MapLP_Timber.mat");
            var colors=new Dictionary<string,string>{{"EqBronze","b29a65"},{"EqIron","424e52"},{"EqCyan","55c3be"},{"EqAmber","e0a756"}};
            foreach(var pair in colors)
            {
                string name="M_MapLP_"+pair.Key,path=Root+"/Materials/"+name+".mat";
                var mat=AssetDatabase.LoadAssetAtPath<Material>(path);
                if(mat==null) {mat=new Material(template) {name=name};ColorUtility.TryParseHtmlString("#"+pair.Value,out var color);mat.color=color;mat.SetFloat("_Glossiness",.12f);AssetDatabase.CreateAsset(mat,path);}
            }
            var assets=Read<AssetTable>("EquipmentAssetTable").rows;
            foreach(var row in assets)
            {
                AssetDatabase.ImportAsset(row.modelPath,ImportAssetOptions.ForceSynchronousImport);
                var importer=(ModelImporter)AssetImporter.GetAtPath(row.modelPath);
                importer.bakeAxisConversion=true;importer.globalScale=1;importer.importAnimation=false;importer.importCameras=false;importer.importLights=false;
                var obj=AssetDatabase.LoadAssetAtPath<GameObject>(row.modelPath);
                foreach(var renderer in obj.GetComponentsInChildren<Renderer>()) foreach(var material in renderer.sharedMaterials)
                {
                    var name=material.name;
                    var mapped=AssetDatabase.LoadAssetAtPath<Material>(Root+"/Materials/"+name+".mat")??AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/MapLowPoly/Materials/"+name+".mat");
                    if(mapped==null) throw new InvalidOperationException("Missing equipment palette: "+name);
                    importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material),name),mapped);
                }
                importer.SaveAndReimport();
            }
            var items=Read<ItemTable>("EquipmentItemTable").rows;
            var sockets=Read<SocketTable>("EquipmentSocketTable").rows;
            foreach(var item in items) if(item.kind=="weapon")
            {
                var asset=Array.Find(assets,x=>x.id==item.assetId);
                var root=new GameObject("Weapon_"+item.id);
                try
                {
                    var model=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(asset.modelPath));model.transform.SetParent(root.transform,false);
                    var mounts=new List<WeaponModelView.Mount>();
                    foreach(var socket in sockets) if(socket.weaponItemId==item.id)
                    {
                        var anchor=new GameObject("Socket_"+socket.id).transform;anchor.SetParent(root.transform,false);
                        anchor.localPosition=new Vector3(socket.position[0],socket.position[1],socket.position[2]);anchor.localRotation=Quaternion.Euler(socket.rotation[0],socket.rotation[1],socket.rotation[2]);
                        mounts.Add(new WeaponModelView.Mount {Id=socket.id,Anchor=anchor});
                    }
                    root.AddComponent<WeaponModelView>().SetMounts(mounts.ToArray());PrefabUtility.SaveAsPrefabAsset(root,asset.prefabPath);
                }
                finally {Object.DestroyImmediate(root);}
            }
            var catalog=AssetDatabase.LoadAssetAtPath<EquipmentAssetCatalog>(CatalogPath);
            if(catalog==null) {catalog=ScriptableObject.CreateInstance<EquipmentAssetCatalog>();AssetDatabase.CreateAsset(catalog,CatalogPath);}
            var entries=new List<EquipmentAssetCatalog.Entry>();
            foreach(var row in assets) entries.Add(new EquipmentAssetCatalog.Entry {Id=row.id,Path=row.prefabPath,Prefab=AssetDatabase.LoadAssetAtPath<GameObject>(row.prefabPath)});
            catalog.SetEntries(entries.ToArray());
            var icons=new List<EquipmentAssetCatalog.Icon>();
            foreach(var item in items)
            {
                var sprite=item.iconPath==""?null:AssetDatabase.LoadAssetAtPath<Sprite>(item.iconPath);
                if(item.iconPath!=""&&sprite==null) throw new InvalidOperationException("Invalid item Sprite: "+item.iconPath);
                icons.Add(new EquipmentAssetCatalog.Icon {Id=item.id,Path=item.iconPath,Sprite=sprite});
            }
            catalog.SetIcons(icons.ToArray());EditorUtility.SetDirty(catalog);
            Entry("EquipmentRow",UIKind.Widget,BuildRow);
            Entry("EquipmentWorkbench",UIKind.Panel,root=>BuildPanel(root,catalog));
            PawnAssetMenu.Sync();BattleHUDAssets.SyncIcons();AssetDatabase.SaveAssets();
            Debug.Log("Equipment models, sockets, pawn bindings and workbench ready.");
        }
        private static void Entry(string name,UIKind kind,Action<GameObject> build)
        {
            var entry=PanelAssets.LoadOrCreate().Entries.Find(e=>e.Name==name);
            if(entry==null) entry=PanelAssets.Save(new PanelDefinition {Name=name,Module="Equipment",Kind=kind,Layer="Popup",Modal=kind==UIKind.Panel,Cache=true,CloseOnBack=true,PauseWorldOnOpen=kind==UIKind.Panel},null);
            PanelAssets.Generate(entry);var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                if(root.transform.childCount==0) build(root);
                if(name=="EquipmentWorkbench") UpgradeWorkbench(root);
                if(name=="EquipmentRow")
                {
                    var reference=root.GetComponent<LuaReference>();
                    if(!Array.Exists(reference.GetEditorBindings(),e=>e.Key=="Layout")) Bind(root,new List<LuaReference.Entry>{Ref("Layout",root.GetComponent<LayoutElement>())});
                }
                root.GetComponent<LuaReference>().ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                LuaViewHints.Export(root.GetComponent<LuaReference>(),entry.ViewType);
            }
            finally {PrefabUtility.UnloadPrefabContents(root);}
        }
        private static RectTransform Node(string name,Transform parent)
        {var obj=new GameObject(name,typeof(RectTransform));obj.transform.SetParent(parent,false);return (RectTransform)obj.transform;}
        private static void Stretch(RectTransform r,float left=0,float bottom=0,float right=0,float top=0)
        {r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=new Vector2(left,bottom);r.offsetMax=new Vector2(-right,-top);}
        private static void Box(RectTransform r,float x,float y,float w,float h)
        {r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);}
        private static Image Paint(RectTransform r,Color color,bool raycast=false)
        {var image=r.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=raycast;return image;}
        private static Text Text(string name,Transform parent,string value,int size=14)
        {
            var r=Node(name,parent);Stretch(r);var t=r.gameObject.AddComponent<Text>();t.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");t.fontSize=size;t.color=Paper;t.text=value;t.raycastTarget=false;t.supportRichText=false;
            t.horizontalOverflow=HorizontalWrapMode.Wrap;t.verticalOverflow=VerticalWrapMode.Truncate;return t;
        }
        private static Button Button(string name,Transform parent,string text,out Text label)
        {
            var r=Node(name,parent);var image=Paint(r,Tile,true);var b=r.gameObject.AddComponent<Button>();b.targetGraphic=image;b.navigation=new Navigation {mode=Navigation.Mode.None};
            label=Text("Label",r,text);label.alignment=TextAnchor.MiddleCenter;Stretch(label.rectTransform,6,3,6,3);return b;
        }
        private static void Height(RectTransform r,float height)
        {var e=r.gameObject.AddComponent<LayoutElement>();e.minHeight=e.preferredHeight=height;}
        private static void Vertical(RectTransform r,int space=8)
        {
            var group=r.gameObject.AddComponent<VerticalLayoutGroup>();group.spacing=space;group.childControlWidth=true;group.childControlHeight=true;group.childForceExpandWidth=true;group.childForceExpandHeight=false;
            var fitter=r.gameObject.AddComponent<ContentSizeFitter>();fitter.verticalFit=ContentSizeFitter.FitMode.PreferredSize;
        }
        private static RectTransform Scroll(RectTransform parent,float top)
        {
            var root=Node("Scroll",parent);Stretch(root,12,12,12,top);var scroll=root.gameObject.AddComponent<ScrollRect>();scroll.horizontal=false;scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=30;
            var viewport=Node("Viewport",root);Stretch(viewport);Paint(viewport,Ink,true);viewport.gameObject.AddComponent<RectMask2D>();
            var content=Node("Content",viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=Vector2.zero;Vertical(content);
            scroll.viewport=viewport;scroll.content=content;return content;
        }
        private static void Bind(GameObject root,List<LuaReference.Entry> entries)
        {var r=root.GetComponent<LuaReference>();var all=new List<LuaReference.Entry>(r.GetEditorBindings());all.AddRange(entries);r.SetEditorBindings(all.ToArray());}
        private static LuaReference.Entry Ref(string key,Component c)=>new LuaReference.Entry(key,c);
        private static void UpgradeWorkbench(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var view=root.GetComponent<EquipmentWorkbenchView>();var layout=view.EditorLayout;
            var refs=new List<LuaReference.Entry>();
            if(layout.SocketDots==null||layout.SocketDots.Length==0)
            {
                layout.SocketDots=new RectTransform[layout.Sockets.Length];layout.SocketLeads=new RectTransform[layout.Sockets.Length];layout.SocketTails=new RectTransform[layout.Sockets.Length];
                for(int i=0;i<layout.Sockets.Length;i++)
                {
                    var dot=Node("SocketPoint"+i,layout.Preview);dot.sizeDelta=new Vector2(7,7);dot.localRotation=Quaternion.Euler(0,0,45);Paint(dot,Gold);
                    var lead=Node("SocketLeader"+i,layout.Preview);Paint(lead,new Color(Gold.r,Gold.g,Gold.b,.8f));
                    var tail=Node("SocketLeaderTail"+i,layout.Preview);Paint(tail,Gold);
                    layout.SocketDots[i]=dot;layout.SocketLeads[i]=lead;layout.SocketTails[i]=tail;
                    lead.SetSiblingIndex(0);tail.SetSiblingIndex(0);dot.SetAsLastSibling();
                    reference.GetText("SocketText"+(i+1)).fontSize=12;
                }
            }
            if(!Array.Exists(reference.GetEditorBindings(),e=>e.Key=="CategoryText"))
            {
                var filter=Node("WeaponCategory",layout.Inventory);filter.anchorMin=new Vector2(0,1);filter.anchorMax=Vector2.one;filter.pivot=new Vector2(.5f,1);filter.anchoredPosition=new Vector2(0,-48);filter.sizeDelta=new Vector2(-24,30);
                Text label;var prev=Button("Previous",filter,"‹",out label);Box((RectTransform)prev.transform,0,0,26,30);
                var next=Button("Next",filter,"›",out label);var nextRect=(RectTransform)next.transform;nextRect.anchorMin=nextRect.anchorMax=new Vector2(1,1);nextRect.pivot=Vector2.one;nextRect.anchoredPosition=Vector2.zero;nextRect.sizeDelta=new Vector2(26,30);
                var title=Text("Category",filter,"全部武器",13);title.alignment=TextAnchor.MiddleCenter;Stretch(title.rectTransform,28,0,28,0);
                refs.Add(Ref("CategoryPrevious",prev));refs.Add(Ref("CategoryNext",next));refs.Add(Ref("CategoryText",title));
                var content=reference.GetTransform("InventorySlots");var scroll=content.GetComponentInParent<ScrollRect>();
                Stretch((RectTransform)scroll.transform,12,12,12,88);
            }
            if(!Array.Exists(reference.GetEditorBindings(),e=>e.Key=="Requirements"))
            {
                var content=reference.GetText("SocketTitle").transform.parent;
                var requirements=Text("Requirements",content,"",13);requirements.transform.SetAsFirstSibling();requirements.color=new Color(.91f,.75f,.47f);requirements.verticalOverflow=VerticalWrapMode.Overflow;
                refs.Add(Ref("Requirements",requirements));
            }
            var subtitle=reference.GetText("Subtitle");subtitle.rectTransform.sizeDelta=new Vector2(340,48);subtitle.fontSize=12;
            var heading=layout.Heading.GetComponent<Text>();heading.resizeTextForBestFit=true;heading.resizeTextMinSize=14;heading.resizeTextMaxSize=22;
            Bind(root,refs);layout.Labels=root.GetComponentsInChildren<Text>(true);EditorUtility.SetDirty(view);
        }
        private static void BuildRow(GameObject root)
        {
            var r=(RectTransform)root.transform;r.sizeDelta=new Vector2(220,68);Height(r,68);
            var image=Paint(r,Tile,true);var button=root.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation {mode=Navigation.Mode.None};
            var selected=Node("Selected",r);Stretch(selected);var edge=Node("Line",selected);Box(edge,0,0,3,68);Paint(edge,Gold);
            var icon=Paint(Node("Icon",r),Color.white);Box(icon.rectTransform,10,14,32,32);icon.preserveAspect=true;icon.enabled=false;
            var title=Text("Title",r,"",13);Stretch(title.rectTransform,50,34,8,9);
            var detail=Text("Detail",r,"",11);Stretch(detail.rectTransform,50,5,8,35);detail.color=new Color(.56f,.65f,.59f);
            Bind(root,new List<LuaReference.Entry> {Ref("Button",button),Ref("Icon",icon),Ref("Title",title),Ref("Detail",detail),Ref("Selected",selected),Ref("Group",root.GetComponent<CanvasGroup>())});
        }
        private static void BuildPanel(GameObject root,EquipmentAssetCatalog catalog)
        {
            var refs=new List<LuaReference.Entry>();var rect=(RectTransform)root.transform;Paint(rect,Ink,true);
            var safe=Node("SafeArea",rect);Stretch(safe);
            var heading=Text("Heading",safe,"旅 人 工 坊  /  FIELD WORKBENCH",22);Box(heading.rectTransform,20,16,700,34);heading.color=Gold;heading.resizeTextForBestFit=true;heading.resizeTextMinSize=14;heading.resizeTextMaxSize=22;
            Text label;var close=Button("Close",safe,"关闭 [I / Esc]",out label);var closeRect=(RectTransform)close.transform;closeRect.anchorMin=closeRect.anchorMax=new Vector2(1,1);closeRect.pivot=new Vector2(1,1);closeRect.anchoredPosition=new Vector2(-20,-18);closeRect.sizeDelta=new Vector2(150,32);refs.Add(Ref("Close",close));
            var actors=Node("Actors",safe);var grid=actors.gameObject.AddComponent<GridLayoutGroup>();grid.cellSize=new Vector2(150,36);grid.spacing=new Vector2(8,0);
            for(int i=1;i<=4;i++) {var b=Button("Actor"+i,actors,"",out label);refs.Add(Ref("Actor"+i,b));refs.Add(Ref("ActorText"+i,label));}
            var inventory=Node("Inventory",safe);Paint(inventory,Tile);var inventoryTitle=Text("InventoryTitle",inventory,"共 享 背 包",16);Box(inventoryTitle.rectTransform,12,14,200,28);inventoryTitle.color=Gold;
            var inventorySlots=Scroll(inventory,50);refs.Add(Ref("InventorySlots",inventorySlots));
            var preview=Node("Preview",safe);var raw=preview.gameObject.AddComponent<RawImage>();raw.color=Color.white;
            var title=Text("WeaponTitle",preview,"",21);Stretch(title.rectTransform,16,0,16,16);title.rectTransform.anchorMin=new Vector2(0,1);title.rectTransform.offsetMin=new Vector2(16,-50);refs.Add(Ref("Title",title));
            var subtitle=Text("Subtitle",preview,"",12);Box(subtitle.rectTransform,16,52,350,30);subtitle.color=new Color(.54f,.66f,.60f);refs.Add(Ref("Subtitle",subtitle));
            var socketRects=new RectTransform[3];
            for(int i=1;i<=3;i++) {var b=Button("Socket"+i,preview,"",out label);var r=(RectTransform)b.transform;r.sizeDelta=new Vector2(144,34);socketRects[i-1]=r;label.color=Gold;refs.Add(Ref("Socket"+i,b));refs.Add(Ref("SocketText"+i,label));}
            var hint=Text("OrbitHint",preview,"拖动旋转  ·  滚轮缩放  ·  点击挂点",11);Stretch(hint.rectTransform,16,12,16,0);hint.rectTransform.anchorMax=new Vector2(1,0);hint.rectTransform.offsetMax=new Vector2(-16,32);hint.alignment=TextAnchor.MiddleCenter;
            var details=Node("Details",safe);Paint(details,Tile);var content=Scroll(details,12);
            var slotTitle=Text("SocketTitle",content,"",15);Height(slotTitle.rectTransform,30);slotTitle.color=Gold;refs.Add(Ref("SocketTitle",slotTitle));
            var options=Node("Options",content);Vertical(options);refs.Add(Ref("OptionSlots",options));
            var remove=Button("Remove",content,"卸下选中挂点组件",out label);Height((RectTransform)remove.transform,32);refs.Add(Ref("Remove",remove));
            var fill=Button("Fill",content,"补满当前弹匣",out label);Height((RectTransform)fill.transform,32);refs.Add(Ref("Fill",fill));
            var statsTitle=Text("StatsTitle",content,"装 配 后 的 技 能",15);Height(statsTitle.rectTransform,34);statsTitle.color=Gold;
            var stats=Text("Stats",content,"",13);stats.verticalOverflow=VerticalWrapMode.Overflow;refs.Add(Ref("Stats",stats));
            var footer=Node("Footer",safe);
            var equip=Button("Equip",footer,"",out label);Box((RectTransform)equip.transform,0,0,220,40);refs.Add(Ref("Equip",equip));refs.Add(Ref("EquipText",label));
            var unequip=Button("Unequip",footer,"卸下角色武器",out label);Box((RectTransform)unequip.transform,232,0,144,40);refs.Add(Ref("Unequip",unequip));
            var status=Text("Status",footer,"",12);Stretch(status.rectTransform,390,0,0,0);status.alignment=TextAnchor.MiddleLeft;refs.Add(Ref("Status",status));
            var view=root.AddComponent<EquipmentWorkbenchView>();view.Bind(new EquipmentWorkbenchView.Layout {Root=rect,Safe=safe,Inventory=inventory,Preview=preview,Details=details,Actors=actors,Footer=footer,Image=raw,Sockets=socketRects,Labels=root.GetComponentsInChildren<Text>(true),ActorGrid=grid,Equip=(RectTransform)equip.transform,Unequip=(RectTransform)unequip.transform,Status=status.rectTransform,Heading=heading.rectTransform,Close=closeRect},catalog);
            refs.Add(Ref("Workbench",view));Bind(root,refs);
        }
    }
}
