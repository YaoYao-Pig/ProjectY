using System;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Explicitly ticked clock/weather presentation; never advances narrative time.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class WeatherDialView : MonoBehaviour
    {
        [SerializeField] private RectTransform hand;
        [SerializeField] private RectTransform handShadow;
        [SerializeField] private RectTransform sun;
        [SerializeField] private RectTransform cloud;
        [SerializeField] private RectTransform stormCloud;
        [SerializeField] private RectTransform rain;
        [SerializeField] private RectTransform lightning;
        [SerializeField] private Image sunImage;
        [SerializeField] private Image cloudImage;
        [SerializeField] private Image stormImage;
        [SerializeField] private Image rainImage;
        [SerializeField] private Image lightningImage;
        [SerializeField] private WeatherDialFace face;

        private Vector2 handPosition, shadowPosition, sunPosition, cloudPosition, stormPosition, rainPosition, lightningPosition;
        private Color sunTint, cloudTint, stormTint, rainTint, lightningTint;
        private bool bindingsCached, configured, hasState;
        private double dayStart, duskStart, nightStart;
        private double displayedMinutes, targetMinutes, visualSeconds;
        private float displayedCloud, displayedRain, targetCloud, targetRain;

        public void Configure(double dayStart, double duskStart, double nightStart)
        {
            WeatherDialFace.ValidatePhases(dayStart, duskStart, nightStart);
            EnsureBindings();
            face.Configure(dayStart, duskStart, nightStart);
            this.dayStart = dayStart; this.duskStart = duskStart; this.nightStart = nightStart;
            configured = true;
        }

        public void SetState(double totalMinutes, float cloudCoverage, float rainIntensity)
        {
            if (double.IsNaN(totalMinutes) || double.IsInfinity(totalMinutes) || totalMinutes < 0)
                throw new ArgumentOutOfRangeException(nameof(totalMinutes));
            RequireFraction(cloudCoverage, nameof(cloudCoverage)); RequireFraction(rainIntensity, nameof(rainIntensity));
            EnsureBindings();
            if (!configured) throw new InvalidOperationException("Configure the weather dial phases before setting its state.");
            // The accumulated minute value avoids taking the short reverse route at midnight.
            // A load/backwards clock or a six-hour skip should not play a long sweep through old time.
            if (!hasState || totalMinutes < targetMinutes || totalMinutes - targetMinutes >= 360)
                displayedMinutes = totalMinutes;
            if (!hasState) { displayedCloud = cloudCoverage; displayedRain = rainIntensity; }
            targetMinutes = totalMinutes; targetCloud = cloudCoverage; targetRain = rainIntensity; hasState = true;
        }

        public void TickVisual(float unscaledDt)
        {
            if (float.IsNaN(unscaledDt) || float.IsInfinity(unscaledDt) || unscaledDt < 0)
                throw new ArgumentOutOfRangeException(nameof(unscaledDt));
            if (!hasState || !isActiveAndEnabled) return;
            float delta = Mathf.Min(unscaledDt, .1f);
            visualSeconds += delta;
            float timeBlend = 1 - Mathf.Exp(-delta * 10);
            float weatherBlend = 1 - Mathf.Exp(-delta * 5);
            displayedMinutes += (targetMinutes - displayedMinutes) * timeBlend;
            displayedCloud = Mathf.Lerp(displayedCloud, targetCloud, weatherBlend);
            displayedRain = Mathf.Lerp(displayedRain, targetRain, weatherBlend);
            float angle = (float)(-(displayedMinutes % 1440) * .25);
            var rotation = Quaternion.Euler(0, 0, angle);
            hand.localRotation = rotation; handShadow.localRotation = rotation;

            float cloudWeight = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(.10f, .85f, displayedCloud));
            float rainWeight = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(.03f, .72f, displayedRain));
            float daylight = Daylight(displayedMinutes % 1440 / 60);
            Alpha(sunImage, sunTint, daylight * (1 - cloudWeight * .90f) * (1 - rainWeight * .45f));
            Alpha(cloudImage, cloudTint, cloudWeight * (1 - rainWeight * .72f));
            Alpha(stormImage, stormTint, cloudWeight * rainWeight);

            double time = visualSeconds;
            var cloudOffset = new Vector2((float)Math.Sin(time * .85) * 1.25f, (float)Math.Sin(time * 1.2 + .4) * .75f);
            var stormOffset = new Vector2((float)Math.Sin(time * .65 + .8) * .9f, (float)Math.Cos(time * .9) * .55f);
            cloud.anchoredPosition = cloudPosition + cloudOffset;
            stormCloud.anchoredPosition = stormPosition + stormOffset;
            float rainPhase = (float)((time * 1.25 + .35) % 1);
            float rainFade = Mathf.SmoothStep(0, 1, rainPhase / .18f) * (1 - Mathf.SmoothStep(0, 1, (rainPhase - .72f) / .28f));
            rain.anchoredPosition = rainPosition + stormOffset + Vector2.down * (rainPhase * 6 - 3);
            Alpha(rainImage, rainTint, displayedRain * rainFade);

            // Two small, soft pulses inside this icon only; this is not a gameplay thunderstorm state.
            float flashPhase = (float)(time % 7.8);
            float flash = Mathf.Max(Pulse(flashPhase, 5.6f, .11f), Pulse(flashPhase, 5.88f, .085f) * .72f);
            float lightningWeight = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(.65f, .95f, displayedRain));
            lightning.anchoredPosition = lightningPosition + stormOffset * .5f;
            Alpha(lightningImage, lightningTint, flash * lightningWeight * .65f);
        }

        public void ResetVisual()
        {
            hasState = false; visualSeconds = 0;
            if (!bindingsCached) return;
            hand.anchoredPosition = handPosition; handShadow.anchoredPosition = shadowPosition;
            sun.anchoredPosition = sunPosition; cloud.anchoredPosition = cloudPosition;
            stormCloud.anchoredPosition = stormPosition; rain.anchoredPosition = rainPosition; lightning.anchoredPosition = lightningPosition;
        }

        private float Daylight(double hour)
        {
            if (hour < dayStart || hour >= nightStart) return 0;
            double dawnDuration = Math.Min(.75, (duskStart - dayStart) * .25);
            if (hour < dayStart + dawnDuration)
                return Mathf.SmoothStep(0, 1, (float)((hour - dayStart) / dawnDuration));
            if (hour >= duskStart)
                return 1 - Mathf.SmoothStep(0, 1, (float)((hour - duskStart) / (nightStart - duskStart)));
            return 1;
        }

        private void EnsureBindings()
        {
            if (bindingsCached) return;
            // AddComponent runs before the native prefab installer fills these serialized references.
            // Validate at the first explicit use, never through hierarchy searches or an OnEnable fallback.
            if (hand == null || handShadow == null || sun == null || cloud == null || stormCloud == null || rain == null || lightning == null ||
                sunImage == null || cloudImage == null || stormImage == null || rainImage == null || lightningImage == null || face == null)
                throw new InvalidOperationException("Weather dial requires all seven transforms, five images and its face to be explicitly bound.");
            var transforms = new[] { hand, handShadow, sun, cloud, stormCloud, rain, lightning };
            var images = new[] { sunImage, cloudImage, stormImage, rainImage, lightningImage };
            // These small arrays are initialization-only; all per-frame work uses the cached fields.
            for (int i = 0; i < transforms.Length; i++)
            {
                var position = transforms[i].anchoredPosition;
                if (!Finite(position.x) || !Finite(position.y)) throw new InvalidOperationException("Weather dial positions must be finite.");
                for (int j = 0; j < i; j++) if (transforms[i] == transforms[j])
                    throw new InvalidOperationException("Weather dial transforms must be distinct.");
            }
            for (int i = 0; i < images.Length; i++)
            {
                var tint = images[i].color;
                if (!Finite(tint.r) || !Finite(tint.g) || !Finite(tint.b) || !Finite(tint.a) || tint.a < 0 || tint.a > 1)
                    throw new InvalidOperationException("Weather dial image colors must be finite with alpha in [0,1].");
                for (int j = 0; j < i; j++) if (images[i] == images[j])
                    throw new InvalidOperationException("Weather dial images must be distinct.");
                images[i].raycastTarget = false;
            }
            handPosition = hand.anchoredPosition; shadowPosition = handShadow.anchoredPosition; sunPosition = sun.anchoredPosition;
            cloudPosition = cloud.anchoredPosition; stormPosition = stormCloud.anchoredPosition;
            rainPosition = rain.anchoredPosition; lightningPosition = lightning.anchoredPosition;
            sunTint = sunImage.color; cloudTint = cloudImage.color; stormTint = stormImage.color; rainTint = rainImage.color; lightningTint = lightningImage.color;
            bindingsCached = true;
        }

        private static void RequireFraction(float value, string name)
        {
            if (float.IsNaN(value) || float.IsInfinity(value) || value < 0 || value > 1) throw new ArgumentOutOfRangeException(name);
        }
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private static float Pulse(float phase, float center, float halfWidth)
            => Mathf.Max(0, 1 - Mathf.Abs(phase - center) / halfWidth);
        private static void Alpha(Image image, Color tint, float alpha)
        {
            tint.a *= alpha; image.color = tint;
        }
    }
}
