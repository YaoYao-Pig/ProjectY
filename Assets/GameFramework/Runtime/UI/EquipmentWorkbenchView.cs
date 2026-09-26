using System;
using ProjectY.Samples;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    [LuaCallCSharp]
    public sealed class EquipmentWorkbenchView : MonoBehaviour, IDragHandler, IScrollHandler
    {
        [Serializable] public sealed class Layout
        {
            public RectTransform Root,Safe,Inventory,Preview,Details,Actors,Footer;
            public RawImage Image;
            public RectTransform[] Sockets;
            public RectTransform[] SocketDots,SocketLeads,SocketTails;
            public Text[] Labels;
            public GridLayoutGroup ActorGrid;
            public RectTransform Equip,Unequip,Status,Heading,Close;
        }
        [SerializeField] private Layout layout;
        [SerializeField] private EquipmentAssetCatalog catalog;
        private GameObject studio;
        private Transform pivot;
        private WeaponModelView weapon;
        private EquipmentVisualData.Weapon model;
        private Camera cameraView;
        private RenderTexture texture;
        private Font font;
        private float yaw=25,tilt=8,zoom=1.45f;
        private int assetId;
        private Vector2 previousSize;
        public Font Font => font??(font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","Noto Sans CJK SC","Arial"},16));
        public void Prepare()
        {
            if(layout.SocketDots==null||layout.SocketDots.Length!=layout.Sockets.Length||layout.SocketLeads==null||layout.SocketLeads.Length!=layout.Sockets.Length||layout.SocketTails==null||layout.SocketTails.Length!=layout.Sockets.Length)
                throw new InvalidOperationException("工坊挂点引线未绑定，请同步装备界面。");
            foreach(var text in layout.Labels) text.font=Font;
            Arrange();
        }
        public void ShowWeapon(LuaTable snapshot)
        {
            model=EquipmentVisualData.Weapon.Read(snapshot);
            if(studio==null) CreateStudio();
            if(assetId!=model.Model.Id)
            {
                if(weapon!=null) WeaponModelView.Remove(weapon.gameObject);
                weapon=Instantiate(catalog.Resolve(model.Model),pivot,false).GetComponent<WeaponModelView>();
                if(weapon==null) throw new InvalidOperationException("改装武器缺少 WeaponModelView。");
                assetId=model.Model.Id;yaw=model.PreviewRotation.y;tilt=model.PreviewRotation.x;zoom=model.PreviewZoom;
            }
            weapon.Apply(model,catalog);
            // Attachments are added after instantiation, so update the complete renderer subtree.
            foreach(var node in weapon.GetComponentsInChildren<Transform>(true)) node.gameObject.layer=31;
            var bounds=new Bounds(weapon.transform.position,Vector3.zero);
            foreach(var renderer in weapon.GetComponentsInChildren<Renderer>()) bounds.Encapsulate(renderer.bounds);
            weapon.transform.localPosition-=pivot.InverseTransformVector(bounds.center-pivot.position);
            RenderPreview();
        }
        public void SetItemIcon(Image image,int itemId,string path)
        { image.sprite=catalog.ItemIcon(itemId,path);image.enabled=image.sprite!=null; }
        private void CreateStudio()
        {
            studio=new GameObject("EquipmentPreviewStudio") { hideFlags=HideFlags.HideAndDontSave };
            UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(studio,gameObject.scene);
            studio.transform.position=new Vector3(10000,10000,10000);
            pivot=new GameObject("Orbit").transform;pivot.SetParent(studio.transform,false);
            cameraView=new GameObject("PreviewCamera").AddComponent<Camera>();cameraView.transform.SetParent(studio.transform,false);
            cameraView.transform.localPosition=new Vector3(0,.12f,-5);cameraView.transform.LookAt(studio.transform.position);
            cameraView.enabled=false;cameraView.orthographic=true;cameraView.nearClipPlane=.1f;cameraView.farClipPlane=15;
            cameraView.scene=gameObject.scene;
            cameraView.cullingMask=1<<31;cameraView.clearFlags=CameraClearFlags.SolidColor;cameraView.backgroundColor=new Color(.055f,.067f,.065f);
            cameraView.allowHDR=false;cameraView.allowMSAA=true;
            var light=new GameObject("KeyLight").AddComponent<Light>();light.transform.SetParent(studio.transform,false);
            light.type=LightType.Directional;light.intensity=1.25f;light.color=new Color(1,.90f,.72f);light.cullingMask=1<<31;light.transform.localRotation=Quaternion.Euler(38,-35,0);
            var fill=new GameObject("FillLight").AddComponent<Light>();fill.transform.SetParent(studio.transform,false);
            fill.type=LightType.Directional;fill.intensity=.7f;fill.color=new Color(.58f,.80f,1);fill.cullingMask=1<<31;fill.transform.localRotation=Quaternion.Euler(12,145,0);
        }
        public void OnDrag(PointerEventData e)
        {
            if(!RectTransformUtility.RectangleContainsScreenPoint(layout.Preview,e.position,e.pressEventCamera)) return;
            yaw+=e.delta.x*.45f;tilt=Mathf.Clamp(tilt-e.delta.y*.3f,-65,65);
        }
        public void OnScroll(PointerEventData e)
        {
            if(RectTransformUtility.RectangleContainsScreenPoint(layout.Preview,e.position,e.pressEventCamera)) zoom=Mathf.Clamp(zoom*Mathf.Exp(-e.scrollDelta.y*.12f),.7f,2.6f);
        }
        private void LateUpdate()
        {
            if(layout==null) return;
            if(previousSize!=layout.Root.rect.size) Arrange();
            if(weapon!=null) RenderPreview();
        }
        public void RenderPreview()
        {
            if(weapon==null) return;
            var rect=layout.Image.rectTransform.rect;
            int width=Mathf.Clamp(Mathf.RoundToInt(rect.width*1.5f),128,1600),height=Mathf.Clamp(Mathf.RoundToInt(rect.height*1.5f),128,1600);
            if(texture==null||texture.width!=width||texture.height!=height)
            {
                if(texture!=null) { cameraView.targetTexture=null;texture.Release();DestroyImmediate(texture); }
                texture=new RenderTexture(width,height,24,RenderTextureFormat.ARGB32) { antiAliasing=4 };
                texture.Create();cameraView.targetTexture=texture;layout.Image.texture=texture;
            }
            cameraView.orthographicSize=zoom;cameraView.aspect=(float)width/height;
            pivot.localRotation=Quaternion.Euler(tilt,yaw,0);cameraView.Render();
            LayoutCallouts();
        }
        private readonly Vector2[] socketPoints=new Vector2[3];
        private readonly float[] labelHeights=new float[3];
        private readonly int[] sortedSockets=new int[3];
        private static void BottomPoint(RectTransform rect,Vector2 point)
        {rect.anchorMin=rect.anchorMax=Vector2.zero;rect.anchoredPosition=point;}
        private static void Line(RectTransform rect,Vector2 a,Vector2 b)
        {
            BottomPoint(rect,a);rect.pivot=new Vector2(0,.5f);var direction=b-a;
            rect.sizeDelta=new Vector2(direction.magnitude,1.4f);rect.localRotation=Quaternion.Euler(0,0,Mathf.Atan2(direction.y,direction.x)*Mathf.Rad2Deg);
        }
        private void LayoutCallouts()
        {
            if(model.Sockets.Length>layout.Sockets.Length) throw new InvalidOperationException("武器挂点超过工坊已绑定的容量。");
            var size=layout.Preview.rect.size;var width=Mathf.Min(144,size.x*.29f);
            var minY=60f;var maxY=Mathf.Max(minY,size.y-110);
            for(int i=0;i<layout.Sockets.Length;i++)
            {
                var active=i<model.Sockets.Length;layout.Sockets[i].gameObject.SetActive(active);
                layout.SocketDots[i].gameObject.SetActive(active);layout.SocketLeads[i].gameObject.SetActive(active);layout.SocketTails[i].gameObject.SetActive(active);
                if(!active) continue;
                var point=cameraView.WorldToViewportPoint(weapon.Socket(model.Sockets[i].Id).position);
                socketPoints[i]=new Vector2(Mathf.Clamp01(point.x)*size.x,Mathf.Clamp01(point.y)*size.y);
                labelHeights[i]=Mathf.Clamp(socketPoints[i].y,minY,maxY);
            }
            // Sort each docking column by projected height, then separate labels before drawing leaders.
            for(int sideIndex=0;sideIndex<2;sideIndex++)
            {
                var side=sideIndex==0?"left":"right";
                int count=0;
                for(int i=0;i<model.Sockets.Length;i++) if(model.Sockets[i].CalloutSide==side) sortedSockets[count++]=i;
                for(int i=1;i<count;i++) for(int j=i;j>0&&labelHeights[sortedSockets[j]]<labelHeights[sortedSockets[j-1]];j--)
                {var temp=sortedSockets[j];sortedSockets[j]=sortedSockets[j-1];sortedSockets[j-1]=temp;}
                var gap=count>1?Mathf.Min(48,(maxY-minY)/(count-1)):48;
                for(int i=0;i<count;i++) labelHeights[sortedSockets[i]]=Mathf.Max(labelHeights[sortedSockets[i]],minY+i*gap);
                for(int i=count-1;i>=0;i--)
                {
                    var index=sortedSockets[i];var ceiling=i==count-1?maxY:labelHeights[sortedSockets[i+1]]-gap;
                    labelHeights[index]=Mathf.Min(labelHeights[index],ceiling);
                }
            }
            for(int i=0;i<model.Sockets.Length;i++)
            {
                var left=model.Sockets[i].CalloutSide=="left";var point=socketPoints[i];var y=labelHeights[i];
                var label=layout.Sockets[i];label.pivot=new Vector2(.5f,.5f);label.sizeDelta=new Vector2(width,34);
                var x=left?12+width*.5f:size.x-12-width*.5f;BottomPoint(label,new Vector2(x,y));
                var end=new Vector2(left?12+width:size.x-12-width,y);
                var elbow=new Vector2(end.x+(left?18:-18),y);
                BottomPoint(layout.SocketDots[i],point);Line(layout.SocketLeads[i],point,elbow);Line(layout.SocketTails[i],elbow,end);
            }
        }
        private static void Place(RectTransform r,float x,float y,float w,float h)
        {r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);}
        public void Arrange()
        {
            previousSize=layout.Root.rect.size;
            var screen=new Vector2(Mathf.Max(1,Screen.width),Mathf.Max(1,Screen.height));
            layout.Safe.anchorMin=Screen.safeArea.min/screen;layout.Safe.anchorMax=Screen.safeArea.max/screen;layout.Safe.offsetMin=layout.Safe.offsetMax=Vector2.zero;
            var w=previousSize.x*Screen.safeArea.width/screen.x;var h=previousSize.y*Screen.safeArea.height/screen.y;
            layout.ActorGrid.cellSize=new Vector2(Mathf.Min(150,(w-64)/4),36);
            Place(layout.Heading,20,16,Mathf.Max(200,w-220),34);
            if(w<700)
            {Place(layout.Equip,0,0,180,36);Place(layout.Unequip,190,0,132,36);Place(layout.Status,0,-20,w-40,20);}
            else {Place(layout.Equip,0,0,220,40);Place(layout.Unequip,232,0,144,40);Place(layout.Status,390,0,w-430,40);}
            Place(layout.Actors,20,68,w-40,36);Place(layout.Footer,20,h-58,w-40,42);
            if(w>=1040)
            {Place(layout.Inventory,20,118,240,h-190);Place(layout.Preview,272,118,w-626,h-190);Place(layout.Details,w-342,118,322,h-190);}
            else
            {var left=Mathf.Clamp(w*.29f,155,240);var bottom=Mathf.Min(260,h*.32f);
                Place(layout.Inventory,16,118,left,h-190);Place(layout.Preview,left+26,118,w-left-42,h-200-bottom);Place(layout.Details,left+26,h-72-bottom,w-left-42,bottom);}
        }
        public void ReleasePreview()
        {
            if(studio!=null) WeaponModelView.Remove(studio);
            studio=null;weapon=null;assetId=0;
            if(texture!=null) {layout.Image.texture=null;texture.Release();DestroyImmediate(texture);texture=null;}
        }
        private void OnDisable() { ReleasePreview(); }
        private void OnDestroy(){ReleasePreview();if(font!=null) Destroy(font);}
#if UNITY_EDITOR
        [BlackList] public void Bind(Layout value,EquipmentAssetCatalog assets) {layout=value;catalog=assets;}
        [BlackList] public Layout EditorLayout => layout;
#endif
    }
}
