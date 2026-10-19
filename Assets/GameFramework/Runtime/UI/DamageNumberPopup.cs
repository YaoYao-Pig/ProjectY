using System;
using System.Globalization;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>One reusable popup; references are authored in the HudHealth prefab.</summary>
    [DisallowMultipleComponent]
    public sealed class DamageNumberPopup : MonoBehaviour
    {
        [SerializeField] private RectTransform root;
        [SerializeField] private CanvasGroup group;
        [SerializeField] private Text number;
        [SerializeField] private Text criticalLabel;
        [SerializeField] private DamageNumberGlow glow;
        [SerializeField] private CanvasGroup burst;
        private bool critical;
        private float age, duration, rise, drift;
        private Vector2 origin;
        internal bool IsBusy { get; private set; }

        internal void Play(Font font, int amount, bool isCritical, int fontSize, float seconds, float risePixels, float delay, int lane, Color? color = null)
        {
            Begin(font,amount.ToString(CultureInfo.InvariantCulture),color ?? (isCritical?new Color(1,.87f,.32f):new Color(1,.95f,.86f)),isCritical,fontSize,seconds,risePixels,delay,lane);
        }
        internal void PlayStatus(Font font,string text,Color color,int fontSize,float seconds,float risePixels,float delay)
        {
            Begin(font,text,color,false,fontSize,seconds,risePixels,delay,0);
            origin=new Vector2(0,104);Sample();
        }
        private void Begin(Font font,string text,Color color,bool isCritical,int fontSize,float seconds,float risePixels,float delay,int lane)
        {
            if (root == null || group == null || number == null || criticalLabel == null || glow == null || burst == null)
                throw new InvalidOperationException($"{name}: damage popup references must be bound.");
            critical = isCritical; duration = seconds; rise = risePixels; age = -delay;
            origin = new Vector2(lane * 20, 24 + Mathf.Abs(lane) * 7); drift = lane * 18;
            number.font = criticalLabel.font = font;
            number.fontSize = fontSize;
            number.supportRichText=false;number.horizontalOverflow=HorizontalWrapMode.Overflow;
            number.text = text;number.color=color;
            criticalLabel.gameObject.SetActive(critical); burst.gameObject.SetActive(critical);
            glow.SetCritical(critical);
            IsBusy = true; gameObject.SetActive(delay <= 0); Sample();
        }

        internal void Advance(float deltaTime)
        {
            if (!IsBusy || deltaTime <= 0) return;
            age += deltaTime;
            if (age < 0) return;
            if (age >= duration) { Clear(); return; }
            if (!gameObject.activeSelf) gameObject.SetActive(true);
            Sample();
        }

        private void Sample()
        {
            float t = Mathf.Max(0, age);
            float scale;
            if (t < .075f) scale = Mathf.Lerp(.35f, critical ? 1.65f : 1.35f, 1 - Mathf.Pow(1 - t / .075f, 3));
            else if (t < .23f) scale = Mathf.Lerp(critical ? 1.65f : 1.35f, .94f, (t - .075f) / .155f);
            else scale = Mathf.Lerp(.94f, 1, Mathf.Clamp01((t - .23f) / .12f));
            float travel = 1 - Mathf.Pow(1 - Mathf.Clamp01(t / duration), 2);
            float punch = critical ? Mathf.Sin(t * 65) * 5 * Mathf.Clamp01(1 - t / .25f) : 0;
            root.anchoredPosition = origin + new Vector2(drift * travel + punch, rise * travel);
            root.localScale = Vector3.one * scale;
            root.localRotation = Quaternion.Euler(0, 0, critical ? -7 * Mathf.Clamp01(1 - t / .3f) : 0);
            group.alpha = 1 - Mathf.SmoothStep(0, 1, Mathf.InverseLerp(duration * .62f, duration, t));
            burst.alpha = .85f * Mathf.Clamp01(1 - t / .32f);
            burst.transform.localScale = Vector3.one * Mathf.Lerp(.45f, 1.6f, Mathf.Clamp01(t / .32f));
        }

        internal void Clear() { IsBusy = false; gameObject.SetActive(false); }

#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(RectTransform rect, CanvasGroup opacity, Text amount, Text label, DamageNumberGlow halo, CanvasGroup flash)
        { root = rect; group = opacity; number = amount; criticalLabel = label; glow = halo; burst = flash; }
#endif
    }
}
