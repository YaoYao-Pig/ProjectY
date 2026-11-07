using System;
using ProjectY.Samples;
using ProjectY.Rendering;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    [LuaCallCSharp]
    public sealed class CampItemPreview : MonoBehaviour
    {
        [SerializeField] private RawImage image;
        [SerializeField] private EquipmentAssetCatalog catalog;
        [SerializeField] private GameObject[] facilityModels;
        [SerializeField] private PawnView pawnPrefab;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] pawnParts;
        private GameObject studio,subject;
        private Camera cameraView;
        private RenderTexture texture;
        private WeaponModelView weapon;
        private readonly UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest request=new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest();
        private Vector2 lastSize;
        private bool pending;
        public void ShowPawn(LuaTable row)
        {
            CreateStudio();ClearSubject();
            var pawn=Instantiate(pawnPrefab,studio.transform,false);subject=pawn.gameObject;
            pawn.ApplyAppearance(PawnAppearanceData.Read(row),part=>
            {
                foreach(var binding in pawnParts)if(binding.id==part.Id && binding.path==part.Path && binding.prefab!=null)return binding.prefab;
                throw new InvalidOperationException("Unbound camp animal appearance: "+part.Id);
            });
            pawn.SkipPresentation();Frame(new Vector3(10,145,0));
        }
        public void ShowFacility(int facility,int level)
        {
            if(facility<1||facility>3||level<0||level>2)throw new ArgumentOutOfRangeException(nameof(facility));
            CreateStudio();ClearSubject();subject=Instantiate(facilityModels[(facility-1)*3+level],studio.transform,false);Frame(new Vector3(18,145,0));
        }
        public void ShowAsset(LuaTable row)
        {
            CreateStudio();ClearSubject();
            subject=Instantiate(catalog.Resolve(EquipmentVisualData.Asset.Read(row)),studio.transform,false);
            Frame(new Vector3(12,35,-18));
        }
        public void ShowWeapon(LuaTable row)
        {
            CreateStudio();ClearSubject();var data=EquipmentVisualData.Weapon.Read(row);
            subject=Instantiate(catalog.Resolve(data.Model),studio.transform,false);
            weapon=subject.GetComponent<WeaponModelView>()??throw new InvalidOperationException("Camp weapon preview requires WeaponModelView.");
            weapon.Apply(data,catalog);Frame(data.PreviewRotation);
        }
        private void CreateStudio()
        {
            if(studio!=null)return;
            studio=new GameObject("CampItemPreviewStudio"){hideFlags=HideFlags.HideAndDontSave};
            UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(studio,gameObject.scene);
            studio.transform.position=new Vector3(28000,28000,28000);
            cameraView=new GameObject("ItemCamera").AddComponent<Camera>();cameraView.transform.SetParent(studio.transform,false);
            cameraView.enabled=false;cameraView.orthographic=true;cameraView.cullingMask=1<<31;cameraView.clearFlags=CameraClearFlags.SolidColor;
            cameraView.backgroundColor=Color.clear;cameraView.nearClipPlane=.03f;cameraView.farClipPlane=30;cameraView.allowHDR=false;
            cameraView.scene=gameObject.scene;UrpCameraRendering.ConfigurePreview(cameraView);
#if UNITY_EDITOR
            cameraView.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(gameObject.scene);
#endif
            AddLight("Key",new Color(1,.87f,.64f),1.4f,new Vector3(35,145,0));
            AddLight("Fill",new Color(.58f,.72f,.82f),.6f,new Vector3(25,-35,0));
        }
        private void AddLight(string name,Color color,float intensity,Vector3 rotation)
        {var light=new GameObject(name).AddComponent<Light>();light.transform.SetParent(studio.transform,false);light.type=LightType.Directional;light.color=color;light.intensity=intensity;light.cullingMask=1<<31;light.transform.localRotation=Quaternion.Euler(rotation);}
        private void Frame(Vector3 rotation)
        {
            foreach(var node in subject.GetComponentsInChildren<Transform>(true))node.gameObject.layer=31;
            foreach(var collider in subject.GetComponentsInChildren<Collider>(true))collider.enabled=false;
            subject.transform.localRotation=Quaternion.Euler(rotation);subject.transform.localPosition=Vector3.zero;
            var renderers=subject.GetComponentsInChildren<Renderer>();bool found=false;Bounds bounds=default;
            foreach(var renderer in renderers)if(!(renderer is ParticleSystemRenderer)){if(!found){bounds=renderer.bounds;found=true;}else bounds.Encapsulate(renderer.bounds);}
            if(!found)throw new InvalidOperationException("Camp preview asset has no geometry.");
            subject.transform.position-=bounds.center-studio.transform.position;
            var size=image.rectTransform.rect.size;float aspect=Mathf.Max(.2f,size.x/Mathf.Max(1,size.y));
            cameraView.orthographicSize=Mathf.Max(.12f,bounds.extents.y,bounds.extents.x/aspect)*1.2f;
            cameraView.transform.localPosition=new Vector3(0,0,-Mathf.Max(5,bounds.size.magnitude*2));cameraView.transform.localRotation=Quaternion.identity;
            cameraView.farClipPlane=Mathf.Max(30,bounds.size.magnitude*4);pending=true;
        }
        private void LateUpdate() {if(subject!=null&&(pending||lastSize!=image.rectTransform.rect.size))Render();}
        public void Render()
        {
            if(subject==null)return;var size=image.rectTransform.rect.size;if(size.x<=0||size.y<=0)return;
            int w=Mathf.Clamp(Mathf.RoundToInt(size.x*1.5f),128,1400),h=Mathf.Clamp(Mathf.RoundToInt(size.y*1.5f),128,1400);
            if(texture==null||texture.width!=w||texture.height!=h)
            {ReleaseTexture();texture=new RenderTexture(w,h,24,RenderTextureFormat.ARGB32){antiAliasing=4};texture.Create();cameraView.targetTexture=texture;image.texture=texture;}
            cameraView.aspect=(float)w/h;weapon?.TickEffects(0);UrpCameraRendering.Render(cameraView,request);lastSize=size;pending=false;
        }
        private void ClearSubject(){if(subject!=null)WeaponModelView.Remove(subject);subject=null;weapon=null;}
        private void ReleaseTexture(){if(texture==null)return;if(cameraView!=null)cameraView.targetTexture=null;image.texture=null;texture.Release();DestroyImmediate(texture);texture=null;}
        public void Release(){ClearSubject();ReleaseTexture();if(studio!=null)WeaponModelView.Remove(studio);studio=null;cameraView=null;}
        private void OnDisable()=>Release();
        private void OnDestroy()=>Release();
#if UNITY_EDITOR
        [BlackList] public void Bind(RawImage target,EquipmentAssetCatalog assets){image=target;catalog=assets;}
        [BlackList] public void BindFacilities(GameObject[] models){facilityModels=models;}
        [BlackList] public void BindPawns(PawnView prefab,MapRuntimeDemo.AssetBinding[] parts){pawnPrefab=prefab;pawnParts=parts;}
#endif
    }
}
