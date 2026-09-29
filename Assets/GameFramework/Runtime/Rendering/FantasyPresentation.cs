using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

namespace ProjectY.Rendering
{
    /// <summary>Owns a world's URP settings and grading; restores the camera and pipeline on disposal.</summary>
    public sealed class FantasyPresentation : IDisposable
    {
        private readonly Camera camera;
        private readonly UniversalAdditionalCameraData cameraData;
        private readonly bool createdCameraData, originalHdr, originalPost, originalDithering, originalStopNaN;
        private readonly AntialiasingMode originalAA;
        private readonly AntialiasingQuality originalAAQuality;
        private readonly LayerMask originalVolumeMask;
        private readonly RenderPipelineAsset originalQualityPipeline;
        private readonly UniversalRenderPipelineAsset pipeline;
        private readonly GameObject volumeObject;

        public FantasyPresentation(Camera view, Transform owner)
        {
            if (view == null || owner == null) throw new ArgumentNullException("World camera and presentation owner are required.");
            var source = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
            var profile = Resources.Load<VolumeProfile>("Rendering/WarmFantasy");
            if (source == null || profile == null) throw new InvalidOperationException("URP / WarmFantasy assets are missing. Run Project Y/渲染/安装 URP 奇幻风格资源.");
            camera = view;
            createdCameraData = !camera.TryGetComponent(out UniversalAdditionalCameraData existing);
            cameraData = createdCameraData ? camera.gameObject.AddComponent<UniversalAdditionalCameraData>() : existing;
            originalHdr = camera.allowHDR;
            originalPost = cameraData.renderPostProcessing;
            originalDithering = cameraData.dithering;
            originalStopNaN = cameraData.stopNaN;
            originalAA = cameraData.antialiasing;
            originalAAQuality = cameraData.antialiasingQuality;
            originalVolumeMask = cameraData.volumeLayerMask;
            originalQualityPipeline = QualitySettings.renderPipeline;
            pipeline = Object.Instantiate(source);
            pipeline.name = source.name + " (World session)";
            pipeline.hideFlags = HideFlags.HideAndDontSave;
            QualitySettings.renderPipeline = pipeline;
            camera.allowHDR = true;
            cameraData.renderPostProcessing = true;
            cameraData.dithering = true;
            cameraData.stopNaN = true;
            cameraData.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
            cameraData.antialiasingQuality = AntialiasingQuality.High;
            cameraData.volumeLayerMask = 1;
            volumeObject = new GameObject("Warm Fantasy Volume") { hideFlags = HideFlags.DontSave, layer = 0 };
            volumeObject.transform.SetParent(owner, false);
            var volume = volumeObject.AddComponent<Volume>();
            volume.isGlobal = true; volume.priority = 10; volume.sharedProfile = profile;
        }

        // Orthographic map cameras sit far from their focus; the configured range starts at the focus.
        public void SetShadowDistance(float distance) { pipeline.shadowDistance = Mathf.Max(1, distance); }

        public void Dispose()
        {
            QualitySettings.renderPipeline = originalQualityPipeline;
            Remove(pipeline);
            if (volumeObject != null) Remove(volumeObject);
            // Scene teardown can destroy the camera before its owning world controller.
            if (camera == null || cameraData == null) return;
            camera.allowHDR = originalHdr;
            if (createdCameraData) { Remove(cameraData); return; }
            cameraData.renderPostProcessing = originalPost;
            cameraData.dithering = originalDithering;
            cameraData.stopNaN = originalStopNaN;
            cameraData.antialiasing = originalAA;
            cameraData.antialiasingQuality = originalAAQuality;
            cameraData.volumeLayerMask = originalVolumeMask;
        }

        private static void Remove(Object value)
        {
            if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value);
        }
    }
}
