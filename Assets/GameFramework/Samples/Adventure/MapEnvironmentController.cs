using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ProjectY.Samples
{
    /// <summary>视觉时钟、天气和室内过渡的唯一所有者；结束演示时还原场景环境，不修改玩法时间。</summary>
    public sealed class MapEnvironmentController : IDisposable
    {
        public readonly MapEnvironmentData Data;
        private readonly Light sun;
        private readonly Camera camera;
        private readonly Light[] lamps;
        private readonly Dictionary<int, Vector3> anchors = new Dictionary<int, Vector3>();
        private readonly HashSet<int> lit = new HashSet<int>();
        private MapAreaViewData layout;
        private float hour, indoors, weatherSun, weatherAmbient, weatherShadow, fogStart, fogEnd;
        private Color weatherTint;
        private int weatherIndex;
        private readonly Snapshot original;
        public bool Running { get; set; }
        public float Hour { get => hour; set => hour = Mathf.Repeat(value, 24); }
        public int WeatherIndex => weatherIndex;
        public float IndoorBlend => indoors;
        // 全局渲染设置不能在销毁演示后泄漏给其他场景或 Editor 预览。
        private sealed class Snapshot
        {
            public AmbientMode Ambient;
            public Color Sky, Equator, Ground, FogColor, Background, SunColor;
            public bool Fog;
            public FogMode FogMode;
            public float FogStart, FogEnd, FogDensity, Reflection, ShadowDistance, SunIntensity, ShadowStrength, ShadowBias, ShadowNormalBias;
            public Light Sun;
            public Quaternion Rotation;
            public LightShadows Shadows;
            public int PixelLights;
        }
        public MapEnvironmentController(MapEnvironmentData data, Light mainLight, Camera viewCamera, Transform owner)
        {
            if (mainLight == null || viewCamera == null || owner == null || mainLight.type != LightType.Directional) throw new InvalidOperationException("环境表现需要绑定方向光、相机和生命周期宿主。");
            Data = data; sun = mainLight; camera = viewCamera;
            original = new Snapshot { Ambient = RenderSettings.ambientMode, Sky = RenderSettings.ambientSkyColor, Equator = RenderSettings.ambientEquatorColor,
                Ground = RenderSettings.ambientGroundColor, Fog = RenderSettings.fog, FogMode = RenderSettings.fogMode, FogColor = RenderSettings.fogColor,
                FogStart = RenderSettings.fogStartDistance, FogEnd = RenderSettings.fogEndDistance, FogDensity = RenderSettings.fogDensity, Reflection = RenderSettings.reflectionIntensity,
                ShadowDistance = QualitySettings.shadowDistance, PixelLights = QualitySettings.pixelLightCount, Background = camera.backgroundColor, Sun = RenderSettings.sun,
                Rotation = sun.transform.rotation, SunColor = sun.color, SunIntensity = sun.intensity, Shadows = sun.shadows, ShadowStrength = sun.shadowStrength,
                ShadowBias = sun.shadowBias, ShadowNormalBias = sun.shadowNormalBias };
            Hour = data.StartHour; Running = data.AutoCycle;
            weatherIndex = Array.FindIndex(data.Weathers, w => w.Id == data.DefaultWeather);
            if (weatherIndex < 0 || data.Keys.Length < 2 || data.CycleSeconds <= 0 || data.Transition <= 0) throw new InvalidOperationException("环境配置缺少关键帧或默认天气。");
            var weather = data.Weathers[weatherIndex]; weatherSun = weather.Sun; weatherAmbient = weather.Ambient; weatherShadow = weather.Shadow;
            weatherTint = weather.Tint; fogStart = weather.FogStart; fogEnd = weather.FogEnd;
            lamps = new Light[data.MaxLights];
            for (var i = 0; i < lamps.Length; i++)
            {
                var go = new GameObject("Map_InteriorLight_" + i) { hideFlags = HideFlags.DontSave }; go.transform.SetParent(owner, false);
                lamps[i] = go.AddComponent<Light>(); lamps[i].type = LightType.Point; lamps[i].color = data.LampColor; lamps[i].range = data.LampRange;
                lamps[i].shadows = LightShadows.None; lamps[i].renderMode = LightRenderMode.ForcePixel; lamps[i].enabled = false;
            }
            RenderSettings.ambientMode = AmbientMode.Trilight; RenderSettings.sun = sun; RenderSettings.reflectionIntensity = 0;
            sun.shadows = LightShadows.Soft; sun.shadowBias = .03f; sun.shadowNormalBias = .25f;
            QualitySettings.shadowDistance = data.ShadowDistance; QualitySettings.pixelLightCount = Mathf.Max(original.PixelLights, data.MaxLights + 1);
        }
        public void SelectWeather(int index)
        {
            if (index < 0 || index >= Data.Weathers.Length) throw new ArgumentOutOfRangeException(nameof(index));
            weatherIndex = index;
        }
        public void SetArea(MapAreaViewData value)
        {
            layout = value; anchors.Clear(); var counts = new Dictionary<int, int>();
            if (value != null) foreach (var cell in value.Cells) if (cell.InteriorId > 0)
            {
                if (!anchors.ContainsKey(cell.InteriorId)) { anchors.Add(cell.InteriorId, Vector3.zero); counts.Add(cell.InteriorId, 0); }
                anchors[cell.InteriorId] += cell.Position; counts[cell.InteriorId]++;
            }
            foreach (var entry in counts) anchors[entry.Key] = anchors[entry.Key] / entry.Value + Vector3.up * Data.LampHeight;
            foreach (var lamp in lamps) lamp.enabled = false;
        }
        public void Tick(float seconds, MapAreaViewData.State state)
        {
            if (Running) Hour += Mathf.Max(0, seconds) * 24 / Data.CycleSeconds;
            var blend = 1 - Mathf.Exp(-Mathf.Max(0, seconds) * 3 / Data.Transition);
            var target = layout != null && state != null && layout.Cells[state.CellIndex].InteriorId > 0 ? 1 : 0;
            indoors = Mathf.Lerp(indoors, target, blend);
            var w = Data.Weathers[weatherIndex]; weatherSun = Mathf.Lerp(weatherSun, w.Sun, blend); weatherAmbient = Mathf.Lerp(weatherAmbient, w.Ambient, blend);
            weatherShadow = Mathf.Lerp(weatherShadow, w.Shadow, blend); weatherTint = Color.Lerp(weatherTint, w.Tint, blend);
            fogStart = Mathf.Lerp(fogStart, w.FogStart, blend); fogEnd = Mathf.Lerp(fogEnd, w.FogEnd, blend);
            var keys = Data.Keys; var index = keys.Length - 1;
            for (var i = 0; i < keys.Length; i++) if (Hour >= keys[i].Hour) index = i;
            var a = keys[index]; var b = keys[(index + 1) % keys.Length]; var span = Mathf.Repeat(b.Hour - a.Hour, 24);
            var t = Mathf.Repeat(Hour - a.Hour, 24) / span;
            var altitude = Mathf.Sin((Hour - 6) / 24 * Mathf.PI * 2);
            sun.transform.rotation = Quaternion.Euler(12 + Mathf.Abs(altitude) * 58, Data.Azimuth + (altitude < 0 ? 180 : 0), 0);
            sun.color = Color.Lerp(a.SunColor, b.SunColor, t) * weatherTint;
            sun.intensity = Mathf.Lerp(a.Sun, b.Sun, t) * weatherSun * Mathf.Lerp(1, Data.IndoorSun, indoors); sun.shadowStrength = weatherShadow;
            RenderSettings.ambientSkyColor = Color.Lerp(Color.Lerp(a.Sky, b.Sky, t) * weatherTint * weatherAmbient, Data.IndoorAmbient * .70f, indoors);
            RenderSettings.ambientEquatorColor = Color.Lerp(Color.Lerp(a.Equator, b.Equator, t) * weatherTint * weatherAmbient, Data.IndoorAmbient * .62f, indoors);
            RenderSettings.ambientGroundColor = Color.Lerp(Color.Lerp(a.Ground, b.Ground, t) * weatherTint * weatherAmbient, Data.IndoorAmbient * .4f, indoors);
            RenderSettings.fog = true; RenderSettings.fogMode = FogMode.Linear; RenderSettings.fogColor = Color.Lerp(a.Fog, b.Fog, t) * weatherTint;
            camera.backgroundColor = RenderSettings.fogColor;
            lit.Clear(); var count = 0; var lampWeight = Mathf.Lerp(.4f, 1, Mathf.Lerp(a.Lamp, b.Lamp, t));
            if (layout != null && state != null) foreach (var member in state.Members)
            {
                var id = layout.Cells[member.CellIndex].InteriorId;
                if (id <= 0 || !lit.Add(id) || count == lamps.Length) continue;
                var lamp = lamps[count++]; lamp.transform.position = anchors[id]; lamp.intensity = Data.LampIntensity * lampWeight; lamp.enabled = true;
            }
            for (var i = count; i < lamps.Length; i++) lamps[i].enabled = false;
        }
        // 正交远景相机距地很远；雾从观察焦点向后累计，不能吞掉整张大地图。
        public void ApplyCameraFocus(Vector3 focus)
        {
            var distance = Mathf.Max(0, Vector3.Dot(focus - camera.transform.position, camera.transform.forward));
            RenderSettings.fogStartDistance = distance + fogStart; RenderSettings.fogEndDistance = distance + fogEnd;
        }
        public void Dispose()
        {
            foreach (var lamp in lamps) { if (Application.isPlaying) UnityEngine.Object.Destroy(lamp.gameObject); else UnityEngine.Object.DestroyImmediate(lamp.gameObject); }
            RenderSettings.ambientMode = original.Ambient; RenderSettings.ambientSkyColor = original.Sky; RenderSettings.ambientEquatorColor = original.Equator; RenderSettings.ambientGroundColor = original.Ground;
            RenderSettings.fog = original.Fog; RenderSettings.fogMode = original.FogMode; RenderSettings.fogColor = original.FogColor;
            RenderSettings.fogStartDistance = original.FogStart; RenderSettings.fogEndDistance = original.FogEnd; RenderSettings.fogDensity = original.FogDensity;
            RenderSettings.reflectionIntensity = original.Reflection; RenderSettings.sun = original.Sun; QualitySettings.shadowDistance = original.ShadowDistance; QualitySettings.pixelLightCount = original.PixelLights;
            camera.backgroundColor = original.Background; sun.transform.rotation = original.Rotation; sun.color = original.SunColor; sun.intensity = original.SunIntensity;
            sun.shadows = original.Shadows; sun.shadowStrength = original.ShadowStrength; sun.shadowBias = original.ShadowBias; sun.shadowNormalBias = original.ShadowNormalBias;
        }
    }
}
