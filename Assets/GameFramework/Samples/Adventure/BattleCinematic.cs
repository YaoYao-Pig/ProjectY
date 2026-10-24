using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEngine;

namespace ProjectY.Samples
{
    [Serializable]
    public sealed class BattleCinematicSettings
    {
        public bool Enabled = true;
        [Range(.1f, 1)] public float PlaybackSpeed = .35f;
        [Min(.01f)] public float BlendIn = .18f, BlendOut = .24f;
        [Min(0)] public float Lift = .20f;
        [Range(0, 1)] public float DimOpacity = .58f;
        [Range(1, 2)] public float Brightness = 1.25f;
        [Range(30, 65)] public float Pitch = 42;
        [Range(0, 15)] public float OrbitDegrees = 7;
        [Min(1)] public float MinimumSize = 2.4f;
    }

    /// <summary>One settled attack and all recipients. Owns temporary presentation state only.</summary>
    public sealed class BattleCinematic : IDisposable
    {
        private sealed class Tint
        {
            public Renderer Renderer;
            public int Index, Property;
            public Color Color;
            public MaterialPropertyBlock Original, Working;
        }
        private readonly BattleCinematicSettings settings;
        private readonly SceneFocusMask mask;
        private readonly List<Transform> targets = new List<Transform>();
        private readonly List<Renderer> renderers = new List<Renderer>();
        private readonly List<Tint> tints = new List<Tint>();
        private readonly List<Material> materials = new List<Material>();
        private float blend, elapsed, played, duration, releaseElapsed;
        private Vector3 appliedLift;
        private Bounds lastBounds;
        private bool releasing;
        public bool Active { get; private set; }
        public float Weight => blend;
        public float PlaybackRate => Active ? Mathf.Lerp(1, settings.PlaybackSpeed, blend) : 1;

        public BattleCinematic(BattleCinematicSettings settings, SceneFocusMask mask)
        { this.settings = settings ?? throw new ArgumentNullException(nameof(settings)); this.mask = mask ?? throw new ArgumentNullException(nameof(mask)); }

        public void Begin(IReadOnlyList<PawnView> participants, float presentationSeconds)
        {
            Clear();
            if (!settings.Enabled || participants.Count < 1) return;
            if (presentationSeconds < 0 || settings.BlendIn <= 0 || settings.BlendOut <= 0 || settings.PlaybackSpeed <= 0)
                throw new ArgumentOutOfRangeException(nameof(presentationSeconds));
            foreach (var pawn in participants)
            {
                if (pawn == null || targets.Contains(pawn.transform)) continue;
                targets.Add(pawn.transform);
                foreach (var renderer in pawn.GetComponentsInChildren<Renderer>())
                {
                    if (!(renderer is MeshRenderer) && !(renderer is SkinnedMeshRenderer)) continue;
                    // Optional customization modules keep empty material slots until they are enabled.
                    if (!renderer.enabled || !renderer.gameObject.activeInHierarchy) continue;
                    renderers.Add(renderer); materials.Clear(); renderer.GetSharedMaterials(materials);
                    for (int i = 0; i < materials.Count; i++)
                    {
                        var material = materials[i];
                        int property = material.HasProperty("_BaseColor") ? Shader.PropertyToID("_BaseColor") : Shader.PropertyToID("_Color");
                        if (!material.HasProperty(property)) continue;
                        var original = new MaterialPropertyBlock(); renderer.GetPropertyBlock(original, i);
                        var working = new MaterialPropertyBlock(); renderer.GetPropertyBlock(working, i);
                        var color = original.HasColor(property) ? original.GetColor(property) : material.GetColor(property);
                        tints.Add(new Tint { Renderer = renderer, Index = i, Property = property, Color = color, Original = original, Working = working });
                    }
                }
            }
            if (renderers.Count == 0) throw new InvalidOperationException("Battle cinematic has no visible participant geometry.");
            duration = Mathf.Max(.35f, presentationSeconds); Active = true;
            lastBounds = BoundsOfParticipants();
        }

