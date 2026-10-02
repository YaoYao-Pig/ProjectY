using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

namespace ProjectY.Rendering
{
    /// <summary>Owns a world's URP settings and grading; restores the camera and pipeline on disposal.</summary>
    public sealed class FantasyPresentation : IDisposable
    {
        private static readonly HashSet<FantasyPresentation> active = new HashSet<FantasyPresentation>();
        private readonly Camera camera;
        private readonly UniversalAdditionalCameraData cameraData;
        private readonly bool createdCameraData, originalHdr, originalPost, originalDithering, originalStopNaN;
        private readonly AntialiasingMode originalAA;
        private readonly AntialiasingQuality originalAAQuality;
        private readonly LayerMask originalVolumeMask;
        private readonly RenderPipelineAsset originalQualityPipeline;
        private UniversalRenderPipelineAsset pipeline;
        private readonly GameObject volumeObject;
        private readonly Volume volume;
        private readonly WorldVisualStyles styles;
        public WorldVisualStyle Style { get; private set; }
        public WorldLightingLook Lighting => Style == WorldVisualStyle.PixelInk ? WorldLightingLook.Neutral : styles.fantasyLighting;
        public Material SkyboxTemplate => styles.fantasySkybox;

        public FantasyPresentation(Camera view, Transform owner)
        {
            if (view == null || owner == null) throw new ArgumentNullException("World camera and presentation owner are required.");
            styles = Resources.Load<WorldVisualStyles>(WorldVisualStyles.ResourcePath);
            if (styles == null) throw new InvalidOperationException("World visual styles are missing. Run Project Y/渲染/安装奇幻光影与对比预设.");
            styles.Get(styles.selected, out _, out _);
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
            camera.allowHDR = true;
            cameraData.renderPostProcessing = true;
            cameraData.stopNaN = true;
            cameraData.antialiasingQuality = AntialiasingQuality.High;
            cameraData.volumeLayerMask = 1;
            volumeObject = new GameObject("Warm Fantasy Volume") { hideFlags = HideFlags.DontSave, layer = 0 };
            volumeObject.transform.SetParent(owner, false);
            volume = volumeObject.AddComponent<Volume>();
            volume.isGlobal = true; volume.priority = 10;
            SetStyle(styles.selected);
            active.Add(this);
        }

        public void SetStyle(WorldVisualStyle style)
        {
            styles.Get(style, out var source, out var profile);
            var previous = pipeline;
            pipeline = Object.Instantiate(source);
            pipeline.name = source.name + " (World session)";
            pipeline.hideFlags = HideFlags.HideAndDontSave;
            if (previous != null) pipeline.shadowDistance = previous.shadowDistance;
            QualitySettings.renderPipeline = pipeline;
            volume.sharedProfile = profile;
            bool pixel = style == WorldVisualStyle.PixelInk;
            cameraData.antialiasing = pixel ? AntialiasingMode.None : AntialiasingMode.SubpixelMorphologicalAntiAliasing;
            cameraData.dithering = !pixel;
            Style = style;
            if (previous != null) Remove(previous);
        }

        public static void ApplyToActive(WorldVisualStyle style)
        {
            foreach (var presentation in active) presentation.SetStyle(style);
        }

        // Orthographic map cameras sit far from their focus; the configured range starts at the focus.
        public void SetShadowDistance(float distance) { pipeline.shadowDistance = Mathf.Max(1, distance); }

        public void Dispose()
        {
            active.Remove(this);
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
