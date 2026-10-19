using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Head-bar-owned popup pool, advanced by the same scaled clock as battle feedback.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class DamageNumberAnimation : MonoBehaviour
    {
        [SerializeField] private DamageNumberPopup template;
        [SerializeField] private UIFollower follower;
        [SerializeField, Min(1)] private int minimumFontSize = 27;
        [SerializeField, Min(1)] private int maximumFontSize = 54;
        [SerializeField, Min(1)] private float damageSizeReference = 100;
        [SerializeField, Min(1)] private float criticalSizeMultiplier = 1.22f;
        [SerializeField, Min(.35f)] private float normalSeconds = .95f;
        [SerializeField, Min(.35f)] private float criticalSeconds = 1.2f;
        [SerializeField, Min(0)] private float risePixels = 58;
        [SerializeField, Min(.1f)] private float statusInterval=.55f;
        [SerializeField, Min(1)] private int statusFontSize=23;
        private float statusTail;
        private readonly List<DamageNumberPopup> pool = new List<DamageNumberPopup>();
        private Font font;
        private int sequence;
        public bool IsAnimating { get; private set; }

        internal void Prepare(Font value)
        {
            if (value == null) throw new ArgumentNullException(nameof(value));
            if (template == null || follower == null) throw new InvalidOperationException($"{name}: bind the damage number template and follower.");
            if (minimumFontSize <= 0 || maximumFontSize < minimumFontSize || damageSizeReference <= 0 || criticalSizeMultiplier < 1 || normalSeconds < .35f || criticalSeconds < .35f)
                throw new InvalidOperationException($"{name}: invalid damage number settings.");
            font = value;
        }

        internal int FontSize(int amount, bool critical)
        {
            float weight = Mathf.Clamp01(Mathf.Log(1f + amount) / Mathf.Log(1 + damageSizeReference));
            return Mathf.RoundToInt(Mathf.Lerp(minimumFontSize, maximumFontSize, weight) * (critical ? criticalSizeMultiplier : 1));
        }

        internal void Queue(int amount, bool critical, float delay, Color? color = null)
        {
            if (amount <= 0 || delay < 0 || float.IsNaN(delay) || float.IsInfinity(delay)) throw new ArgumentOutOfRangeException(nameof(amount));
            if (font == null) throw new InvalidOperationException($"{name}: prepare damage numbers before queuing hits.");
            if (!isActiveAndEnabled) return;
            DamageNumberPopup popup = null;
            foreach (var candidate in pool) if (!candidate.IsBusy) { popup = candidate; break; }
            if (popup == null) { popup = Instantiate(template, template.transform.parent, false); pool.Add(popup); }
            int lane = !IsAnimating ? 0 : (++sequence % 2 == 0 ? -1 : 1);
            popup.transform.SetAsLastSibling();
            popup.Play(font, amount, critical, FontSize(amount, critical), critical ? criticalSeconds : normalSeconds,
                risePixels * (critical ? 1.25f : 1), delay, lane,color);
            IsAnimating = true;
        }

        internal void Advance(float deltaTime)
        {
            if (deltaTime <= 0) return;
            statusTail=Mathf.Max(0,statusTail-deltaTime);
            IsAnimating = false;
            foreach (var popup in pool) { popup.Advance(deltaTime); IsAnimating |= popup.IsBusy; }
        }

        public void Clear()
        {
            foreach (var popup in pool) popup.Clear();
            IsAnimating = false; sequence = 0;statusTail=0;
        }
        internal void QueueStatus(string text,Color color,float delay)
        {
            if(string.IsNullOrEmpty(text) || delay<0 || float.IsNaN(delay) || float.IsInfinity(delay))throw new ArgumentException("Invalid status popup.");
            if(font==null || statusInterval<=0 || statusFontSize<1)throw new InvalidOperationException("Status popups require prepared font and valid timings.");
            if(!isActiveAndEnabled)return;
            DamageNumberPopup popup=null;
            foreach(var candidate in pool)if(!candidate.IsBusy){popup=candidate;break;}
            if(popup==null){popup=Instantiate(template,template.transform.parent,false);pool.Add(popup);}
            delay=Mathf.Max(delay,statusTail);statusTail=delay+statusInterval;
            popup.transform.SetAsLastSibling();popup.PlayStatus(font,text,color,statusFontSize,.95f,42,delay);IsAnimating=true;
        }

        public void Retire() => follower.RetainLastWorldPosition();

        private void OnDisable() => Clear();
#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(DamageNumberPopup value, UIFollower anchor) { template = value; follower = anchor; }
#endif
    }
}
