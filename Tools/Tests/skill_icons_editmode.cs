// Unity MCP execute_code body: real imported Sprites and saved HUD bindings; isolated PreviewScene, no Play.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalDirty = originalScene.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var previous = RenderTexture.active;
var target = new RenderTexture(1200, 600, 24, RenderTextureFormat.ARGB32); target.Create();
var cameraObject = new GameObject("Skill icon preview camera");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, scene);
var camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene;
camera.orthographic = true; camera.orthographicSize = 300; camera.aspect = 2;
camera.nearClipPlane = .1f; camera.farClipPlane = 2000; camera.transform.position = new Vector3(0, 0, -1000);
camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.055f, .072f, .065f); camera.targetTexture = target;
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
try
{
    var canvasObject = new GameObject("Skill icon size review", typeof(RectTransform), typeof(Canvas));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(canvasObject, scene);
    var canvas = canvasObject.GetComponent<Canvas>(); canvas.renderMode = RenderMode.WorldSpace; canvas.worldCamera = camera;
    var bounds = (RectTransform)canvasObject.transform; bounds.sizeDelta = new Vector2(1200, 600);
    var hud = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab").GetComponent<ProjectY.UI.BattleHUDView>();
    var main = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab");
    var icons = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Adventure/BattleIconTable.json"))["rows"];
    var skills = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Adventure/CombatSkillTable.json"))["rows"];
    var manifest = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Art/SkillIcons/manifest.json"))["entries"];
    var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
    if (main == null || main.GetComponentsInChildren<ProjectY.UI.BattleHUDView>(true).Length == 0)
        throw new System.Exception("MainHud is missing its nested BattleHUD");
    System.Action<string, float, float, int> label = (text, x, y, size) => {
        var obj = new GameObject("Preview label", typeof(RectTransform), typeof(UnityEngine.UI.Text)); obj.transform.SetParent(bounds, false);
        var caption = obj.GetComponent<UnityEngine.UI.Text>(); caption.font = font; caption.text = text; caption.fontSize = size;
        caption.color = new Color(.90f, .88f, .77f); caption.alignment = TextAnchor.MiddleCenter;
        caption.rectTransform.sizeDelta = new Vector2(220, 32); caption.rectTransform.anchoredPosition = new Vector2(x, y);
    };
    label("SKILL ICONS / v1", -435, 265, 22);
    var names = new[] { "SLASH", "SHOOT", "SPARK", "DEFEND", "HEAL" };
    var sizes = new[] { 128, 64, 32, 64 };
    var yValues = new[] { 145f, 12f, -78f, -190f };
    for (var i = 0; i < 5; i++)
    {
        var id = 10001 + i; string assetPath = null; int configuredSize = 0;
        foreach (var row in icons) if ((int)row["id"] == id) assetPath = (string)row["spritePath"];
        foreach (var entry in manifest) if ((int)entry["recipeId"] == id) configuredSize = (int)entry["maxTextureSize"];
        var mapped = false; foreach (var skill in skills) if ((int)skill["id"] == i + 1) mapped = (int)skill["iconId"] == id;
        if (!mapped || assetPath == null) throw new System.Exception("Skill icon config not published: " + id);
        var importer = (UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(assetPath);
        if (importer.textureType != UnityEditor.TextureImporterType.Sprite || importer.spriteImportMode != UnityEditor.SpriteImportMode.Single ||
            importer.filterMode != FilterMode.Point || importer.mipmapEnabled || importer.textureCompression != UnityEditor.TextureImporterCompression.Uncompressed ||
            importer.maxTextureSize != configuredSize || !importer.alphaIsTransparency)
            throw new System.Exception("Incorrect icon import settings: " + assetPath);
        var x = -440 + i * 220;
        label(names[i], x, 223, 18);
        var panel = new GameObject("Light background", typeof(RectTransform), typeof(UnityEngine.UI.Image)); panel.transform.SetParent(bounds, false);
        var background = panel.GetComponent<UnityEngine.UI.Image>(); background.color = new Color(.78f, .77f, .70f);
        background.rectTransform.sizeDelta = new Vector2(196, 100); background.rectTransform.anchoredPosition = new Vector2(x, -190);
        for (var r = 0; r < sizes.Length; r++)
        {
            var obj = new GameObject("Bound skill icon", typeof(RectTransform), typeof(UnityEngine.UI.Image)); obj.transform.SetParent(bounds, false);
            var image = obj.GetComponent<UnityEngine.UI.Image>(); image.preserveAspect = true;
            image.rectTransform.sizeDelta = new Vector2(sizes[r], sizes[r]); image.rectTransform.anchoredPosition = new Vector2(x, yValues[r]);
            hud.SetIcon(image, id, assetPath);
            if (!image.enabled || image.sprite == null) throw new System.Exception("Saved HUD binding is missing: " + id);
            foreach (var nested in main.GetComponentsInChildren<ProjectY.UI.BattleHUDView>(true)) nested.SetIcon(image, id, assetPath);
        }
    }
    label("128 / 64 / 32 px", 435, 265, 18);
    Canvas.ForceUpdateCanvases(); ProjectY.Rendering.UrpCameraRendering.Render(camera); RenderTexture.active = target;
    var pixels = new Texture2D(target.width, target.height, TextureFormat.RGBA32, false);
    try
    {
        pixels.ReadPixels(new Rect(0, 0, target.width, target.height), 0, 0); pixels.Apply();
        System.IO.Directory.CreateDirectory("Docs/Previews/SkillIcons");
        System.IO.File.WriteAllBytes("Docs/Previews/SkillIcons/first-five.png", pixels.EncodeToPNG());
    }
    finally { UnityEngine.Object.DestroyImmediate(pixels); }
}
finally
{
    camera.targetTexture = null; RenderTexture.active = previous; target.Release(); UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != originalDirty)
    throw new System.Exception("Icon preview changed the user's scene");
return new { passed = true, icons = 5, sizes = "128/64/32", playMode = false, preview = "Docs/Previews/SkillIcons/first-five.png" };
