using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace ProjectY.UI
{
    /// <summary>HUD-owned battle presentation; receives settled values and the pawn impact delay.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class BattleFeedbackSystem : MonoBehaviour
    {
        private struct HealthChange { public int HealthId; public float Fraction; }
        private struct Impact { public float Delay, Strength; }
        private sealed class Binding { public int ActorId; public HealthBarAnimation Bar; }
        [SerializeField, Min(0)] private float shakePixels = 7;
        [SerializeField, Min(.01f)] private float shakeSeconds = .18f;
        [SerializeField, Min(1)] private float shakeFrequency = 32;
        [SerializeField, Min(.001f)] private float burstHitInterval = .2f;
        [SerializeField, Min(1)] private float criticalShakeMultiplier = 1.7f;
        [SerializeField, Min(1)] private float deathShakeMultiplier = 2.5f;
        private readonly Dictionary<int, HealthChange> queued = new Dictionary<int, HealthChange>();
        private readonly List<Impact> queuedImpacts = new List<Impact>();
        private readonly List<Binding> bindings = new List<Binding>();
        private readonly List<Impact> impacts = new List<Impact>();
        private float shakeElapsed;
        private float shakeStrength = 1;
        private bool shaking;
        public Vector2 ScreenOffset { get; private set; }

        public void QueueHealth(int actorId, int healthId, float fraction)
        {
            if (float.IsNaN(fraction) || float.IsInfinity(fraction)) throw new ArgumentOutOfRangeException(nameof(fraction));
            queued[actorId] = new HealthChange { HealthId = healthId, Fraction = Mathf.Clamp01(fraction) };
        }

        // One entry per actual damage event; misses retain their gap through the original shot index.
        // Critical/death affect presentation only. A later normal hit also interrupts a stronger shake.
        public void QueueImpact(int shotIndex, bool critical, bool defeated)
        {
            if (shotIndex < 1) throw new ArgumentOutOfRangeException(nameof(shotIndex));
            float strength = Mathf.Max(critical ? criticalShakeMultiplier : 1, defeated ? deathShakeMultiplier : 1);
            queuedImpacts.Add(new Impact { Delay = (shotIndex - 1) * burstHitInterval, Strength = strength });
        }

        public void BindHealth(HealthBarAnimation bar, int actorId, int healthId, float fraction)
        {
            if (bar == null) throw new ArgumentNullException(nameof(bar));
            var binding = bindings.Find(item => item.Bar == bar);
            if (binding == null) { binding = new Binding { Bar = bar }; bindings.Add(binding); }
            if (binding.ActorId != actorId) { bar.Clear(); binding.ActorId = actorId; }
            bar.SetValue(healthId, fraction, 0);
        }

        public void UnbindHealth(HealthBarAnimation bar)
        {
            bindings.RemoveAll(item => item.Bar == bar);
            bar.Clear();
        }

        // Called after the world snapshot has queued its attacks, before Lua refreshes the HUD.
        internal void Commit(float impactDelay)
        {
            foreach (var pair in queued)
            {
                foreach (var binding in bindings)
                    if (binding.ActorId == pair.Key)
                        binding.Bar.SetValue(pair.Value.HealthId, pair.Value.Fraction, impactDelay);
            }
            foreach (var queuedImpact in queuedImpacts)
            {
                var impact = queuedImpact; impact.Delay += impactDelay;
                int index = impacts.FindIndex(pending => pending.Delay > impact.Delay);
                if (index < 0) impacts.Add(impact); else impacts.Insert(index, impact);
            }
            queuedImpacts.Clear();
            queued.Clear();
        }

        internal void Tick(float deltaTime)
        {
            if (deltaTime <= 0) return;
            if (shaking) shakeElapsed += deltaTime;
            for (int i = 0; i < impacts.Count; i++)
            {
                var impact = impacts[i]; impact.Delay -= deltaTime; impacts[i] = impact;
            }
            // Process due hits chronologically, retaining frame overshoot for the newest one.
            while (impacts.Count > 0 && impacts[0].Delay <= 0)
            {
                var impact = impacts[0]; impacts.RemoveAt(0);
                shakeElapsed = -impact.Delay; shakeStrength = impact.Strength; shaking = true;
            }
            if (!shaking) return;
            float progress = Mathf.Clamp01(shakeElapsed / shakeSeconds);
            float amplitude = shakePixels * shakeStrength * (1 - progress) * (1 - progress);
            float phase = shakeElapsed * shakeFrequency * Mathf.PI * 2;
            ScreenOffset = new Vector2(Mathf.Sin(phase), Mathf.Cos(phase * .79f)) * amplitude;
            if (progress >= 1) { shaking = false; ScreenOffset = Vector2.zero; }
        }

        // The camera owner calls this after writing its base pose; offsets never accumulate.
        internal void ApplyCamera(Camera camera)
        {
            if (ScreenOffset == Vector2.zero) return;
            float height = camera.orthographic ? camera.orthographicSize * 2 : 20 * Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * .5f);
            var offset = ScreenOffset * (height / Mathf.Max(1, camera.pixelHeight));
            camera.transform.position += camera.transform.right * offset.x + camera.transform.up * offset.y;
        }

        public void Skip()
        {
            queued.Clear(); queuedImpacts.Clear(); impacts.Clear(); shaking = false; shakeElapsed = 0; shakeStrength = 1; ScreenOffset = Vector2.zero;
            foreach (var binding in bindings) binding.Bar.Complete();
        }
        public void Clear()
        {
            Skip();
            foreach (var binding in bindings) binding.Bar.Clear();
            bindings.Clear();
        }
        private void OnDisable() => Clear();
    }
}
