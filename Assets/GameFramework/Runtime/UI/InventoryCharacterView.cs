using System;
using System.Collections.Generic;
using ProjectY.Samples;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Read-only character studio and projected equipment leaders, using the scene pawn renderer.</summary>
    [LuaCallCSharp]
    public sealed class InventoryCharacterView : MonoBehaviour, IDragHandler, IScrollHandler
    {
        [Serializable] public sealed class Callout {public string Slot;public RectTransform Target,Dot,Lead,Tail;}
        [SerializeField] private RawImage image;
        [SerializeField] private PawnView pawnPrefab;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] parts;
        [SerializeField] private Callout[] callouts;
        [SerializeField] private Color background = new Color(.055f,.075f,.083f);
        [SerializeField] private bool portraitMode;
        private readonly Dictionary<int,MapRuntimeDemo.AssetBinding> assets=new Dictionary<int,MapRuntimeDemo.AssetBinding>();
        private GameObject studio;
        private Transform pivot;
        private PawnView pawn;
        private Camera cameraView;
        private ProjectY.Rendering.SkinnedPreviewSnapshot previewSkin;
        private readonly UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest renderRequest = new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest();
        private RenderTexture texture;
        private float yaw=-15,zoom=1,fit=1.2f;
        private Vector3 focus=new Vector3(0,1.04f,0);
        private BlockParticleEffects skillEffects;
        private BlockEffectProfile skillProfile;
        private int previewSkillId,previewShots,previewShot,previewTrail;
        private float previewElapsed,previewImpact,previewScale;
        private string previewTrajectory;
        private bool previewSelf;
        private const float PreviewShotInterval=.2f;
        public void Show(LuaTable snapshot)
        {
            var appearance=PawnAppearanceData.Read(snapshot);
            if(studio==null) CreateStudio();
            StopSkillPreview();
            studio.SetActive(true);
            pawn.ApplyAppearance(appearance,Resolve);
            previewSkin.RefreshSources();
            foreach(var node in pawn.GetComponentsInChildren<Transform>(true)) node.gameObject.layer=31;
            pivot.localRotation=Quaternion.identity;
            var renderers=pawn.GetComponentsInChildren<Renderer>();
            bool found=false;var bounds=new Bounds();
            foreach(var renderer in renderers)if(!(renderer is ParticleSystemRenderer)&&renderer.enabled&&!renderer.forceRenderingOff)
            {if(found)bounds.Encapsulate(renderer.bounds);else{bounds=renderer.bounds;found=true;}}
            if(!found) throw new InvalidOperationException("角色预览没有可见模型。");
            focus=studio.transform.InverseTransformPoint(bounds.center);
            fit=Mathf.Max(1.2f,bounds.extents.y*1.16f,bounds.extents.x*1.1f);
            if(portraitMode){focus=studio.transform.InverseTransformPoint(pawn.HealthTarget.position);fit=.42f;}
            using(var skill=snapshot.Get<LuaTable>("skillPreview"))
                if(skill!=null) BeginSkillPreview(skill);
            RenderPreview(0);
        }
        private void BeginSkillPreview(LuaTable skill)
        {
            if(portraitMode)throw new InvalidOperationException("HUD portraits do not support skill playback.");
            previewSkillId=skill.Get<int>("id");previewShots=skill.Get<int>("shots");
            if(previewSkillId<=0||previewShots<1)throw new InvalidOperationException("Invalid skill preview identity or shot count.");
            using(var profile=skill.Get<LuaTable>("profile")) skillProfile=BlockEffectCatalog.ReadProfile(profile);
            previewTrajectory=skill.Get<string>("trajectory");previewSelf=skill.Get<bool>("selfTarget");
            if(previewTrajectory!="sight"&&previewTrajectory!="direct"&&previewTrajectory!="lobbed")
                throw new InvalidOperationException("Invalid preview skill trajectory: "+previewTrajectory);
            if(skillEffects==null)skillEffects=new BlockParticleEffects(pivot,31,true);
            previewScale=Mathf.Min(1,.65f/Mathf.Max(.65f,skillProfile.Radius,skillProfile.Height));
            previewImpact=pawn.PreviewAction(skill.Get<int>("actionTemplate"));
            previewElapsed=0;previewShot=previewTrail=0;
        }
        private void StopSkillPreview()
        {
            if(skillProfile!=null&&pawn!=null)pawn.SkipPresentation();
            skillEffects?.Clear();skillProfile=null;previewSkillId=0;
        }
        private void TickSkillPreview(float deltaTime)
        {
            skillEffects?.Tick(deltaTime);
            if(skillProfile==null||deltaTime<=0)return;
            previewElapsed+=deltaTime;
            var origin=pawn.EquipmentSlotPosition("weapon");
            var target=pawn.transform.TransformPoint(new Vector3(0,.95f,previewSelf?0:1.05f));
            if(previewSelf)origin=target;
            if(!previewSelf&&previewTrajectory!="sight")
                while(previewTrail<previewShots&&previewElapsed>=Mathf.Max(0,previewImpact-.16f)+previewTrail*PreviewShotInterval)
                {
                    var trail=BlockEffectCatalog.Variant(skillProfile,previewTrajectory=="lobbed"?"arc":"beam",Mathf.Min(24,skillProfile.Count),.24f);
                    skillEffects.Play(trail,origin,target,previewSkillId+previewTrail++,previewScale*.6f);
                }
            while(previewShot<previewShots&&previewElapsed>=previewImpact+previewShot*PreviewShotInterval)
                skillEffects.Play(skillProfile,origin,target,previewSkillId+previewShot++,previewScale);
            if(previewShot==previewShots&&!skillEffects.Busy&&!pawn.PresentationBusy){skillProfile=null;previewSkillId=0;}
        }
        private GameObject Resolve(PawnAppearanceData.Part part)
        {
            if(!assets.TryGetValue(part.Id,out var binding)||binding.path!=part.Path||binding.prefab==null)
                throw new InvalidOperationException("角色预览资源未同步: "+part.Id+" / "+part.Path);
            return binding.prefab;
        }
        private void CreateStudio()
        {
            if(pawnPrefab==null||image==null||parts==null||callouts==null||(callouts.Length!=0&&callouts.Length!=8))
                throw new InvalidOperationException("请同步背包 3D 预览引用。");
            assets.Clear();foreach(var part in parts) assets.Add(part.id,part);
            studio=new GameObject("InventoryCharacterStudio") {hideFlags=HideFlags.HideAndDontSave};
            UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(studio,gameObject.scene);
            studio.transform.position=new Vector3(20000,20000,20000);
            pivot=new GameObject("Orbit").transform;pivot.SetParent(studio.transform,false);
            pawn=Instantiate(pawnPrefab,pivot,false);
            previewSkin=new ProjectY.Rendering.SkinnedPreviewSnapshot(pawn.transform);
            cameraView=new GameObject("PortraitCamera").AddComponent<Camera>();cameraView.transform.SetParent(studio.transform,false);
            cameraView.transform.localPosition=new Vector3(0,1.04f,5);cameraView.transform.LookAt(studio.transform.position+Vector3.up*1.04f);
            cameraView.enabled=false;cameraView.orthographic=true;cameraView.nearClipPlane=.1f;cameraView.farClipPlane=15;
            cameraView.scene=gameObject.scene;cameraView.cullingMask=1<<31;
            cameraView.clearFlags=CameraClearFlags.SolidColor;cameraView.backgroundColor=background;
#if UNITY_EDITOR
            cameraView.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(gameObject.scene);
#endif
            cameraView.allowHDR=false;
            ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(cameraView);
            Light("Key",new Color(1,.9f,.75f),1.25f,new Vector3(35,155,0));
            Light("Fill",new Color(.55f,.76f,1),.75f,new Vector3(15,-25,0));
        }
        private void Light(string name,Color color,float intensity,Vector3 angles)
        {
            var light=new GameObject(name).AddComponent<Light>();light.transform.SetParent(studio.transform,false);
            light.type=LightType.Directional;light.color=color;light.intensity=intensity;light.cullingMask=1<<31;light.transform.localRotation=Quaternion.Euler(angles);
        }
        public void OnDrag(PointerEventData e) {if(e.button==PointerEventData.InputButton.Left) yaw+=e.delta.x*.45f;}
        public void OnScroll(PointerEventData e) {zoom=Mathf.Clamp(zoom*Mathf.Exp(-e.scrollDelta.y*.08f),.75f,1.5f);}
        private void LateUpdate() {if(pawn!=null&&!portraitMode) RenderPreview();}
        public void RenderPreview()
        { RenderPreview(Time.unscaledDeltaTime); }
        private void RenderPreview(float deltaTime)
        {
            if(pawn==null) return;
            if(portraitMode)studio.SetActive(true);
            try
            {
                pivot.localRotation=Quaternion.Euler(0,yaw,0);
                pawn.TickPresentation(deltaTime);TickSkillPreview(deltaTime);
                var size=image.rectTransform.rect.size;
                int width=Mathf.Clamp(Mathf.RoundToInt(size.x*1.5f),128,1200),height=Mathf.Clamp(Mathf.RoundToInt(size.y*1.5f),128,1200);
                if(texture==null||texture.width!=width||texture.height!=height)
                {
                    ReleaseTexture();texture=new RenderTexture(width,height,24,RenderTextureFormat.ARGB32) {antiAliasing=4};
                    texture.Create();cameraView.targetTexture=texture;image.texture=texture;
                }
                pivot.localRotation=Quaternion.Euler(0,yaw,0);cameraView.aspect=(float)width/height;cameraView.orthographicSize=fit*zoom;
                cameraView.transform.localPosition=focus+Vector3.forward*5;cameraView.transform.LookAt(studio.transform.TransformPoint(focus));previewSkin.Render(cameraView, renderRequest);
                foreach(var callout in callouts)
                {
                    var projected=cameraView.WorldToViewportPoint(pawn.EquipmentSlotPosition(callout.Slot));
                    var point=new Vector2(Mathf.Clamp01(projected.x)*size.x,Mathf.Clamp01(projected.y)*size.y);
                    var target=callout.Target;var bounds=target.rect;
                    var local=image.rectTransform.InverseTransformPoint(target.TransformPoint(bounds.center));
                    bool left=local.x<0;
                    var end=(Vector2)image.rectTransform.InverseTransformPoint(target.TransformPoint(new Vector3(left?bounds.xMax:bounds.xMin,bounds.center.y,0)))-image.rectTransform.rect.min;
                    var elbow=end+new Vector2(left?14:-14,0);
                    Point(callout.Dot,point);Line(callout.Lead,point,elbow);Line(callout.Tail,elbow,end);
                }
                // HUD portraits render only when their appearance changes. Inactive studios cannot overlap
                // another portrait's camera or add lights to its render.
            }
            finally {if(portraitMode&&studio!=null)studio.SetActive(false);}
        }
        private static void Point(RectTransform r,Vector2 p) {r.anchorMin=r.anchorMax=Vector2.zero;r.anchoredPosition=p;}
        private static void Line(RectTransform r,Vector2 a,Vector2 b)
        {Point(r,a);r.pivot=new Vector2(0,.5f);var d=b-a;r.sizeDelta=new Vector2(d.magnitude,1.2f);r.localRotation=Quaternion.Euler(0,0,Mathf.Atan2(d.y,d.x)*Mathf.Rad2Deg);}
        private void ReleaseTexture()
        {
            if(texture==null) return;
            if(cameraView!=null) cameraView.targetTexture=null;
            image.texture=null;texture.Release();DestroyImmediate(texture);texture=null;
        }
        public void ReleasePreview()
        {
            StopSkillPreview();skillEffects?.Dispose();skillEffects=null;
            if(previewSkin!=null){previewSkin.Dispose();previewSkin=null;}
            ReleaseTexture();if(studio!=null) WeaponModelView.Remove(studio);
            studio=null;pawn=null;cameraView=null;assets.Clear();
        }
        private void OnDisable() {ReleasePreview();}
        private void OnDestroy() {ReleasePreview();}
#if UNITY_EDITOR
        [BlackList] public void Bind(RawImage target,PawnView rig,MapRuntimeDemo.AssetBinding[] bindings,Callout[] links)
        {image=target;pawnPrefab=rig;parts=bindings;callouts=links;}
#endif
    }
}
