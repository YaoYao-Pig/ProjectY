using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ProjectY.Samples
{
    /// <summary>Authored equipment accents, driven by the existing host clock and VFX pool.</summary>
    [ExecuteAlways]
    public sealed class EquipmentVisualProfileView : MonoBehaviour
    {
        [Serializable] public sealed class MaterialBinding
        {
            public Renderer Renderer;
            public int MaterialIndex;
            public Material OriginalMaterial;
        }
        [SerializeField] private int profileId;
        [SerializeField] private MaterialBinding[] materialBindings=Array.Empty<MaterialBinding>();
        [SerializeField] private Vector3[] particleAnchors=Array.Empty<Vector3>();
        [SerializeField] private float particleInterval=1.8f, particleScale=.7f;
        [SerializeField] private int particleCount=4;
        [SerializeField] private Color particleColor=Color.white, particleAccent=Color.white;
        [SerializeField] private float particleEmission=2f;
        [SerializeField] private Light pointLight;
        [SerializeField] private float maxVisibleDistance=18f, lightIntensity=.5f, pulseSpeed=1f, pulseAmount=.15f;
        private EquipmentEffectDisplay[] displays;
        private MaterialPropertyBlock[] blocks;
        private float elapsed;
        private bool registered;
        private static readonly int EffectTime=Shader.PropertyToID("_ArcaneTime");

        public const int MaximumActiveLights=4;
        private static readonly List<EquipmentVisualProfileView> LightOwners=new List<EquipmentVisualProfileView>();
        private static readonly EquipmentVisualProfileView[] SelectedLights=new EquipmentVisualProfileView[MaximumActiveLights];
        private static readonly float[] SelectedDistances=new float[MaximumActiveLights];
        private static readonly Plane[] CameraPlanes=new Plane[6];
        public int ProfileId=>profileId;
        public MaterialBinding[] MaterialBindings=>materialBindings;
        public Light PointLight=>pointLight;

        private void Initialize()
        {
            if(blocks!=null) return;
            if(profileId<=0 || materialBindings==null || particleAnchors==null)
                throw new InvalidOperationException("Equipment visual profile is not bound.");
            blocks=new MaterialPropertyBlock[materialBindings.Length];
            for(int i=0;i<blocks.Length;i++)
            {
                var binding=materialBindings[i];
                if(binding==null || binding.Renderer==null || binding.OriginalMaterial==null || binding.MaterialIndex<0)
                    throw new InvalidOperationException("Equipment visual material binding is incomplete: "+profileId);
                blocks[i]=new MaterialPropertyBlock();
            }
            displays=new EquipmentEffectDisplay[particleAnchors.Length];
            for(int i=0;i<displays.Length;i++) displays[i]=new EquipmentEffectDisplay(transform,particleInterval,particleScale,particleCount);
        }
        public void SetEffect(BlockEffectProfile effect)
        {
            Initialize();
            // The item catalog retains ownership of pattern and motion. This profile only tints its local accent.
            var tinted=effect==null?null:BlockEffectCatalog.Variant(effect,effect.Pattern,effect.Count,effect.Lifetime);
            if(tinted!=null) {tinted.Color=particleColor;tinted.Accent=particleAccent;tinted.Emission=particleEmission;}
            foreach(var display in displays) display.Set(tinted);
        }
        public void TickEffects(float deltaTime)
        {
            if(!isActiveAndEnabled || deltaTime<=0) return;
            if(float.IsNaN(deltaTime) || float.IsInfinity(deltaTime)) throw new ArgumentOutOfRangeException(nameof(deltaTime));
            Initialize();RegisterLight();elapsed+=deltaTime;
            for(int i=0;i<materialBindings.Length;i++)
            {
                var binding=materialBindings[i];var block=blocks[i];
                binding.Renderer.GetPropertyBlock(block,binding.MaterialIndex);
                block.SetFloat(EffectTime,elapsed);binding.Renderer.SetPropertyBlock(block,binding.MaterialIndex);
            }
            for(int i=0;i<displays.Length;i++) displays[i].Tick(deltaTime,transform.TransformPoint(particleAnchors[i]));
            if(pointLight!=null) pointLight.intensity=lightIntensity*(1f-pulseAmount*.5f+pulseAmount*.5f*Mathf.Sin(elapsed*pulseSpeed));
        }
        private void RegisterLight()
        {
            if(registered || pointLight==null || !gameObject.scene.IsValid()) return;
            if(LightOwners.Count==0) RenderPipelineManager.beginCameraRendering+=BeforeCameraRender;
            LightOwners.Add(this);registered=true;pointLight.enabled=false;
        }
        private void OnEnable() {RegisterLight();}
        public void ClearEffects()
        {
            if(displays!=null) foreach(var display in displays) display.Clear();
            if(pointLight!=null) pointLight.enabled=false;
            if(!registered) return;
            LightOwners.Remove(this);registered=false;
            if(LightOwners.Count==0) RenderPipelineManager.beginCameraRendering-=BeforeCameraRender;
        }
        private void OnDisable() {ClearEffects();}
        private void OnDestroy()
        {
            OnDisable();
            if(displays!=null) foreach(var display in displays) display.Dispose();
            displays=null;blocks=null;
        }
        private static void BeforeCameraRender(ScriptableRenderContext context,Camera camera)
        {
            GeometryUtility.CalculateFrustumPlanes(camera,CameraPlanes);
            for(int i=0;i<MaximumActiveLights;i++) {SelectedLights[i]=null;SelectedDistances[i]=float.PositiveInfinity;}
            foreach(var owner in LightOwners)
            {
                var light=owner.pointLight;light.enabled=false;
                if(!owner.isActiveAndEnabled || (camera.cullingMask&(1<<owner.gameObject.layer))==0) continue;
                bool surfaceEnabled=false;
                foreach(var binding in owner.materialBindings)
                    if(binding.Renderer.enabled && binding.Renderer.gameObject.activeInHierarchy) {surfaceEnabled=true;break;}
                if(!surfaceEnabled) continue;
                var position=light.transform.position;float distance=(camera.transform.position-position).sqrMagnitude;
                if(distance>owner.maxVisibleDistance*owner.maxVisibleDistance ||
                   !GeometryUtility.TestPlanesAABB(CameraPlanes,new Bounds(position,Vector3.one*light.range*2))) continue;
                for(int i=0;i<MaximumActiveLights;i++)
                {
                    if(distance>=SelectedDistances[i]) continue;
                    for(int j=MaximumActiveLights-1;j>i;j--) {SelectedDistances[j]=SelectedDistances[j-1];SelectedLights[j]=SelectedLights[j-1];}
                    SelectedDistances[i]=distance;SelectedLights[i]=owner;break;
                }
            }
            for(int i=0;i<MaximumActiveLights;i++) if(SelectedLights[i]!=null) SelectedLights[i].pointLight.enabled=true;
        }
#if UNITY_EDITOR
        public void Bind(int id,MaterialBinding[] bindings,Vector3[] anchors,float interval,float scale,int count,
            Color color,Color accent,float emission,Light light,float intensity,float distance,float speed,float amount)
        {
            OnDestroy();
            profileId=id;materialBindings=bindings;particleAnchors=anchors;particleInterval=interval;particleScale=scale;particleCount=count;
            particleColor=color;particleAccent=accent;particleEmission=emission;pointLight=light;lightIntensity=intensity;
            maxVisibleDistance=distance;pulseSpeed=speed;pulseAmount=amount;elapsed=0;
            RegisterLight();
        }
#endif
    }
}
