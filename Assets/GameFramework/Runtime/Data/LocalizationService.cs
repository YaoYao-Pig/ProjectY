using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    /// <summary>Default-text lookup boundary. Future i18n export/resolution plugs in here.</summary>
    [LuaCallCSharp]
    public sealed class LocalizationService
    {
        public static LocalizationService Shared { get; } = new LocalizationService();
        private readonly Dictionary<string, Dictionary<string, string>> sources = new Dictionary<string, Dictionary<string, string>>(StringComparer.Ordinal);
        public event Action Changed;

        public void SetText(string source, string id, string text)
        {
            if (string.IsNullOrEmpty(source) || string.IsNullOrEmpty(id) || text == null)
                throw new ArgumentException("Text source/id must be nonempty and text cannot be null.");
            if (!sources.TryGetValue(source, out var values)) sources.Add(source, values = new Dictionary<string, string>(StringComparer.Ordinal));
            values[id] = text;
        }
        public string Find(string source, string id)
        {
            if (string.IsNullOrEmpty(source) || string.IsNullOrEmpty(id)) return null;
            return sources.TryGetValue(source, out var values) && values.TryGetValue(id, out var text) ? text : null;
        }
        public string Resolve(string source, string id, string fallback) => Find(source, id) ?? fallback ?? string.Empty;
        public void NotifyChanged() => Changed?.Invoke();
        public void Clear() { sources.Clear(); NotifyChanged(); }
    }
}
