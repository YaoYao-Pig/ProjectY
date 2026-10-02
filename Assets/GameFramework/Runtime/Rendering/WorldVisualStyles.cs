using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Rendering
{
    public enum WorldVisualStyle { PixelInk, MedievalFantasy }

    [Serializable]
    public sealed class WorldLightingLook
    {
        [Range(1, 8), Tooltip("白天主光倍率，增强实际照明和高光，不是整屏提亮。")]
        public float daySunMultiplier = 4;
        [Range(.5f, 3), Tooltip("天空漫反射补光倍率，让阴影保留颜色和细节。")]
        public float dayAmbientMultiplier = 1.18f;
        [Range(0, 2)] public float reflectionIntensity = .75f;
        public Color skyLightTint = new Color(.88f, .95f, 1);
        public bool skybox = true;
        public static readonly WorldLightingLook Neutral = new WorldLightingLook
        { daySunMultiplier = 1, dayAmbientMultiplier = 1, reflectionIntensity = 0, skyLightTint = Color.white, skybox = false };
    }

    [CreateAssetMenu(menuName = "Project Y/Rendering/World Visual Styles")]
    public sealed class WorldVisualStyles : ScriptableObject
    {
        public const string ResourcePath = "Rendering/WorldVisualStyles";
        public WorldVisualStyle selected = WorldVisualStyle.MedievalFantasy;
        public UniversalRenderPipelineAsset pixelPipeline;
        public VolumeProfile pixelProfile;
        public UniversalRenderPipelineAsset fantasyPipeline;
        public VolumeProfile fantasyProfile;
        public WorldLightingLook fantasyLighting = new WorldLightingLook();
        public Material fantasySkybox;

        public void Get(WorldVisualStyle style, out UniversalRenderPipelineAsset pipeline, out VolumeProfile profile)
        {
            switch (style)
            {
                case WorldVisualStyle.PixelInk: pipeline = pixelPipeline; profile = pixelProfile; break;
                case WorldVisualStyle.MedievalFantasy: pipeline = fantasyPipeline; profile = fantasyProfile; break;
                default: throw new ArgumentOutOfRangeException(nameof(style));
            }
            if (pipeline == null || profile == null) throw new InvalidOperationException("World visual style assets are missing. Run Project Y/渲染/安装奇幻光影与对比预设.");
        }
    }
}
