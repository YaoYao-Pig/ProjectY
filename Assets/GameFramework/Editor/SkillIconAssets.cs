using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    /// <summary>Imports published skill icons using the configured pixel style, then saves HUD references.</summary>
    public static class SkillIconAssets
    {
        private const string IconRoot = "Assets/DynamicAsset/UI/Icons/Skills/";
        [Serializable] private sealed class RecipeTable { public Recipe[] rows; }
        [Serializable] private sealed class Recipe { public int id; public string styleId; }
        [Serializable] private sealed class StyleTable { public Style[] rows; }
        [Serializable] private sealed class Style { public string id; public int maxTextureSize; }
        [Serializable] private sealed class IconTable { public Icon[] rows; }
        [Serializable] private sealed class Icon { public int id; public string spritePath; }

        [MenuItem("Project Y/UI/导入技能图标并同步引用")]
        public static void ImportPublished()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode)
                throw new InvalidOperationException("Skill icon import requires Edit Mode.");
            var recipes = JsonUtility.FromJson<RecipeTable>(File.ReadAllText("Config/Tables/Adventure/SkillIconRecipeTable.json")).rows;
            var styles = JsonUtility.FromJson<StyleTable>(File.ReadAllText("Config/Tables/Adventure/SkillIconStyleTable.json")).rows;
            var icons = JsonUtility.FromJson<IconTable>(File.ReadAllText("Config/Tables/Adventure/BattleIconTable.json")).rows;
            var styleById = new Dictionary<string, Style>();
            foreach (var style in styles)
            {
                if (style.maxTextureSize < 32 || style.maxTextureSize > 2048 ||
                    (style.maxTextureSize & (style.maxTextureSize - 1)) != 0)
                    throw new InvalidOperationException("Invalid skill icon texture size: " + style.id);
                styleById.Add(style.id, style);
            }
            var recipeById = new Dictionary<int, Recipe>();
            foreach (var recipe in recipes) recipeById.Add(recipe.id, recipe);
            var pending = new List<KeyValuePair<Icon, Style>>();
            var absoluteRoot = Path.GetFullPath(IconRoot);
            foreach (var icon in icons)
            {
                if (!recipeById.TryGetValue(icon.id, out var recipe)) continue;
                if (string.IsNullOrEmpty(icon.spritePath) || !icon.spritePath.StartsWith(IconRoot, StringComparison.Ordinal) ||
                    !Path.GetFullPath(icon.spritePath).StartsWith(absoluteRoot, StringComparison.OrdinalIgnoreCase) ||
                    !icon.spritePath.EndsWith(".png", StringComparison.Ordinal) || !File.Exists(icon.spritePath))
                    throw new InvalidOperationException("Published skill icon is missing or outside the icon folder: " + icon.id);
                pending.Add(new KeyValuePair<Icon, Style>(icon, styleById[recipe.styleId]));
            }
            if (pending.Count == 0) throw new InvalidOperationException("No published skill icons. Run Tools/SkillIcons/cli.mjs first.");
            foreach (var entry in pending)
            {
                var assetPath = entry.Key.spritePath;
                AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceSynchronousImport);
                var importer = AssetImporter.GetAtPath(assetPath) as TextureImporter;
                if (importer == null) throw new InvalidOperationException("Skill icon is not a texture: " + assetPath);
                importer.textureType = TextureImporterType.Sprite;
                importer.spriteImportMode = SpriteImportMode.Single;
                importer.spritePixelsPerUnit = 64;
                importer.sRGBTexture = true;
                importer.alphaIsTransparency = true;
                importer.mipmapEnabled = false;
                importer.filterMode = FilterMode.Point;
                importer.wrapMode = TextureWrapMode.Clamp;
                importer.npotScale = TextureImporterNPOTScale.None;
                importer.maxTextureSize = entry.Value.maxTextureSize;
                importer.textureCompression = TextureImporterCompression.Uncompressed;
                importer.SaveAndReimport();
                if (AssetDatabase.LoadAssetAtPath<Sprite>(assetPath) == null)
                    throw new InvalidOperationException("Skill icon Sprite import failed: " + assetPath);
            }
            BattleHUDAssets.SyncIcons();
            Debug.Log("Imported and bound " + pending.Count + " published skill icons.");
        }
    }
}
