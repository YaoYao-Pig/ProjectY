using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Rendering
{
    public sealed class FantasyAtmosphereRendererFeature : ScriptableRendererFeature
    {
        [SerializeField] private Shader atmosphereShader;
        private Material material;
        private AtmospherePass pass;

        public override void Create()
        {
            pass?.Dispose(); CoreUtils.Destroy(material);
            material = atmosphereShader == null ? null : CoreUtils.CreateEngineMaterial(atmosphereShader);
            pass = new AtmospherePass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            ref var camera = ref renderingData.cameraData;
            if (camera.cameraType != CameraType.Game || camera.renderType != CameraRenderType.Base || !camera.postProcessEnabled) return;
            var atmosphere = VolumeManager.instance.stack.GetComponent<FantasyAtmosphere>();
            if (atmosphere == null || !atmosphere.IsActive()) return;
            if (material == null) throw new InvalidOperationException("Fantasy Atmosphere shader is missing.");
            pass.Setup(material, atmosphere); renderer.EnqueuePass(pass);
        }

        protected override void Dispose(bool disposing)
        {
            pass?.Dispose(); CoreUtils.Destroy(material);
        }

        private sealed class AtmospherePass : ScriptableRenderPass
        {
            private static readonly int Parameters = Shader.PropertyToID("_AtmosphereParameters");
            private static readonly int Lighting = Shader.PropertyToID("_AtmosphereLighting");
            private static readonly int Color = Shader.PropertyToID("_AtmosphereColor");
            private static readonly int FogTexture = Shader.PropertyToID("_FantasyFogTexture");
            private static readonly int FogSize = Shader.PropertyToID("_FantasyFogSize");
            private readonly ProfilingSampler sampler = new ProfilingSampler("Fantasy Atmosphere");
            private RTHandle fog, composite;
            private Material material;

            public AtmospherePass()
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
                ConfigureInput(ScriptableRenderPassInput.Depth);
            }

            public void Setup(Material value, FantasyAtmosphere settings)
            {
                material = value;
                material.SetVector(Parameters, new Vector4(settings.density.value, settings.baseHeight.value, settings.heightFalloff.value, settings.samples.value));
                material.SetVector(Lighting, new Vector4(settings.maximumDistance.value, settings.sunlight.value, settings.anisotropy.value, settings.strength.value));
                material.SetColor(Color, settings.fogColor.value.linear);
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                ResetTarget();
                var descriptor = renderingData.cameraData.cameraTargetDescriptor;
                descriptor.depthBufferBits = 0; descriptor.msaaSamples = 1; descriptor.bindMS = false;
                descriptor.useMipMap = false; descriptor.autoGenerateMips = false;
                RenderingUtils.ReAllocateIfNeeded(ref composite, descriptor, FilterMode.Point, TextureWrapMode.Clamp, name: "_FantasyAtmosphereComposite");
                descriptor.width = Mathf.Max(1, (descriptor.width + 1) / 2);
                descriptor.height = Mathf.Max(1, (descriptor.height + 1) / 2);
                // Alpha stores transmission; the camera's HDR format may have no alpha channel.
                descriptor.graphicsFormat = GraphicsFormat.R16G16B16A16_SFloat;
                RenderingUtils.ReAllocateIfNeeded(ref fog, descriptor, FilterMode.Point, TextureWrapMode.Clamp, name: "_FantasyAtmosphereHalf");
                material.SetVector(FogSize, new Vector4(descriptor.width, descriptor.height, 1f / descriptor.width, 1f / descriptor.height));
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                var source = renderingData.cameraData.renderer.cameraColorTargetHandle;
                var cmd = CommandBufferPool.Get();
                try
                {
                    using (new ProfilingScope(cmd, sampler))
                    {
                        Blitter.BlitCameraTexture(cmd, source, fog, material, 0);
                        cmd.SetGlobalTexture(FogTexture, fog.nameID);
                        Blitter.BlitCameraTexture(cmd, source, composite, material, 1);
                        Blitter.BlitCameraTexture(cmd, composite, source);
                    }
                    context.ExecuteCommandBuffer(cmd);
                }
                finally { CommandBufferPool.Release(cmd); }
            }

            public void Dispose() { fog?.Release(); composite?.Release(); fog = null; composite = null; }
        }
    }
}
