// Unity MCP execute_code method body. Saved MainHud prefab, real v2 sprites, isolated PreviewScene.
// No game startup, player saves, Play mode, asset writes, screen-resolution changes or clip modification.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Weather dial check requires idle Edit Mode.");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool originalDirty = originalScene.isDirty;
var originalTarget = RenderTexture.active; float originalTimeScale = Time.timeScale;
var originalPipeline = QualitySettings.renderPipeline;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
int checks = 0, layoutCases = 0, flashPulses = 0, faceVertices = 0;
long tickAllocatedBytes = -1; double tickMilliseconds = 0;
RenderTexture target = null; Texture2D pixels = null; Mesh faceMesh = null;
var imagesWritten = new System.Collections.Generic.List<string>();
var errors = new System.Collections.Generic.List<string>();
Application.LogCallback log = (message, trace, kind) => { if (kind == LogType.Error || kind == LogType.Exception) errors.Add(message); };
Application.logMessageReceived += log;
System.Action<bool, string> check = (ok, message) => { if (!ok) throw new System.Exception(message); checks++; };
System.Func<object, string, object> field = (value, name) => value.GetType().GetField(name, flags).GetValue(value);
string folder = "Docs/Previews/WeatherDial";
try
{
    var profileRows = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Rendering/MapEnvironmentTable.json"))["rows"];
    Newtonsoft.Json.Linq.JToken profile = null;
    foreach (var row in profileRows) if ((int)row["id"] == 1) { profile = row; break; }
    check(profile != null, "Weather dial environment profile is missing.");
    var keys = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Rendering/MapLightKeyTable.json"))["rows"];
    System.Func<string, double> hour = name =>
    {
        int id = (int)profile[name];
        foreach (var key in keys) if ((int)key["id"] == id) return (double)key["hour"];
        throw new System.Exception("Weather dial references a missing light key: " + name);
    };
    double dayStart = hour("dialDayKeyId"), duskStart = hour("dialDuskKeyId"), nightStart = hour("dialNightKeyId");
    check(dayStart == 7 && duskStart == 17 && nightStart == 21, "Expected current light-key phase boundaries 7/17/21.");

    var cameraObject = new GameObject("Weather dial preview camera");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, scene);
    var camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic = true; camera.nearClipPlane = .1f; camera.farClipPlane = 500;
    camera.transform.SetPositionAndRotation(new Vector3(0, 0, -100), Quaternion.identity);
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.10f, .14f, .15f);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var canvasObject = new GameObject("Weather dial preview canvas", typeof(RectTransform), typeof(Canvas));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(canvasObject, scene);
    var canvas = canvasObject.GetComponent<Canvas>(); canvas.renderMode = RenderMode.WorldSpace; canvas.worldCamera = camera;
    var canvasRect = (RectTransform)canvasObject.transform; canvasRect.sizeDelta = new Vector2(1280, 720);
    var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab");
    check(prefab != null, "Saved MainHudPanel prefab is missing.");
    var root = UnityEngine.Object.Instantiate(prefab, canvasRect, false); root.SetActive(false);
    var rootRect = (RectTransform)root.transform;
    rootRect.anchorMin = Vector2.zero; rootRect.anchorMax = Vector2.one;
    rootRect.offsetMin = rootRect.offsetMax = Vector2.zero; rootRect.localScale = Vector3.one;
    var rootScaler = root.GetComponent<UnityEngine.UI.CanvasScaler>(); if (rootScaler != null) rootScaler.enabled = false;
    var reference = root.GetComponent<ProjectY.UI.LuaReference>(); reference.ValidateBindings();
    var hud = (ProjectY.UI.MainHudView)reference.Get("HUD");
    var dial = reference.Get("WeatherDial") as ProjectY.UI.WeatherDialView;
    var dialGroup = reference.Get("WeatherDialGroup") as CanvasGroup;
    check(dial != null && dialGroup != null, "Saved WeatherDial and WeatherDialGroup bindings are missing.");
    check(dialGroup.alpha == 0, "Saved weather art must remain hidden until its first explicit visual tick.");
    var transition = (ProjectY.UI.HudModeTransition)reference.Get("MapTransition");
    transition.SetProgress(0);
    foreach (var nested in root.GetComponentsInChildren<ProjectY.UI.LuaReference>(true))
        typeof(ProjectY.UI.LuaReference).GetMethod("ApplyLocalizations", flags).Invoke(nested, null);
    root.SetActive(true); hud.Prepare(); hud.SetCharacterSkillBar((RectTransform)reference.Get("CharacterSkills")); hud.SetMode(true, false);
    reference.Get("Menu").gameObject.SetActive(false); reference.Get("Hint").gameObject.SetActive(false);
    reference.Get("Interaction").gameObject.SetActive(false); reference.Get("HealthLayer").gameObject.SetActive(false);
    reference.Get("BattleContent").gameObject.SetActive(false);
    transition.SetProgress(0);
    var layout = (ProjectY.UI.MainHudView.Layout)field(hud, "layout");
    var worldControls = (RectTransform)field(hud, "worldControls");
    check(worldControls != null, "WorldControls must use the serialized HUD binding.");
    var clock = layout.Clock; var rail = layout.Rail; var menu = layout.Menu; var journal = layout.Journal;
    var characterSkills = (RectTransform)reference.Get("CharacterSkills");
    var hand = (RectTransform)field(dial, "hand"); var handShadow = (RectTransform)field(dial, "handShadow");
    var cloud = (RectTransform)field(dial, "cloud"); var rain = (RectTransform)field(dial, "rain");
    var sunImage = (UnityEngine.UI.Image)field(dial, "sunImage");
    var cloudImage = (UnityEngine.UI.Image)field(dial, "cloudImage");
    var stormImage = (UnityEngine.UI.Image)field(dial, "stormImage");
    var rainImage = (UnityEngine.UI.Image)field(dial, "rainImage");
    var lightningImage = (UnityEngine.UI.Image)field(dial, "lightningImage");
    var face = (ProjectY.UI.WeatherDialFace)field(dial, "face");
    foreach (var image in new[] { sunImage, cloudImage, stormImage, rainImage, lightningImage, hand.GetComponent<UnityEngine.UI.Image>(), handShadow.GetComponent<UnityEngine.UI.Image>() })
        check(image != null && image.sprite != null && image.sprite.name.StartsWith("WeatherDialV2_", StringComparison.Ordinal) &&
            !string.IsNullOrEmpty(UnityEditor.AssetDatabase.GetAssetPath(image.sprite)), "A saved dial layer lacks its real v2 sprite asset.");
    check(reference.Get("ClockNeedle") == hand, "The original ClockNeedle binding was replaced instead of retained.");
    dial.Configure(dayStart, duskStart, nightStart);
    check((double)field(face, "dayStart") == dayStart && (double)field(face, "duskStart") == duskStart &&
        (double)field(face, "nightStart") == nightStart, "Dial sectors diverged from the shared phase configuration.");
    dial.SetState(720, 0, 0); dial.TickVisual(0); dialGroup.alpha = 1;
    check(sunImage.color.a > .9f && cloudImage.color.a < .001f && rainImage.color.a < .001f, "Initial sunny noon state was not applied.");

    System.Action<double, float, float> initialize = (minutes, cloudValue, rainValue) =>
    { dial.ResetVisual(); dial.SetState(minutes, cloudValue, rainValue); dial.TickVisual(0); };
    const float dt = 1f / 60;
    initialize(720, 0, 0);
    var oldRotation = hand.localRotation; var oldCloudColor = cloudImage.color; var oldRainPosition = rain.anchoredPosition;
    dial.SetState(720.5, .8f, .7f);
    check(hand.localRotation == oldRotation && cloudImage.color == oldCloudColor && rain.anchoredPosition == oldRainPosition,
        "SetState wrote visual transforms or image colors before TickVisual.");
    dial.TickVisual(0);
    check(hand.localRotation == oldRotation && cloudImage.color == oldCloudColor, "Zero delta advanced an existing interpolation.");
    dial.TickVisual(dt);
    double fractional = (double)field(dial, "displayedMinutes");
    check(fractional > 720 && fractional < 720.5, "Fractional minutes are not smoothly represented by the hand.");
    check(Mathf.DeltaAngle(180, hand.localEulerAngles.z) < 0, "Forward time rotated the hand backwards.");
    initialize(720, 0, 0); dial.SetState(721, 0, 0);
    double priorMinutes = 720; int movingFrames = 0;
    for (int frame = 0; frame < 60; frame++)
    {
        dial.TickVisual(dt); double now = (double)field(dial, "displayedMinutes");
        check(now >= priorMinutes && now <= 721, "A one-minute interpolation reversed or overshot.");
        if (now > priorMinutes) movingFrames++; priorMinutes = now;
    }
    check(movingFrames > 30 && Math.Abs(priorMinutes - 721) < .001, "A one-minute update snapped or failed to converge.");

    initialize(1439.9, 0, 0); dial.SetState(1440.1, 0, 0);
    float priorAngle = hand.localEulerAngles.z, accumulatedAngle = 0; priorMinutes = 1439.9;
    for (int frame = 0; frame < 60; frame++)
    {
        dial.TickVisual(dt); float nowAngle = hand.localEulerAngles.z;
        float movement = Mathf.DeltaAngle(priorAngle, nowAngle); accumulatedAngle += movement;
        double nowMinutes = (double)field(dial, "displayedMinutes");
        check(movement <= .0001f && movement > -.02f && nowMinutes >= priorMinutes, "Midnight caused a reverse or long-way sweep.");
        priorAngle = nowAngle; priorMinutes = nowMinutes;
    }
    check(accumulatedAngle < -.04f && accumulatedAngle > -.06f, "Midnight hand motion does not match 0.2 forward minutes.");
    oldRotation = hand.localRotation;
    double loadedMinute = 1440.0 * 10000 + 120.25;
    dial.SetState(loadedMinute, 1, 1);
    check(hand.localRotation == oldRotation, "A long time jump bypassed the explicit tick.");
    dial.TickVisual(0);
    check(Math.Abs((double)field(dial, "displayedMinutes") - loadedMinute) < .0001 &&
        Mathf.Abs(Mathf.DeltaAngle(hand.localEulerAngles.z, -30.0625f)) < .001f, "Long clock jump retained stale hand time.");
    initialize(720, 1, 1); check(stormImage.color.a > .9f && rainImage.color.a > .9f, "Rain did not initialize directly after ResetVisual.");
    initialize(720, 0, 0);
    check(sunImage.color.a > .9f && stormImage.color.a < .001f && rainImage.color.a < .001f, "ResetVisual interpolated weather from the previous save.");
    initialize(23 * 60, 0, 0); check(sunImage.color.a < .001f, "Sunny night displays a white sun.");
    initialize(12 * 60, .8f, 0); check(cloudImage.color.a > .8f && rainImage.color.a < .001f, "Overcast layers are incorrect.");

    initialize(12 * 60, 1, 1);
    float rainMin = rain.anchoredPosition.y, rainMax = rainMin, maxFlash = 0; bool flashing = false;
    for (int frame = 0; frame < 8 * 60; frame++)
    {
        dial.TickVisual(dt); rainMin = Mathf.Min(rainMin, rain.anchoredPosition.y); rainMax = Mathf.Max(rainMax, rain.anchoredPosition.y);
        maxFlash = Mathf.Max(maxFlash, lightningImage.color.a);
        bool lit = lightningImage.color.a > .10f; if (lit && !flashing) flashPulses++; flashing = lit;
    }
    check(rainMax - rainMin > 4 && rainMax - rainMin < 8, "Rain group lacks its bounded downward cycle.");
    check(flashPulses == 2 && maxFlash > .3f && maxFlash <= .66f, "Storm icon must show exactly two restrained local flashes per cycle.");

    oldRotation = hand.localRotation; var oldCloudPosition = cloud.anchoredPosition; oldRainPosition = rain.anchoredPosition;
    dial.enabled = false; dial.TickVisual(.1f);
    check(hand.localRotation == oldRotation && cloud.anchoredPosition == oldCloudPosition && rain.anchoredPosition == oldRainPosition, "Disabled dial kept animating.");
    dial.enabled = true; dial.gameObject.SetActive(false); dial.TickVisual(.1f);
    check(hand.localRotation == oldRotation && cloud.anchoredPosition == oldCloudPosition && rain.anchoredPosition == oldRainPosition, "Inactive dial kept animating.");
    dial.gameObject.SetActive(true); dial.TickVisual(dt);
    check(cloud.anchoredPosition != oldCloudPosition, "Re-enabled dial failed to resume visual animation.");

    Canvas.ForceUpdateCanvases(); hud.ApplyLayout(); Canvas.ForceUpdateCanvases();
    check(Mathf.Abs(clock.rect.width - 192) < .01f && Mathf.Abs(clock.rect.height - 246) < .01f, "Saved clock must occupy 192x246 logical units.");
    faceMesh = new Mesh { name = "Weather dial test mesh" };
    using (var helper = new UnityEngine.UI.VertexHelper())
    {
        typeof(ProjectY.UI.WeatherDialFace).GetMethod("OnPopulateMesh", flags, null, new[] { typeof(UnityEngine.UI.VertexHelper) }, null).Invoke(face, new object[] { helper });
        helper.FillMesh(faceMesh); faceVertices = faceMesh.vertexCount;
    }
    check(faceVertices > 100 && faceVertices <= 500, "Procedural face exceeds its bounded mesh budget.");

    var corners = new Vector3[4];
    System.Func<RectTransform, Rect> bounds = rect =>
    {
        rect.GetWorldCorners(corners);
        var min = new Vector2(float.MaxValue, float.MaxValue); var max = new Vector2(float.MinValue, float.MinValue);
        for (int i = 0; i < 4; i++)
        { Vector2 p = canvasRect.InverseTransformPoint(corners[i]); min = Vector2.Min(min, p); max = Vector2.Max(max, p); }
        return Rect.MinMaxRect(min.x, min.y, max.x, max.y);
    };
    System.Func<Rect, Rect, bool> overlaps = (a, b) => Mathf.Min(a.xMax, b.xMax) - Mathf.Max(a.xMin, b.xMin) > .1f &&
        Mathf.Min(a.yMax, b.yMax) - Mathf.Max(a.yMin, b.yMin) > .1f;
    System.Action<Rect, Rect, string> inside = (inner, outer, message) => check(inner.xMin >= outer.xMin - .1f && inner.xMax <= outer.xMax + .1f &&
        inner.yMin >= outer.yMin - .1f && inner.yMax <= outer.yMax + .1f, message);
    System.Func<Transform, float> opacity = leaf =>
    {
        if (!leaf.gameObject.activeInHierarchy) return 0;
        float alpha = 1;
        for (var current = leaf; current != null; current = current.parent)
        {
            var groups = current.GetComponents<CanvasGroup>(); bool stop = false;
            foreach (var group in groups) { alpha *= group.alpha; stop |= group.ignoreParentGroups; }
            if (stop) break;
        }
        return alpha;
    };
    System.Action validateLayout = () =>
    {
        var screen = canvasRect.rect; var clockBounds = bounds(clock); var railBounds = bounds(rail); var controlBounds = bounds(worldControls);
        inside(clockBounds, screen, "Clock escaped the rendered screen."); inside(railBounds, screen, "Rail escaped the rendered screen.");
        inside(controlBounds, screen, "WorldControls escaped the rendered screen.");
        check(!overlaps(clockBounds, railBounds) && !overlaps(clockBounds, controlBounds), "Clock overlaps Rail or WorldControls.");
        foreach (var text in clock.GetComponentsInChildren<UnityEngine.UI.Text>(true))
            if (text.gameObject.activeInHierarchy) inside(bounds(text.rectTransform), clockBounds, "Clock text escaped its footer bounds: " + text.name);
        if (menu.gameObject.activeSelf)
        {
            inside(bounds(menu), screen, "Open menu escaped the screen.");
            check(bounds(menu).xMax <= clockBounds.xMin + .1f && !overlaps(bounds(menu), clockBounds), "Open menu must remain left of the clock.");
        }
        if (journal.gameObject.activeInHierarchy)
        {
            inside(bounds(journal), screen, "Journal escaped the screen.");
            check(!overlaps(bounds(journal), railBounds), "Journal overlaps the bottom of the rail.");
            if (characterSkills.gameObject.activeInHierarchy)
                check(!overlaps(bounds(journal), bounds(characterSkills)), "Journal overlaps CharacterSkills at " + canvasRect.rect.size +
                    ": Journal=" + bounds(journal) + ", CharacterSkills=" + bounds(characterSkills));
        }
        layoutCases++;
    };
    System.Action<int, int, string, double, float, float, bool> capture = (width, height, name, minutes, cloudValue, rainValue, menuOpen) =>
    {
        if (target != null) { camera.targetTexture = null; target.Release(); UnityEngine.Object.DestroyImmediate(target); target = null; }
        if (pixels != null) { UnityEngine.Object.DestroyImmediate(pixels); pixels = null; }
        target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32); target.Create(); camera.targetTexture = target;
        pixels = new Texture2D(width, height, TextureFormat.RGB24, false);
        canvasRect.sizeDelta = new Vector2(width, height); camera.orthographicSize = height * .5f; camera.aspect = (float)width / height;
        menu.gameObject.SetActive(menuOpen); transition.SetProgress(0);
        Canvas.ForceUpdateCanvases(); hud.ApplyLayout(); Canvas.ForceUpdateCanvases();
        initialize(minutes, cloudValue, rainValue); dialGroup.alpha = 1;
        long integral = (long)Math.Floor(minutes), minuteOfDay = integral % 1440;
        reference.GetText("ClockTime").text = (minuteOfDay / 60).ToString("00") + ":" + (minuteOfDay % 60).ToString("00");
        reference.GetText("ClockDay").text = ProjectY.UI.LuaLanguage.Get("UIMainHudClockDayText").Replace("%s", (integral / 1440 + 1).ToString());
        reference.GetText("Coins").text = ProjectY.UI.LuaLanguage.Get("UIMainHudCoinsText").Replace("%s", "1250");
        Canvas.ForceUpdateCanvases(); validateLayout();
        ProjectY.Rendering.UrpCameraRendering.Render(camera); RenderTexture.active = target;
        pixels.ReadPixels(new Rect(0, 0, width, height), 0, 0); pixels.Apply();
        string path = folder + "/" + name + ".png"; System.IO.File.WriteAllBytes(path, pixels.EncodeToPNG()); imagesWritten.Add(path);
    };
    System.IO.Directory.CreateDirectory(folder);
    capture(1280, 720, "runtime-clear-1280x720", 720, 0, 0, false);
    capture(1280, 720, "runtime-rain-1280x720", 975, .95f, .90f, false);
    capture(1280, 720, "runtime-menu-1280x720", 975, .95f, .90f, true);
    capture(1100, 720, "runtime-clear-1100x720", 720, 0, 0, false);
    menu.gameObject.SetActive(true); hud.ApplyLayout(); Canvas.ForceUpdateCanvases(); validateLayout();
    capture(1024, 768, "runtime-rain-1024x768", 975, .95f, .90f, false);
    menu.gameObject.SetActive(true); hud.ApplyLayout(); Canvas.ForceUpdateCanvases(); validateLayout();
    capture(800, 600, "runtime-clear-800x600", 720, 0, 0, false);
    menu.gameObject.SetActive(true); hud.ApplyLayout(); Canvas.ForceUpdateCanvases(); validateLayout();
    menu.gameObject.SetActive(false); hud.ApplyLayout(); Canvas.ForceUpdateCanvases();

    var animation = root.GetComponent<ProjectY.UI.AnimationWrap>(); check(animation.HasClip("map-overview"), "Saved overview clip is missing.");
    transition.SetProgress(1); Canvas.ForceUpdateCanvases();
    check(opacity(clock) < .01f && opacity(hand) < .01f, "Overview clip fails to hide the new clock and its weather art.");
    transition.SetProgress(0); Canvas.ForceUpdateCanvases();
    check(opacity(clock) > .99f && opacity(hand) > .99f, "MainHud restoration failed to reveal the clock.");

    // Exercise the actual xLua reflection bridge with the production config/model and weather field.
    using (var lua = new XLua.LuaEnv())
    {
        var services = new ProjectY.FrameworkServices(null);
        var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
        lua.Global.Set("Services", services); lua.Global.Set("PreviewDial", dial);
        try
        {
            var bridge = lua.DoString(@"
local config=require('Config.ConfigSystem')();config:OnInit({services=Services})
local a={config=config,data={Seed=4294967295,Phase='map',Areas={ActiveSiteId=0}},map={hexRadius=1,GetCellWorldPosition=function() return 12,0,19 end},
    travel={data={Q=1,R=2}},narrative={data={Minutes=720.5}}}
require('Game.Adventure.Weather').Bind(a)
local model=require('Game.Adventure.WeatherDialModel').New(a)
PreviewDial:Configure(model:Periods());PreviewDial:ResetVisual()
local minute,cloud,rain=model:Read(0)
PreviewDial:SetState(minute,cloud,rain);PreviewDial:TickVisual(0)
return minute,cloud,rain
", "weather_dial_saved_view_bridge");
            check(Convert.ToDouble(bridge[0]) == 720.5 && Math.Abs((double)field(dial,"displayedMinutes") - 720.5) < .00001,
                "The actual Lua model failed to drive the saved WeatherDial component.");
        }
        finally { lua.Global.Set<string,object>("PreviewDial",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners(); }
    }

    // Warm the real Image/Shadow meshes before checking only the component's tick allocations.
    initialize(720, .9f, .8f);
    for (int i = 0; i < 30; i++) { dial.TickVisual(dt); Canvas.ForceUpdateCanvases(); }
    int faceDirty = 0; UnityEngine.Events.UnityAction dirtyCallback = () => faceDirty++;
    face.RegisterDirtyVerticesCallback(dirtyCallback);
    System.Func<int[]> resources = () => new[] { Resources.FindObjectsOfTypeAll<GameObject>().Length, Resources.FindObjectsOfTypeAll<Material>().Length,
        Resources.FindObjectsOfTypeAll<Mesh>().Length, Resources.FindObjectsOfTypeAll<Texture2D>().Length };
    var resourcesBefore = resources();
    var timer = System.Diagnostics.Stopwatch.StartNew(); timer.Stop(); System.GC.GetAllocatedBytesForCurrentThread();
    long allocatedBefore = System.GC.GetAllocatedBytesForCurrentThread(); timer.Restart();
    for (int i = 0; i < 120; i++) { dial.SetState(720 + i / 120.0, .9f, .8f); dial.TickVisual(dt); }
    timer.Stop(); tickAllocatedBytes = System.GC.GetAllocatedBytesForCurrentThread() - allocatedBefore; tickMilliseconds = timer.Elapsed.TotalMilliseconds;
    Canvas.ForceUpdateCanvases(); var resourcesAfter = resources();
    face.UnregisterDirtyVerticesCallback(dirtyCallback);
    check(tickAllocatedBytes == 0, "Weather dial SetState/TickVisual allocated managed memory: " + tickAllocatedBytes);
    check(faceDirty == 0, "Clock animation dirtied the static face mesh.");
    for (int i = 0; i < resourcesBefore.Length; i++) check(resourcesBefore[i] == resourcesAfter[i], "Weather dial animation created a native object/resource.");
    check(errors.Count == 0, "Weather dial check logged an error: " + (errors.Count == 0 ? "" : errors[0]));
}
finally
{
    Application.logMessageReceived -= log; RenderTexture.active = originalTarget;
    if (pixels != null) UnityEngine.Object.DestroyImmediate(pixels);
    if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    if (faceMesh != null) UnityEngine.Object.DestroyImmediate(faceMesh);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
check(UnityEngine.SceneManagement.SceneManager.GetActiveScene() == originalScene && originalScene.isDirty == originalDirty,
    "Weather dial check changed the user's scene.");
check(Time.timeScale == originalTimeScale && QualitySettings.renderPipeline == originalPipeline && !UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode,
    "Weather dial check changed time scale, pipeline or Play state.");
var report = new { passed = true, checks, layoutCases, flashPulses, faceVertices, tickFrames = 120,
    tickAllocatedBytes, tickMilliseconds, screenshots = imagesWritten.ToArray(), playMode = false, sceneRestored = true };
System.IO.File.WriteAllText(folder + "/runtime-validation.json", Newtonsoft.Json.JsonConvert.SerializeObject(report, Newtonsoft.Json.Formatting.Indented));
return report;
