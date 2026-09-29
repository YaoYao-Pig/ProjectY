using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Rendering
{
    /// <summary>Explicit URP render requests for model portraits and Editor captures.</summary>
    public static class UrpCameraRendering
    {
        public static void ConfigurePreview(Camera camera)
        {
            var data = camera.GetUniversalAdditionalCameraData();
            data.SetRenderer(1); // Dedicated renderer without world SSAO.
            data.renderPostProcessing = false;
            data.renderShadows = false;
            data.volumeLayerMask = 0;
            data.antialiasing = AntialiasingMode.None;
            data.requiresDepthOption = CameraOverrideOption.Off;
            data.requiresColorOption = CameraOverrideOption.Off;
        }

        public static void Render(Camera camera, UniversalRenderPipeline.SingleCameraRequest request = null)
        {
            if (camera == null || camera.targetTexture == null) throw new InvalidOperationException("Offscreen rendering requires a camera target texture.");
            if (!(GraphicsSettings.currentRenderPipeline is UniversalRenderPipelineAsset)) throw new InvalidOperationException("Project Y requires Universal Render Pipeline.");
            if (request == null) request = new UniversalRenderPipeline.SingleCameraRequest();
            request.destination = camera.targetTexture;
            RenderPipeline.SubmitRenderRequest(camera, request);
        }
    }
}
