using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Serialization;
using XLua;

namespace ProjectY.UI
{
    /// <summary>MVC View: serialized Unity references only; no business state or Lua controller.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class LuaReference : MonoBehaviour
    {
        [Serializable]
        public struct Entry
        {
            [FormerlySerializedAs("Name")] public string Key;
            public Component Target;
            public Entry(string key, Component target) { Key = key; Target = target; }
        }

        [SerializeField] private Entry[] entries = Array.Empty<Entry>();
        private Dictionary<string, Component> lookup;

        public Component Get(string key)
        {
            if (lookup == null) ValidateBindings();
            if (!lookup.TryGetValue(key, out var value) || value == null)
                throw new InvalidOperationException($"{name}: missing LuaReference '{key}'.");
            return value;
        }

        public Button GetButton(string key) => Require<Button>(key);
        public Text GetText(string key) => Require<Text>(key);
        public UITxt GetUITxt(string key) => Require<UITxt>(key);
        public Image GetImage(string key) => Require<Image>(key);
        public Toggle GetToggle(string key) => Require<Toggle>(key);
        public Slider GetSlider(string key) => Require<Slider>(key);
        public InputField GetInputField(string key) => Require<InputField>(key);
        public Transform GetTransform(string key) => Require<Transform>(key);
        public LuaReference GetReference(string key) => Require<LuaReference>(key);

        private T Require<T>(string key) where T : Component
        {
            var value = Get(key);
            if (value is T result) return result;
            throw new InvalidOperationException($"{name}.{key}: expected {typeof(T).Name}, got {value.GetType().Name}.");
        }

        public void ValidateBindings()
        {
            var next = new Dictionary<string, Component>(StringComparer.Ordinal);
            foreach (var entry in entries)
            {
                if (!IsValidKey(entry.Key) || entry.Target == null)
                    throw new InvalidOperationException($"{name}: invalid Lua key '{entry.Key}' or missing Component.");
                if (next.ContainsKey(entry.Key))
                    throw new InvalidOperationException($"{name}: duplicate LuaReference '{entry.Key}'.");
                next.Add(entry.Key, entry.Target);
            }
            lookup = next;
        }

        public static bool IsValidKey(string key) => !string.IsNullOrEmpty(key) &&
            System.Text.RegularExpressions.Regex.IsMatch(key, @"\A[A-Za-z_][A-Za-z0-9_]*\z") &&
            !System.Text.RegularExpressions.Regex.IsMatch(key, @"\A(?:and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while)\z");

#if UNITY_EDITOR
        [BlackList]
        public void SetEditorBindings(params Entry[] bindings) { entries = bindings; lookup = null; }
        [BlackList] public Entry[] GetEditorBindings() => (Entry[])entries.Clone();
        private void OnValidate() => lookup = null;
#endif
    }
}
