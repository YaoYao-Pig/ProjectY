using System;
using ProjectY.Data;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    /// <summary>Bounded, camera-local presentation of the authoritative world weather field.</summary>
    public sealed class MapWeatherRenderer : IDisposable
    {
        private const int MapResolution = 32;
        private readonly Camera camera;
        private readonly int layer;
        private readonly MapEnvironmentData.WeatherSettings settings;
        private readonly MapWeatherSurface surface = new MapWeatherSurface();
        private readonly Material rainMaterial, splashMaterial, cloudMaterial;
        private readonly ParticleSystem rain, splashes;
        private readonly ParticleSystemRenderer rainRenderer, splashRenderer;
        private readonly ParticleSystem.Particle[] rainParticles, splashParticles;
        private readonly Matrix4x4[] cloudMatrices;
        private readonly Vector4[] cloudTints;
        private readonly CloudSlot[] cloudSlots;
        private readonly MaterialPropertyBlock cloudProperties = new MaterialPropertyBlock();
        private readonly Plane[] planes = new Plane[6];
        private readonly Mesh cloudMesh;
        private readonly Texture2D weatherMap;
        private readonly Color32[] pixels = new Color32[MapResolution * MapResolution];
        private readonly Column[] columns;
        private struct Column { public Vector3 Ground; public float Rain, Phase, Speed; public Vector2 Drift; }
        private struct CloudSlot
        {
            public bool Occupied, Desired;
            public long X, Z;
            public double BaseX, BaseZ;
            public Vector3 Position;
            public float TargetHeight, Scale;
            public Quaternion Rotation;
            public Vector4 Tint, TargetTint;
        }
        private WorldWeatherField field;
        private MapAreaViewData area;
        private Vector2 origin;
        private double minutes;
        private float visualTime, elapsed;
        private double cloudTravelX, cloudTravelZ;
        private float cloudElapsed, cloudSpacing;
        private Vector2 cloudVelocity;
        private bool cloudTargetsDirty = true, cloudSpacingReset;
        private Rect footprint;
        private Vector4 mapRect;
        private bool dirty = true, active, disposed;
        private MapEnvironmentData.Weather preview;
        private double lastMinutes = double.NaN;
        private int columnCount;
        private int constructionRevision = -1;
        private static readonly int MapId = Shader.PropertyToID("_WorldWeatherMap");
        private static readonly int RectId = Shader.PropertyToID("_WorldWeatherRect");
        private static readonly int EnabledId = Shader.PropertyToID("_WorldWeatherEnabled");
        private static readonly int TintId = Shader.PropertyToID("_WeatherCloudTint");
        private Texture previousMap;
        private Vector4 previousRect;
        private float previousEnabled;
        private bool globalsInstalled;
        public int RainCount { get; private set; }
        public int SplashCount { get; private set; }
        public int CloudCount { get; private set; }
        public int RefreshCount { get; private set; }
        public float VisualTime => visualTime;
        public bool IsBound => field != null;
        public bool IsLocal => area != null;
        public Texture2D WeatherMap => weatherMap;

        public MapWeatherRenderer(Camera camera, Transform owner, MapEnvironmentData.WeatherSettings settings)
        {
            this.camera = camera != null ? camera : throw new ArgumentNullException(nameof(camera));
            if (owner == null) throw new ArgumentNullException(nameof(owner));
            this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
            if (settings.MaxRainParticles < 1 || settings.MaxRainParticles > 8192 || settings.MaxSplashParticles < 0 ||
                settings.MaxSplashParticles > 1024 || settings.MaxClouds < 1 || settings.MaxClouds > 512 ||
                settings.RainRate <= 0 || settings.RefreshSeconds < .05f || settings.CloudSpacingHexes <= 0)
                throw new InvalidOperationException("Invalid weather presentation budget.");
            layer = owner.gameObject.layer;
            rainMaterial = NewMaterial("MapWeatherParticle");
            splashMaterial = NewMaterial("MapWeatherParticle"); splashMaterial.SetFloat("_Splash", 1);
            cloudMaterial = NewMaterial("MapWeatherCloud"); cloudMaterial.enableInstancing = true;
            rainParticles = new ParticleSystem.Particle[settings.MaxRainParticles];
            splashParticles = new ParticleSystem.Particle[settings.MaxSplashParticles];
            columns = new Column[settings.MaxRainParticles];
            cloudMatrices = new Matrix4x4[settings.MaxClouds]; cloudTints = new Vector4[settings.MaxClouds];
            cloudSlots = new CloudSlot[settings.MaxClouds];
            rain = CreateParticles(owner, "Weather Rain", rainMaterial, settings.MaxRainParticles, false);
            splashes = CreateParticles(owner, "Weather Splashes", splashMaterial, Mathf.Max(1, settings.MaxSplashParticles), true);
            rainRenderer = rain.GetComponent<ParticleSystemRenderer>(); splashRenderer = splashes.GetComponent<ParticleSystemRenderer>();
            rainRenderer.enabled = splashRenderer.enabled = false;
            cloudMesh = CreateCloudMesh();
            weatherMap = new Texture2D(MapResolution, MapResolution, TextureFormat.RGBA32, false, true) {
                name = "Visible weather field", filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp,
                hideFlags = HideFlags.HideAndDontSave };
            RenderPipelineManager.beginCameraRendering += BeginCamera;
            RenderPipelineManager.endCameraRendering += EndCamera;
        }

        private static Material NewMaterial(string path)
        {
            var shader = Resources.Load<Shader>(path);
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("Weather shader unavailable: " + path);
            return new Material(shader) { name = path + " (session)", hideFlags = HideFlags.HideAndDontSave };
        }
        private static ParticleSystem CreateParticles(Transform owner, string name, Material material, int budget, bool splash)
        {
            var go = new GameObject(name) { hideFlags = HideFlags.DontSave, layer = owner.gameObject.layer };
            go.transform.SetParent(owner, false);
            var system = go.AddComponent<ParticleSystem>();
            system.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            var main = system.main; main.playOnAwake = false; main.maxParticles = budget;
            main.simulationSpace = ParticleSystemSimulationSpace.World; main.startSpeed = 0;
            main.cullingMode = ParticleSystemCullingMode.AlwaysSimulate;
            var emission = system.emission; emission.enabled = false;
            var shape = system.shape; shape.enabled = false;
            var renderer = system.GetComponent<ParticleSystemRenderer>();
            renderer.sharedMaterial = material; renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false; renderer.lightProbeUsage = LightProbeUsage.Off;
            renderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
            renderer.renderMode = splash ? ParticleSystemRenderMode.Billboard : ParticleSystemRenderMode.Stretch;
            renderer.alignment = splash ? ParticleSystemRenderSpace.World : ParticleSystemRenderSpace.View;
            renderer.velocityScale = splash ? 0 : .035f; renderer.lengthScale = 1; renderer.cameraVelocityScale = 0;
            system.Pause(false); // Positions are analytic; Unity must not simulate or catch up culled particles.
            return system;
        }
        public void BindWorld(MapPreviewData map, WorldWeatherField value)
        {
            if (value == null || map == null || value.Seed != map.Seed) throw new ArgumentException("Weather must belong to the displayed world.");
            field = value; surface.SetWorld(map); area = null; preview = null; dirty = true;
            ResetClouds(); Hide();
        }
        public void SetArea(MapAreaViewData value)
        {
            area = value; constructionRevision = -1; surface.SetArea(value); dirty = true; ResetClouds(); Hide();
        }
        public void UpdateConstruction(int revision)
        {
            if (area == null || constructionRevision == revision) return;
            constructionRevision = revision; surface.SetArea(area); dirty = true;
        }
        public void SetContext(double gameMinutes, Vector2 worldOrigin)
        {
            if (double.IsNaN(gameMinutes) || double.IsInfinity(gameMinutes)) throw new ArgumentOutOfRangeException(nameof(gameMinutes));
            if (origin != worldOrigin) dirty = true;
            origin = worldOrigin; minutes = gameMinutes;
        }
        public void SelectPreview(MapEnvironmentData.Weather value) { preview = value; dirty = true; }
        public WeatherSample Sample(float x, float z)
        {
            if (field == null) throw new InvalidOperationException("Bind a world before sampling weather.");
            var sample = field.Sample(area == null ? x : origin.x, area == null ? z : origin.y, minutes);
            return preview == null ? sample : new WeatherSample(preview.Id, preview.Cloud, preview.Rain, sample.WindX, sample.WindZ);
        }
        public void Hide()
        {
            if (active)
                for (int i = 0; i < cloudSlots.Length; i++) cloudSlots[i].Tint.w = 0;
            active = false; dirty = true; RainCount = SplashCount = CloudCount = 0;
            rain.SetParticles(rainParticles, 0); splashes.SetParticles(splashParticles, 0);
        }
        public void Draw(float seconds, Vector3 focus, bool underground)
        {
            if (disposed) throw new ObjectDisposedException(nameof(MapWeatherRenderer));
            if (field == null || underground) { Hide(); return; }
            active = true; visualTime += Mathf.Max(0, seconds); elapsed += Mathf.Max(0, seconds);
            var view = ViewFootprint(focus);
            // A padded field survives ordinary camera movement; teleport/zoom refresh immediately.
            bool moved = (view.center - footprint.center).sqrMagnitude > surface.Radius * surface.Radius * .25f;
            if (dirty || elapsed >= settings.RefreshSeconds && (moved || minutes != lastMinutes) || Math.Abs(minutes - lastMinutes) > 10 || !footprint.Contains(new Vector2(focus.x, focus.z)) ||
                Mathf.Abs(view.width - footprint.width) > Mathf.Max(surface.Radius, footprint.width * .18f))
            {
                footprint = view; elapsed = 0; dirty = false;
                Rebuild(); lastMinutes = minutes; RefreshCount++;
            }
            DrawParticles(focus);
            UpdateClouds(seconds, view, focus);
            if (CloudCount > 0)
                Graphics.DrawMeshInstanced(cloudMesh, 0, cloudMaterial, cloudMatrices, CloudCount, cloudProperties,
                    ShadowCastingMode.Off, false, layer, camera, LightProbeUsage.Off);
        }
        private Rect ViewFootprint(Vector3 focus)
        {
            var min = new Vector2(focus.x, focus.z); var max = min;
            float padding = surface.Radius * 4;
            for (int h = 0; h < 2; h++) for (int i = 0; i < 4; i++)
            {
                var ray = camera.ViewportPointToRay(new Vector3(i % 2, i / 2, 0));
                if (Mathf.Abs(ray.direction.y) < .001f) continue;
                float t = (focus.y + h * surface.Radius * 14 - ray.origin.y) / ray.direction.y;
                if (t < 0) continue;
                var p = ray.GetPoint(t); var point = new Vector2(p.x, p.z);
                min = Vector2.Min(min, point); max = Vector2.Max(max, point);
            }
            return Rect.MinMaxRect(min.x - padding, min.y - padding, max.x + padding, max.y + padding);
        }
        private void Rebuild()
        {
            float width = footprint.width, depth = footprint.height;
            mapRect = new Vector4(footprint.xMin, footprint.yMin, 1 / width, 1 / depth);
            for (int z = 0; z < MapResolution; z++) for (int x = 0; x < MapResolution; x++)
            {
                var sample = Sample(footprint.xMin + (x + .5f) * width / MapResolution, footprint.yMin + (z + .5f) * depth / MapResolution);
                pixels[z * MapResolution + x] = new Color32((byte)(sample.Cloud * 255), (byte)(sample.Rain * 255), 0, 255);
            }
            weatherMap.SetPixels32(pixels); weatherMap.Apply(false, false);
            BuildColumns(); cloudTargetsDirty = true;
        }
        private void BuildColumns()
        {
            columnCount = 0;
            int target = Mathf.Min(columns.Length, Mathf.CeilToInt(settings.RainRate * .9f));
            // A fixed world lattice wraps into the visible rectangle. Panning does not drag existing rain.
            float spacing = Mathf.Max(surface.Radius * .18f, Mathf.Sqrt(footprint.width * footprint.height / target));
            int nx = Mathf.Max(1, Mathf.FloorToInt(footprint.width / spacing));
            int nz = Mathf.Max(1, Mathf.Min(target / nx, Mathf.FloorToInt(footprint.height / spacing)));
            nx = Mathf.Min(nx, target);
            int startX = Mathf.FloorToInt(footprint.center.x / spacing) - nx / 2;
            int startZ = Mathf.FloorToInt(footprint.center.y / spacing) - nz / 2;
            for (int z = 0; z < nz; z++) for (int x = 0; x < nx && columnCount < columns.Length; x++)
            {
                int q = startX + x, r = startZ + z;
                float a = Hash(q, r, 7), b = Hash(q, r, 29);
                float px = (q + a) * spacing, pz = (r + b) * spacing;
                if (!surface.TryGet(px, pz, out var height, out var sheltered) || sheltered) continue;
                var sample = Sample(px, pz);
                if (sample.Rain <= .005f) continue;
                var drift = Vector2.ClampMagnitude(new Vector2(sample.WindX, sample.WindZ), 2) * surface.Radius * .35f;
                // Both ends must be outdoors, so wind never sends streaks through an open cutaway roof.
                if (!surface.TryGet(px - drift.x, pz - drift.y, out _, out var covered) || covered) continue;
                columns[columnCount++] = new Column { Ground = new Vector3(px, height, pz), Rain = sample.Rain,
                    Phase = Hash(q, r, 67), Speed = 1.05f + a * .35f, Drift = drift };
            }
        }
        private void DrawParticles(Vector3 focus)
        {
            RainCount = SplashCount = 0;
            float radius = surface.Radius, height = radius * 12;
            float worldPixel = camera.orthographic ? camera.orthographicSize * 2 / Mathf.Max(1, camera.pixelHeight) :
                Vector3.Distance(camera.transform.position, focus) * Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * .5f) * 2 / Mathf.Max(1, camera.pixelHeight);
            float width = Mathf.Clamp(worldPixel * .65f, radius * .018f, radius * .18f);
            bool near = worldPixel < radius * .08f;
            for (int i = 0; i < columnCount; i++)
            {
                var c = columns[i];
                if (c.Phase > c.Rain) continue;
                float phase = Mathf.Repeat(visualTime * c.Speed + c.Phase, 1), elevation = 1 - phase;
                var p = new ParticleSystem.Particle {
                    position = c.Ground + new Vector3(-c.Drift.x * elevation, height * elevation + radius * .03f, -c.Drift.y * elevation),
                    velocity = new Vector3(c.Drift.x, -height, c.Drift.y) * c.Speed,
                    startColor = new Color(.70f, .82f, .94f, (.28f + c.Rain * .32f) * Mathf.Clamp01((c.Rain - c.Phase) * 12)), startSize = width,
                    startLifetime = 1000, remainingLifetime = 1000, randomSeed = (uint)(i + 1) };
                rainParticles[RainCount++] = p;
                if (!near || SplashCount >= splashParticles.Length) continue;
                float splashPhase = Mathf.Repeat(visualTime * 2.3f + c.Phase * 13, 1);
                if (splashPhase > .45f) continue;
                splashParticles[SplashCount++] = new ParticleSystem.Particle {
                    position = c.Ground + Vector3.up * radius * .025f,
                    rotation3D = new Vector3(90, 0, 0), startSize = radius * (.12f + splashPhase * .55f),
                    startColor = new Color(.65f, .78f, .88f, (1 - splashPhase / .45f) * .4f),
                    startLifetime = 1000, remainingLifetime = 1000, randomSeed = (uint)(i + 1) };
            }
            rain.SetParticles(rainParticles, RainCount); splashes.SetParticles(splashParticles, SplashCount);
        }
        private void ResetClouds()
        {
            Array.Clear(cloudSlots, 0, cloudSlots.Length);
            cloudTravelX = cloudTravelZ = 0; cloudElapsed = cloudSpacing = 0;
            cloudVelocity = Vector2.zero; cloudSpacingReset = false; cloudTargetsDirty = true;
        }
        private float DesiredCloudSpacing(Rect view)
        {
            // Reserve a quarter of the fixed pool for clouds fading out while new edge cells enter.
            int target = Mathf.Max(1, cloudSlots.Length * 3 / 4);
            return Mathf.Max(surface.Radius * settings.CloudSpacingHexes, Mathf.Sqrt(view.width * view.height / target) * 1.1f);
        }
        private void RefreshCloudTargets(Rect view, Vector3 focus)
        {
            float radius = surface.Radius;
            var centerWeather = Sample(focus.x, focus.z);
            // Display speed is radius-scaled and bounded, with the authoritative wind direction.
            // Narrative minutes select weather, never a cloud's position or animation delta.
            cloudVelocity = Vector2.ClampMagnitude(new Vector2(centerWeather.WindX, centerWeather.WindZ), 2) * radius * .35f;
            float desiredSpacing = DesiredCloudSpacing(view);
            if (cloudSpacing <= 0) cloudSpacing = desiredSpacing;
            if (desiredSpacing > cloudSpacing * 1.3f || desiredSpacing < cloudSpacing * .7f) cloudSpacingReset = true;
            bool occupied = false;
            for (int i = 0; i < cloudSlots.Length; i++)
            {
                ref var slot = ref cloudSlots[i];
                slot.Desired = false;
                if (!slot.Occupied) continue;
                slot.TargetTint.w = 0;
                // Fully offscreen clouds can be reclaimed immediately after a camera teleport.
                float margin = cloudSpacing * 2;
                if (slot.Position.x < view.xMin - margin || slot.Position.x > view.xMax + margin ||
                    slot.Position.z < view.yMin - margin || slot.Position.z > view.yMax + margin)
                { slot.Occupied = false; continue; }
                occupied = true;
            }
            // Changing the lattice spacing would move every cloud. Fade the old lattice out first.
            if (cloudSpacingReset)
            {
                if (occupied) return;
                cloudSpacing = desiredSpacing; cloudSpacingReset = false;
            }
            int target = Mathf.Max(1, cloudSlots.Length * 3 / 4);
            int nx = Mathf.Min(target, Mathf.Max(1, Mathf.FloorToInt(view.width / cloudSpacing)));
            int nz = Mathf.Max(1, Mathf.Min(target / nx, Mathf.FloorToInt(view.height / cloudSpacing)));
            long startX = (long)Math.Floor((view.center.x - cloudTravelX) / cloudSpacing) - nx / 2;
            long startZ = (long)Math.Floor((view.center.y - cloudTravelZ) / cloudSpacing) - nz / 2;
            for (int z = 0; z < nz; z++) for (int x = 0; x < nx; x++)
            {
                long q = startX + x, r = startZ + z;
                int idX = unchecked((int)q), idZ = unchecked((int)r);
                double baseX = (q + Hash(idX, idZ, 91) * .6) * cloudSpacing;
                double baseZ = (r + Hash(idX, idZ, 103) * .6) * cloudSpacing;
                float px = (float)(baseX + cloudTravelX), pz = (float)(baseZ + cloudTravelZ);
                if (!surface.TryGet(px, pz, out var ground, out _)) continue;
                var sample = Sample(px, pz);
                float density = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(.12f, .82f, sample.Cloud));
                float height = Mathf.Max(surface.Bounds.center.y + radius * (11 + Hash(idX, idZ, 149) * 4), ground + radius * 3);
                var color = Color.Lerp(new Color(.87f, .92f, 1), new Color(.35f, .43f, .53f), sample.Rain);
                int index = -1, available = -1;
                // This bounded scan runs only at target refresh (96 slots by default), never per frame.
                for (int i = 0; i < cloudSlots.Length; i++)
                {
                    if (cloudSlots[i].Occupied && cloudSlots[i].X == q && cloudSlots[i].Z == r) { index = i; break; }
                    if (!cloudSlots[i].Occupied && available < 0) available = i;
                }
                if (index < 0)
                {
                    if (available < 0) continue;
                    index = available;
                    cloudSlots[index] = new CloudSlot {
                        Occupied = true, X = q, Z = r, BaseX = baseX, BaseZ = baseZ, Position = new Vector3(px, height, pz),
                        Scale = Mathf.Min(cloudSpacing, radius * 14) * (.70f + Hash(idX, idZ, 139) * .35f),
                        Rotation = Quaternion.Euler(0, Hash(idX, idZ, 157) * 360, 0), Tint = new Vector4(color.r, color.g, color.b, 0) };
                }
                ref var slot = ref cloudSlots[index];
                slot.Desired = true; slot.TargetHeight = height;
                slot.TargetTint = new Vector4(color.r, color.g, color.b, density * (area == null ? .32f : .20f));
            }
        }
        private void UpdateClouds(float seconds, Rect view, Vector3 focus)
        {
            // No catch-up teleport after a suspended frame; a paused game clock still permits visual wind.
            float delta = Mathf.Clamp(seconds, 0, .1f);
            cloudTravelX += cloudVelocity.x * delta; cloudTravelZ += cloudVelocity.y * delta;
            cloudElapsed += delta;
            if (cloudTargetsDirty || cloudElapsed >= settings.RefreshSeconds)
            {
                RefreshCloudTargets(view, focus); cloudElapsed = 0; cloudTargetsDirty = false;
            }
            CloudCount = 0;
            GeometryUtility.CalculateFrustumPlanes(camera, planes);
            float blend = 1 - Mathf.Exp(-delta * 4);
            for (int i = 0; i < cloudSlots.Length; i++)
            {
                ref var slot = ref cloudSlots[i];
                if (!slot.Occupied) continue;
                slot.Tint = Vector4.Lerp(slot.Tint, slot.TargetTint, blend);
                slot.Position = new Vector3((float)(slot.BaseX + cloudTravelX), Mathf.Lerp(slot.Position.y, slot.TargetHeight, blend), (float)(slot.BaseZ + cloudTravelZ));
                if (!slot.Desired && slot.Tint.w < .001f) { slot.Occupied = false; continue; }
                float edge = Mathf.Min(Mathf.Min(slot.Position.x - view.xMin, view.xMax - slot.Position.x), Mathf.Min(slot.Position.z - view.yMin, view.yMax - slot.Position.z));
                var tint = slot.Tint; tint.w *= Mathf.Clamp01(edge / cloudSpacing);
                if (tint.w < .001f || !GeometryUtility.TestPlanesAABB(planes, new Bounds(slot.Position, new Vector3(slot.Scale * 3, surface.Radius * 5, slot.Scale * 2)))) continue;
                cloudMatrices[CloudCount] = Matrix4x4.TRS(slot.Position, slot.Rotation, new Vector3(slot.Scale, surface.Radius * 2, slot.Scale * .72f));
                cloudTints[CloudCount++] = tint;
            }
            // Only bounded instance data changes per frame. The 32x32 weather texture is untouched here.
            cloudProperties.SetVectorArray(TintId, cloudTints);
        }
        private void BeginCamera(ScriptableRenderContext context, Camera renderingCamera)
        {
            if (renderingCamera != camera || disposed) return;
            rainRenderer.enabled = active && RainCount > 0; splashRenderer.enabled = active && SplashCount > 0;
            previousMap = Shader.GetGlobalTexture(MapId); previousRect = Shader.GetGlobalVector(RectId); previousEnabled = Shader.GetGlobalFloat(EnabledId);
            Shader.SetGlobalTexture(MapId, weatherMap); Shader.SetGlobalVector(RectId, mapRect);
            // Local areas already modulate their single outdoor sun; world maps use spatial attenuation.
            Shader.SetGlobalFloat(EnabledId, active && area == null ? 1 : 0); globalsInstalled = true;
        }
        private void EndCamera(ScriptableRenderContext context, Camera renderingCamera)
        {
            if (renderingCamera != camera) return;
            rainRenderer.enabled = splashRenderer.enabled = false; RestoreGlobals();
        }
        private void RestoreGlobals()
        {
            if (!globalsInstalled) return;
            Shader.SetGlobalTexture(MapId, previousMap); Shader.SetGlobalVector(RectId, previousRect); Shader.SetGlobalFloat(EnabledId, previousEnabled);
            globalsInstalled = false;
        }
        private static float Hash(int x, int z, uint salt)
        {
            unchecked { uint h = (uint)x * 374761393u + (uint)z * 668265263u + salt; h = (h ^ (h >> 13)) * 1274126177u; return ((h ^ (h >> 16)) & 0xffffff) / 16777216f; }
        }
        private static Mesh CreateCloudMesh()
        {
            const int rings = 6, sides = 10, lobes = 3;
            var vertices = new Vector3[(rings + 1) * (sides + 1) * lobes]; var normals = new Vector3[vertices.Length];
            var indices = new int[rings * sides * 6 * lobes]; int v = 0, t = 0;
            for (int l = 0; l < lobes; l++)
            {
                int start = v; float size = l == 1 ? .72f : .55f;
                var center = new Vector3((l - 1) * .55f, l == 1 ? .15f : -.08f, l == 2 ? .10f : 0);
                for (int y = 0; y <= rings; y++) for (int x = 0; x <= sides; x++)
                {
                    float a = y * Mathf.PI / rings, b = x * Mathf.PI * 2 / sides;
                    var n = new Vector3(Mathf.Sin(a) * Mathf.Cos(b), Mathf.Cos(a), Mathf.Sin(a) * Mathf.Sin(b));
                    normals[v] = n; vertices[v++] = center + n * size;
                }
                for (int y = 0; y < rings; y++) for (int x = 0; x < sides; x++)
                {
                    int a = start + y * (sides + 1) + x, b = a + sides + 1;
                    indices[t++] = a; indices[t++] = a + 1; indices[t++] = b;
                    indices[t++] = a + 1; indices[t++] = b + 1; indices[t++] = b;
                }
            }
            var mesh = new Mesh { name = "Weather cloud lobes", hideFlags = HideFlags.HideAndDontSave };
            mesh.vertices = vertices; mesh.normals = normals; mesh.triangles = indices; mesh.RecalculateBounds(); mesh.UploadMeshData(true); return mesh;
        }
        public void Dispose()
        {
            if (disposed) return;
            disposed = true; RestoreGlobals();
            RenderPipelineManager.beginCameraRendering -= BeginCamera; RenderPipelineManager.endCameraRendering -= EndCamera;
            Release(rain.gameObject); Release(splashes.gameObject); Release(rainMaterial); Release(splashMaterial);
            Release(cloudMaterial); Release(cloudMesh); Release(weatherMap); field = null;
        }
        private static void Release(Object value) { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); }
    }
}
