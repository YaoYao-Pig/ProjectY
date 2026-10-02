using System;
using System.Linq;
using ProjectY.Rendering;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Editor
{
    public static class WorldVisualStyleAssets
    {
        public const string SettingsPath = "Assets/GameFramework/Resources/Rendering/WorldVisualStyles.asset";
        public const string ProfilePath = "Assets/GameFramework/Resources/Rendering/MedievalFantasy.asset";
        public const string PipelinePath = "Assets/GameFramework/Rendering/MedievalFantasyURP.asset";
        public const string SkyboxPath = "Assets/GameFramework/Rendering/FantasySky.mat";
        private const string RendererPath = "Assets/GameFramework/Rendering/MedievalFantasyRenderer.asset";
        private const string FantasyMenu = "Project Y/渲染/风格/奇幻光影";
        private const string PixelMenu = "Project Y/渲染/风格/像素墨线";

        [MenuItem("Project Y/渲染/安装奇幻光影与对比预设")]
        public static void Install()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Style installation requires Edit Mode.");
            var pixelPipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(FantasyRenderingAssets.PipelinePath);
            var pixelProfile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(FantasyRenderingAssets.ProfilePath);
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(FantasyRenderingAssets.Root + "/FantasyAtmosphere.shader");
            if (pixelPipeline == null || pixelProfile == null || shader == null) throw new InvalidOperationException("Existing URP assets and FantasyAtmosphere shader are required.");
            var renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
            if (renderer == null)
            {
                if (!AssetDatabase.CopyAsset(FantasyRenderingAssets.Root + "/WarmFantasyRenderer.asset", RendererPath))
                    throw new InvalidOperationException("Could not copy the world renderer.");
                renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
                renderer.name = "MedievalFantasyRenderer";
                foreach (var existing in renderer.rendererFeatures)
                {
                    if (AssetDatabase.GetAssetPath(existing) != RendererPath) throw new InvalidOperationException("Renderer copy shares mutable features with the source.");
                    if (existing is PixelArtRendererFeature) existing.SetActive(false);
                    if (existing.GetType().Name == "ScreenSpaceAmbientOcclusion")
                    {
                        var ao = new SerializedObject(existing);
                        ao.FindProperty("m_Settings.Downsample").boolValue = false;
                        ao.FindProperty("m_Settings.Intensity").floatValue = .35f;
                        ao.FindProperty("m_Settings.Radius").floatValue = .32f;
                        ao.FindProperty("m_Settings.DirectLightingStrength").floatValue = .08f;
                        ao.ApplyModifiedPropertiesWithoutUndo();
                    }
                    EditorUtility.SetDirty(existing);
                }
            }
            var feature = renderer.rendererFeatures.OfType<FantasyAtmosphereRendererFeature>().SingleOrDefault();
            if (feature == null)
            {
                feature = ScriptableObject.CreateInstance<FantasyAtmosphereRendererFeature>();
                feature.name = "Fantasy Atmosphere"; AssetDatabase.AddObjectToAsset(feature, renderer); renderer.rendererFeatures.Add(feature);
            }
            var parameters = new SerializedObject(feature);
            parameters.FindProperty("atmosphereShader").objectReferenceValue = shader;
            parameters.ApplyModifiedPropertiesWithoutUndo(); feature.Create();
            EditorUtility.SetDirty(feature); EditorUtility.SetDirty(renderer); renderer.SetDirty(); AssetDatabase.SaveAssetIfDirty(renderer);

            var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
            if (pipeline == null)
            {
                pipeline = UnityEngine.Object.Instantiate(pixelPipeline); pipeline.name = "MedievalFantasyURP";
                pipeline.renderScale = 1; pipeline.msaaSampleCount = 4;
                pipeline.shadowDepthBias = .25f; pipeline.shadowNormalBias = .4f;
                var properties = new SerializedObject(pipeline);
                properties.FindProperty("m_RendererDataList").GetArrayElementAtIndex(0).objectReferenceValue = renderer;
                properties.FindProperty("m_MainLightShadowmapResolution").intValue = 4096;
                properties.FindProperty("m_AdditionalLightsShadowmapResolution").intValue = 2048;
                properties.ApplyModifiedPropertiesWithoutUndo();
                AssetDatabase.CreateAsset(pipeline, PipelinePath);
            }
            var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(ProfilePath);
            if (profile == null)
            {
                profile = ScriptableObject.CreateInstance<VolumeProfile>(); profile.name = "MedievalFantasy";
                AssetDatabase.CreateAsset(profile, ProfilePath);
                profile.Add<Tonemapping>(true).mode.value = TonemappingMode.ACES;
                var color = profile.Add<ColorAdjustments>(true);
                color.postExposure.value = .4f; color.contrast.value = 10; color.saturation.value = 6;
                profile.Add<WhiteBalance>(true).temperature.value = 0;
                var tone = profile.Add<SplitToning>(true);
                tone.shadows.value = new Color(.465f, .49f, .535f);
                tone.highlights.value = new Color(.51f, .505f, .495f); tone.balance.value = 0;
                var bloom = profile.Add<Bloom>(true);
                bloom.threshold.value = .9f; bloom.intensity.value = .48f; bloom.scatter.value = .6f; bloom.highQualityFiltering.value = true;
                var vignette = profile.Add<Vignette>(true); vignette.intensity.value = .025f; vignette.smoothness.value = .55f;
                profile.Add<PixelArt>(true).enableEffect.value = false;
                var atmosphere = profile.Add<FantasyAtmosphere>(true); atmosphere.enableEffect.value = true;
                atmosphere.strength.value = .85f; atmosphere.density.value = .0045f;
                atmosphere.sunlight.value = 2; atmosphere.anisotropy.value = .68f;
                atmosphere.samples.value = 16; atmosphere.maximumDistance.value = 110;
                foreach (var component in profile.components) { component.name = component.GetType().Name; AssetDatabase.AddObjectToAsset(component, profile); }
                EditorUtility.SetDirty(profile); AssetDatabase.SaveAssetIfDirty(profile);
            }
            var choices = AssetDatabase.LoadAssetAtPath<WorldVisualStyles>(SettingsPath);
            if (choices == null)
            {
                choices = ScriptableObject.CreateInstance<WorldVisualStyles>(); choices.name = "WorldVisualStyles";
                AssetDatabase.CreateAsset(choices, SettingsPath);
            }
            choices.pixelPipeline = pixelPipeline; choices.pixelProfile = pixelProfile;
            choices.fantasyPipeline = pipeline; choices.fantasyProfile = profile;
            var skybox = AssetDatabase.LoadAssetAtPath<Material>(SkyboxPath);
            if (skybox == null)
            {
                var skyShader = AssetDatabase.LoadAssetAtPath<Shader>(FantasyRenderingAssets.Root + "/FantasySky.shader");
                if (skyShader == null) throw new InvalidOperationException("FantasySky shader is missing.");
                skybox = new Material(skyShader) { name = "FantasySky" }; AssetDatabase.CreateAsset(skybox, SkyboxPath);
            }
            choices.fantasySkybox = skybox;
            EditorUtility.SetDirty(choices); AssetDatabase.SaveAssetIfDirty(choices);
            Debug.Log("World styles ready. Project Y/渲染/风格: 奇幻光影 / 像素墨线; F9 toggles the live world. Original pixel assets retained.");
        }

        public static void Select(WorldVisualStyle style)
        {
            var choices = AssetDatabase.LoadAssetAtPath<WorldVisualStyles>(SettingsPath);
            if (choices == null) throw new InvalidOperationException("Install world visual styles first.");
            choices.Get(style, out _, out _);
            Undo.RecordObject(choices, "Change world visual style"); choices.selected = style;
            EditorUtility.SetDirty(choices); AssetDatabase.SaveAssetIfDirty(choices);
            FantasyPresentation.ApplyToActive(style);
            Debug.Log("World style: " + (style == WorldVisualStyle.PixelInk ? "像素墨线" : "奇幻光影") + ". F9 switches styles; the selection is saved for the next world session.");
        }

        [MenuItem(FantasyMenu)] public static void Fantasy() => Select(WorldVisualStyle.MedievalFantasy);
        [MenuItem(PixelMenu)] public static void Pixel() => Select(WorldVisualStyle.PixelInk);
        [MenuItem("Project Y/渲染/风格/切换对比 _F9")]
        public static void Toggle()
        {
            var choices = AssetDatabase.LoadAssetAtPath<WorldVisualStyles>(SettingsPath);
            if (choices == null) throw new InvalidOperationException("Install world visual styles first.");
            Select(choices.selected == WorldVisualStyle.PixelInk ? WorldVisualStyle.MedievalFantasy : WorldVisualStyle.PixelInk);
        }

        [MenuItem(FantasyMenu, true)] private static bool ValidateFantasy() => Validate(FantasyMenu, WorldVisualStyle.MedievalFantasy);
        [MenuItem(PixelMenu, true)] private static bool ValidatePixel() => Validate(PixelMenu, WorldVisualStyle.PixelInk);
        private static bool Validate(string menu, WorldVisualStyle style)
        {
            var choices = AssetDatabase.LoadAssetAtPath<WorldVisualStyles>(SettingsPath);
            Menu.SetChecked(menu, choices != null && choices.selected == style);
            return choices != null && !EditorApplication.isCompiling;
        }

        [MenuItem("Project Y/渲染/风格/打开当前风格参数")]
        public static void Inspect()
        {
            var choices = AssetDatabase.LoadAssetAtPath<WorldVisualStyles>(SettingsPath);
            if (choices == null) throw new InvalidOperationException("Install world visual styles first.");
            choices.Get(choices.selected, out _, out var profile);
            Selection.activeObject = profile; EditorGUIUtility.PingObject(profile);
        }

        [MenuItem("Project Y/渲染/风格/打开日照与天空参数")]
        public static void InspectLighting()
        {
            Selection.activeObject = AssetDatabase.LoadAssetAtPath<WorldVisualStyles>(SettingsPath);
            EditorGUIUtility.PingObject(Selection.activeObject);
        }
    }
}
