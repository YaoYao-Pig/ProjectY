using System;
using System.IO;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEditor.Rendering.Universal;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Editor
{
    /// <summary>Idempotent URP installation. Existing authored profiles are never reset.</summary>
    public static class FantasyRenderingAssets
    {
        public const string Root = "Assets/GameFramework/Rendering";
        public const string PipelinePath = Root + "/WarmFantasyURP.asset";
        public const string ProfilePath = "Assets/GameFramework/Resources/Rendering/WarmFantasy.asset";

        [MenuItem("Project Y/渲染/安装 URP 奇幻风格资源")]
        public static void Install()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("URP installation requires Edit Mode.");
            Folder(Root); Folder(Root + "/ImportedMaterials");
            var world = Renderer("WarmFantasyRenderer", true);
            var preview = Renderer("PreviewRenderer", false);
            var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
            if (pipeline == null)
            {
                pipeline = UniversalRenderPipelineAsset.Create(world);
                pipeline.name = "WarmFantasyURP";
                pipeline.supportsHDR = true; pipeline.msaaSampleCount = 4; pipeline.renderScale = 1;
                pipeline.supportsCameraDepthTexture = true;
                pipeline.supportsCameraOpaqueTexture = false;
                pipeline.shadowDistance = 180; pipeline.shadowCascadeCount = 4;
                pipeline.cascadeBorder = .15f; pipeline.maxAdditionalLightsCount = 8;
                pipeline.shadowDepthBias = .35f; pipeline.shadowNormalBias = .5f;
                var settings = new SerializedObject(pipeline);
                var renderers = settings.FindProperty("m_RendererDataList"); renderers.arraySize = 2;
                renderers.GetArrayElementAtIndex(0).objectReferenceValue = world;
                renderers.GetArrayElementAtIndex(1).objectReferenceValue = preview;
                settings.FindProperty("m_SoftShadowsSupported").boolValue = true;
                settings.FindProperty("m_MainLightShadowmapResolution").intValue = 2048;
                settings.FindProperty("m_AdditionalLightShadowsSupported").boolValue = true;
                settings.FindProperty("m_AdditionalLightsShadowmapResolution").intValue = 1024;
                settings.FindProperty("m_ColorGradingMode").intValue = (int)ColorGradingMode.HighDynamicRange;
                settings.ApplyModifiedPropertiesWithoutUndo();
                AssetDatabase.CreateAsset(pipeline, PipelinePath);
            }
            CreateProfile();
            int converted = ConvertMaterials();
            GraphicsSettings.defaultRenderPipeline = pipeline;
            int level = QualitySettings.GetQualityLevel();
            try
            {
                for (int i = 0; i < QualitySettings.names.Length; i++)
                {
                    QualitySettings.SetQualityLevel(i, false);
                    QualitySettings.renderPipeline = pipeline;
                }
            }
            finally { QualitySettings.SetQualityLevel(level, false); }
            AssetDatabase.SaveAssetIfDirty(pipeline);
            Debug.Log("URP 14 warm fantasy ready; converted " + converted + " materials. World renderer=0, preview renderer=1. No scene was saved.");
        }

        private static UniversalRendererData Renderer(string name, bool ambientOcclusion)
        {
            var path = Root + "/" + name + ".asset";
            var data = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(path);
            if (data != null) return data;
            data = ScriptableObject.CreateInstance<UniversalRendererData>(); data.name = name;
            data.renderingMode = RenderingMode.Forward;
            data.postProcessData = AssetDatabase.LoadAssetAtPath<PostProcessData>(UniversalRenderPipelineAsset.packagePath + "/Runtime/Data/PostProcessData.asset");
            if (data.postProcessData == null) throw new InvalidOperationException("URP post-process resources are missing.");
            AssetDatabase.CreateAsset(data, path);
            ResourceReloader.ReloadAllNullIn(data, UniversalRenderPipelineAsset.packagePath);
            if (ambientOcclusion)
            {
                // URP 14 exposes its built-in SSAO as an internal feature; serialize its documented settings.
                var type = typeof(UniversalRendererData).Assembly.GetType("UnityEngine.Rendering.Universal.ScreenSpaceAmbientOcclusion", true);
                var feature = (ScriptableRendererFeature)ScriptableObject.CreateInstance(type);
                feature.name = "Soft Contact Shadows";
                AssetDatabase.AddObjectToAsset(feature, data);
                var settings = new SerializedObject(feature);
                settings.FindProperty("m_Settings.Downsample").boolValue = true;
                settings.FindProperty("m_Settings.Intensity").floatValue = .65f;
                settings.FindProperty("m_Settings.Radius").floatValue = .35f;
                settings.FindProperty("m_Settings.DirectLightingStrength").floatValue = .1f;
                settings.FindProperty("m_Settings.Falloff").floatValue = 180;
                settings.FindProperty("m_Settings.Samples").intValue = 1;
                settings.ApplyModifiedPropertiesWithoutUndo();
                ResourceReloader.ReloadAllNullIn(feature, UniversalRenderPipelineAsset.packagePath);
                data.rendererFeatures.Add(feature); feature.Create();
                EditorUtility.SetDirty(feature); AssetDatabase.SaveAssetIfDirty(feature);
            }
            EditorUtility.SetDirty(data); AssetDatabase.SaveAssetIfDirty(data);
            return data;
        }

        private static void CreateProfile()
        {
            if (AssetDatabase.LoadAssetAtPath<VolumeProfile>(ProfilePath) != null) return;
            var profile = ScriptableObject.CreateInstance<VolumeProfile>(); profile.name = "WarmFantasy";
            AssetDatabase.CreateAsset(profile, ProfilePath);
            profile.Add<Tonemapping>(true).mode.value = TonemappingMode.ACES;
            var color = profile.Add<ColorAdjustments>(true);
            color.postExposure.value = .15f; color.contrast.value = 10; color.saturation.value = -4;
            profile.Add<WhiteBalance>(true).temperature.value = 5;
            var tone = profile.Add<SplitToning>(true);
            tone.shadows.value = new Color(.47f, .49f, .53f);
            tone.highlights.value = new Color(.54f, .51f, .46f); tone.balance.value = 5;
            var bloom = profile.Add<Bloom>(true);
            bloom.threshold.value = 1.1f; bloom.intensity.value = .18f; bloom.scatter.value = .55f;
            bloom.highQualityFiltering.value = true;
            var vignette = profile.Add<Vignette>(true);
            vignette.intensity.value = .12f; vignette.smoothness.value = .5f;
            foreach (var component in profile.components)
            {
                component.name = component.GetType().Name;
                AssetDatabase.AddObjectToAsset(component, profile);
            }
            EditorUtility.SetDirty(profile); AssetDatabase.SaveAssetIfDirty(profile);
        }

        private static int ConvertMaterials()
        {
            int count = 0;
            // Preserve material GUIDs, source colors, textures, emission and transparency via Unity's upgrader.
            foreach (var guid in AssetDatabase.FindAssets("t:Material", new[] { "Assets" }))
            {
                var path = AssetDatabase.GUIDToAssetPath(guid);
                if (!path.EndsWith(".mat", StringComparison.OrdinalIgnoreCase)) continue;
                var material = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (Upgrade(material)) { AssetDatabase.SaveAssetIfDirty(material); count++; }
            }
            // FBX subassets cannot be edited persistently. Extract only remaining built-in materials and remap imports.
            foreach (var guid in AssetDatabase.FindAssets("t:Model", new[] { "Assets/DynamicAsset" }))
            {
                var path = AssetDatabase.GUIDToAssetPath(guid);
                var importer = AssetImporter.GetAtPath(path) as ModelImporter;
                if (importer == null) continue;
                bool changed = false;
                foreach (var asset in AssetDatabase.LoadAllAssetsAtPath(path))
                {
                    var embedded = asset as Material;
                    if (embedded == null || !IsStandard(embedded)) continue;
                    string materialPath = Root + "/ImportedMaterials/" + guid + "_" + embedded.name + ".mat";
                    var material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
                    if (material == null)
                    {
                        material = new Material(embedded) { name = embedded.name }; Upgrade(material);
                        AssetDatabase.CreateAsset(material, materialPath); count++;
                    }
                    importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), embedded.name), material);
                    changed = true;
                }
                if (changed) importer.SaveAndReimport();
            }
            return count;
        }

        private static bool IsStandard(Material material) => material.shader != null &&
            (material.shader.name == "Standard" || material.shader.name == "Standard (Specular setup)");
        private static bool Upgrade(Material material)
        {
            if (!IsStandard(material)) return false;
            new StandardUpgrader(material.shader.name).Upgrade(material, MaterialUpgrader.UpgradeFlags.None);
            EditorUtility.SetDirty(material); return true;
        }
        private static void Folder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            var parent = Path.GetDirectoryName(path).Replace('\\', '/'); Folder(parent);
            AssetDatabase.CreateFolder(parent, Path.GetFileName(path));
        }
    }
}
