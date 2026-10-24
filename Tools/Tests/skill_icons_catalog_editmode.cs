// Unity MCP execute_code body. Set usePublished=false for candidate review; onlySkills optionally restricts the sheet.
var usePublished = true;
var onlySkills = new int[0];
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var originalDirty = originalScene.isDirty;
var recipes = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Adventure/SkillIconRecipeTable.json"))["rows"];
var skills = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Adventure/CombatSkillTable.json"))["rows"];
var icons = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Adventure/BattleIconTable.json"))["rows"];
var entries = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Art/SkillIcons/manifest.json"))["entries"];
var latest = new System.Collections.Generic.Dictionary<int, Newtonsoft.Json.Linq.JToken>();
foreach (var entry in entries)
{
    var id = (int)entry["recipeId"];
    if (!latest.ContainsKey(id) || (int)latest[id]["version"] < (int)entry["version"]) latest[id] = entry;
}
var rows = new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>();
foreach (var recipe in recipes)
{
    var skillId = (int)recipe["skillId"];
    if (onlySkills.Length > 0 && System.Array.IndexOf(onlySkills, skillId) < 0) continue;
    var candidate = "Art/SkillIcons/Candidates/" + (int)recipe["id"] + ".png";
    if (usePublished || System.IO.File.Exists(candidate) || latest.ContainsKey((int)recipe["id"])) rows.Add(recipe);
}
if (rows.Count == 0) throw new System.Exception("No icons available for review");
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var previous = RenderTexture.active;
var target = new RenderTexture(1200, 960, 24, RenderTextureFormat.ARGB32); target.Create();
var owned = new System.Collections.Generic.List<UnityEngine.Object>();
var cameraObject = new GameObject("Skill catalog preview camera"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, scene);
var camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene; camera.orthographic = true;
camera.orthographicSize = 480; camera.aspect = 1.25f; camera.nearClipPlane = .1f; camera.farClipPlane = 2000;
camera.transform.position = new Vector3(0, 0, -1000); camera.clearFlags = CameraClearFlags.SolidColor;
camera.backgroundColor = new Color(.055f, .072f, .065f); camera.targetTexture = target;
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var files = new System.Collections.Generic.List<string>();
try
{
    var hud = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab").GetComponent<ProjectY.UI.BattleHUDView>();
    var main = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab");
    var nestedHuds = main.GetComponentsInChildren<ProjectY.UI.BattleHUDView>(true);
    if (nestedHuds.Length == 0) throw new System.Exception("MainHud is missing its nested BattleHUD");
    var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
    for (var page = 0; page * 20 < rows.Count; page++)
    {
        var canvasObject = new GameObject("Skill catalog page", typeof(RectTransform), typeof(Canvas));
        UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(canvasObject, scene);
        try
        {
            var canvas = canvasObject.GetComponent<Canvas>(); canvas.renderMode = RenderMode.WorldSpace; canvas.worldCamera = camera;
            var bounds = (RectTransform)canvasObject.transform; bounds.sizeDelta = new Vector2(1200, 960);
            System.Action<string, float, float, int> label = (text, x, y, size) => {
                var obj = new GameObject("Preview label", typeof(RectTransform), typeof(UnityEngine.UI.Text)); obj.transform.SetParent(bounds, false);
                var caption = obj.GetComponent<UnityEngine.UI.Text>(); caption.font = font; caption.text = text; caption.fontSize = size;
                caption.color = new Color(.90f, .88f, .77f); caption.alignment = TextAnchor.MiddleCenter;
                caption.rectTransform.sizeDelta = new Vector2(194, 42); caption.rectTransform.anchoredPosition = new Vector2(x, y);
            };
            label("SKILL ICONS / " + (page + 1), -490, 450, 20); label("96 / 64 / 32 px", 490, 450, 17);
            for (var slot = 0; slot < 20 && page * 20 + slot < rows.Count; slot++)
            {
                var recipe = rows[page * 20 + slot]; var id = (int)recipe["id"]; var skillId = (int)recipe["skillId"];
                var candidate = "Art/SkillIcons/Candidates/" + id + ".png";
                var candidateExists = !usePublished && System.IO.File.Exists(candidate);
                string assetPath = null; Sprite sprite;
                if (candidateExists)
                {
                    var texture = new Texture2D(2, 2, TextureFormat.RGBA32, false); owned.Add(texture);
                    if (!texture.LoadImage(System.IO.File.ReadAllBytes(candidate))) throw new System.Exception("Cannot decode " + candidate);
                    texture.filterMode = FilterMode.Point;
                    sprite = Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), new Vector2(.5f, .5f), 64); owned.Add(sprite);
                }
                else
                {
                    if (!latest.ContainsKey(id)) throw new System.Exception("Unpublished skill: " + skillId);
                    var entry = latest[id]; assetPath = (string)entry["assetPath"];
                    var mapped = false; foreach (var skill in skills) if ((int)skill["id"] == skillId) mapped = (int)skill["iconId"] == id;
                    var pathMapped = false; foreach (var icon in icons) if ((int)icon["id"] == id) pathMapped = (string)icon["spritePath"] == assetPath;
                    if (!mapped || !pathMapped) throw new System.Exception("Published skill mapping mismatch: " + id);
                    var importer = UnityEditor.AssetImporter.GetAtPath(assetPath) as UnityEditor.TextureImporter;
                    if (importer == null || importer.textureType != UnityEditor.TextureImporterType.Sprite || importer.spriteImportMode != UnityEditor.SpriteImportMode.Single ||
                        importer.filterMode != FilterMode.Point || importer.mipmapEnabled || !importer.alphaIsTransparency ||
                        importer.textureCompression != UnityEditor.TextureImporterCompression.Uncompressed || importer.maxTextureSize != (int)entry["maxTextureSize"])
                        throw new System.Exception("Incorrect icon import settings: " + assetPath);
                    sprite = UnityEditor.AssetDatabase.LoadAssetAtPath<Sprite>(assetPath);
                    if (sprite == null) throw new System.Exception("Missing Sprite " + assetPath);
                }
                var x = -480 + (slot % 5) * 240; var y = 320 - (slot / 5) * 216;
                label(skillId + " / " + (string)recipe["slug"], x, y + 71, 14);
                var panel = new GameObject("Light background", typeof(RectTransform), typeof(UnityEngine.UI.Image)); panel.transform.SetParent(bounds, false);
                var background = panel.GetComponent<UnityEngine.UI.Image>(); background.color = new Color(.78f, .77f, .70f);
                background.rectTransform.sizeDelta = new Vector2(176, 72); background.rectTransform.anchoredPosition = new Vector2(x, y - 89);
                var sizes = new[] { 96, 64, 32 }; var xs = new[] { 0, -40, 48 }; var ys = new[] { 6, -89, -89 };
                for (var r = 0; r < sizes.Length; r++)
                {
                    var obj = new GameObject("Skill icon", typeof(RectTransform), typeof(UnityEngine.UI.Image)); obj.transform.SetParent(bounds, false);
                    var image = obj.GetComponent<UnityEngine.UI.Image>(); image.preserveAspect = true;
                    image.rectTransform.sizeDelta = new Vector2(sizes[r], sizes[r]); image.rectTransform.anchoredPosition = new Vector2(x + xs[r], y + ys[r]);
                    if (candidateExists) image.sprite = sprite;
                    else
                    {
                        hud.SetIcon(image, id, assetPath); foreach (var nested in nestedHuds) nested.SetIcon(image, id, assetPath);
                        if (!image.enabled || image.sprite != sprite) throw new System.Exception("Saved HUD binding mismatch: " + id);
                    }
                }
            }
            Canvas.ForceUpdateCanvases(); ProjectY.Rendering.UrpCameraRendering.Render(camera); RenderTexture.active = target;
            var pixels = new Texture2D(target.width, target.height, TextureFormat.RGBA32, false);
            try
            {
                pixels.ReadPixels(new Rect(0, 0, target.width, target.height), 0, 0); pixels.Apply();
                System.IO.Directory.CreateDirectory("Docs/Previews/SkillIcons");
                var output = "Docs/Previews/SkillIcons/" + (usePublished ? "catalog-" : "candidates-") + (page + 1) + ".png";
                System.IO.File.WriteAllBytes(output, pixels.EncodeToPNG()); files.Add(output);
            }
            finally { UnityEngine.Object.DestroyImmediate(pixels); }
        }
        finally { UnityEngine.Object.DestroyImmediate(canvasObject); }
    }
}
finally
{
    camera.targetTexture = null; RenderTexture.active = previous; target.Release(); UnityEngine.Object.DestroyImmediate(target);
    foreach (var obj in owned) UnityEngine.Object.DestroyImmediate(obj);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != originalDirty)
    throw new System.Exception("Icon preview changed the user's scene");
return new { passed = true, published = usePublished, icons = rows.Count, playMode = false, previews = files.ToArray() };
