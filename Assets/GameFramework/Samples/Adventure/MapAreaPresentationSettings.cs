using System;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Local-map material detail and authored light anchors. Does not change navigation or source materials.</summary>
    public sealed class MapAreaPresentationSettings : ScriptableObject
    {
        public const string ResourcePath = "Rendering/MapAreaPresentation";
        [Serializable] public sealed class MaterialDetail
        {
            public Material material;
            // Same pattern identities as MapAreaSurfaceTable. Coordinates are in model space for props.
            public Vector4 pattern;
            public float relief = .025f;
        }
        [Serializable] public sealed class PropLight
        {
            public int assetId;
            public Vector3 position;
            public Color color = new Color(1, .65f, .32f);
            public float intensity = 5, range = 10, emission = 3;
            public int[] emissionSlots = Array.Empty<int>();
            // Optional visible lantern for an existing beam or table with no built-in lamp.
            public GameObject fixture;
            public float fixtureScale = 1;
            public int fixtureEmissionSlot = 1;
        }
        public MaterialDetail[] materials = Array.Empty<MaterialDetail>();
        public PropLight[] lights = Array.Empty<PropLight>();
        public int[] undergroundAreaTypes = { 1, 6 };
        public Color undergroundAmbient = new Color(.22f, .28f, .36f);
        public Color undergroundBackground = new Color(.035f, .045f, .065f);
        public float undergroundSunIntensity = .10f;
        public Color undergroundSunColor = new Color(.64f, .74f, .9f);
        public float interiorAmbientScale = .7f, interiorSunScale = .2f;
        public int shadowLightBudget = 2;

        public static MapAreaPresentationSettings Load()
        {
            var value = Resources.Load<MapAreaPresentationSettings>(ResourcePath);
            if (value == null) throw new InvalidOperationException("Local-map presentation settings are missing.");
            return value;
        }
        public MaterialDetail Detail(Material material)
        {
            foreach (var row in materials) if (row.material == material) return row;
            return null; // Unlisted materials deliberately retain their original finish.
        }
        public PropLight Light(int assetId)
        {
            foreach (var row in lights) if (row.assetId == assetId) return row;
            return null;
        }
        public bool Underground(int areaType) => Array.IndexOf(undergroundAreaTypes, areaType) >= 0;
    }
}
