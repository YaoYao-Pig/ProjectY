using System;
using System.IO;
using ProjectY.Data;
using ProjectY.UI;
using UnityEngine;
using XLua;

namespace ProjectY
{
    [LuaCallCSharp]
    public sealed class FrameworkServices
    {
        public PlayerData Player { get; } = new PlayerData();
        public LocalizationService Localization => LocalizationService.Shared;
        public UIHost UI { get; }
        public FrameworkServices(UIHost ui) { UI = ui; }

        // xLua maps byte[] directly to a Lua binary string, preserving embedded zero bytes.
        public byte[] ReadConfig(string name)
        {
            if (string.IsNullOrEmpty(name) || !System.Text.RegularExpressions.Regex.IsMatch(name, "^[A-Za-z][A-Za-z0-9_]*$"))
                throw new ArgumentException("Invalid config name.");
            var asset = Resources.Load<TextAsset>("Config/" + name);
            if (asset == null) throw new FileNotFoundException("Missing exported config: " + name);
            return asset.bytes;
        }

        public void LogError(string message) => Debug.LogError(message);
        public void Log(string message) => Debug.Log(message);
    }
}
