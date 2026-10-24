using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace ProjectY.UI
{
    /// <summary>Screen-space inverse silhouette. Call after positioning the camera; owns no gameplay state.</summary>
    public sealed class SceneFocusMask : IDisposable
    {
        private readonly RawImage image;
        private readonly Material silhouetteMaterial, dimMaterial;
        private readonly CommandBuffer commands;
        private readonly List<Material> rendererMaterials = new List<Material>();
        private RenderTexture texture;
        private bool ownsImage;
        public Material SilhouetteMaterial => silhouetteMaterial;
        public RawImage Image => image;

        public static SceneFocusMask Create(RectTransform parent)
        {
            var prefab = Resources.Load<RawImage>("UI/SceneFocusMask");
            if (prefab == null) throw new InvalidOperationException("SceneFocusMask prefab is missing; synchronize world-site UI assets.");
            var view = Object.Instantiate(prefab, parent, false); view.transform.SetAsFirstSibling();
            return new SceneFocusMask(view) { ownsImage = true };
        }
        public SceneFocusMask(RawImage view)
        {
            image = view != null ? view : throw new ArgumentNullException(nameof(view));
            var silhouetteShader = Resources.Load<Shader>("WorldSiteSilhouette");
            var dimShader = Resources.Load<Shader>("WorldSiteDim");
            if (silhouetteShader == null || !silhouetteShader.isSupported || dimShader == null || !dimShader.isSupported)
                throw new InvalidOperationException("Scene focus shaders are missing or unsupported.");
            silhouetteMaterial = new Material(silhouetteShader) { name = "Focus silhouette", enableInstancing = true };
            silhouetteMaterial.SetVector("_SiteMask", Vector4.one);
            dimMaterial = new Material(dimShader) { name = "Focus dim overlay" };
            commands = new CommandBuffer { name = "Scene focus silhouette" };
            image.material = dimMaterial; image.raycastTarget = false; Hide();
        }
        public CommandBuffer Begin(Camera camera)
        {
            if (camera == null) throw new ArgumentNullException(nameof(camera));
            var width = Mathf.Max(1, camera.pixelWidth / 2); var height = Mathf.Max(1, camera.pixelHeight / 2);
            if (texture == null || texture.width != width || texture.height != height)
            {
                if (texture != null) { texture.Release(); Release(texture); }
                texture = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear)
                { name = "Focus silhouette", filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp };
                texture.Create(); image.texture = texture;
            }
            var rect = image.rectTransform; rect.anchorMin = camera.rect.min; rect.anchorMax = camera.rect.max;
            rect.offsetMin = rect.offsetMax = Vector2.zero;
            commands.Clear(); commands.SetRenderTarget(texture); commands.ClearRenderTarget(true, true, Color.black);
            commands.SetViewport(new Rect(0, 0, width, height));
            // CommandBuffer performs the platform conversion. Supplying a GPU-adjusted
            // matrix here converts twice and reverses depth ordering on Direct3D.
            commands.SetViewProjectionMatrices(camera.worldToCameraMatrix, camera.projectionMatrix);
            return commands;
        }
        public void DrawRenderers(IReadOnlyList<Renderer> renderers)
        {
            foreach (var renderer in renderers)
            {
                if (renderer == null || !renderer.enabled || !renderer.gameObject.activeInHierarchy) continue;
                rendererMaterials.Clear(); renderer.GetSharedMaterials(rendererMaterials);
                for (var i = 0; i < rendererMaterials.Count; i++) commands.DrawRenderer(renderer, silhouetteMaterial, i, 0);
            }
        }
        public void End(float opacity)
        {
            var previous = RenderTexture.active;
            Graphics.ExecuteCommandBuffer(commands); RenderTexture.active = previous;
            image.color = new Color(.12f, .14f, .16f, Mathf.Clamp01(opacity)); image.gameObject.SetActive(opacity > 0);
        }
        public void Hide() { if (image != null) image.gameObject.SetActive(false); }
        public void Dispose()
        {
            Hide(); commands.Release();
            if (texture != null) { texture.Release(); Release(texture); }
            if (image != null) { image.texture = null; image.material = null; if (ownsImage) Release(image.gameObject); }
            Release(silhouetteMaterial); Release(dimMaterial);
        }
        private static void Release(Object value)
        { if (value != null) { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); } }
    }
}
