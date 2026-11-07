// Unity MCP execute_code method body. Pure data only: no scene, asset, Play or global RNG changes.
// Run only after the task's consolidated C# compilation has completed.
var field = new ProjectY.Data.WorldWeatherField(4294967295u, 72.0, 240.0, .7, .25);
var restored = new ProjectY.Data.WorldWeatherField(field.Seed, field.RegionSize, field.EvolutionMinutes, .7, .25);
System.Action<bool, string> check = (condition, message) => { if (!condition) throw new System.Exception(message); };
System.Func<ProjectY.Data.WeatherSample, ProjectY.Data.WeatherSample, bool> same = (a, b) =>
    a.WeatherId == b.WeatherId && a.Cloud == b.Cloud && a.Rain == b.Rain && a.WindX == b.WindX && a.WindZ == b.WindZ;
System.Action<ProjectY.Data.WeatherSample> valid = sample =>
{
    check(sample.WeatherId >= 1 && sample.WeatherId <= 3, "Unknown weather identity");
    check(!float.IsNaN(sample.Cloud) && sample.Cloud >= 0 && sample.Cloud <= 1, "Cloud outside [0,1]");
    check(!float.IsNaN(sample.Rain) && sample.Rain >= 0 && sample.Rain <= 1, "Rain outside [0,1]");
    check(sample.Rain == 0 || sample.Cloud > .6f, "Rain exists without thick clouds");
    check(sample.WeatherId != 3 || sample.Rain > 0, "Rain identity has no precipitation");
    check(sample.WindX == .7f && sample.WindZ == .25f, "Weather lost configured wind");
};
System.Action<System.Action> rejects = action =>
{
    bool rejected = false;
    try { action(); } catch (System.ArgumentOutOfRangeException) { rejected = true; }
    check(rejected, "Invalid weather input was accepted");
};

check(field.Seed == uint.MaxValue && field.RegionSize == 72 && field.EvolutionMinutes == 240, "Weather construction contract changed");
var expected = new ProjectY.Data.WeatherSample[257];
for (int i = 0; i < expected.Length; i++) expected[i] = field.Sample(i * 23.17 - 3000, i * -7.73 + 400, i * 137.25);
for (int i = 0; i < expected.Length; i++)
{
    int j = i * 73 % expected.Length;
    var actual = restored.Sample(j * 23.17 - 3000, j * -7.73 + 400, j * 137.25);
    check(same(expected[j], actual), "Weather depends on query order or non-persisted state");
    check(same(actual, field.Sample(j * 23.17 - 3000, j * -7.73 + 400, j * 137.25)), "Weather replay differs");
    valid(actual);
}

var counts = new int[4];
float spatialMin = 1, spatialMax = 0;
for (int t = 0; t < 8; t++)
for (int z = -16; z < 16; z++)
for (int x = -16; x < 16; x++)
{
    var sample = field.Sample(x * 29.3, z * 31.7, t * 183.4);
    valid(sample); counts[sample.WeatherId]++;
    if (t == 0) { spatialMin = System.Math.Min(spatialMin, sample.Cloud); spatialMax = System.Math.Max(spatialMax, sample.Cloud); }
}
check(counts[1] > 81 && counts[2] > 81 && counts[3] > 81, "Clear, overcast and rain must all occur across a broad world/time sample");
check(spatialMax - spatialMin > .35f, "Weather lacks meaningful spatial variation");
float temporalMin = 1, temporalMax = 0;
var calm = new ProjectY.Data.WorldWeatherField(7u, 72, 240, 0, 0);
float calmMin = 1, calmMax = 0;
for (int i = 0; i < 256; i++)
{
    var sample = field.Sample(18.5, -44.2, i * 61.5);
    temporalMin = System.Math.Min(temporalMin, sample.Cloud); temporalMax = System.Math.Max(temporalMax, sample.Cloud);
    var calmSample = calm.Sample(18.5, -44.2, i * 61.5);
    calmMin = System.Math.Min(calmMin, calmSample.Cloud); calmMax = System.Math.Max(calmMax, calmSample.Cloud);
}
check(temporalMax - temporalMin > .35f, "Weather lacks temporal variation");
check(calmMax - calmMin > .35f, "Zero wind freezes weather evolution");

