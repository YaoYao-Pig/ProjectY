using System;

namespace ProjectY.Data
{
    /// <summary>Continuous outdoor weather at a world position and absolute game minute.</summary>
    public readonly struct WeatherSample
    {
        public int WeatherId { get; }
        public float Cloud { get; }
        public float Rain { get; }
        public float WindX { get; }
        public float WindZ { get; }

        internal WeatherSample(int weatherId, float cloud, float rain, float windX, float windZ)
        {
            WeatherId = weatherId;
            Cloud = cloud;
            Rain = rain;
            WindX = windX;
            WindZ = windZ;
        }
    }

    /// <summary>
    /// Stateless, seed-owned weather field. Position and region size use world units;
    /// wind uses world units per game minute. Query cost and storage do not depend on map size.
    /// No random stream, frame delta, generated cells or previous queries affect a result.
    /// </summary>
    public sealed class WorldWeatherField
    {
        // Keep fractional precision well inside a noise cell, even for long-running saves.
        // Limit is applied after normalization and advection, rather than to map coordinates.
        private const double MaximumNoiseCoordinate = 1099511627776.0; // 2^40
        private readonly double inverseRegionSize;
        private readonly double inverseEvolutionMinutes;
        private readonly double windRegionsX;
        private readonly double windRegionsZ;
        private readonly float windX;
        private readonly float windZ;

        public uint Seed { get; }
        public double RegionSize { get; }
        public double EvolutionMinutes { get; }

        public WorldWeatherField(uint seed, double regionSize, double evolutionMinutes, double windX, double windZ)
        {
            RequirePositiveFinite(regionSize, nameof(regionSize));
            RequirePositiveFinite(evolutionMinutes, nameof(evolutionMinutes));
            RequireFinite(windX, nameof(windX));
            RequireFinite(windZ, nameof(windZ));
            if (Math.Abs(windX) > float.MaxValue) throw new ArgumentOutOfRangeException(nameof(windX));
            if (Math.Abs(windZ) > float.MaxValue) throw new ArgumentOutOfRangeException(nameof(windZ));

            inverseRegionSize = 1.0 / regionSize;
            inverseEvolutionMinutes = 1.0 / evolutionMinutes;
            RequirePositiveFinite(inverseRegionSize, nameof(regionSize));
            RequirePositiveFinite(inverseEvolutionMinutes, nameof(evolutionMinutes));
            windRegionsX = windX * inverseRegionSize;
            windRegionsZ = windZ * inverseRegionSize;
            RequireFinite(windRegionsX, nameof(windX));
            RequireFinite(windRegionsZ, nameof(windZ));

            Seed = seed;
            RegionSize = regionSize;
            EvolutionMinutes = evolutionMinutes;
            this.windX = (float)windX;
            this.windZ = (float)windZ;
        }

        /// <summary>
        /// Samples without allocation or mutation. Signed finite minutes support replay and
        /// arbitrary jumps. Normalized, advected coordinates must stay within +/- 2^40 cells.
        /// Weather IDs are 1 clear, 2 overcast and 3 rain; only the ID is discrete.
        /// </summary>
        public WeatherSample Sample(double x, double z, double minutes)
        {
            RequireFinite(x, nameof(x));
            RequireFinite(z, nameof(z));
            RequireFinite(minutes, nameof(minutes));

            double nx = x * inverseRegionSize - minutes * windRegionsX;
            double nz = z * inverseRegionSize - minutes * windRegionsZ;
            double nt = minutes * inverseEvolutionMinutes;
            RequireNoiseCoordinate(nx, nameof(x));
            RequireNoiseCoordinate(nz, nameof(z));
            RequireNoiseCoordinate(nt, nameof(minutes));

            // A broad moving front dominates; a second octave breaks up uniform boundaries.
            // Time is a separate noise dimension so weather still evolves when wind is zero.
            double broad = Noise(nx, nz, nt, Seed);
            double detail = Noise(nx * 2.07 + 17.13, nz * 2.07 - 7.91, nt * .73 + 29.4, Seed ^ 0xB5297A4Du);
            float cloud = (float)SmoothStep(.18, .82, broad * .82 + detail * .18);
            float rain = (float)SmoothStep(.64, .95, cloud);
            int weatherId = rain > .02f ? 3 : cloud >= .38f ? 2 : 1;
            return new WeatherSample(weatherId, cloud, rain, windX, windZ);
        }

        private static double Noise(double x, double z, double time, uint seed)
        {
            long ix = (long)Math.Floor(x);
            long iz = (long)Math.Floor(z);
            long it = (long)Math.Floor(time);
            double fx = Fade(x - ix);
            double fz = Fade(z - iz);
            double ft = Fade(time - it);
            double lower = Lerp(
                Lerp(Hash(ix, iz, it, seed), Hash(ix + 1, iz, it, seed), fx),
                Lerp(Hash(ix, iz + 1, it, seed), Hash(ix + 1, iz + 1, it, seed), fx), fz);
            double upper = Lerp(
                Lerp(Hash(ix, iz, it + 1, seed), Hash(ix + 1, iz, it + 1, seed), fx),
                Lerp(Hash(ix, iz + 1, it + 1, seed), Hash(ix + 1, iz + 1, it + 1, seed), fx), fz);
            return Lerp(lower, upper, ft);
        }

        private static double Hash(long x, long z, long time, uint seed)
        {
            unchecked
            {
                // Include both halves of every signed lattice coordinate, avoiding a 32-bit
                // wrap in large worlds or long-running games. All uint seeds are valid.
                uint value = seed ^ 0x9E3779B9u;
                value ^= (uint)x * 0x85EBCA6Bu ^ (uint)(x >> 32) * 0x27D4EB2Fu;
                value ^= (uint)z * 0xC2B2AE35u ^ (uint)(z >> 32) * 0x165667B1u;
                value ^= (uint)time * 0xD3A2646Cu ^ (uint)(time >> 32) * 0xA24BAED5u;
                value ^= value >> 16;
                value *= 0x7FEB352Du;
                value ^= value >> 15;
                value *= 0x846CA68Bu;
                value ^= value >> 16;
                return (value >> 8) * (1.0 / 16777215.0);
            }
        }

        private static double Fade(double value) => value * value * value * (value * (value * 6.0 - 15.0) + 10.0);
        private static double Lerp(double from, double to, double amount) => from + (to - from) * amount;

        private static double SmoothStep(double from, double to, double value)
        {
            double amount = Math.Max(0.0, Math.Min(1.0, (value - from) / (to - from)));
            return amount * amount * (3.0 - 2.0 * amount);
        }

        private static void RequireFinite(double value, string name)
        {
            if (double.IsNaN(value) || double.IsInfinity(value))
                throw new ArgumentOutOfRangeException(name, "Weather values must be finite.");
        }

        private static void RequirePositiveFinite(double value, string name)
        {
            RequireFinite(value, name);
            if (value <= 0.0) throw new ArgumentOutOfRangeException(name, "Weather scales must be positive and representable.");
        }

        private static void RequireNoiseCoordinate(double value, string name)
        {
            RequireFinite(value, name);
            if (Math.Abs(value) > MaximumNoiseCoordinate)
                throw new ArgumentOutOfRangeException(name, "Weather query exceeds the supported normalized coordinate range.");
        }
    }
}
