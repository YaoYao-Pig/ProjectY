using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Rendering
{
    /// <summary>World-only, after grading/Bloom; screen overlay UI and preview renderer stay full resolution.</summary>
    public sealed class PixelArtRendererFeature : ScriptableRendererFeature
    {
        // Serialized reference keeps the hidden shader in Player builds.
        [SerializeField] private Shader pixelArtShader;
        private Material material;
        private PixelArtPass pass;

        public override void Create()
        {
            pass?.Dispose();
            CoreUtils.Destroy(material);
            material = pixelArtShader == null ? null : CoreUtils.CreateEngineMaterial(pixelArtShader);
            pass = new PixelArtPass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            ref var camera = ref renderingData.cameraData;
            if (camera.cameraType != CameraType.Game || camera.renderType != CameraRenderType.Base || !camera.postProcessEnabled)
                return;
            var settings = VolumeManager.instance.stack.GetComponent<PixelArt>();
            if (settings == null || !settings.IsActive()) return;
            if (material == null) throw new InvalidOperationException("Pixel Art shader is missing. Run Project Y/渲染/安装像素风后处理.");
            pass.Setup(material, settings);
            renderer.EnqueuePass(pass);
        }

        protected override void Dispose(bool disposing)
        {
            pass?.Dispose();
            CoreUtils.Destroy(material);
        }

        private sealed class PixelArtPass : ScriptableRenderPass
        {
            private static readonly int SourceSize = Shader.PropertyToID("_PixelSourceSize");
            private static readonly int GridSize = Shader.PropertyToID("_PixelGridSize");
            private static readonly int Style = Shader.PropertyToID("_PixelStyle");
            private static readonly int Ink = Shader.PropertyToID("_PixelInk");
            private readonly ProfilingSampler sampler = new ProfilingSampler("World Pixel Art");
            private RTHandle pixels;
            private Material material;
            private int referenceHeight;
            private Vector4 style;
            private Vector4 ink;

            public PixelArtPass()
            {
                // URP checks this exact event to keep its post-process result in an intermediate color target.
                renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
            }

            public void Setup(Material value, PixelArt settings)
            {
                material = value;
                referenceHeight = settings.referenceHeight.value;
                style = new Vector4(1, settings.colorLevels.value - 1, settings.colorStrength.value, settings.ditherStrength.value);
                ink = new Vector4(settings.outlineStrength.value, settings.outlineWidth.value, settings.outlineDepthThreshold.value, settings.creaseStrength.value);
                ConfigureInput(ink.x > 0 ? ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal : ScriptableRenderPassInput.None);
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                ResetTarget();
                var descriptor = renderingData.cameraData.cameraTargetDescriptor;
                int width = descriptor.width, height = descriptor.height;
                int blockSize = Mathf.Max(1, Mathf.CeilToInt(height / (float)referenceHeight));
                descriptor.width = (width + blockSize - 1) / blockSize;
                descriptor.height = (height + blockSize - 1) / blockSize;
                descriptor.depthBufferBits = 0;
                descriptor.msaaSamples = 1;
                descriptor.bindMS = false;
                descriptor.useMipMap = false;
                descriptor.autoGenerateMips = false;
                RenderingUtils.ReAllocateIfNeeded(ref pixels, descriptor, FilterMode.Point, TextureWrapMode.Clamp, name: "_WorldPixelArt");
                style.x = blockSize;
                material.SetVector(SourceSize, new Vector4(width, height, 1f / width, 1f / height));
                material.SetVector(GridSize, new Vector4(descriptor.width, descriptor.height, 1f / descriptor.width, 1f / descriptor.height));
                material.SetVector(Style, style);
                material.SetVector(Ink, ink);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                // Fetch here: URP swaps the active color buffer during its post-process pass.
                var source = renderingData.cameraData.renderer.cameraColorTargetHandle;
                var cmd = CommandBufferPool.Get();
                try
                {
                    using (new ProfilingScope(cmd, sampler))
                    {
                        Blitter.BlitCameraTexture(cmd, source, pixels, material, 0);
                        Blitter.BlitCameraTexture(cmd, pixels, source, material, 1);
                    }
                    context.ExecuteCommandBuffer(cmd);
                }
                finally { CommandBufferPool.Release(cmd); }
            }

            public void Dispose() { pixels?.Release(); pixels = null; }
        }
    }
}
