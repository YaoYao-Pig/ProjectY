using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    // 一个地图观察器拥有一份水纹贴图和一个水花系统，不给每个水格挂组件。
    public sealed class MapWaterEffects : IDisposable
    {
        private sealed class Source
        {
            public Vector3 Position, Direction;
            public float Rate, Strength, Accumulator, Drop, Phase;
        }
        private sealed class Bucket
        {
            public Bounds Bounds;
            public readonly List<Source> Sources = new List<Source>();
        }
        private const int VisibleSourceLimit = 32;
        private readonly Dictionary<Vector2Int, Bucket> buckets = new Dictionary<Vector2Int, Bucket>();
        private readonly List<Source> visibleSources = new List<Source>(VisibleSourceLimit);
        private readonly float[] sourceScores = new float[VisibleSourceLimit];
        private readonly Plane[] frustum = new Plane[6];
        private readonly Texture2D flowTexture;
        private readonly GameObject splashObject;
        private readonly ParticleSystem splashes;
        private readonly Material splashMaterial;
        private System.Random random;
        private float radius, selectionDelay;
        private int emissionCursor;
        private bool visible;

        public Material SurfaceMaterial { get; }
        public Material FoamMaterial { get; }
        public Vector4[] Flows { get; private set; } = Array.Empty<Vector4>();

        public MapWaterEffects(Transform owner)
        {
            // Resources 显式依赖同时保留 Player 构建中的水面 Shader。
            var shader = Resources.Load<Shader>("MapWater");
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("地图水面 Shader 缺失或不受支持。");
            flowTexture = CreateFlowTexture();
            SurfaceMaterial = new Material(shader) { name = "地图_动态水面", enableInstancing = true };
            SurfaceMaterial.SetTexture("_FlowTex", flowTexture);
            FoamMaterial = CreateTransparentMaterial("地图_落水泡沫", 2);
            splashMaterial = CreateTransparentMaterial("地图_飞溅水滴", 3);
            splashMaterial.color = Color.white;
            splashObject = new GameObject("地图水花", typeof(ParticleSystem));
            splashObject.transform.SetParent(owner, false);
            splashes = splashObject.GetComponent<ParticleSystem>();
            splashes.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            var main = splashes.main;
            main.playOnAwake = false;
            main.loop = true;
            main.duration = 5;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.cullingMode = ParticleSystemCullingMode.AlwaysSimulate;
            main.maxParticles = 768;
            main.startSize3D = true;
            main.startSpeed = 0;
            main.gravityModifier = 0;
            var emission = splashes.emission; emission.enabled = false;
            var shape = splashes.shape; shape.enabled = false;
            var color = splashes.colorOverLifetime; color.enabled = true;
            var gradient = new Gradient();
            gradient.SetKeys(new[] { new GradientColorKey(Color.white, 0), new GradientColorKey(Color.white, 1) },
                new[] { new GradientAlphaKey(0, 0), new GradientAlphaKey(.85f, .12f), new GradientAlphaKey(0, 1) });
            color.color = gradient;
            var size = splashes.sizeOverLifetime; size.enabled = true;
            size.size = new ParticleSystem.MinMaxCurve(1, AnimationCurve.Linear(0, 1, 1, .3f));
            splashes.useAutoRandomSeed = false;
            splashes.randomSeed = 173;
            var renderer = splashObject.GetComponent<ParticleSystemRenderer>();
            renderer.sharedMaterial = splashMaterial;
            renderer.renderMode = ParticleSystemRenderMode.Billboard;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            renderer.lightProbeUsage = LightProbeUsage.Off;
            renderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
            splashObject.SetActive(false);
        }

        private Material CreateTransparentMaterial(string name, int mode)
        {
            var result = new Material(SurfaceMaterial) { name = name, enableInstancing = false, renderQueue = 3000 };
            result.SetFloat("_WaterMode", mode);
            result.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
            result.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
            result.SetInt("_ZWrite", 0);
            result.SetOverrideTag("RenderType", "Transparent");
            result.SetShaderPassEnabled("DepthOnly", false);
            result.SetShaderPassEnabled("DepthNormals", false);
            return result;
        }

        private static Texture2D CreateFlowTexture()
        {
            const int size = 128;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, true, true) {
                name = "地图_可平铺分层水纹", wrapMode = TextureWrapMode.Repeat,
                filterMode = FilterMode.Trilinear, anisoLevel = 2
            };
            var pixels = new Color[size * size];
            var textureRandom = new System.Random(19373);
            // 各通道使用独立随机格点，周期插值保持平铺连续，避免正弦谐波形成整齐斜线。
            var frequencies = new[] { 5, 11, 23, 47 };
            var weights = new[] { .55f, .27f, .13f, .05f };
            for (var channel = 0; channel < 4; channel++)
                for (var octave = 0; octave < frequencies.Length; octave++)
                {
                    var frequency = frequencies[octave];
                    var lattice = new float[frequency * frequency];
                    for (var i = 0; i < lattice.Length; i++) lattice[i] = (float)textureRandom.NextDouble();
                    for (var y = 0; y < size; y++)
                        for (var x = 0; x < size; x++)
                        {
                            var px = x * (frequency / (float)size); var py = y * (frequency / (float)size);
                            var ix = Mathf.FloorToInt(px); var iy = Mathf.FloorToInt(py);
                            var fx = px - ix; var fy = py - iy;
                            fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
                            var nx = (ix + 1) % frequency; var ny = (iy + 1) % frequency;
                            var value = Mathf.Lerp(Mathf.Lerp(lattice[iy * frequency + ix], lattice[iy * frequency + nx], fx),
                                Mathf.Lerp(lattice[ny * frequency + ix], lattice[ny * frequency + nx], fx), fy);
                            var pixel = pixels[y * size + x]; pixel[channel] += value * weights[octave]; pixels[y * size + x] = pixel;
                        }
                }
            for (var y = 0; y < size; y++)
                for (var x = 0; x < size; x++)
                {
                    var pixel = pixels[y * size + x];
                    for (var channel = 0; channel < 4; channel++) pixel[channel] = Mathf.Clamp01(.5f + (pixel[channel] - .5f) * 1.65f);
                    pixels[y * size + x] = pixel;
                }
            texture.SetPixels(pixels); texture.Apply(true, true);
            return texture;
        }

        public void Build(MapPreviewData map)
        {
            SetVisible(false);
            buckets.Clear(); visibleSources.Clear();
            radius = map.Radius;
            random = new System.Random(unchecked((int)map.Seed));
            SurfaceMaterial.SetFloat("_WaterScale", radius);
            FoamMaterial.SetFloat("_WaterScale", radius);
            splashMaterial.SetFloat("_WaterScale", radius);
            var force = splashes.forceOverLifetime; force.enabled = true;
            force.space = ParticleSystemSimulationSpace.World; force.y = -7 * radius;
            Flows = BuildFlows(map);
            foreach (var cell in map.Cells)
            {
                if (!cell.HasWater) continue;
                var direction = Vector3.zero;
                foreach (var index in cell.Neighbors)
                    if (!map.Cells[index].HasWater) direction += map.Cells[index].Position - cell.Position;
                direction.y = 0;
                var shore = direction.sqrMagnitude > .001f;
                direction = shore ? direction.normalized : new Vector3(.8f, 0, .6f);
                var position = cell.Position + direction * (shore ? .56f * radius : 0);
                position.y = cell.WaterLevel + radius * .025f;
                // 湖心只有稀疏碎浪；水岸和河道的飞溅更明显。
                AddSource(position, -direction, shore ? (cell.IsRiver ? 2.4f : 1.2f) : (cell.IsRiver ? 1.1f : .22f),
                    cell.IsRiver ? .55f : .32f);
            }
            // 每条真实落差都包含下冲水束和落点反弹飞溅，不依赖瀑布标签。
            foreach (var cell in map.Cells)
            {
                if (!cell.HasWater) continue;
                foreach (var index in cell.Neighbors)
                {
                    var lower = map.Cells[index];
                    var drop = cell.WaterLevel - lower.WaterLevel;
                    if (!lower.HasWater || drop < radius * .12f) continue;
                    var direction = lower.Position - cell.Position; direction.y = 0; direction.Normalize();
                    var position = (cell.Position + lower.Position) * .5f + direction * radius * .28f;
                    position.y = lower.WaterLevel + radius * .035f;
                    var strength = Mathf.Clamp(Mathf.Sqrt(drop / radius), .7f, 2.2f);
                    AddSource(position, direction, 38 * strength, strength, drop);
                }
            }
            selectionDelay = 0;
        }

        private static Vector4[] BuildFlows(MapPreviewData map)
        {
            var flows = new Vector4[map.Cells.Length];
            var assigned = new bool[flows.Length];
            var queue = new Queue<int>();
            for (var i = 0; i < flows.Length; i++)
            {
                var cell = map.Cells[i];
                flows[i] = new Vector4(.8f, .6f, cell.IsRiver ? 1 : 0, cell.WaterDepth / map.Radius);
                if (!cell.HasWater || !cell.IsRiver || cell.FlowTo < 0) continue;
                var direction = map.Cells[cell.FlowTo].Position - cell.Position; direction.y = 0;
                if (direction.sqrMagnitude < .0001f) throw new InvalidOperationException("河流下游不能指向自身。");
                direction.Normalize(); flows[i].x = direction.x; flows[i].y = direction.z;
                assigned[i] = true; queue.Enqueue(i);
            }
            // 扩宽河格不一定持有 flowTo，沿同 riverId 传播最近中心线的方向。
            while (queue.Count > 0)
            {
                var current = queue.Dequeue(); var cell = map.Cells[current];
                foreach (var index in cell.Neighbors)
                {
                    var other = map.Cells[index];
                    if (assigned[index] || !other.HasWater || !other.IsRiver || other.RiverId != cell.RiverId) continue;
                    flows[index].x = flows[current].x; flows[index].y = flows[current].y;
                    assigned[index] = true; queue.Enqueue(index);
                }
            }
            return flows;
        }

        private void AddSource(Vector3 position, Vector3 direction, float rate, float strength, float drop = 0)
        {
            var key = new Vector2Int(Mathf.FloorToInt(position.x / (radius * 12)), Mathf.FloorToInt(position.z / (radius * 12)));
            if (!buckets.TryGetValue(key, out var bucket))
            {
                bucket = new Bucket { Bounds = new Bounds(position, Vector3.one * radius * 2) };
                buckets.Add(key, bucket);
            }
            var bounds = bucket.Bounds; bounds.Encapsulate(new Bounds(position, Vector3.one * radius * 2)); bucket.Bounds = bounds;
            bucket.Sources.Add(new Source { Position = position, Direction = direction, Rate = rate,
                Strength = strength, Accumulator = (float)random.NextDouble(), Drop = drop,
                Phase = (float)random.NextDouble() * Mathf.PI * 2 });
            bounds = bucket.Bounds;
            bounds.Encapsulate(position + Vector3.up * (drop + radius)); bucket.Bounds = bounds;
        }

        public void SetVisible(bool value)
        {
            if (visible == value) return;
            visible = value;
            if (!visible) splashes.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            splashObject.SetActive(visible);
            if (visible) { selectionDelay = 0; splashes.Play(); }
        }

        public void Tick(Camera camera, float deltaTime)
        {
            if (!visible) return;
            selectionDelay -= deltaTime;
            if (selectionDelay <= 0)
            {
                SelectSources(camera);
                selectionDelay = .35f;
            }
            // 总图缩小时纹理动画仍运行，水滴小于像素后不再发射。
            var budget = 64;
            for (var i = 0; i < visibleSources.Count; i++)
            {
                var source = visibleSources[(emissionCursor + i) % visibleSources.Count];
                var pulse = source.Drop > 0 ? .8f + .45f * Mathf.Sin(Time.time * 8.3f + source.Phase) : 1;
                source.Accumulator = Mathf.Min(6, source.Accumulator + Mathf.Min(deltaTime, .05f) * source.Rate * pulse);
                while (source.Accumulator >= 1 && budget > 0)
                {
                    source.Accumulator -= 1; budget--;
                    Emit(source);
                }
            }
            emissionCursor = (emissionCursor + 1) % Mathf.Max(1, visibleSources.Count);
        }

        private void Emit(Source source)
        {
            var along = source.Direction;
            var side = Vector3.Cross(Vector3.up, along);
            var lateral = (float)random.NextDouble() * 2 - 1;
            var variation = (float)random.NextDouble();
            var impact = source.Drop > 0;
            var position = source.Position + side * lateral * radius * (impact ? .43f : .12f);
            Vector3 velocity, size;
            float lifetime, alpha;
            if (impact && random.NextDouble() < .42)
            {
                // 快速下落的长水滴先砸向水潭，再由同一个源发射向外反弹的水花。
                var height = source.Drop * (.45f + .5f * variation);
                position += Vector3.up * height - along * radius * .14f;
                var speed = Mathf.Sqrt(14 * radius * source.Drop) * (.7f + variation * .3f);
                velocity = Vector3.down * speed + along * radius * .1f;
                lifetime = (Mathf.Sqrt(speed * speed + 14 * radius * height) - speed) / (7 * radius);
                size = new Vector3(.06f, .18f + .11f * variation, .06f) * radius;
                alpha = .75f;
            }
            else
            {
                var speed = radius * (impact ? 1.5f + .65f * source.Strength + variation * .8f : .65f + variation * .35f);
                velocity = Vector3.up * speed + along * radius * (impact ? .55f + variation * .4f : .14f)
                    + side * lateral * radius * (impact ? .85f : .1f);
                lifetime = 2 * speed / (7 * radius);
                var diameter = radius * (impact ? .075f + variation * .055f : .035f + variation * .02f);
                size = new Vector3(diameter, diameter * (impact ? 1.7f : 1), diameter);
                alpha = impact ? .92f : .75f;
                if (impact && variation > .8f) { size = Vector3.one * radius * .2f; alpha = .32f; }
            }
            var parameters = new ParticleSystem.EmitParams {
                position = position, velocity = velocity, startLifetime = lifetime, startSize3D = size,
                startColor = new Color(.86f, .97f, 1, alpha), applyShapeToPosition = false
            };
            splashes.Emit(parameters, 1);
        }

        private void SelectSources(Camera camera)
        {
            visibleSources.Clear();
            if (camera.orthographic && camera.orthographicSize > radius * 42) return;
            GeometryUtility.CalculateFrustumPlanes(camera, frustum);
            var minimumPixels = 2f / Mathf.Max(1, camera.pixelHeight);
            foreach (var bucket in buckets.Values)
            {
                if (!GeometryUtility.TestPlanesAABB(frustum, bucket.Bounds)) continue;
                foreach (var source in bucket.Sources)
                {
                    var focus = source.Position;
                    if (source.Drop > 0)
                    {
                        // 放大看水幕上半段时，下冲水束不能因潭面落点出屏而消失。
                        focus += Vector3.up * source.Drop * .5f;
                        var bounds = new Bounds(focus, new Vector3(radius * 1.4f, source.Drop + radius * 1.2f, radius * 1.4f));
                        if (!GeometryUtility.TestPlanesAABB(frustum, bounds)) continue;
                    }
                    var viewport = camera.WorldToViewportPoint(focus);
                    if (viewport.z <= 0) continue;
                    if (source.Drop <= 0 && (viewport.x < 0 || viewport.x > 1 || viewport.y < 0 || viewport.y > 1)) continue;
                    viewport.x = Mathf.Clamp01(viewport.x); viewport.y = Mathf.Clamp01(viewport.y);
                    if (!camera.orthographic && radius * (source.Drop > 0 ? .12f : .065f) / (2 * viewport.z * Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * .5f)) < minimumPixels) continue;
                    var score = (new Vector2(viewport.x - .5f, viewport.y - .5f).sqrMagnitude + .035f)
                        / (source.Strength * (source.Drop > 0 ? 3 : 1));
                    var index = visibleSources.Count;
                    if (index == VisibleSourceLimit)
                    {
                        var worst = 0;
                        for (var i = 1; i < VisibleSourceLimit; i++) if (sourceScores[i] > sourceScores[worst]) worst = i;
                        if (score >= sourceScores[worst]) continue;
                        index = worst; visibleSources[index] = source;
                    }
                    else visibleSources.Add(source);
                    sourceScores[index] = score;
                }
            }
        }

        public void Dispose()
        {
            splashes.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            Release(splashObject); Release(splashMaterial); Release(FoamMaterial); Release(SurfaceMaterial); Release(flowTexture);
            buckets.Clear(); visibleSources.Clear(); Flows = Array.Empty<Vector4>();
        }

        private static void Release(Object value)
        {
            if (value == null) return;
            if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value);
        }
    }
}
