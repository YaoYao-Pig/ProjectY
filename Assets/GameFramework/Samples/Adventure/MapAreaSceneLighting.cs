using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    /// <summary>Fixed light sources, a bounded light pool and optional visible lanterns. Rebuilt only on area entry.</summary>
    public sealed class MapAreaSceneLighting : IDisposable
    {
        private sealed class Source
        {
            public MapAreaViewData.Prop Prop;
            public MapAreaPresentationSettings.PropLight Rule;
            public Vector3 Position;
            public GameObject Fixture;
        }
        private readonly MapAreaPresentationSettings settings;
        private readonly Transform owner;
        private readonly Light[] lamps;
        private readonly int[] selected;
        private readonly float[] distances;
        private readonly List<Source> sources = new List<Source>();
        private readonly List<Material> fixtureMaterials = new List<Material>();
        private readonly HashSet<int> visible = new HashSet<int>();
        private MapAreaViewData layout;
        private int revision = -1, leaderIndex = -1;
        public int SourceCount => sources.Count;
        public int ActiveCount { get; private set; }

        public MapAreaSceneLighting(Transform owner, int capacity, MapAreaPresentationSettings settings)
        {
            this.owner = owner; this.settings = settings;
            lamps = new Light[capacity]; selected = new int[capacity]; distances = new float[capacity];
            for (int i = 0; i < capacity; i++)
            {
                var go = new GameObject("Map_SceneLight_" + i) { hideFlags = HideFlags.DontSave };
                go.transform.SetParent(owner, false);
                var lamp = go.AddComponent<Light>(); lamp.type = LightType.Point;
                lamp.renderMode = LightRenderMode.ForcePixel;
                lamp.shadowBias = .035f; lamp.shadowNormalBias = .12f; lamp.shadowNearPlane = .12f;
                lamp.shadowCustomResolution = 512; lamp.enabled = false; lamps[i] = lamp; selected[i] = -1;
            }
        }
        public void SetArea(MapAreaViewData value)
        {
            Clear(); layout = value; revision = leaderIndex = -1;
            if (layout == null) return;
            foreach (var prop in layout.Props)
            {
                var rule = settings.Light(prop.AssetId);
                if (rule == null) continue;
                var matrix = Matrix4x4.TRS(prop.Position, Quaternion.Euler(0, prop.Rotation, 0), prop.Scale3);
                var source = new Source { Prop = prop, Rule = rule, Position = matrix.MultiplyPoint3x4(rule.position) };
                if (rule.fixture != null)
                {
                    source.Fixture = Object.Instantiate(rule.fixture, owner);
                    source.Fixture.name = "Map_AttachedLantern"; source.Fixture.hideFlags = HideFlags.DontSave;
                    source.Fixture.transform.SetPositionAndRotation(source.Position, Quaternion.Euler(0, prop.Rotation, 0));
                    source.Fixture.transform.localScale = Vector3.one * rule.fixtureScale;
                    var renderer = source.Fixture.GetComponent<MeshRenderer>();
                    if (renderer == null) throw new InvalidOperationException("Light fixture requires a root MeshRenderer.");
                    var materials = renderer.sharedMaterials;
                    var glow = new Material(materials[rule.fixtureEmissionSlot]) { hideFlags = HideFlags.DontSave };
                    glow.SetColor("_EmissionColor", rule.color * rule.emission); glow.EnableKeyword("_EMISSION");
                    fixtureMaterials.Add(glow); materials[rule.fixtureEmissionSlot] = glow; renderer.sharedMaterials = materials;
                    // Point source sits just outside the lantern cage, not inside opaque glass geometry.
                    source.Position += Vector3.up * (.45f * rule.fixtureScale);
                    source.Fixture.SetActive(false);
                }
                sources.Add(source);
            }
        }
        private bool Shown(Source source, MapAreaViewData.State state)
        {
            bool seen = false;
            foreach (int index in source.Prop.Cells) seen |= visible.Contains(index);
            if (!seen) return false;
            var prop = source.Prop;
            int groupLayer = -1, interiorLayer = -1;
            foreach (var member in state.Members)
            {
                var cell = layout.Cells[member.CellIndex];
                if (prop.CutawayGroup > 0 && cell.CutawayGroup == prop.CutawayGroup) groupLayer = Math.Max(groupLayer, cell.Layer);
                if (prop.InteriorId > 0 && (cell.InteriorId == prop.InteriorId || cell.CoverInteriorId == prop.InteriorId)) interiorLayer = Math.Max(interiorLayer, cell.Layer);
            }
            return !(groupLayer >= 0 && prop.CutawayLayer > groupLayer || interiorLayer >= 0 && (prop.Cutaway || prop.Layer > interiorLayer));
        }
        public void Tick(MapAreaViewData.State state, float outdoorWeight, bool torchEnabled)
        {
            ActiveCount = 0;
            if (layout == null || state == null)
            {
                foreach (var lamp in lamps) lamp.enabled = false;
                foreach (var source in sources) if (source.Fixture != null) source.Fixture.SetActive(false);
                revision = -1; return;
            }
            if (state.Revision != revision || leaderIndex != state.CellIndex)
            {
                revision = state.Revision; leaderIndex = state.CellIndex; visible.Clear();
                foreach (int index in state.Visible) visible.Add(index);
                for (int i = 0; i < lamps.Length; i++) { selected[i] = -1; distances[i] = float.MaxValue; }
                for (int i = 0; i < sources.Count; i++)
                {
                    var source = sources[i]; bool shown = Shown(source, state);
                    if (source.Fixture != null) source.Fixture.SetActive(shown);
                    if (!shown) continue;
                    float distance = (source.Position - layout.Cells[state.CellIndex].Position).sqrMagnitude;
                    foreach (var member in state.Members) distance = Mathf.Min(distance, (source.Position - layout.Cells[member.CellIndex].Position).sqrMagnitude);
                    if (distance > source.Rule.range * source.Rule.range * 4) continue;
                    for (int slot = 0; slot < selected.Length; slot++) if (distance < distances[slot])
                    {
                        for (int j = selected.Length - 1; j > slot; j--) { selected[j] = selected[j - 1]; distances[j] = distances[j - 1]; }
                        selected[slot] = i; distances[slot] = distance; break;
                    }
                }
            }
            int shadowBudget = Mathf.Max(0, settings.shadowLightBudget - (torchEnabled ? 1 : 0));
            for (int i = 0; i < lamps.Length; i++)
            {
                var lamp = lamps[i]; lamp.enabled = selected[i] >= 0;
                if (!lamp.enabled) continue;
                var source = sources[selected[i]]; var rule = source.Rule;
                bool enclosed = settings.Underground(layout.AreaType) || source.Prop.InteriorId > 0;
                lamp.transform.position = source.Position; lamp.color = rule.color;
                lamp.range = rule.range; lamp.intensity = rule.intensity * (enclosed ? 1 : outdoorWeight);
                lamp.shadows = i < shadowBudget ? LightShadows.Soft : LightShadows.None; ActiveCount++;
            }
        }
        private void Clear()
        {
            foreach (var lamp in lamps) lamp.enabled = false;
            foreach (var source in sources) if (source.Fixture != null) Remove(source.Fixture);
            foreach (var material in fixtureMaterials) Remove(material);
            sources.Clear(); fixtureMaterials.Clear(); ActiveCount = 0;
        }
        public void Dispose() { Clear(); foreach (var lamp in lamps) if (lamp != null) Remove(lamp.gameObject); }
        private static void Remove(Object value) { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); }
    }
}
