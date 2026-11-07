// Unity MCP method body. Import and slice the generated v1 atlas through native Sprite metadata.
// Does not modify the MainHud prefab, enter Play, refresh scripts or rewrite generated image pixels.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Weather dial art import requires idle Edit Mode.");
var manifest = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Art/WeatherDial/v1/sprites.json"));
var report = new System.Collections.Generic.List<object>();
int spriteCount = 0;
foreach (var atlas in manifest["atlases"])
{
    string path = (string)atlas["path"];
    if (!path.StartsWith("Assets/DynamicAsset/UI/Skins/WeatherDial/", StringComparison.Ordinal) || !System.IO.File.Exists(path))
        throw new System.InvalidOperationException("Invalid weather dial atlas path: " + path);
    UnityEditor.AssetDatabase.ImportAsset(path, UnityEditor.ImportAssetOptions.ForceSynchronousImport);
    var importer = UnityEditor.AssetImporter.GetAtPath(path) as UnityEditor.TextureImporter;
    if (importer == null) throw new System.InvalidOperationException("Missing atlas importer: " + path);
    importer.textureType = UnityEditor.TextureImporterType.Sprite;
    importer.spriteImportMode = UnityEditor.SpriteImportMode.Multiple;
    importer.spritePixelsPerUnit = 100;
    importer.alphaSource = UnityEditor.TextureImporterAlphaSource.FromInput;
    importer.alphaIsTransparency = true;
    importer.sRGBTexture = true;
    importer.mipmapEnabled = false;
    importer.isReadable = false;
    importer.filterMode = FilterMode.Bilinear;
    importer.wrapMode = TextureWrapMode.Clamp;
    importer.npotScale = UnityEditor.TextureImporterNPOTScale.None;
    importer.textureCompression = UnityEditor.TextureImporterCompression.Uncompressed;
    importer.maxTextureSize = Mathf.NextPowerOfTwo(Mathf.Max((int)atlas["width"], (int)atlas["height"]));
    if (importer.maxTextureSize > 4096) throw new System.InvalidOperationException("Weather dial atlas exceeds the UI texture budget.");
    var settings = new UnityEditor.TextureImporterSettings(); importer.ReadTextureSettings(settings);
    settings.spriteMeshType = SpriteMeshType.FullRect; importer.SetTextureSettings(settings);
    var slices = new System.Collections.Generic.List<UnityEditor.SpriteMetaData>();
    foreach (var entry in atlas["sprites"])
    {
        var rect = entry["rectUnityBottomLeft"]; var pivot = entry["pivot"]; var border = entry["borderUnityLeftBottomRightTop"];
        var bounds = new Rect((float)rect["x"], (float)rect["y"], (float)rect["width"], (float)rect["height"]);
        if (bounds.xMin < 0 || bounds.yMin < 0 || bounds.xMax > (int)atlas["width"] || bounds.yMax > (int)atlas["height"])
            throw new System.InvalidOperationException("Weather dial sprite leaves its source atlas: " + (string)entry["name"]);
        foreach (var prior in slices) if (bounds.Overlaps(prior.rect)) throw new System.InvalidOperationException("Weather dial slices overlap.");
        slices.Add(new UnityEditor.SpriteMetaData { name = (string)entry["name"], rect = bounds,
            alignment = (int)UnityEngine.SpriteAlignment.Custom, pivot = new Vector2((float)pivot["x"], (float)pivot["y"]),
            border = new Vector4((float)border[0], (float)border[1], (float)border[2], (float)border[3]) });
    }
    importer.spritesheet = slices.ToArray(); importer.SaveAndReimport();
    var texture = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture2D>(path);
    if (texture.width != (int)atlas["width"] || texture.height != (int)atlas["height"] || texture.isReadable || !importer.DoesSourceTextureHaveAlpha())
        throw new System.InvalidOperationException("Atlas size, alpha or readback policy changed during native import.");
    var sprites = new System.Collections.Generic.Dictionary<string, Sprite>();
    foreach (var asset in UnityEditor.AssetDatabase.LoadAllAssetsAtPath(path)) if (asset is Sprite sprite) sprites.Add(sprite.name, sprite);
    foreach (var slice in slices)
    {
        if (!sprites.TryGetValue(slice.name, out var sprite) || sprite.rect != slice.rect || sprite.border != slice.border ||
            Vector2.Distance(sprite.pivot, Vector2.Scale(slice.pivot, slice.rect.size)) > .01f)
            throw new System.InvalidOperationException("Native Sprite slice mismatch: " + slice.name);
        spriteCount++;
        report.Add(new { name = sprite.name, path, rect = new { x = sprite.rect.x, y = sprite.rect.y, width = sprite.rect.width, height = sprite.rect.height },
            pivotPixels = new { x = sprite.pivot.x, y = sprite.pivot.y }, pixelsPerUnit = sprite.pixelsPerUnit });
    }
}
var result = new { spriteCount, sprites = report, mainHudReplaced = false, playMode = false, sourcePixelsRewritten = false };
System.IO.File.WriteAllText("Art/WeatherDial/v1/native-slices.json", Newtonsoft.Json.JsonConvert.SerializeObject(result, Newtonsoft.Json.Formatting.Indented));
return result;
