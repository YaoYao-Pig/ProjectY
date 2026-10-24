using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ProjectY.Samples
{
    public sealed class BlockEffectProfile
    {
        public int Id, Count;
        public string Name, Pattern;
        public Color Color, Accent;
        public float Lifetime, Size, Radius, Height, Emission, Speed, Gravity;
    }

    /// <summary>Session-owned, bounded cube particles. Only the host's Tick advances time.</summary>
    public sealed class BlockParticleEffects : IDisposable
    {
        public const int MaximumSystems = 32;
        public const int MaximumParticles = 1024;
        public const int MaximumParticlesPerEffect = 64;
        public const int MaximumGlobalParticles = 4096;
        // ParticleSystem stores Color32. Encode linear HDR radiance in its vertex color,
        // then decode by the same constant in Resources/Rendering/BlockParticle.shader.
        private const float HdrColorRange = 8f;
        private const float Tau = Mathf.PI * 2f;
        private static Mesh sharedCube;
        private static Material sharedMaterial;
        private static int resourceOwners, globalParticleCount;
        private readonly Transform root;
        private readonly Mesh cube;
        private readonly Material material;
        private readonly Slot[] slots = new Slot[MaximumSystems];
        private readonly int layer;
        private readonly bool linearColor;
        private readonly bool followTransform;
        private Matrix4x4 previousWorldToLocal;
        private int activeParticleCount;
        private bool disposed;

        private enum Pattern
        {
            Slash, Thrust, Burst, Ring, Shield, Spiral, Beam, Arc,
            Rain, Cross, Column, Scatter, Rune, Shards, Tether, Footprint
        }

        private struct ParticleState
        {
            public Vector3 Position, Velocity, Acceleration, Rotation, Spin;
            public float Age, Lifetime, Size;
            public Color32 Color;
        }

        private sealed class Slot
        {
            public ParticleSystem System;
            public readonly ParticleState[] States = new ParticleState[MaximumParticlesPerEffect];
            public readonly ParticleSystem.Particle[] Particles = new ParticleSystem.Particle[MaximumParticlesPerEffect];
            public int Count;
        }

        public bool Busy => activeParticleCount > 0;
        public int ActiveParticleCount => activeParticleCount;
        public static int ActiveGlobalParticleCount => globalParticleCount;

        public BlockParticleEffects(Transform parent, int layer = 0, bool followTransform = false)
        {
            if (parent == null) throw new ArgumentNullException(nameof(parent));
            if (layer < 0 || layer > 31) throw new ArgumentOutOfRangeException(nameof(layer));
            this.layer = layer;
            this.followTransform = followTransform;
            linearColor = QualitySettings.activeColorSpace == ColorSpace.Linear;
            AcquireSharedResources();
            cube = sharedCube;
            material = sharedMaterial;
            root = new GameObject("BlockParticleEffects") { layer = layer }.transform;
            root.SetParent(parent, false);
            previousWorldToLocal = root.worldToLocalMatrix;
        }

        public void Play(BlockEffectProfile profile, Vector3 origin, Vector3 target, int seed, float scale = 1f)
        {
            ThrowIfDisposed();
            Validate(profile, origin, target, scale);
            var pattern = ParsePattern(profile.Pattern);
            int count = Mathf.Min(Mathf.Min(profile.Count, MaximumParticlesPerEffect),
                Mathf.Min(MaximumParticles - activeParticleCount, MaximumGlobalParticles - globalParticleCount));
            if (count <= 0) return; // Presentation degrades when its fixed budget is exhausted.
            FollowOwner();
            var slot = AcquireSlot();
            if (slot == null) return;
            var random = new System.Random(unchecked(seed * 397 ^ profile.Id));
            Vector3 forward = target - origin;
            forward.y = 0f;
            forward = forward.sqrMagnitude > .0001f ? forward.normalized : Vector3.forward;
            Vector3 right = Vector3.Cross(Vector3.up, forward);
            float radius = profile.Radius * scale, height = profile.Height * scale;
            float speed = profile.Speed * scale;
            // World simulation keeps already emitted particles independent of parent movement.
            slot.System.transform.position = target;
            for (int i = 0; i < count; i++)
            {
                Shape(pattern, i, count, random, origin, target, forward, right,
                    radius, height, speed, out Vector3 position, out Vector3 velocity);
                float tint = i % 4 == 0 ? 1f : Next(random) * .28f;
                var state = new ParticleState
                {
                    Position = position,
                    Velocity = velocity,
                    Rotation = new Vector3(random.Next(4), random.Next(4), random.Next(4)) * 90f,
                    Spin = new Vector3(Signed(random), Signed(random), Signed(random)) * 65f,
                    Lifetime = profile.Lifetime * Mathf.Lerp(.82f, 1f, Next(random)),
                    Size = profile.Size * scale * Mathf.Lerp(.78f, 1.16f, Next(random)),
                    Acceleration = Vector3.down * (profile.Gravity * scale),
                    Color = EncodeColor(Color.Lerp(profile.Color, profile.Accent, tint), profile.Emission)
                };
                // Structured glyphs hold their right angles; fragments may tumble.
                if (pattern == Pattern.Rune || pattern == Pattern.Cross || pattern == Pattern.Shield || pattern == Pattern.Footprint)
                {
                    state.Rotation = new Vector3(0f, Mathf.Atan2(forward.x, forward.z) * Mathf.Rad2Deg, 0f);
                    state.Spin = Vector3.zero;
                }
                slot.States[i] = state;
                slot.Particles[i] = new ParticleSystem.Particle
                {
                    position = state.Position,
                    velocity = Vector3.zero,
                    startLifetime = state.Lifetime,
                    remainingLifetime = state.Lifetime,
                    startSize = state.Size,
                    startColor = state.Color,
                    rotation3D = state.Rotation,
                    randomSeed = (uint)random.Next(1, int.MaxValue)
                };
            }
            slot.Count = count;
            activeParticleCount += count;
            globalParticleCount += count;
            slot.System.SetParticles(slot.Particles, count);
        }

        public void Tick(float deltaTime)
        {
            ThrowIfDisposed();
            if (!Finite(deltaTime) || deltaTime < 0f) throw new ArgumentOutOfRangeException(nameof(deltaTime));
            if (deltaTime == 0f) return;
            FollowOwner();
            if (!Busy) return;
            for (int s = 0; s < slots.Length; s++)
            {
                var slot = slots[s];
                if (slot == null || slot.Count == 0) continue;
                for (int i = 0; i < slot.Count;)
                {
                    var state = slot.States[i];
                    state.Age += deltaTime;
                    if (state.Age >= state.Lifetime)
                    {
                        --slot.Count;
                        --activeParticleCount;
                        --globalParticleCount;
                        slot.States[i] = slot.States[slot.Count];
                        slot.Particles[i] = slot.Particles[slot.Count];
                        continue;
                    }
                    slot.States[i] = state;
                    float progress = state.Age / state.Lifetime;
                    var particle = slot.Particles[i];
                    particle.position = state.Position + state.Velocity * state.Age
                        + state.Acceleration * (.5f * state.Age * state.Age);
                    particle.rotation3D = state.Rotation + state.Spin * state.Age;
                    particle.remainingLifetime = state.Lifetime - state.Age;
                    particle.startSize = state.Size * (1f - .35f * progress);
                    Color32 color = state.Color;
                    color.a = (byte)Mathf.RoundToInt(color.a * Mathf.Clamp01((1f - progress) / .45f));
                    particle.startColor = color;
                    slot.Particles[i] = particle;
                    ++i;
                }
                slot.System.SetParticles(slot.Particles, slot.Count);
            }
        }

        public void Clear()
        {
            ThrowIfDisposed();
            for (int i = 0; i < slots.Length; i++)
            {
                var slot = slots[i];
                if (slot == null) continue;
                slot.Count = 0;
                if (slot.System != null) slot.System.Clear(false);
            }
            globalParticleCount -= activeParticleCount;
            activeParticleCount = 0;
        }

        public void Dispose()
        {
            if (disposed) return;
            // The owner may already have destroyed its parent during scene teardown.
            globalParticleCount -= activeParticleCount;
            activeParticleCount = 0;
            if (root != null)
            {
                root.gameObject.SetActive(false);
                DestroyOwned(root.gameObject);
            }
            ReleaseSharedResources();
            disposed = true;
        }

        private void FollowOwner()
        {
            if (!followTransform) return;
            Matrix4x4 currentWorldToLocal = root.worldToLocalMatrix;
            if (currentWorldToLocal == previousWorldToLocal) return;
            Matrix4x4 delta = root.localToWorldMatrix * previousWorldToLocal;
            previousWorldToLocal = currentWorldToLocal;
            if (!Busy) return;
            Quaternion rotation = delta.rotation;
            float sizeScale = Mathf.Pow(Mathf.Abs(delta.determinant), 1f / 3f);
            for (int s = 0; s < slots.Length; s++)
            {
                var slot = slots[s];
                if (slot == null) continue;
                for (int i = 0; i < slot.Count; i++)
                {
                    var state = slot.States[i];
                    state.Position = delta.MultiplyPoint3x4(state.Position);
                    state.Velocity = delta.MultiplyVector(state.Velocity);
                    state.Acceleration = delta.MultiplyVector(state.Acceleration);
                    state.Rotation = (rotation * Quaternion.Euler(state.Rotation)).eulerAngles;
                    state.Spin = rotation * state.Spin;
                    state.Size *= sizeScale;
                    slot.States[i] = state;
                }
            }
        }

        private static void AcquireSharedResources()
        {
            if (resourceOwners == 0)
            {
                var shader = Resources.Load<Shader>("Rendering/BlockParticle");
                if (shader == null || !shader.isSupported)
                    throw new InvalidOperationException("Block effects require the supported Rendering/BlockParticle Resources shader.");
                sharedCube = CreateCube();
                sharedMaterial = new Material(shader) { name = "Block particle shared material", hideFlags = HideFlags.DontSave };
            }
            ++resourceOwners;
        }

        private static void ReleaseSharedResources()
        {
            if (--resourceOwners != 0) return;
            DestroyOwned(sharedMaterial);
            DestroyOwned(sharedCube);
            sharedMaterial = null;
            sharedCube = null;
        }

        private Slot AcquireSlot()
        {
            for (int i = 0; i < slots.Length; i++)
            {
                if (slots[i] == null) slots[i] = CreateSlot(i);
                if (slots[i].Count == 0) return slots[i];
            }
            return null;
        }

        private Slot CreateSlot(int index)
        {
            var go = new GameObject("Block particle slot " + index) { layer = layer };
            go.SetActive(false);
            go.transform.SetParent(root, false);
            var system = go.AddComponent<ParticleSystem>();
            var main = system.main;
            main.playOnAwake = false;
            main.loop = false;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.scalingMode = ParticleSystemScalingMode.Shape;
            main.simulationSpeed = 0f;
            main.maxParticles = MaximumParticlesPerEffect;
            main.startSpeed = 0f;
            main.startRotation3D = true;
            main.gravityModifier = 0f;
            main.stopAction = ParticleSystemStopAction.None;
            main.cullingMode = ParticleSystemCullingMode.AlwaysSimulate;
            var emission = system.emission;
            emission.enabled = false;
            var shape = system.shape;
            shape.enabled = false;
            system.useAutoRandomSeed = false;
            system.randomSeed = 1;
            var renderer = go.GetComponent<ParticleSystemRenderer>();
            renderer.renderMode = ParticleSystemRenderMode.Mesh;
            renderer.mesh = cube;
            renderer.sharedMaterial = material;
            renderer.alignment = ParticleSystemRenderSpace.World;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            renderer.lightProbeUsage = LightProbeUsage.Off;
            renderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
            renderer.sortMode = ParticleSystemSortMode.Distance;
            renderer.SetActiveVertexStreams(new List<ParticleSystemVertexStream>
            {
                ParticleSystemVertexStream.Position,
                ParticleSystemVertexStream.Normal,
                ParticleSystemVertexStream.Color
            });
            go.SetActive(true);
            system.Pause(false);
            return new Slot { System = system };
        }

        private static void Shape(Pattern pattern, int index, int count, System.Random random,
            Vector3 origin, Vector3 target, Vector3 forward, Vector3 right,
            float radius, float height, float speed, out Vector3 position, out Vector3 velocity)
        {
            float u = (index + .5f) / count;
            float angle = u * Tau;
            Vector3 radial = right * Mathf.Cos(angle) + forward * Mathf.Sin(angle);
            Vector3 tangent = -right * Mathf.Sin(angle) + forward * Mathf.Cos(angle);
            position = target;
            velocity = Vector3.zero;
            switch (pattern)
            {
                case Pattern.Slash:
                    angle = Mathf.Lerp(-2.3f, 2.3f, u);
                    radial = right * Mathf.Sin(angle) + forward * Mathf.Cos(angle);
                    position += radial * radius + Vector3.up * (height * (.35f + .3f * u));
                    velocity = (right * Mathf.Cos(angle) - forward * Mathf.Sin(angle)) * speed;
                    break;
                case Pattern.Thrust:
                    position = Vector3.Lerp(origin, target, u) + Vector3.up * height * .35f;
                    position += right * ((index % 3 - 1) * radius * (1f - u) * .4f);
                    velocity = PathDirection(origin, target, forward) * speed;
                    break;
                case Pattern.Burst:
                    float vertical = Signed(random);
                    radial = radial * Mathf.Sqrt(1f - vertical * vertical) + Vector3.up * vertical;
                    position += Vector3.up * height * .5f + radial * radius * .2f;
                    velocity = radial * speed;
                    break;
                case Pattern.Ring:
                    position += radial * radius + Vector3.up * height * .12f;
                    velocity = radial * speed * .45f + Vector3.up * speed * .12f;
                    break;
                case Pattern.Shield:
                    Vector2 edge = SquareEdge(u);
                    float band = index % 3 == 0 ? .6f : 1f;
                    position += right * edge.x * radius * band
                        + Vector3.up * height * (.5f + edge.y * .45f * band);
                    velocity = forward * speed * .12f;
                    break;
                case Pattern.Spiral:
                    angle = u * Tau * 2.5f;
                    radial = right * Mathf.Cos(angle) + forward * Mathf.Sin(angle);
                    tangent = -right * Mathf.Sin(angle) + forward * Mathf.Cos(angle);
                    position += radial * radius * (.35f + .65f * u) + Vector3.up * height * u;
                    velocity = tangent * speed * .45f + Vector3.up * speed * .3f;
                    break;
                case Pattern.Beam:
                    position = Vector3.Lerp(origin, target, u) + Vector3.up * height * .35f;
                    position += (right * (index % 2 == 0 ? 1f : -1f)
                        + Vector3.up * (index % 4 < 2 ? 1f : -1f)) * radius * .16f;
                    velocity = PathDirection(origin, target, forward) * speed * .2f;
                    break;
                case Pattern.Arc:
                    position = Vector3.Lerp(origin, target, u) + Vector3.up * (4f * u * (1f - u) * height);
                    velocity = (PathDirection(origin, target, forward) + Vector3.up * (1f - 2f * u)) * speed * .25f;
                    break;
                case Pattern.Rain:
                    position += right * Signed(random) * radius + forward * Signed(random) * radius;
                    position += Vector3.up * height * Mathf.Lerp(.6f, 1.2f, Next(random));
                    velocity = Vector3.down * speed + forward * speed * .12f;
                    break;
                case Pattern.Cross:
                    position += (index % 2 == 0 ? right : forward) * ((u * 2f - 1f) * radius);
                    position += Vector3.up * height * .15f;
                    velocity = Vector3.up * speed * .2f;
                    break;
                case Pattern.Column:
                    Vector2 corner = new Vector2(index % 4 < 2 ? -1f : 1f, index % 2 == 0 ? -1f : 1f);
                    position += (right * corner.x + forward * corner.y) * radius * .55f + Vector3.up * height * u;
                    velocity = Vector3.up * speed;
                    break;
                case Pattern.Scatter:
                    position += radial * radius * Mathf.Sqrt(Next(random)) + Vector3.up * height * Next(random);
                    velocity = radial * speed * Mathf.Lerp(.3f, 1f, Next(random)) + Vector3.up * speed * .35f;
                    break;
                case Pattern.Rune:
                    Vector2 glyph = SquareEdge(u);
                    if (index % 3 == 0) glyph *= .5f;
                    position += (right * glyph.x + forward * glyph.y) * radius + Vector3.up * height * .1f;
                    velocity = Vector3.up * speed * .08f;
                    break;
                case Pattern.Shards:
                    position += radial * radius * Next(random) * .55f + Vector3.up * height * .15f;
                    velocity = radial * speed * .75f + Vector3.up * speed * Mathf.Lerp(.35f, 1.2f, Next(random));
                    break;
                case Pattern.Tether:
                    Vector3 path = PathDirection(origin, target, forward);
                    Vector3 pathUp = Vector3.Cross(path, right).normalized;
                    angle = u * Tau * 3f + (index % 2) * Mathf.PI;
                    position = Vector3.Lerp(origin, target, u) + Vector3.up * height * .3f;
                    position += (right * Mathf.Cos(angle) + pathUp * Mathf.Sin(angle)) * radius * .35f;
                    velocity = path * speed * .15f;
                    break;
                case Pattern.Footprint:
                    Vector2 sole = SquareEdge((index / 2 + .5f) / Mathf.Max(1, (count + 1) / 2));
                    float side = index % 2 == 0 ? -1f : 1f;
                    position += right * radius * (side * .45f + sole.x * .2f)
                        + forward * radius * (sole.y * .45f + side * .25f) + Vector3.up * height * .08f;
                    velocity = Vector3.up * speed * .1f;
                    break;
            }
        }

        private Color32 EncodeColor(Color color, float emission)
        {
            if (linearColor) color = color.linear;
            float gain = emission / HdrColorRange;
            return new Color(color.r * gain, color.g * gain, color.b * gain, color.a);
        }

        private static Vector2 SquareEdge(float u)
        {
            float edge = Mathf.Repeat(u, 1f) * 4f;
            if (edge < 1f) return new Vector2(-1f + edge * 2f, -1f);
            if (edge < 2f) return new Vector2(1f, -1f + (edge - 1f) * 2f);
            if (edge < 3f) return new Vector2(1f - (edge - 2f) * 2f, 1f);
            return new Vector2(-1f, 1f - (edge - 3f) * 2f);
        }

        private static Vector3 PathDirection(Vector3 origin, Vector3 target, Vector3 fallback)
        {
            Vector3 direction = target - origin;
            return direction.sqrMagnitude > .0001f ? direction.normalized : fallback;
        }

        private static float Next(System.Random random) => (float)random.NextDouble();
        private static float Signed(System.Random random) => Next(random) * 2f - 1f;
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private static bool Finite(Vector3 value) => Finite(value.x) && Finite(value.y) && Finite(value.z);

        private static void Validate(BlockEffectProfile profile, Vector3 origin, Vector3 target, float scale)
        {
            if (profile == null) throw new ArgumentNullException(nameof(profile));
            if (!Finite(origin) || !Finite(target)) throw new ArgumentException("Effect positions must be finite.");
            if (!Finite(scale) || scale <= 0f) throw new ArgumentOutOfRangeException(nameof(scale));
            if (profile.Count <= 0 || !Finite(profile.Lifetime) || profile.Lifetime <= 0f
                || !Finite(profile.Size) || profile.Size <= 0f || !Finite(profile.Radius) || profile.Radius < 0f
                || !Finite(profile.Height) || profile.Height < 0f || !Finite(profile.Emission)
                || profile.Emission < 0f || profile.Emission > HdrColorRange
                || !Finite(profile.Speed) || profile.Speed < 0f || !Finite(profile.Gravity)
                || !ValidColor(profile.Color) || !ValidColor(profile.Accent))
                throw new ArgumentException("Invalid block effect profile " + profile.Id + " (" + profile.Name + ").", nameof(profile));
        }

        private static bool ValidColor(Color color)
        {
            return Finite(color.r) && color.r >= 0f && color.r <= 1f
                && Finite(color.g) && color.g >= 0f && color.g <= 1f
                && Finite(color.b) && color.b >= 0f && color.b <= 1f
                && Finite(color.a) && color.a >= 0f && color.a <= 1f;
        }

        private static Pattern ParsePattern(string pattern)
        {
            switch (pattern)
            {
                case "slash": return Pattern.Slash;
                case "thrust": return Pattern.Thrust;
                case "burst": return Pattern.Burst;
                case "ring": return Pattern.Ring;
                case "shield": return Pattern.Shield;
                case "spiral": return Pattern.Spiral;
                case "beam": return Pattern.Beam;
                case "arc": return Pattern.Arc;
                case "rain": return Pattern.Rain;
                case "cross": return Pattern.Cross;
                case "column": return Pattern.Column;
                case "scatter": return Pattern.Scatter;
                case "rune": return Pattern.Rune;
                case "shards": return Pattern.Shards;
                case "tether": return Pattern.Tether;
                case "footprint": return Pattern.Footprint;
                default: throw new ArgumentException("Unknown block effect pattern: " + pattern, nameof(pattern));
            }
        }

        private static Mesh CreateCube()
        {
            var mesh = new Mesh { name = "Block particle cube", hideFlags = HideFlags.DontSave };
            mesh.vertices = new[]
            {
                new Vector3(-.5f,-.5f,.5f), new Vector3(.5f,-.5f,.5f), new Vector3(.5f,.5f,.5f), new Vector3(-.5f,.5f,.5f),
                new Vector3(.5f,-.5f,-.5f), new Vector3(-.5f,-.5f,-.5f), new Vector3(-.5f,.5f,-.5f), new Vector3(.5f,.5f,-.5f),
                new Vector3(.5f,-.5f,.5f), new Vector3(.5f,-.5f,-.5f), new Vector3(.5f,.5f,-.5f), new Vector3(.5f,.5f,.5f),
                new Vector3(-.5f,-.5f,-.5f), new Vector3(-.5f,-.5f,.5f), new Vector3(-.5f,.5f,.5f), new Vector3(-.5f,.5f,-.5f),
                new Vector3(-.5f,.5f,.5f), new Vector3(.5f,.5f,.5f), new Vector3(.5f,.5f,-.5f), new Vector3(-.5f,.5f,-.5f),
                new Vector3(-.5f,-.5f,-.5f), new Vector3(.5f,-.5f,-.5f), new Vector3(.5f,-.5f,.5f), new Vector3(-.5f,-.5f,.5f)
            };
            var triangles = new int[36];
            for (int face = 0; face < 6; face++)
            {
                int vertex = face * 4, triangle = face * 6;
                triangles[triangle] = vertex;
                triangles[triangle + 1] = vertex + 1;
                triangles[triangle + 2] = vertex + 2;
                triangles[triangle + 3] = vertex;
                triangles[triangle + 4] = vertex + 2;
                triangles[triangle + 5] = vertex + 3;
            }
            mesh.triangles = triangles;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            // ParticleSystem's non-instanced mesh renderer needs the CPU vertex data.
            mesh.UploadMeshData(false);
            return mesh;
        }

        private void ThrowIfDisposed()
        {
            if (disposed) throw new ObjectDisposedException(nameof(BlockParticleEffects));
        }

        private static void DestroyOwned(UnityEngine.Object value)
        {
            if (value == null) return;
            if (Application.isPlaying) UnityEngine.Object.Destroy(value);
            else UnityEngine.Object.DestroyImmediate(value);
        }
    }
}
