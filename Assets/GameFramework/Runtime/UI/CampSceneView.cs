using System;
using System.Collections.Generic;
using ProjectY.Samples;
using ProjectY.Rendering;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.EventSystems;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    [LuaCallCSharp]
    public sealed class CampSceneView : MonoBehaviour,IPointerClickHandler,IPointerMoveHandler,IPointerExitHandler
    {
        public const string ScenePath="Assets/DynamicAsset/CampPresentation/Scenes/CampPresentation.unity";
        [SerializeField] private RawImage image,background;
        [SerializeField] private Shader blurShader;
        [SerializeField] private RectTransform[] labels;
        [SerializeField] private PawnView pawnPrefab;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] parts;
        public UnityEvent<int> FacilityChosen {get;}=new UnityEvent<int>();
        private readonly Dictionary<int,MapRuntimeDemo.AssetBinding> assets=new Dictionary<int,MapRuntimeDemo.AssetBinding>();
        private readonly List<PawnView> pawns=new List<PawnView>();
        private readonly List<PawnAppearanceData> appearances=new List<PawnAppearanceData>();
        private readonly List<Light> isolatedLights=new List<Light>();
        private readonly List<int> originalLightMasks=new List<int>();
        private readonly UniversalRenderPipeline.SingleCameraRequest request=new UniversalRenderPipeline.SingleCameraRequest();
        private readonly UniversalRenderPipeline.SingleCameraRequest worldRequest=new UniversalRenderPipeline.SingleCameraRequest();
        private CampStage stage;
        private Camera worldCamera;
        private RenderTexture texture,worldTexture;
        private Material blur;
        private AsyncOperation loading;
        private Scene loadedScene;
        private bool wanted,exploring=true,capturePending,preview;
        private int benchLevel,medicalLevel,warehouseLevel;
        private float nextRender;
        private int tagHighlight;
        public void HighlightTag(int id){tagHighlight=id;if(stage!=null&&exploring)stage.Highlight(id);}
        public void Begin(Camera source,LuaTable party)
        {
            worldCamera=source??throw new ArgumentNullException(nameof(source));wanted=true;capturePending=true;appearances.Clear();
            for(int i=1;i<=party.Length;i++)using(var row=party.Get<int,LuaTable>(i))appearances.Add(PawnAppearanceData.Read(row));
            assets.Clear();foreach(var part in parts)assets.Add(part.id,part);
            if(stage!=null)ApplyParty();
            if(isActiveAndEnabled)StartLoad();
        }
        private void OnEnable(){if(wanted)StartLoad();}
        private void StartLoad()
        {
            if(stage!=null||loading!=null)return;
            if(!Application.isPlaying)throw new InvalidOperationException("Edit Mode camp preview must attach its authored stage explicitly.");
            loading=SceneManager.LoadSceneAsync(ScenePath,LoadSceneMode.Additive);
            if(loading==null)throw new InvalidOperationException("Camp scene is missing from build settings.");
            loading.completed+=FinishLoad;
        }
        private void FinishLoad(AsyncOperation operation)
        {
            operation.completed-=FinishLoad;loading=null;
            var scene=SceneManager.GetSceneByPath(ScenePath);
            if(!wanted||this==null){if(scene.IsValid()&&scene.isLoaded)SceneManager.UnloadSceneAsync(scene);return;}
            loadedScene=scene;
            foreach(var root in scene.GetRootGameObjects())
            {var found=root.GetComponent<CampStage>();if(found!=null){if(stage!=null)throw new InvalidOperationException("Multiple camp stages.");stage=found;}}
            if(stage==null)throw new InvalidOperationException("Camp scene has no CampStage.");
            stage.transform.position=new Vector3(36000,36000,36000);InitializeStage();
        }
        private void InitializeStage()
        {
            foreach(var node in stage.GetComponentsInChildren<Transform>(true))node.gameObject.layer=30;
            stage.Camera.enabled=false;stage.Camera.scene=stage.gameObject.scene;stage.Camera.cullingMask=1<<30;
            UrpCameraRendering.ConfigurePreview(stage.Camera);stage.Camera.GetUniversalAdditionalCameraData().renderShadows=true;
            stage.Camera.clearFlags=CameraClearFlags.SolidColor;stage.Camera.backgroundColor=Color.clear;stage.Camera.allowHDR=false;
#if UNITY_EDITOR
            stage.Camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(stage.gameObject.scene);
#endif
            // Directional lights have no spatial range. Exclude the studio bit and restore it on close.
            foreach(var light in UnityEngine.Object.FindObjectsOfType<Light>())
                if(light.gameObject.scene!=stage.gameObject.scene&&(light.cullingMask&(1<<30))!=0)
                {isolatedLights.Add(light);originalLightMasks.Add(light.cullingMask);light.cullingMask&=~(1<<30);}
            ApplyLevels();ApplyParty();nextRender=0;
        }
        private GameObject Resolve(PawnAppearanceData.Part part)
        {
            if(!assets.TryGetValue(part.Id,out var binding)||binding.path!=part.Path||binding.prefab==null)throw new InvalidOperationException("Unbound camp party appearance: "+part.Id);
            return binding.prefab;
        }
        private void ApplyParty()
        {
            if(stage==null)return;
            foreach(var pawn in pawns)if(pawn!=null)WeaponModelView.Remove(pawn.gameObject);pawns.Clear();
            int count=Math.Min(appearances.Count,stage.PartyAnchors.Length);
            for(int i=0;i<count;i++)
            {
                var pawn=Instantiate(pawnPrefab,stage.PartyAnchors[i],false);pawn.ApplyAppearance(appearances[i],Resolve);
                foreach(var node in pawn.GetComponentsInChildren<Transform>(true))node.gameObject.layer=30;
                foreach(var collider in pawn.GetComponentsInChildren<Collider>(true))collider.enabled=false;
                pawn.SkipPresentation();pawns.Add(pawn);
            }
        }
        public void SetLevels(int workbench,int medical,int warehouse){benchLevel=workbench;medicalLevel=medical;warehouseLevel=warehouse;ApplyLevels();}
        private void ApplyLevels(){if(stage!=null)stage.SetLevels(benchLevel,medicalLevel,warehouseLevel);}
        public void SetExploring(bool value){exploring=value;tagHighlight=0;if(stage!=null)stage.Highlight(0);foreach(var label in labels)label.gameObject.SetActive(value);}
        public void RefreshBackground()=>capturePending=true;
        private void CaptureWorld()
        {
            if(worldCamera==null)return;
            int w=Mathf.Max(128,Screen.width/2),h=Mathf.Max(128,Screen.height/2);
            if(worldTexture==null||worldTexture.width!=w||worldTexture.height!=h)
            {ReleaseTexture(ref worldTexture);worldTexture=new RenderTexture(w,h,0,RenderTextureFormat.ARGB32);worldTexture.Create();background.texture=worldTexture;}
            if(blur==null)blur=new Material(blurShader){hideFlags=HideFlags.HideAndDontSave};
            var source=RenderTexture.GetTemporary(w,h,24,RenderTextureFormat.ARGBHalf);var temp=RenderTexture.GetTemporary(w,h,0,RenderTextureFormat.ARGBHalf);
            var oldTarget=worldCamera.targetTexture;var oldRect=worldCamera.rect;float oldAspect=worldCamera.aspect;
            try
            {
                worldCamera.targetTexture=source;worldCamera.rect=new Rect(0,0,1,1);worldCamera.aspect=(float)w/h;
                UrpCameraRendering.Render(worldCamera,worldRequest);
                blur.SetVector("_Direction",new Vector4(1f/w,0,0,0));Graphics.Blit(source,temp,blur,0);
                blur.SetVector("_Direction",new Vector4(0,1f/h,0,0));Graphics.Blit(temp,worldTexture,blur,0);
            }
            finally{worldCamera.targetTexture=oldTarget;worldCamera.rect=oldRect;worldCamera.aspect=oldAspect;RenderTexture.ReleaseTemporary(source);RenderTexture.ReleaseTemporary(temp);}
            capturePending=false;
        }
        private void LateUpdate()
        {
            if(!wanted)return;if(capturePending)CaptureWorld();if(stage==null)return;
            foreach(var pawn in pawns)pawn.TickPresentation(Time.unscaledDeltaTime);
            if(stage.FireLight!=null)stage.FireLight.intensity=1.8f+.16f*Mathf.Sin(Time.unscaledTime*5.1f)+.08f*Mathf.Sin(Time.unscaledTime*9.7f);
            if(Time.unscaledTime<nextRender)return;nextRender=Time.unscaledTime+1f/30f;Render();
        }
        public void Render()
        {
            if(stage==null)return;var rect=image.rectTransform.rect;
            int w=Mathf.Clamp(Mathf.RoundToInt(rect.width*1.4f),640,1920),h=Mathf.Clamp(Mathf.RoundToInt(rect.height*1.4f),360,1200);
            if(texture==null||texture.width!=w||texture.height!=h)
            {ReleaseTexture(ref texture);texture=new RenderTexture(w,h,24,RenderTextureFormat.ARGB32){antiAliasing=4};texture.Create();stage.Camera.targetTexture=texture;image.texture=texture;capturePending=true;}
            stage.Camera.aspect=(float)w/h;stage.Camera.orthographicSize=Mathf.Max(7.1f,11.3f/stage.Camera.aspect);
            UrpCameraRendering.Render(stage.Camera,request);
            for(int i=0;i<labels.Length;i++)
            {
                var p=stage.Camera.WorldToViewportPoint(stage.Facilities[i].LabelAnchor.position);
                labels[i].anchorMin=labels[i].anchorMax=Vector2.zero;labels[i].anchoredPosition=new Vector2(p.x*rect.width,p.y*rect.height);
            }
        }
        private int Hit(PointerEventData e)
        {
            if(!exploring||stage==null)return 0;
            RectTransformUtility.ScreenPointToLocalPointInRectangle(image.rectTransform,e.position,e.pressEventCamera,out var local);
            var rect=image.rectTransform.rect;var uv=new Vector3((local.x-rect.xMin)/rect.width,(local.y-rect.yMin)/rect.height,0);
            if(uv.x<0||uv.y<0||uv.x>1||uv.y>1)return 0;
            return stage.Hit(stage.Camera.ViewportPointToRay(uv));
        }
        public void OnPointerClick(PointerEventData e){if(e.button==PointerEventData.InputButton.Left){int id=Hit(e);if(id!=0)FacilityChosen.Invoke(id);}}
        public void OnPointerMove(PointerEventData e){if(stage!=null)stage.Highlight(tagHighlight>0?tagHighlight:Hit(e));}
        public void OnPointerExit(PointerEventData e){if(stage!=null)stage.Highlight(0);}
        private static void ReleaseTexture(ref RenderTexture value){if(value==null)return;value.Release();DestroyImmediate(value);value=null;}
        public void Release()
        {
            wanted=false;appearances.Clear();foreach(var pawn in pawns)if(pawn!=null)WeaponModelView.Remove(pawn.gameObject);pawns.Clear();
            for(int i=0;i<isolatedLights.Count;i++)if(isolatedLights[i]!=null)isolatedLights[i].cullingMask=(isolatedLights[i].cullingMask&~(1<<30))|(originalLightMasks[i]&(1<<30));
            isolatedLights.Clear();originalLightMasks.Clear();
            if(stage!=null)stage.Camera.targetTexture=null;stage=null;
            image.texture=null;background.texture=null;ReleaseTexture(ref texture);ReleaseTexture(ref worldTexture);
            if(blur!=null)DestroyImmediate(blur);blur=null;
            if(!preview&&loadedScene.IsValid()&&loadedScene.isLoaded)SceneManager.UnloadSceneAsync(loadedScene);
            loadedScene=default;worldCamera=null;
        }
        private void OnDisable()=>Release();
        private void OnDestroy(){Release();FacilityChosen.RemoveAllListeners();}
#if UNITY_EDITOR
        [BlackList] public void Bind(RawImage target,RawImage backdrop,Shader shader,RectTransform[] anchorLabels,PawnView prefab,MapRuntimeDemo.AssetBinding[] bindings)
        {image=target;background=backdrop;blurShader=shader;labels=anchorLabels;pawnPrefab=prefab;parts=bindings;}
        [BlackList] public void AttachPreviewStage(CampStage value){stage=value;preview=true;InitializeStage();}
#endif
    }
}
