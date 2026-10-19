// Unity MCP execute_code body. Imports only the authored ground textures and their shaders.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Ground texture import requires Edit Mode");
var report = new System.Collections.Generic.List<object>();
foreach (string name in new[] { "Grass", "Forest", "Rock", "Shore", "Snow" })
{
    string path = "Assets/GameFramework/Resources/MapGround/" + name + ".png";
    UnityEditor.AssetDatabase.ImportAsset(path, UnityEditor.ImportAssetOptions.ForceSynchronousImport);
    var importer = (UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(path);
    importer.textureType = UnityEditor.TextureImporterType.Default;
    importer.sRGBTexture = true; importer.mipmapEnabled = true; importer.isReadable = false;
    importer.npotScale = UnityEditor.TextureImporterNPOTScale.ToNearest;
    importer.alphaSource = UnityEditor.TextureImporterAlphaSource.None;
    importer.wrapMode = TextureWrapMode.Repeat; importer.filterMode = FilterMode.Trilinear; importer.anisoLevel = 4;
    importer.maxTextureSize = 512; importer.textureCompression = UnityEditor.TextureImporterCompression.Uncompressed;
    var settings = importer.GetDefaultPlatformTextureSettings();
    settings.maxTextureSize = 512; settings.format = UnityEditor.TextureImporterFormat.RGBA32;
    settings.textureCompression = UnityEditor.TextureImporterCompression.Uncompressed;
    importer.SetPlatformTextureSettings(settings); importer.SaveAndReimport();
    var texture = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture2D>(path);
    if (texture.width != 512 || texture.height != 512 || texture.format != TextureFormat.RGBA32 || texture.mipmapCount != 10)
        throw new System.Exception("Ground texture import contract failed: " + path + " / " + texture.format);
    report.Add(new { path, texture.width, texture.height, format = texture.format.ToString(), texture.mipmapCount });
}
foreach (string path in new[] { "Assets/GameFramework/Resources/MapGround.shader", "Assets/GameFramework/Resources/MapNature.shader", "Assets/GameFramework/Resources/_Gen/Config/MapBiomeTable.bytes" })
    UnityEditor.AssetDatabase.ImportAsset(path, UnityEditor.ImportAssetOptions.ForceSynchronousImport);
foreach (string name in new[] { "MapGround", "MapNature" })
{
    var shader = Resources.Load<Shader>(name);
    if (shader == null || !shader.isSupported || UnityEditor.ShaderUtil.ShaderHasError(shader)) throw new System.Exception("Ground shader invalid: " + name);
}
return report;