        // Remove the visual offset before PawnMotion writes the next display position.
        public void RestoreTransforms()
        {
            if (appliedLift == Vector3.zero) return;
            foreach (var target in targets) if (target != null) target.position -= appliedLift;
            appliedLift = Vector3.zero;
        }

        public float Advance(float deltaTime)
        {
            if (!Active || deltaTime <= 0) return deltaTime;
            elapsed += deltaTime;
            if (releasing)
            {
                releaseElapsed += deltaTime;
                blend = 1 - Mathf.SmoothStep(0, 1, Mathf.Clamp01(releaseElapsed / settings.BlendOut));
                if (releaseElapsed >= settings.BlendOut) { Clear(); return deltaTime; }
            }
            else blend = Mathf.SmoothStep(0, 1, Mathf.Clamp01(elapsed / settings.BlendIn));
            var presentationDelta = deltaTime * PlaybackRate;
            played += presentationDelta;
            if (!releasing && played >= duration) releasing = true;
            return presentationDelta;
        }

        private Bounds BoundsOfParticipants()
        {
            bool any = false; var result = lastBounds;
            foreach (var renderer in renderers)
            {
                if (renderer == null || !renderer.enabled || !renderer.gameObject.activeInHierarchy) continue;
                if (!any) { result = renderer.bounds; any = true; } else result.Encapsulate(renderer.bounds);
            }
            return result;
        }

        // Owner rebuilds the base camera each frame. No camera or global time state is accumulated.
        public void ApplyCamera(Camera camera, Vector3 baseFocus, float baseYaw, float basePitch)
        {
            if (!Active) return;
            RestoreTransforms();
            appliedLift = Vector3.up * (settings.Lift * blend);
            foreach (var target in targets) if (target != null) target.position += appliedLift;
            foreach (var tint in tints)
            {
                if (tint.Renderer == null) continue;
                var color = tint.Color * Mathf.Lerp(1, settings.Brightness, blend); color.a = tint.Color.a;
                tint.Working.SetColor(tint.Property, color); tint.Renderer.SetPropertyBlock(tint.Working, tint.Index);
            }
            lastBounds = BoundsOfParticipants();
            var rotation = Quaternion.Euler(Mathf.Lerp(basePitch, settings.Pitch, blend),
                baseYaw + Mathf.Sin(Mathf.Clamp01(played / duration) * Mathf.PI) * settings.OrbitDegrees * blend, 0);
            var right = rotation * Vector3.right; var up = rotation * Vector3.up; var extents = lastBounds.extents;
            float horizontal = Vector3.Dot(new Vector3(Mathf.Abs(right.x), Mathf.Abs(right.y), Mathf.Abs(right.z)), extents);
            float vertical = Vector3.Dot(new Vector3(Mathf.Abs(up.x), Mathf.Abs(up.y), Mathf.Abs(up.z)), extents);
            float fit = Mathf.Max(settings.MinimumSize, vertical * 1.45f, horizontal * 1.3f / camera.aspect);
            float distance = Vector3.Distance(camera.transform.position, baseFocus);
            var center = Vector3.Lerp(baseFocus, lastBounds.center, blend);
            camera.orthographicSize = Mathf.Lerp(camera.orthographicSize, fit, blend);
            camera.transform.SetPositionAndRotation(center - rotation * Vector3.forward * distance, rotation);
        }

        public void DrawMask(Camera camera)
        {
            if (!Active) { mask.Hide(); return; }
            mask.Begin(camera); mask.DrawRenderers(renderers); mask.End(settings.DimOpacity * blend);
        }

        public void Clear()
        {
            RestoreTransforms();
            foreach (var tint in tints) if (tint.Renderer != null) tint.Renderer.SetPropertyBlock(tint.Original, tint.Index);
            targets.Clear(); renderers.Clear(); tints.Clear(); mask.Hide();
            Active = releasing = false; blend = elapsed = played = duration = releaseElapsed = 0;
        }
        public void Dispose() { Clear(); mask.Dispose(); }
    }
}
