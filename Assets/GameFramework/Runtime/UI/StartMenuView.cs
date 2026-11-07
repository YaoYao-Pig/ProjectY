using System;
using System.Collections.Generic;
using ProjectY.Data;
using ProjectY.Rendering;
using ProjectY.Samples;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Owns only menu presentation, unscaled camera motion, and bounded render targets.</summary>
    [LuaCallCSharp]
    public sealed class StartMenuView : MonoBehaviour
    {
        public const string ReducedMotionPreference="ProjectY.Menu.ReducedMotion";
        [SerializeField] private StartMenuStage stagePrefab;
        [SerializeField] private RawImage sceneImage,selectedMap;
        [SerializeField] private Shader transitionShader;
        [SerializeField] private CanvasGroup home,frame,newPage,loadPage;
        [SerializeField] private RectTransform[] signButtons;
        [SerializeField] private Text[] labels;
        [SerializeField] private Text previewTitle,previewCaption;
        private StartMenuStage stage;
        private Scene stageScene;
        private RenderTexture texture,mapTexture;
        private Material transitionMaterial;
        private readonly UniversalRenderPipeline.SingleCameraRequest renderRequest=new UniversalRenderPipeline.SingleCameraRequest();
        private readonly List<Light> isolatedLights=new List<Light>();
        private readonly List<int> masks=new List<int>();
        private WorldMenuSnapshot homeSnapshot;
        private int currentPage,fromPage;
        private float elapsed,duration,pose;
        private bool wanted,dirty,reduced;
        private Vector2 renderedSize;
        public bool IsTransitioning {get;private set;}
        public Font Font {get;private set;}
        public UnityEvent BackRequested {get;}=new UnityEvent();
        public bool ReducedMotion=>PlayerPrefs.GetInt(ReducedMotionPreference,1)!=0;
        public void Prepare(Font font,float unusedWidth)
        {Font=font??throw new ArgumentNullException(nameof(font));foreach(var label in labels)if(label!=null)label.font=font;}
        public void Begin(WorldMenuSelection selection)
        {
            if(stagePrefab==null||transitionShader==null)throw new InvalidOperationException("Start menu presentation assets are not bound.");
            Release();wanted=true;reduced=ReducedMotion;
#if UNITY_EDITOR
            stageScene=!Application.isPlaying?UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene():SceneManager.CreateScene("StartMenuPresentation");
#else
            stageScene=SceneManager.CreateScene("StartMenuPresentation");
#endif
            stage=Instantiate(stagePrefab);SceneManager.MoveGameObjectToScene(stage.gameObject,stageScene);stage.transform.position=new Vector3(48000,48000,48000);
            foreach(var node in stage.GetComponentsInChildren<Transform>(true))node.gameObject.layer=30;
            ConfigureCamera(stage.Camera);ConfigureCamera(stage.MapCamera);
            foreach(var light in UnityEngine.Object.FindObjectsOfType<Light>())
                if(light.gameObject.scene!=stageScene&&(light.cullingMask&(1<<30))!=0){isolatedLights.Add(light);masks.Add(light.cullingMask);light.cullingMask&=~(1<<30);}
            transitionMaterial=new Material(transitionShader){hideFlags=HideFlags.HideAndDontSave};sceneImage.material=transitionMaterial;
            UpdateHome(selection);ShowPage(0,false);RenderNow();
        }
        private void ConfigureCamera(Camera camera)
        {
            camera.enabled=false;camera.scene=stageScene;camera.cullingMask=1<<30;UrpCameraRendering.ConfigurePreview(camera);camera.GetUniversalAdditionalCameraData().renderShadows=true;
#if UNITY_EDITOR
            camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(stageScene);
#endif
        }
        public void UpdateHome(WorldMenuSelection selection)
        {
            if(selection==null)throw new ArgumentNullException(nameof(selection));
            homeSnapshot=selection.Snapshot??CampaignPreviewCapture.Default();
            previewTitle.text=string.IsNullOrEmpty(selection.WorldName)?LuaLanguage.Get("MenuUnnamedWorld"):selection.WorldName;
            previewCaption.text=LuaLanguage.Get(selection.Status==0?"MenuDefaultPreview":selection.Status==1?"MenuRecentWorld":selection.Status==2?"MenuPreviewMissing":"MenuPreviewUnreadable");
            if(stage!=null&&currentPage==0){stage.SetSnapshot(homeSnapshot);dirty=true;}
        }
        public void PreviewSelected(WorldMenuSelection selection)
        {
            if(stage==null)throw new InvalidOperationException("Menu stage is not initialized.");
            stage.SetSnapshot(selection.Snapshot??CampaignPreviewCapture.Default());
            if(mapTexture==null){mapTexture=new RenderTexture(640,360,24,RenderTextureFormat.ARGB32){antiAliasing=2,name="Selected campaign preview"};mapTexture.Create();selectedMap.texture=mapTexture;}
            stage.MapCamera.targetTexture=mapTexture;stage.RenderThumbnail(RenderStageCamera);dirty=true;
        }
        public void ShowPage(int page,bool animate)
        {
            if(page<0||page>2)throw new ArgumentOutOfRangeException(nameof(page));
            if(IsTransitioning)return;fromPage=currentPage;currentPage=page;elapsed=0;reduced=ReducedMotion;duration=reduced?.3f:1.1f;
            IsTransitioning=animate&&fromPage!=page;
            if(page==0&&stage!=null)stage.SetSnapshot(homeSnapshot);
            ApplyProgress(IsTransitioning?0:1);dirty=true;
        }
        private static void Group(CanvasGroup group,float alpha,bool input,bool active)
        {group.gameObject.SetActive(active);group.alpha=alpha;group.interactable=input;group.blocksRaycasts=active;}
        private void ApplyProgress(float t)
        {
            float s=t*t*(3-2*t),outgoing=1-Mathf.Clamp01(t/.32f),incoming=Mathf.Clamp01((t-.59f)/.41f);
            float old=fromPage==0?0:1,target=currentPage==0?0:1;
            pose=reduced?(t<.5f?old:target):Mathf.Lerp(old,target,s);
            Func<int,float> alpha=p=>!IsTransitioning?(currentPage==p?1:0):(fromPage==p?outgoing:currentPage==p?incoming:0);
            float ha=alpha(0),na=alpha(1),la=alpha(2),fa=Mathf.Max(na,la);
            Group(home,ha,!IsTransitioning&&currentPage==0,ha>0||currentPage==0);
            Group(frame,fa,!IsTransitioning&&currentPage!=0,fa>0||currentPage!=0);
            Group(newPage,na,!IsTransitioning&&currentPage==1,na>0||currentPage==1);
            Group(loadPage,la,!IsTransitioning&&currentPage==2,la>0||currentPage==2);
            float speed=IsTransitioning&&!reduced?Mathf.Pow(Mathf.Sin(t*Mathf.PI),3):0;
            if(transitionMaterial!=null)transitionMaterial.SetFloat("_Speed",speed);
            if(stage!=null){float aspect=sceneImage.rectTransform.rect.width/Mathf.Max(1,sceneImage.rectTransform.rect.height);stage.Pose(pose,speed,aspect);}
        }
        public void Advance(float unscaledDelta)
        {
            if(!wanted||stage==null)return;
            if(IsTransitioning){elapsed+=Mathf.Max(0,unscaledDelta);float t=Mathf.Clamp01(elapsed/duration);if(t>=1)IsTransitioning=false;ApplyProgress(t);dirty=true;}
            var size=sceneImage.rectTransform.rect.size;if(size!=renderedSize)dirty=true;
            if(dirty)RenderNow();
        }
        private void Update(){if(wanted&&!IsTransitioning&&Input.GetKeyDown(KeyCode.Escape))BackRequested.Invoke();}
        private void LateUpdate()=>Advance(Time.unscaledDeltaTime);
        public void RenderNow()
        {
            if(stage==null)return;var rect=sceneImage.rectTransform.rect;int w=Mathf.Clamp(Mathf.RoundToInt(rect.width),640,1600),h=Mathf.Clamp(Mathf.RoundToInt(rect.height),360,900);
            if(texture==null||texture.width!=w||texture.height!=h){ReleaseTexture(ref texture);texture=new RenderTexture(w,h,24,RenderTextureFormat.ARGB32){antiAliasing=2,name="Main menu presentation"};texture.Create();stage.Camera.targetTexture=texture;sceneImage.texture=texture;}
            float speed=IsTransitioning&&!reduced?Mathf.Pow(Mathf.Sin(Mathf.Clamp01(elapsed/duration)*Mathf.PI),3):0;stage.Pose(pose,speed,(float)w/h);
            RenderStageCamera(stage.Camera);UpdateSigns(rect);renderedSize=rect.size;dirty=false;
        }
        private void RenderStageCamera(Camera camera)
        {bool fog=RenderSettings.fog;try{RenderSettings.fog=false;UrpCameraRendering.Render(camera,renderRequest);}finally{RenderSettings.fog=fog;}}
        private void UpdateSigns(Rect rect)
        {
            if(signButtons.Length!=stage.SignAnchors.Length)throw new InvalidOperationException("Menu sign anchors do not match buttons.");
            for(int i=0;i<signButtons.Length;i++)
            {
                var anchor=stage.SignAnchors[i];var p=stage.Camera.WorldToViewportPoint(anchor.position);var left=stage.Camera.WorldToViewportPoint(anchor.TransformPoint(-1.22f,0,0));var right=stage.Camera.WorldToViewportPoint(anchor.TransformPoint(1.22f,0,0));
                var top=stage.Camera.WorldToViewportPoint(anchor.TransformPoint(0,.26f,0));var bottom=stage.Camera.WorldToViewportPoint(anchor.TransformPoint(0,-.26f,0));
                float angle=Mathf.Atan2((right.y-left.y)*rect.height,(right.x-left.x)*rect.width)*Mathf.Rad2Deg;
                if(angle>90)angle-=180;else if(angle<-90)angle+=180;
                var b=signButtons[i];b.anchorMin=b.anchorMax=Vector2.zero;b.pivot=new Vector2(.5f,.5f);b.anchoredPosition=new Vector2(p.x*rect.width,p.y*rect.height);b.sizeDelta=new Vector2(Mathf.Abs(right.x-left.x)*rect.width,Mathf.Max(44,Mathf.Abs(top.y-bottom.y)*rect.height));b.localRotation=Quaternion.Euler(0,0,angle);
            }
        }
        private static void ReleaseTexture(ref RenderTexture value){if(value==null)return;value.Release();DestroyImmediate(value);value=null;}
        public void Release()
        {
            wanted=false;IsTransitioning=false;
            for(int i=0;i<isolatedLights.Count;i++)if(isolatedLights[i]!=null)isolatedLights[i].cullingMask=(isolatedLights[i].cullingMask&~(1<<30))|(masks[i]&(1<<30));isolatedLights.Clear();masks.Clear();
            if(stage!=null){stage.Camera.targetTexture=null;stage.MapCamera.targetTexture=null;stage.gameObject.SetActive(false);if(Application.isPlaying)Destroy(stage.gameObject);else DestroyImmediate(stage.gameObject);}stage=null;
            if(stageScene.IsValid()&&stageScene.isLoaded){
#if UNITY_EDITOR
                if(!Application.isPlaying)UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(stageScene);else SceneManager.UnloadSceneAsync(stageScene);
#else
                SceneManager.UnloadSceneAsync(stageScene);
#endif
            }
            stageScene=default;if(sceneImage!=null){sceneImage.texture=null;sceneImage.material=null;}if(selectedMap!=null)selectedMap.texture=null;ReleaseTexture(ref texture);ReleaseTexture(ref mapTexture);if(transitionMaterial!=null)DestroyImmediate(transitionMaterial);transitionMaterial=null;
        }
        private void OnDisable()=>Release();
        private void OnDestroy(){Release();BackRequested.RemoveAllListeners();}
#if UNITY_EDITOR
        [BlackList] public void Bind(StartMenuStage prefab,RawImage image,RawImage map,Shader shader,CanvasGroup homeGroup,CanvasGroup frameGroup,CanvasGroup freshGroup,CanvasGroup loadGroup,RectTransform[] signs,Text[] texts,Text title,Text caption)
        {stagePrefab=prefab;sceneImage=image;selectedMap=map;transitionShader=shader;home=homeGroup;frame=frameGroup;newPage=freshGroup;loadPage=loadGroup;signButtons=signs;labels=texts;previewTitle=title;previewCaption=caption;}
#endif
    }
}
