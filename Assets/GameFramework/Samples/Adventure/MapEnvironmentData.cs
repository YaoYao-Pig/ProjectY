using System;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    /// <summary>只读的画面配方；表结构和引用关系由现有配置系统负责。</summary>
    public sealed class MapEnvironmentData
    {
        public sealed class Key
        {
            public float Hour, Sun, Lamp;
            public Color SunColor, Sky, Equator, Ground, Fog;
        }
        public sealed class Weather
        {
            public int Id;
            public string Name;
            public float Sun, Ambient, FogStart, FogEnd, Shadow;
            public Color Tint;
        }
        public Key[] Keys;
        public Weather[] Weathers;
        public int DefaultWeather, MaxLights;
        public float CycleSeconds, StartHour, Transition, Azimuth, IndoorSun, LampIntensity, LampRange, LampHeight, ShadowDistance;
        public bool AutoCycle;
        public Color IndoorAmbient, LampColor;
        private static Color ColorValue(LuaTable row, string name)
        {
            if (!ColorUtility.TryParseHtmlString(row.Get<string>(name), out var value)) throw new InvalidOperationException("光照配色无效：" + name);
            return value;
        }
        public static MapEnvironmentData Read(LuaTable root)
        {
            var result = new MapEnvironmentData();
            using (var p = root.Get<LuaTable>("profile"))
            {
                result.DefaultWeather = p.Get<int>("defaultWeatherId"); result.MaxLights = p.Get<int>("maxLocalLights");
                result.CycleSeconds = p.Get<float>("cycleSeconds"); result.StartHour = p.Get<float>("startHour"); result.AutoCycle = p.Get<bool>("autoCycle");
                result.Transition = p.Get<float>("transitionSeconds"); result.Azimuth = p.Get<float>("sunAzimuth"); result.IndoorSun = p.Get<float>("indoorSunMultiplier");
                result.LampIntensity = p.Get<float>("lampIntensity"); result.LampRange = p.Get<float>("lampRange"); result.LampHeight = p.Get<float>("lampHeight");
                result.ShadowDistance = p.Get<float>("shadowDistance"); result.IndoorAmbient = ColorValue(p, "indoorAmbientColor"); result.LampColor = ColorValue(p, "lampColor");
            }
            using (var rows = root.Get<LuaTable>("keys"))
            {
                result.Keys = new Key[rows.Length];
                for (var i = 0; i < rows.Length; i++) using (var row = rows.Get<int, LuaTable>(i + 1))
                    result.Keys[i] = new Key { Hour = row.Get<float>("hour"), Sun = row.Get<float>("sunIntensity"), Lamp = row.Get<float>("lampWeight"),
                        SunColor = ColorValue(row, "sunColor"), Sky = ColorValue(row, "skyColor"), Equator = ColorValue(row, "equatorColor"), Ground = ColorValue(row, "groundColor"), Fog = ColorValue(row, "fogColor") };
            }
            using (var rows = root.Get<LuaTable>("weather"))
            {
                result.Weathers = new Weather[rows.Length];
                for (var i = 0; i < rows.Length; i++) using (var row = rows.Get<int, LuaTable>(i + 1))
                    result.Weathers[i] = new Weather { Id = row.Get<int>("id"), Name = row.Get<string>("name"), Sun = row.Get<float>("sunMultiplier"), Ambient = row.Get<float>("ambientMultiplier"),
                        FogStart = row.Get<float>("fogStart"), FogEnd = row.Get<float>("fogEnd"), Shadow = row.Get<float>("shadowStrength"), Tint = ColorValue(row, "tint") };
            }
            return result;
        }
    }
}
