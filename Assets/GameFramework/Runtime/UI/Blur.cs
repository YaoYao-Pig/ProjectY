using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>One screen snapshot per enable, filtered on the GPU and displayed by the attached Image.</summary>
    [ExecuteAlways, DisallowMultipleComponent, RequireComponent(typeof(Image)), AddComponentMenu("UI/Project Y/Blur")]
    public sealed class Blur : MonoBehaviour
    {
        [Tooltip("Optional window to hide while taking the snapshot. Without it, only this Image is hidden.")]
        [SerializeField] private CanvasGroup captureGroup;
        [SerializeField, Range(1, 6)] private int iterations = 4;
        [SerializeField, Range(.5f, 3f)] private float radius = 1;
        [SerializeField, Range(1, 4)] private int downsample = 2;

        private static readonly WaitForEndOfFrame EndOfFrame = new WaitForEndOfFrame();
        private static readonly int RadiusId = Shader.PropertyToID("_Radius");
        private static readonly int TextureId = Shader.PropertyToID("_BlurTexture");
        private Image image;
        private Material originalMaterial, displayMaterial, filterMaterial;
        private RenderTexture result;
        private Coroutine capture;
        private bool hidden, imageWasEnabled;
        private float groupAlpha;

        public RenderTexture BlurredTexture => result;
        public bool IsReady => result != null;
        public bool IsCapturing => capture != null;

        private void OnEnable()
        {
            if (Application.IsPlaying(gameObject)) Capture();
        }

        /// <summary>Capture at the end of this frame. This also works while timeScale is zero.</summary>
        public void Capture()
        {
            if (!Application.IsPlaying(gameObject) || !isActiveAndEnabled)
                throw new InvalidOperationException("Screen capture requires an active Blur in Play Mode; use CaptureFrom for an offscreen source.");
            CancelCapture();
            EnsureResources();
            HideForCapture();
            capture = StartCoroutine(CaptureScreen());
        }

        /// <summary>Copy/filter an explicit full-screen source, e.g. an offscreen UI preview. The caller keeps ownership.</summary>
        public void CaptureFrom(Texture source)
        {
            if (source == null) throw new ArgumentNullException(nameof(source));
            if (!isActiveAndEnabled) throw new InvalidOperationException("Blur must be active before capturing.");
            CancelCapture();
            EnsureResources();
            ApplyBlur(source);
        }

        private IEnumerator CaptureScreen()
        {
            RenderTexture screenshot = null;
            yield return EndOfFrame;
            var previousTarget = RenderTexture.active;
            try
            {
                screenshot = RenderTexture.GetTemporary(Mathf.Max(1, Screen.width), Mathf.Max(1, Screen.height), 0, RenderTextureFormat.ARGB32);
                screenshot.filterMode = FilterMode.Bilinear;
                screenshot.wrapMode = TextureWrapMode.Clamp;
                ScreenCapture.CaptureScreenshotIntoRenderTexture(screenshot);
                ApplyBlur(screenshot);
            }
            finally
            {
                RenderTexture.active = previousTarget;
                if (screenshot != null) RenderTexture.ReleaseTemporary(screenshot);
                RestoreVisibility();
                capture = null;
            }
        }

        private void EnsureResources()
        {
            if (image == null) image = GetComponent<Image>();
            if (displayMaterial != null) return;
            var filterShader = Resources.Load<Shader>("UI/BlurFilter");
            var displayShader = Resources.Load<Shader>("UI/BlurImage");
            if (filterShader == null || displayShader == null || !filterShader.isSupported || !displayShader.isSupported)
                throw new InvalidOperationException("UI Blur shaders are missing or unsupported.");
            originalMaterial = image.material;
            filterMaterial = new Material(filterShader) { name = "UI Blur filter", hideFlags = HideFlags.HideAndDontSave };
            displayMaterial = new Material(displayShader) { name = "UI Blur image", hideFlags = HideFlags.HideAndDontSave };
        }

        private void HideForCapture()
        {
            hidden = true;
            if (captureGroup != null) { groupAlpha = captureGroup.alpha; captureGroup.alpha = 0; }
            else { imageWasEnabled = image.enabled; image.enabled = false; }
        }

        private void RestoreVisibility()
        {
            if (!hidden) return;
            if (captureGroup != null) captureGroup.alpha = groupAlpha;
            else if (image != null) image.enabled = imageWasEnabled;
            hidden = false;
        }

        private void CancelCapture()
        {
            if (capture != null) { StopCoroutine(capture); capture = null; }
            RestoreVisibility();
        }

        private void ApplyBlur(Texture source)
        {
            // Dual filtering: Marius Bjorge, ARM, SIGGRAPH 2015, Bandwidth-Efficient Rendering, slides 20-21.
            var levels = new RenderTexture[Mathf.Clamp(iterations, 1, 6)];
            var width = Mathf.Max(1, source.width / Mathf.Clamp(downsample, 1, 4));
            var height = Mathf.Max(1, source.height / Mathf.Clamp(downsample, 1, 4));
            var previousTarget = RenderTexture.active;
            var previousSrgb = GL.sRGBWrite;
            var sourceFilter = source.filterMode;
            var sourceWrap = source.wrapMode;
            RenderTexture next = null, previousResult = null;
            try
            {
                source.filterMode = FilterMode.Bilinear;
                source.wrapMode = TextureWrapMode.Clamp;
                filterMaterial.SetFloat(RadiusId, Mathf.Clamp(radius, .5f, 3f));
                Texture current = source;
                int count = 0;
                for (int i = 0; i < levels.Length; i++)
                {
                    var level = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGB32);
                    levels[i] = level;
                    level.filterMode = FilterMode.Bilinear; level.wrapMode = TextureWrapMode.Clamp;
                    Blit(current, level, 0);
                    current = level; count++;
                    if (width == 1 && height == 1) break;
                    width = Mathf.Max(1, width / 2); height = Mathf.Max(1, height / 2);
                }
                for (int i = count - 2; i > 0; i--)
                {
                    Blit(current, levels[i], 1);
                    current = levels[i];
                }
                next = new RenderTexture(levels[0].width, levels[0].height, 0, RenderTextureFormat.ARGB32)
                {
                    name = "UI Blur snapshot", hideFlags = HideFlags.HideAndDontSave,
                    filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp
                };
                if (!next.Create()) throw new InvalidOperationException("Cannot allocate UI Blur snapshot.");
                Blit(current, next, count > 1 ? 1 : 2);
                displayMaterial.SetTexture(TextureId, next);
                image.material = displayMaterial;
                // Refresh the UI stencil derivative as well as the original material on recapture.
                image.RecalculateMasking();
                image.SetMaterialDirty();
                previousResult = result;
                result = next; next = null;
            }
            finally
            {
                source.filterMode = sourceFilter; source.wrapMode = sourceWrap;
                RenderTexture.active = previousTarget; GL.sRGBWrite = previousSrgb;
                foreach (var level in levels) if (level != null) RenderTexture.ReleaseTemporary(level);
                ReleaseTexture(next);
                ReleaseTexture(previousResult);
            }
        }

        private void Blit(Texture source, RenderTexture target, int pass)
        {
            GL.sRGBWrite = QualitySettings.activeColorSpace == ColorSpace.Linear && target.sRGB;
            Graphics.Blit(source, target, filterMaterial, pass);
        }

        public void Clear()
        {
            CancelCapture();
            if (image != null && image.material == displayMaterial)
            {
                image.material = originalMaterial;
                image.RecalculateMasking();
            }
            ReleaseTexture(result); result = null;
            ReleaseObject(displayMaterial); displayMaterial = null;
            ReleaseObject(filterMaterial); filterMaterial = null;
            originalMaterial = null;
        }

        private void OnDisable() => Clear();
        private void OnDestroy() => Clear();
        private static void ReleaseTexture(RenderTexture texture)
        {
            if (texture == null) return;
            texture.Release(); ReleaseObject(texture);
        }
        private static void ReleaseObject(UnityEngine.Object value)
        {
            if (value == null) return;
            if (Application.isPlaying) Destroy(value); else DestroyImmediate(value);
        }
    }
}
