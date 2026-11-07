// Native Sprite assembly preview, independent from the live HUD; no Play or scene save.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Weather dial preview requires idle Edit Mode.");
var original = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool dirty = original.isDirty;
var previousTarget = RenderTexture.active;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
GameObject owner = null; RenderTexture target = null; Texture2D readback = null;
try
{
    var manifest = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Art/WeatherDial/v1/sprites.json"));
    var sprites = new System.Collections.Generic.Dictionary<string, Sprite>();
    var entries = new System.Collections.Generic.Dictionary<string, Newtonsoft.Json.Linq.JToken>();
    foreach (var atlas in manifest["atlases"])
    {
        foreach (var asset in UnityEditor.AssetDatabase.LoadAllAssetsAtPath((string)atlas["path"]))
            if (asset is Sprite sprite) sprites.Add(sprite.name, sprite);
        foreach (var entry in atlas["sprites"]) entries.Add((string)entry["name"], entry);
    }
    if (sprites.Count != 8) throw new System.InvalidOperationException("Import all eight weather dial sprites first.");
    owner = new GameObject("Weather dial art preview"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner, scene);
    var camera = new GameObject("Camera").AddComponent<Camera>(); camera.transform.SetParent(owner.transform, false);
    camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.035f,.045f,.04f);
    camera.orthographic = true; camera.orthographicSize = 350; camera.nearClipPlane = .1f; camera.farClipPlane = 20;
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    target = new RenderTexture(1200, 700, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB); target.Create(); camera.targetTexture = target;
    var canvasObject = new GameObject("Preview canvas", typeof(RectTransform), typeof(Canvas)); canvasObject.transform.SetParent(owner.transform, false);
    var canvas = canvasObject.GetComponent<Canvas>(); canvas.renderMode = RenderMode.ScreenSpaceCamera; canvas.worldCamera = camera; canvas.planeDistance = 2;
    var canvasRect = (RectTransform)canvas.transform;
    System.Func<RectTransform, string, bool, RectTransform> layer = (parent, key, shadow) =>
    {
        var entry = entries[key]; var placement = entry["designPlacementAt200"];
        var rect = (RectTransform)new GameObject(key + (shadow ? " Shadow" : ""), typeof(RectTransform), typeof(UnityEngine.UI.Image)).transform;
        rect.SetParent(parent, false); rect.anchorMin = rect.anchorMax = new Vector2(.5f,.5f);
        rect.pivot = new Vector2((float)entry["pivot"]["x"], (float)entry["pivot"]["y"]);
        rect.sizeDelta = new Vector2((float)placement["size"][0], (float)placement["size"][1]);
        rect.anchoredPosition = new Vector2((float)placement["anchoredPosition"][0], (float)placement["anchoredPosition"][1]) + (shadow ? new Vector2(1.2f,-1.7f) : Vector2.zero);
        var image = rect.GetComponent<UnityEngine.UI.Image>(); image.sprite = sprites[key]; image.preserveAspect = true; image.raycastTarget = false;
        image.color = shadow ? new Color(.04f,.025f,.01f,.28f) : Color.white;
        return rect;
    };
    for (int row = 0; row < 2; row++) for (int state = 0; state < 3; state++)
    {
        var root = (RectTransform)new GameObject("Dial " + row + " " + state, typeof(RectTransform)).transform;
        root.SetParent(canvasRect, false); root.anchorMin = root.anchorMax = new Vector2(.5f,.5f); root.pivot = new Vector2(.5f,.5f);
        root.anchoredPosition = new Vector2((state - 1) * 360, row == 0 ? 150 : -180); root.sizeDelta = Vector2.one * 200;
        root.localScale = Vector3.one * (row == 0 ? 1.5f : 1);
        layer(root, "WeatherDial_Frame", true);
        layer(root, "WeatherDial_Face", false);
        string weather = state == 0 ? "WeatherDial_Sun" : state == 1 ? "WeatherDial_Cloud" : "WeatherDial_StormCloud";
        layer(root, weather, true); layer(root, weather, false);
        if (state == 2) layer(root, "WeatherDial_RainLightning", false);
        layer(root, "WeatherDial_Frame", false);
        var handShadow = layer(root, "WeatherDial_Hand", true); var hand = layer(root, "WeatherDial_Hand", false);
        float hour = state == 0 ? 12 : state == 1 ? 18 : 23;
        handShadow.localEulerAngles = hand.localEulerAngles = new Vector3(0,0,-hour/24*360);
        layer(root, "WeatherDial_Hub", false);
    }
    Canvas.ForceUpdateCanvases(); ProjectY.Rendering.UrpCameraRendering.Render(camera);
    RenderTexture.active = target;
    readback = new Texture2D(1200,700,TextureFormat.RGB24,false); readback.ReadPixels(new Rect(0,0,1200,700),0,0); readback.Apply();
    var path = "Art/WeatherDial/v1/native-preview.png"; System.IO.File.WriteAllBytes(path, readback.EncodeToPNG());
    camera.targetTexture = null;
    return new { path, states = new[] { "clear 12:00", "cloudy 18:00", "rain 23:00" }, displaySizes = new[] { 300, 200 },
        nativeSprites = 8, liveHudChanged = false, playMode = false };
}
finally
{
    RenderTexture.active = previousTarget;
    if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    if (readback != null) UnityEngine.Object.DestroyImmediate(readback);
    if (owner != null) UnityEngine.Object.DestroyImmediate(owner);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != original || original.isDirty != dirty)
        throw new System.InvalidOperationException("Weather dial art preview changed the active scene.");
}
