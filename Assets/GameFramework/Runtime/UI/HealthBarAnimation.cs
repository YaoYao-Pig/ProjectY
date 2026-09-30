using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Presentation only: foreground drains first, then the pale trail catches up.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class HealthBarAnimation : MonoBehaviour
    {
        [SerializeField] private Image foreground;
        [SerializeField] private Image trail;
        [SerializeField, Min(.01f)] private float foregroundSeconds = .22f;
        [SerializeField, Min(.01f)] private float trailSeconds = .38f;
        [SerializeField] private AnimationCurve foregroundEase = AnimationCurve.EaseInOut(0, 0, 1, 1);
        [SerializeField] private AnimationCurve trailEase = AnimationCurve.EaseInOut(0, 0, 1, 1);
        private Coroutine routine;
        private float wait, elapsed, startForeground, startTrail;
        private bool drainingTrail;
        private int identity;
        private bool initialized;
        public bool IsAnimating { get; private set; }
        public float TargetFraction { get; private set; }
        public float ForegroundFraction => foreground.rectTransform.anchorMax.x;
        public float TrailFraction => trail.rectTransform.anchorMax.x;

        public void SetValue(int healthId, float fraction, float delay)
        {
            if (foreground == null || trail == null || foreground == trail)
                throw new InvalidOperationException($"{name}: bind both distinct health bar images.");
            if (foregroundSeconds <= 0 || trailSeconds <= 0 || foregroundEase == null || trailEase == null)
                throw new InvalidOperationException($"{name}: health animation durations and curves must be configured.");
            if (float.IsNaN(fraction) || float.IsInfinity(fraction) || delay < 0)
                throw new ArgumentOutOfRangeException(nameof(fraction));
            fraction = Mathf.Clamp01(fraction);
            if (!initialized || healthId != identity || !isActiveAndEnabled)
            {
                identity = healthId; initialized = true; TargetFraction = fraction;
                Complete(); return;
            }
            if (Mathf.Approximately(TargetFraction, fraction)) return;
            var previousTarget = TargetFraction;
            Cancel(); TargetFraction = fraction;
            // Healing and a changed health owner never replay an old damage trail.
            if (fraction >= previousTarget) { Complete(); return; }
            wait = delay; elapsed = 0; drainingTrail = false;
            startForeground = ForegroundFraction; startTrail = TrailFraction;
            IsAnimating = true;
            routine = StartCoroutine(Drain());
        }

        private IEnumerator Drain()
        {
            while (IsAnimating) { yield return null; Advance(Time.deltaTime); }
            routine = null;
        }

        internal void Advance(float deltaTime)
        {
            if (!IsAnimating || deltaTime <= 0) return;
            if (wait > 0)
            {
                float consumed = Mathf.Min(wait, deltaTime); wait -= consumed; deltaTime -= consumed;
            }
            elapsed += deltaTime;
            if (!drainingTrail)
            {
                SetFraction(foreground, Mathf.Lerp(startForeground, TargetFraction, Mathf.Clamp01(foregroundEase.Evaluate(elapsed / foregroundSeconds))));
                if (elapsed < foregroundSeconds) return;
                SetFraction(foreground, TargetFraction); elapsed -= foregroundSeconds; drainingTrail = true;
            }
            SetFraction(trail, Mathf.Max(TargetFraction, Mathf.Lerp(startTrail, TargetFraction, Mathf.Clamp01(trailEase.Evaluate(elapsed / trailSeconds)))));
            if (elapsed < trailSeconds) return;
            SetFraction(trail, TargetFraction); IsAnimating = false;
        }

        private static void SetFraction(Image image, float value)
        {
            var rect = image.rectTransform;
            rect.anchorMax = new Vector2(value, 1);
        }
        private void Cancel()
        {
            if (routine != null) StopCoroutine(routine);
            routine = null; IsAnimating = false;
        }
        public void Complete()
        {
            Cancel();
            if (!initialized) return;
            SetFraction(foreground, TargetFraction); SetFraction(trail, TargetFraction);
        }
        public void Clear() { Complete(); initialized = false; }
        private void OnDisable() => Clear();
#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(Image front, Image back) { foreground = front; trail = back; }
#endif
    }
}
