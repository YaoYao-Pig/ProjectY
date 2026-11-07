// Unity MCP execute_code method body. Isolated flat-world motion contract, no Play or asset writes.
// Run after the task's consolidated compile. Reflection observes owned slots only, outside allocation timing.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Weather motion check requires idle Edit Mode.");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool originalDirty = originalScene.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapWeatherRenderer renderer = null;
GameObject owner = null;
System.Action<bool, string> check = (condition, message) => { if (!condition) throw new System.Exception(message); };
var binding = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
int movingPairs = 0, samplingBoundaryPairs = 0, reusedPairs = 0;
float minimumStep = float.MaxValue, maximumStep = 0;
long allocatedBytes = -1;
double elapsedMilliseconds = 0;
try
{
    // A large flat fixture isolates motion from terrain-height changes and has room to pan/teleport.
    const int half = 60, side = half * 2 + 1;
    var cells = new ProjectY.Samples.MapPreviewData.Cell[side * side];
    int index = 0;
    for (int r = -half; r <= half; r++) for (int q = -half; q <= half; q++)
        cells[index++] = new ProjectY.Samples.MapPreviewData.Cell {
            Q = q, R = r, Position = new Vector3(1.73205080757f * (q + r * .5f), 0, r * 1.5f) };
    var map = new ProjectY.Samples.MapPreviewData { Seed = 20261027u, Radius = 1, Cells = cells };
    var field = new ProjectY.Data.WorldWeatherField(map.Seed, 18, 240, .7, .25);
    var settings = new ProjectY.Samples.MapEnvironmentData.WeatherSettings {
        MaxClouds = 96, MaxRainParticles = 1800, MaxSplashParticles = 128,
        RainRate = 950, RefreshSeconds = .25f, CloudSpacingHexes = 5 };
    owner = new GameObject("Weather motion isolated check");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner, scene);
    var cameraObject = new GameObject("Weather motion camera"); cameraObject.transform.SetParent(owner.transform, false);
    var camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic = true; camera.orthographicSize = 36; camera.aspect = 1.6f;
    camera.nearClipPlane = .1f; camera.farClipPlane = 200;
    camera.transform.SetPositionAndRotation(new Vector3(0, 80, 0), Quaternion.Euler(90, 0, 0));
    renderer = new ProjectY.Samples.MapWeatherRenderer(camera, owner.transform, settings);
    renderer.BindWorld(map, field); renderer.SetContext(600, Vector2.zero);
    renderer.SelectPreview(new ProjectY.Samples.MapEnvironmentData.Weather { Id = 3, Cloud = 1, Rain = .8f });
    var focus = Vector3.zero;
    const float delta = 1f / 60;
    for (int frame = 0; frame < 90; frame++) renderer.Draw(delta, focus, false);
    check(renderer.CloudCount > 5, "Motion fixture did not produce visible clouds.");

    var slotsField = typeof(ProjectY.Samples.MapWeatherRenderer).GetField("cloudSlots", binding);
    check(slotsField != null, "Weather renderer no longer exposes its fixed cloud pool to the motion check.");
    var slots = (System.Array)slotsField.GetValue(renderer);
    var matrices = (Matrix4x4[])typeof(ProjectY.Samples.MapWeatherRenderer).GetField("cloudMatrices", binding).GetValue(renderer);
    var slotType = slots.GetType().GetElementType();
    var occupiedField = slotType.GetField("Occupied", binding); var xField = slotType.GetField("X", binding);
    var zField = slotType.GetField("Z", binding); var positionField = slotType.GetField("Position", binding);
    var tintField = slotType.GetField("Tint", binding);
    System.Func<System.Collections.Generic.Dictionary<Vector2Int, System.Tuple<Vector3, Vector4>>> snapshot = () =>
    {
        var result = new System.Collections.Generic.Dictionary<Vector2Int, System.Tuple<Vector3, Vector4>>();
        for (int i = 0; i < slots.Length; i++)
        {
            var slot = slots.GetValue(i);
            if (!(bool)occupiedField.GetValue(slot)) continue;
            var id = new Vector2Int((int)(long)xField.GetValue(slot), (int)(long)zField.GetValue(slot));
            check(!result.ContainsKey(id), "Cloud identity was allocated to two slots.");
            result.Add(id, System.Tuple.Create((Vector3)positionField.GetValue(slot), (Vector4)tintField.GetValue(slot)));
        }
        check(result.Count <= settings.MaxClouds && renderer.CloudCount <= settings.MaxClouds, "Cloud pool exceeded its budget.");
        check(renderer.RainCount <= settings.MaxRainParticles && renderer.SplashCount <= settings.MaxSplashParticles, "Particle budget regressed.");
        for (int i = 0; i < renderer.CloudCount; i++)
        {
            Vector3 submittedPosition = matrices[i].GetColumn(3); bool matched = false;
            foreach (var entry in result)
                if ((entry.Value.Item1 - submittedPosition).sqrMagnitude < .00000001f) { matched = true; break; }
            check(matched, "Submitted cloud matrix retained an old position between weather samples.");
        }
        return result;
    };
    System.Func<System.Collections.Generic.Dictionary<Vector2Int, System.Tuple<Vector3, Vector4>>,
        System.Collections.Generic.Dictionary<Vector2Int, System.Tuple<Vector3, Vector4>>, int> smoothStep = (before, after) =>
    {
        int common = 0;
        foreach (var entry in before)
        {
            if (!after.TryGetValue(entry.Key, out var next)) continue;
            var movement = next.Item1 - entry.Value.Item1;
            float distance = movement.magnitude;
            check(distance > .0001f && distance < .02f, "A cloud stopped between samples or jumped at a refresh.");
            check(movement.x > 0 && movement.z > 0, "Visual motion reversed the configured wind.");
            check(System.Math.Abs(next.Item2.w - entry.Value.Item2.w) < .03f, "Cloud opacity snapped instead of transitioning.");
            minimumStep = Mathf.Min(minimumStep, distance); maximumStep = Mathf.Max(maximumStep, distance);
            common++;
        }
        check(common >= 8, "Too few stable cloud identities survived between adjacent frames.");
        return common;
    };

    // Frozen game clock: clouds still move at 60 fps, while the weather texture is not uploaded again.
    int refreshBefore = renderer.RefreshCount;
    var previous = snapshot();
    for (int frame = 0; frame < 60; frame++)
    {
        renderer.Draw(delta, focus, false);
        var next = snapshot(); movingPairs += smoothStep(previous, next); previous = next;
    }
    check(renderer.RefreshCount == refreshBefore, "Visual cloud animation forced weather texture uploads while game time and camera were unchanged.");

    // Travel-style minute increments cross several low-frequency weather sampling boundaries.
    for (int frame = 0; frame < 120; frame++)
    {
        renderer.SetContext(605 + (frame / 30) * 5, Vector2.zero);
        int priorRefresh = renderer.RefreshCount;
        renderer.Draw(delta, focus, false);
        var next = snapshot(); int common = smoothStep(previous, next);
        if (renderer.RefreshCount != priorRefresh) samplingBoundaryPairs += common;
        movingPairs += common; previous = next;
    }
    check(samplingBoundaryPairs > 0, "Motion check never crossed a weather resample.");

    // Zero display delta pauses motion, even if the authoritative clock jumps by centuries.
    renderer.SelectPreview(null); renderer.SetContext(1000000000, Vector2.zero);
    renderer.Draw(0, focus, false);
    var paused = snapshot(); int pausedCommon = 0;
    foreach (var entry in previous)
    {
        if (!paused.TryGetValue(entry.Key, out var next)) continue;
        check(next.Item1 == entry.Value.Item1 && next.Item2 == entry.Value.Item2, "Zero display delta moved or faded a cloud.");
        pausedCommon++;
    }
    check(pausedCommon >= 8, "Time jump unnecessarily replaced the cloud lattice.");
    renderer.Draw(delta, focus, false);
    previous = snapshot(); smoothStep(paused, previous);

    renderer.Draw(5, focus, false);
    var resumed = snapshot(); int resumedCommon = 0;
    foreach (var entry in previous)
        if (resumed.TryGetValue(entry.Key, out var next))
        {
            check(Vector3.Distance(next.Item1, entry.Value.Item1) < .05f, "A suspended display frame caused a cloud catch-up teleport.");
            resumedCommon++;
        }
    check(resumedCommon >= 8, "Suspended frame unnecessarily replaced cloud identities.");
    previous = resumed;

    // Density and tint are targets: preview changes must not replace positions or switch opacity abruptly.
    renderer.SelectPreview(new ProjectY.Samples.MapEnvironmentData.Weather { Id = 1, Cloud = 0, Rain = 0 });
    renderer.Draw(delta, focus, false);
    var faded = snapshot(); smoothStep(previous, faded);
    foreach (var entry in previous)
        if (faded.TryGetValue(entry.Key, out var next))
            check((next.Item2 - entry.Value.Item2).magnitude < .08f, "Weather color changed discontinuously.");
    renderer.SelectPreview(new ProjectY.Samples.MapEnvironmentData.Weather { Id = 3, Cloud = 1, Rain = .8f });

    // Panning changes only the visible selection; retained cloud identities remain anchored in world space.
    previous = faded;
    for (int frame = 0; frame < 30; frame++)
    {
        focus.x += .4f; camera.transform.position += Vector3.right * .4f;
        renderer.Draw(delta, focus, false);
        var next = snapshot(); reusedPairs += smoothStep(previous, next); previous = next;
    }
    check(reusedPairs > 0, "Camera pan did not reuse cloud slots.");

    // A teleport recycles offscreen slots; every newly visible identity fades in from zero.
    focus.x = 90; camera.transform.position = new Vector3(focus.x, 80, focus.z);
    renderer.Draw(delta, focus, false);
    var teleported = snapshot(); int newClouds = 0;
    foreach (var entry in teleported)
        if (!previous.ContainsKey(entry.Key)) { check(entry.Value.Item2.w < .03f, "Teleported cloud appeared at full opacity."); newClouds++; }
    check(newClouds > 0, "Teleport did not exercise cloud slot recycling.");

    // Zooming changes density LOD only after old slots have faded, rather than rescaling their positions.
    previous = teleported; camera.orthographicSize *= 1.8f;
    renderer.Draw(delta, focus, false);
    var zoomed = snapshot(); int fadingClouds = 0;
    foreach (var entry in previous)
    {
        if (!zoomed.TryGetValue(entry.Key, out var next)) continue;
        check(Vector3.Distance(next.Item1, entry.Value.Item1) < .02f, "Zoom immediately relocated a visible cloud.");
        check(next.Item2.w <= entry.Value.Item2.w + .00001f, "Old zoom lattice was not faded out."); fadingClouds++;
    }
    check(fadingClouds > 0, "Zoom did not exercise lattice fade-out.");
    for (int frame = 0; frame < 180; frame++) renderer.Draw(delta, focus, false);
    check(snapshot().Count > 0, "Cloud lattice was not repopulated after its zoom transition.");

    renderer.Hide(); check(renderer.CloudCount == 0, "Hide retained visible cloud instances.");
    renderer.Draw(delta, focus, false);
    foreach (var entry in snapshot()) check(entry.Value.Item2.w < .03f, "Hidden clouds did not fade back in.");
    for (int frame = 0; frame < 120; frame++) renderer.Draw(delta, focus, false);

    // No reflection, snapshots or assertions in the warmed allocation measurement.
    var timer = System.Diagnostics.Stopwatch.StartNew(); timer.Stop();
    System.GC.GetAllocatedBytesForCurrentThread();
    long allocatedBefore = System.GC.GetAllocatedBytesForCurrentThread();
    timer.Restart();
    for (int frame = 0; frame < 120; frame++) renderer.Draw(delta, focus, false);
    timer.Stop();
    allocatedBytes = System.GC.GetAllocatedBytesForCurrentThread() - allocatedBefore;
    elapsedMilliseconds = timer.Elapsed.TotalMilliseconds;
    check(allocatedBytes == 0, "Weather motion allocated managed memory: " + allocatedBytes);
    snapshot();
}
finally
{
    renderer?.Dispose();
    if (owner != null) UnityEngine.Object.DestroyImmediate(owner);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
check(UnityEngine.SceneManagement.SceneManager.GetActiveScene() == originalScene && originalScene.isDirty == originalDirty,
    "Weather motion check changed the user's active scene.");
return "weather motion passed; movingPairs=" + movingPairs + " samplingBoundaryPairs=" + samplingBoundaryPairs
    + " reusedPairs=" + reusedPairs + " minFrameStep=" + minimumStep + " maxFrameStep=" + maximumStep
    + " measuredFrames=120 elapsedMs=" + elapsedMilliseconds + " allocatedBytes=" + allocatedBytes;