// Includes noise lattice boundaries and reverse time; visual channels, not discrete IDs, must be continuous.
for (int i = -128; i < 128; i++)
{
    double minute = i * 240.0;
    double x = i * 72.0 + minute * .7;
    double z = -i * 72.0 + minute * .25;
    var before = field.Sample(x - .00001, z - .00001, minute - .00001);
    var after = field.Sample(x + .00001, z + .00001, minute + .00001);
    check(System.Math.Abs(before.Cloud - after.Cloud) < .001f && System.Math.Abs(before.Rain - after.Rain) < .001f,
        "Nearby weather queries are discontinuous");
}

uint[] seeds = { 0u, 1u, 2147483648u, uint.MaxValue };
double priorSeedSignature = -1;
foreach (uint seed in seeds)
{
    var seeded = new ProjectY.Data.WorldWeatherField(seed, 72, 240, .7, .25);
    var seededRestore = new ProjectY.Data.WorldWeatherField(seed, 72, 240, .7, .25);
    double signature = 0;
    for (int i = 0; i < 16; i++)
    {
        var sample = seeded.Sample(-113.7 + i * 31.3, 453.5 - i * 25.7, 879.3 + i * 113.1);
        valid(sample);
        check(same(sample, seededRestore.Sample(-113.7 + i * 31.3, 453.5 - i * 25.7, 879.3 + i * 113.1)), "Full uint seed failed deterministic replay");
        signature += sample.Cloud * (i + 1);
    }
    check(signature != priorSeedSignature, "Different seed failed to alter the weather field");
    priorSeedSignature = signature;
}
double[] longTimes = { 1000000000.0, 1000000000000.0, -1000000000000.0 };
foreach (double minute in longTimes)
{
    var sample = field.Sample(1000000.25, -2000000.5, minute);
    valid(sample);
    check(same(sample, restored.Sample(1000000.25, -2000000.5, minute)), "Long-running save cannot reproduce weather");
}

double[] invalidScales = { 0, -1, double.NaN, double.PositiveInfinity, double.NegativeInfinity, double.Epsilon };
foreach (double scale in invalidScales)
{
    rejects(() => new ProjectY.Data.WorldWeatherField(0, scale, 240, 0, 0));
    rejects(() => new ProjectY.Data.WorldWeatherField(0, 72, scale, 0, 0));
}
double[] nonFinite = { double.NaN, double.PositiveInfinity, double.NegativeInfinity };
foreach (double value in nonFinite)
{
    rejects(() => new ProjectY.Data.WorldWeatherField(0, 72, 240, value, 0));
    rejects(() => new ProjectY.Data.WorldWeatherField(0, 72, 240, 0, value));
    rejects(() => field.Sample(value, 0, 0));
    rejects(() => field.Sample(0, value, 0));
    rejects(() => field.Sample(0, 0, value));
}
rejects(() => new ProjectY.Data.WorldWeatherField(0, 72, 240, double.MaxValue, 0));
rejects(() => new ProjectY.Data.WorldWeatherField(0, 72, 240, 0, -double.MaxValue));
rejects(() => field.Sample(double.MaxValue, 0, 0));
rejects(() => field.Sample(0, -double.MaxValue, 0));
rejects(() => field.Sample(0, 0, double.MaxValue));

// Warm code and timer before the measured loop. Record CPU time without a hardware-specific time assertion.
double checksum = 0;
for (int i = 0; i < 4096; i++) checksum += field.Sample(i * .7, -i * .3, i * 1.25).Cloud;
var timer = System.Diagnostics.Stopwatch.StartNew(); timer.Stop();
System.GC.GetAllocatedBytesForCurrentThread();
long allocatedBefore = System.GC.GetAllocatedBytesForCurrentThread();
timer.Restart();
for (int i = 0; i < 100000; i++)
{
    var sample = field.Sample(i * .7, -i * .3, i * 1.25);
    checksum += sample.Cloud + sample.Rain;
}
timer.Stop();
long allocatedBytes = System.GC.GetAllocatedBytesForCurrentThread() - allocatedBefore;
check(allocatedBytes == 0, "Weather sampling allocates managed memory: " + allocatedBytes);
check(checksum > 0, "Weather timing loop produced no samples");
return "weather core passed; samples=8192 clear=" + counts[1] + " overcast=" + counts[2] + " rain=" + counts[3]
    + "; spatialCloudRange=" + (spatialMax - spatialMin) + "; temporalCloudRange=" + (temporalMax - temporalMin)
    + "; queries=100000 elapsedMs=" + timer.Elapsed.TotalMilliseconds + " allocatedBytes=" + allocatedBytes + " checksum=" + checksum;
