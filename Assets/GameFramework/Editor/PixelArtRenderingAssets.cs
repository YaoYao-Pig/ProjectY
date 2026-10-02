using System;
using ProjectY.Rendering;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Editor
{
    /// <summary>Installs only the pixel effect; preserves all existing grading and material assets.</summary>
    public static class PixelArtRenderingAssets
    {
        [MenuItem("Project Y/渲染/安装像素风后处理")]
        public static void Install()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Pixel Art installation requires Edit Mode.");
            var renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(FantasyRenderingAssets.Root + "/WarmFantasyRenderer.asset");
            var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(FantasyRenderingAssets.ProfilePath);
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(FantasyRenderingAssets.Root + "/PixelArt.shader");
            if (renderer == null || profile == null || shader == null) throw new InvalidOperationException("World renderer, WarmFantasy profile and PixelArt shader are required.");

            PixelArtRendererFeature feature = null;
            foreach (var existing in renderer.rendererFeatures)
                if (existing is PixelArtRendererFeature pixel) { feature = pixel; break; }
            if (feature == null)
            {
                feature = ScriptableObject.CreateInstance<PixelArtRendererFeature>();
                feature.name = "World Pixel Art";
                AssetDatabase.AddObjectToAsset(feature, renderer);
                renderer.rendererFeatures.Add(feature);
            }
            var settings = new SerializedObject(feature);
            settings.FindProperty("pixelArtShader").objectReferenceValue = shader;
            settings.ApplyModifiedPropertiesWithoutUndo();
            feature.Create();

            if (!profile.TryGet<PixelArt>(out var effect))
            {
                effect = profile.Add<PixelArt>(true);
                effect.name = "Pixel Art";
                effect.enableEffect.value = true;
                AssetDatabase.AddObjectToAsset(effect, profile);
            }
            EditorUtility.SetDirty(feature);
            EditorUtility.SetDirty(renderer);
            EditorUtility.SetDirty(effect);
            EditorUtility.SetDirty(profile);
            renderer.SetDirty();
            AssetDatabase.SaveAssetIfDirty(renderer);
            AssetDatabase.SaveAssetIfDirty(profile);
            Debug.Log("Pixel Art ready on world renderer. Tune Project Y/Pixel Art in WarmFantasy; UI/preview renderer stay full resolution.");
        }
    }
}
