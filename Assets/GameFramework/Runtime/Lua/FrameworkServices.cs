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
        public AdventureData Adventure { get; } = new AdventureData();
        public LocalizationService Localization => LocalizationService.Shared;
        public UIHost UI { get; }
        public FrameworkServices(UIHost ui) { UI = ui; }

        // 统一从 _Gen 读取导表二进制；xLua 直接把 byte[] 映射为保留零字节的 Lua 字符串。
        public byte[] ReadConfig(string name)
        {
            if (string.IsNullOrEmpty(name) || !System.Text.RegularExpressions.Regex.IsMatch(name, "^[A-Za-z][A-Za-z0-9_]*$"))
                throw new ArgumentException("Invalid config name.");
            var asset = Resources.Load<TextAsset>("_Gen/Config/" + name);
            if (asset == null) throw new FileNotFoundException("Missing exported config: " + name);
            return asset.bytes;
        }

        public void LogError(string message) => Debug.LogError(message);
        public void Log(string message) => Debug.Log(message);
    }
}
