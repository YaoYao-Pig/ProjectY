using System;
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
        private readonly Transform owner;
        public MapWeatherRenderer Weather { get; private set; }
        private int weatherPreview = -1;
        private Vector3 weatherFocus;
        private float cloudCoverage, rainIntensity;
        private Vector2 weatherWind;
        public bool AutomaticWeather => weatherPreview < 0;
        private readonly MapAreaSceneLighting sceneLighting;
        private readonly MapAreaPresentationSettings localPresentation;
        private bool underground;
        private readonly Light torch;
        public int SceneLightCount => sceneLighting.SourceCount;
        public int ActiveSceneLights => sceneLighting.ActiveCount;
        private MapAreaViewData layout;
        private float hour, indoors, weatherSun, weatherAmbient, weatherShadow, fogStart, fogEnd;
        private Color weatherTint;
        private int weatherIndex;
        private readonly Snapshot original;
        private readonly ProjectY.Rendering.FantasyPresentation presentation;
        private Material skyMaterial;
        private bool skyEnabled;
        private Vector3 reflectionSunDirection;
        private static readonly int SkySunDirection = Shader.PropertyToID("_SunDirection");
        private static readonly int SkySunRadiance = Shader.PropertyToID("_SunRadiance");
        private static readonly int SkyDaylight = Shader.PropertyToID("_Daylight");
        private static readonly int SkyCloudCoverage = Shader.PropertyToID("_CloudCoverage");
        private static readonly int SkyRain = Shader.PropertyToID("_WeatherRain");
        private static readonly int SkyStars = Shader.PropertyToID("_StarVisibility");
        private static readonly int SkyTime = Shader.PropertyToID("_WeatherTime");
        private static readonly int SkyWind = Shader.PropertyToID("_WeatherWind");
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
            public float FogStart, FogEnd, FogDensity, Reflection, SunIntensity, ShadowStrength, ShadowBias, ShadowNormalBias;
            public Light Sun;
            public Quaternion Rotation;
            public LightShadows Shadows;
            public Material Skybox;
            public CameraClearFlags ClearFlags;
        }
        public MapEnvironmentController(MapEnvironmentData data, Light mainLight, Camera viewCamera, Transform owner)
        {
            if (mainLight == null || viewCamera == null || owner == null || mainLight.type != LightType.Directional) throw new InvalidOperationException("环境表现需要绑定方向光、相机和生命周期宿主。");
            Data = data; sun = mainLight; camera = viewCamera; this.owner = owner;
            original = new Snapshot { Ambient = RenderSettings.ambientMode, Sky = RenderSettings.ambientSkyColor, Equator = RenderSettings.ambientEquatorColor,
                Ground = RenderSettings.ambientGroundColor, Fog = RenderSettings.fog, FogMode = RenderSettings.fogMode, FogColor = RenderSettings.fogColor,
                FogStart = RenderSettings.fogStartDistance, FogEnd = RenderSettings.fogEndDistance, FogDensity = RenderSettings.fogDensity, Reflection = RenderSettings.reflectionIntensity,
                Background = camera.backgroundColor, Sun = RenderSettings.sun, Skybox = RenderSettings.skybox, ClearFlags = camera.clearFlags,
                Rotation = sun.transform.rotation, SunColor = sun.color, SunIntensity = sun.intensity, Shadows = sun.shadows, ShadowStrength = sun.shadowStrength,
                ShadowBias = sun.shadowBias, ShadowNormalBias = sun.shadowNormalBias };
            Hour = data.StartHour; Running = data.AutoCycle;
            weatherIndex = Array.FindIndex(data.Weathers, w => w.Id == data.DefaultWeather);
            if (weatherIndex < 0 || data.Keys.Length < 2 || data.CycleSeconds <= 0 || data.Transition <= 0) throw new InvalidOperationException("环境配置缺少关键帧或默认天气。");
            var weather = data.Weathers[weatherIndex]; weatherSun = weather.Sun; weatherAmbient = weather.Ambient; weatherShadow = weather.Shadow;
            weatherTint = weather.Tint; fogStart = weather.FogStart; fogEnd = weather.FogEnd;
            cloudCoverage = weather.Cloud; rainIntensity = weather.Rain;
            localPresentation = MapAreaPresentationSettings.Load();
            sceneLighting = new MapAreaSceneLighting(owner, data.MaxLights, localPresentation);
            var torchObject = new GameObject("Map_PartyTorch") { hideFlags = HideFlags.DontSave };
            torchObject.transform.SetParent(owner, false);
            torch = torchObject.AddComponent<Light>(); torch.type = LightType.Point;
            torch.color = data.TorchColor; torch.intensity = data.TorchIntensity; torch.range = data.TorchRange;
            torch.shadows = LightShadows.Soft; torch.shadowCustomResolution = 512;
            torch.shadowBias = .035f; torch.shadowNormalBias = .12f; torch.shadowNearPlane = .12f;
            torch.renderMode = LightRenderMode.ForcePixel; torch.enabled = false;
            RenderSettings.ambientMode = AmbientMode.Trilight; RenderSettings.sun = sun;
            sun.shadows = LightShadows.Soft; sun.shadowBias = .03f; sun.shadowNormalBias = .25f;
            presentation = new ProjectY.Rendering.FantasyPresentation(camera, owner);
            presentation.SetShadowDistance(data.ShadowDistance);
        }
        public void SelectWeather(int index)
        {
            if (index < 0 || index >= Data.Weathers.Length) throw new ArgumentOutOfRangeException(nameof(index));
            weatherIndex = index; weatherPreview = index;
            Weather?.SelectPreview(Data.Weathers[index]);
        }
        public void UseAutomaticWeather() { weatherPreview = -1; Weather?.SelectPreview(null); }
        public void BindWeather(MapPreviewData map, ProjectY.Data.WorldWeatherField field)
        {
            if (Weather == null) Weather = new MapWeatherRenderer(camera, owner, Data.WeatherEffects);
            Weather.BindWorld(map, field); UseAutomaticWeather();
            if (layout != null) Weather.SetArea(layout);
        }
        public void SetWeatherContext(double minutes, Vector2 worldOrigin) { Weather?.SetContext(minutes, worldOrigin); }
        public void DrawWeather(float seconds, Vector3 focus) { Weather?.Draw(seconds, focus, underground); }
        public void HideWeather() { Weather?.Hide(); }
        public void SetArea(MapAreaViewData value)
        {
            layout = value;
            Weather?.SetArea(value);
            underground = value != null && localPresentation.Underground(value.AreaType);
            sceneLighting.SetArea(value);
            torch.enabled = false;
        }
        // The inventory snapshot owns availability; this light follows the rendered leader, including movement interpolation.
        public void SetTorch(bool enabled, Vector3 leaderPosition)
        {
            torch.enabled = enabled && layout != null;
            if (torch.enabled) torch.transform.position = leaderPosition + Vector3.up * Data.TorchHeight;
        }
        public void SetWorldTorch(bool enabled, Vector3 partyPosition)
        {
            torch.enabled=enabled && layout==null;
            if(torch.enabled)torch.transform.position=partyPosition+Vector3.up*Data.TorchHeight;
        }
        public void Tick(float seconds, MapAreaViewData.State state)
        {
            if (state != null) Weather?.UpdateConstruction(state.ConstructionRevision);
            if (Running) Hour += Mathf.Max(0, seconds) * 24 / Data.CycleSeconds;
            var blend = 1 - Mathf.Exp(-Mathf.Max(0, seconds) * 3 / Data.Transition);
            var target = underground || layout != null && state != null && layout.Cells[state.CellIndex].InteriorId > 0 ? 1 : 0;
            indoors = Mathf.Lerp(indoors, target, blend);
            var w = Data.Weathers[weatherIndex];
            float targetCloud = w.Cloud, targetRain = w.Rain;
            if (Weather != null && Weather.IsBound)
            {
                var sample = Weather.Sample(weatherFocus.x, weatherFocus.z);
                targetCloud = sample.Cloud; targetRain = sample.Rain; weatherWind = new Vector2(sample.WindX, sample.WindZ);
                // IDs select UI labels; light/cloud transitions use continuous fields, never threshold jumps.
                for (int i = 0; i < Data.Weathers.Length; i++) if (Data.Weathers[i].Id == sample.WeatherId) { weatherIndex = i; break; }
            }
            cloudCoverage = Mathf.Lerp(cloudCoverage, targetCloud, blend); rainIntensity = Mathf.Lerp(rainIntensity, targetRain, blend);
            MapEnvironmentData.Weather clear = null, overcast = null, rain = null;
            for (int i = 0; i < Data.Weathers.Length; i++)
            { var row = Data.Weathers[i]; if (row.Id == 1) clear = row; else if (row.Id == 2) overcast = row; else if (row.Id == 3) rain = row; }
            if (clear == null || overcast == null || rain == null) throw new InvalidOperationException("Weather needs clear, overcast and rain profiles.");
            float cover = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(clear.Cloud, overcast.Cloud, targetCloud));
            bool spatial = Weather != null && Weather.IsBound && layout == null;
            // One global sun cannot represent simultaneous regional weather. The world material samples its weather field.
            float targetSun = spatial ? clear.Sun : Mathf.Lerp(Mathf.Lerp(clear.Sun, overcast.Sun, cover), rain.Sun, targetRain);
            float targetAmbient = spatial ? clear.Ambient : Mathf.Lerp(Mathf.Lerp(clear.Ambient, overcast.Ambient, cover), rain.Ambient, targetRain);
            Color targetTint = spatial ? clear.Tint : Color.Lerp(Color.Lerp(clear.Tint, overcast.Tint, cover), rain.Tint, targetRain);
            weatherSun = Mathf.Lerp(weatherSun, targetSun, blend); weatherAmbient = Mathf.Lerp(weatherAmbient, targetAmbient, blend);
            weatherShadow = Mathf.Lerp(weatherShadow, spatial ? clear.Shadow : Mathf.Lerp(Mathf.Lerp(clear.Shadow, overcast.Shadow, cover), rain.Shadow, targetRain), blend);
            weatherTint = Color.Lerp(weatherTint, targetTint, blend);
            fogStart = Mathf.Lerp(fogStart, spatial ? clear.FogStart : Mathf.Lerp(Mathf.Lerp(clear.FogStart, overcast.FogStart, cover), rain.FogStart, targetRain), blend);
            fogEnd = Mathf.Lerp(fogEnd, spatial ? clear.FogEnd : Mathf.Lerp(Mathf.Lerp(clear.FogEnd, overcast.FogEnd, cover), rain.FogEnd, targetRain), blend);
            var keys = Data.Keys; var index = keys.Length - 1;
            for (var i = 0; i < keys.Length; i++) if (Hour >= keys[i].Hour) index = i;
            var a = keys[index]; var b = keys[(index + 1) % keys.Length]; var span = Mathf.Repeat(b.Hour - a.Hour, 24);
            var t = Mathf.Repeat(Hour - a.Hour, 24) / span;
            var altitude = Mathf.Sin((Hour - 6) / 24 * Mathf.PI * 2);
            var look = presentation.Lighting;
            var daylight = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(-.15f, .3f, altitude));
            var sunGain = Mathf.Lerp(1, look.daySunMultiplier, daylight);
            var ambientGain = Mathf.Lerp(1, look.dayAmbientMultiplier, daylight);
            var skyTint = Color.Lerp(Color.white, look.skyLightTint, daylight);
            sun.transform.rotation = Quaternion.Euler(12 + Mathf.Abs(altitude) * 58, Data.Azimuth + (altitude < 0 ? 180 : 0), 0);
            sun.color = Color.Lerp(a.SunColor, b.SunColor, t) * weatherTint;
            sun.intensity = Mathf.Lerp(a.Sun, b.Sun, t) * weatherSun * Mathf.Lerp(1, Data.IndoorSun * look.indoorSunMultiplier * localPresentation.interiorSunScale, indoors) * sunGain; sun.shadowStrength = weatherShadow;
            if (underground)
            {
                sun.intensity = localPresentation.undergroundSunIntensity;
                sun.color = localPresentation.undergroundSunColor;
                sun.transform.rotation = Quaternion.Euler(55, -35, 0);
            }
            var indoorAmbient = underground ? localPresentation.undergroundAmbient :
                Data.IndoorAmbient * look.indoorAmbientMultiplier * look.skyLightTint * localPresentation.interiorAmbientScale;
            RenderSettings.ambientSkyColor = Color.Lerp(Color.Lerp(a.Sky, b.Sky, t) * weatherTint * weatherAmbient * ambientGain * skyTint, indoorAmbient * .70f, indoors);
            RenderSettings.ambientEquatorColor = Color.Lerp(Color.Lerp(a.Equator, b.Equator, t) * weatherTint * weatherAmbient * ambientGain, indoorAmbient * .62f, indoors);
            RenderSettings.ambientGroundColor = Color.Lerp(Color.Lerp(a.Ground, b.Ground, t) * weatherTint * weatherAmbient * ambientGain, indoorAmbient * .4f, indoors);
            RenderSettings.fog = !underground; RenderSettings.fogMode = FogMode.Linear; RenderSettings.fogColor = Color.Lerp(a.Fog, b.Fog, t) * weatherTint;
            camera.backgroundColor = underground ? localPresentation.undergroundBackground : RenderSettings.fogColor;
            RenderSettings.reflectionIntensity = look.reflectionIntensity * Mathf.Lerp(Mathf.Lerp(.3f, 1, daylight), .16f, indoors);
            ApplySky(look.skybox && !underground, daylight);
            if (underground) camera.clearFlags = CameraClearFlags.SolidColor;
            presentation.SetEnclosure(underground ? 1 : indoors * .9f);
            sceneLighting.Tick(state, Mathf.Lerp(.18f, 1, Mathf.Lerp(a.Lamp, b.Lamp, t)), torch.enabled);
        }

        private void ApplySky(bool enabled, float daylight)
        {
            if (!enabled)
            {
                if (skyEnabled) { RenderSettings.skybox = original.Skybox; camera.clearFlags = original.ClearFlags; DynamicGI.UpdateEnvironment(); }
                skyEnabled = false;
                return;
            }
            if (skyMaterial == null)
            {
                if (presentation.SkyboxTemplate == null) throw new InvalidOperationException("Fantasy skybox is missing. Install the world style assets.");
                skyMaterial = new Material(presentation.SkyboxTemplate) { name = "Fantasy Sky (World session)", hideFlags = HideFlags.HideAndDontSave };
            }
            skyMaterial.SetVector(SkySunDirection, -sun.transform.forward);
            var radiance = sun.color.linear * sun.intensity;
            skyMaterial.SetVector(SkySunRadiance, new Vector4(radiance.r, radiance.g, radiance.b, 1));
            skyMaterial.SetFloat(SkyDaylight, daylight);
            skyMaterial.SetFloat(SkyCloudCoverage, cloudCoverage);
            skyMaterial.SetFloat(SkyRain, rainIntensity);
            skyMaterial.SetFloat(SkyStars, 1);
            skyMaterial.SetFloat(SkyTime, Weather != null ? Weather.VisualTime : Time.unscaledTime);
            skyMaterial.SetVector(SkyWind, new Vector4(weatherWind.x, weatherWind.y, 0, 0));
            RenderSettings.skybox = skyMaterial; camera.clearFlags = CameraClearFlags.Skybox;
            // Refresh reflections on style changes or meaningful sun movement, not every frame.
            if (!skyEnabled || Vector3.Dot(reflectionSunDirection, sun.transform.forward) < .995f)
            { DynamicGI.UpdateEnvironment(); reflectionSunDirection = sun.transform.forward; }
            skyEnabled = true;
        }
        // 正交远景相机距地很远；雾从观察焦点向后累计，不能吞掉整张大地图。
        public void ApplyCameraFocus(Vector3 focus)
        {
            weatherFocus = focus;
            var distance = Mathf.Max(0, Vector3.Dot(focus - camera.transform.position, camera.transform.forward));
            RenderSettings.fogStartDistance = distance + fogStart; RenderSettings.fogEndDistance = distance + fogEnd;
            presentation.SetShadowDistance(distance + Data.ShadowDistance);
        }
        public void Dispose()
        {
            Weather?.Dispose(); Weather = null;
            presentation.Dispose();
            sceneLighting.Dispose();
            if (torch != null) { if (Application.isPlaying) UnityEngine.Object.Destroy(torch.gameObject); else UnityEngine.Object.DestroyImmediate(torch.gameObject); }
            RenderSettings.ambientMode = original.Ambient; RenderSettings.ambientSkyColor = original.Sky; RenderSettings.ambientEquatorColor = original.Equator; RenderSettings.ambientGroundColor = original.Ground;
            RenderSettings.fog = original.Fog; RenderSettings.fogMode = original.FogMode; RenderSettings.fogColor = original.FogColor;
            RenderSettings.fogStartDistance = original.FogStart; RenderSettings.fogEndDistance = original.FogEnd; RenderSettings.fogDensity = original.FogDensity;
            RenderSettings.reflectionIntensity = original.Reflection; RenderSettings.sun = original.Sun;
            RenderSettings.skybox = original.Skybox;
            if (skyEnabled) DynamicGI.UpdateEnvironment();
            if (skyMaterial != null) { if (Application.isPlaying) UnityEngine.Object.Destroy(skyMaterial); else UnityEngine.Object.DestroyImmediate(skyMaterial); }
            if (camera != null) { camera.backgroundColor = original.Background; camera.clearFlags = original.ClearFlags; }
            if (sun != null)
            {
                sun.transform.rotation = original.Rotation; sun.color = original.SunColor; sun.intensity = original.SunIntensity;
                sun.shadows = original.Shadows; sun.shadowStrength = original.ShadowStrength; sun.shadowBias = original.ShadowBias; sun.shadowNormalBias = original.ShadowNormalBias;
            }
        }
    }
}
