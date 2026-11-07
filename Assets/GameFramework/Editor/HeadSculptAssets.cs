using System;
using System.IO;
using System.Linq;
using ProjectY.Data;
using ProjectY.Samples;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    public static class HeadSculptAssets
    {
        public static GameObject Source(PawnCustomizationRules.Module definition, GameObject fallback)
        {
            if (string.IsNullOrEmpty(definition.source)) return fallback;
            return AssetDatabase.LoadAssetAtPath<GameObject>(definition.source) ?? throw new FileNotFoundException(definition.source);
        }
        public static Texture2D Albedo(PawnCustomizationRules.Module definition)
        {
            if (string.IsNullOrEmpty(definition.texture)) return null;
            return AssetDatabase.LoadAssetAtPath<Texture2D>(definition.texture) ?? throw new FileNotFoundException(definition.texture);
        }
        [MenuItem("Project Y/角色/同步新增雕刻头部")]
        public static void Sync()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Head sync requires Edit Mode.");
            var catalog = AssetDatabase.LoadAssetAtPath<PawnCustomizationCatalog>(PawnCustomizationAssets.CatalogPath);
            if (catalog == null) throw new InvalidOperationException("Existing character catalog is required.");
            var rules = JsonUtility.FromJson<PawnCustomizationRules>(File.ReadAllText("Art/PawnCustomization/Integration/catalog.json"));
            var original = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnAnimation/PawnHumanoid.fbx");
            var parts = catalog.Parts.ToDictionary(p => p.Id, StringComparer.Ordinal);
            foreach (var definition in rules.modules.Where(m => !string.IsNullOrEmpty(m.source)))
            {
                if (definition.slot != "head") throw new InvalidOperationException("The additive head importer only owns head modules.");
                var source = Source(definition, null);
                var renderer = source.GetComponentsInChildren<SkinnedMeshRenderer>(true).Single(r => r.name == definition.id + "_export");
                parts[definition.id] = PawnCustomizationAssets.ImportPart(source, renderer, original, definition.id, Albedo(definition));
            }
            foreach (var definition in rules.modules.Where(m => m.id != "none"))
                if (!parts.ContainsKey(definition.id)) throw new InvalidOperationException("Missing existing module: " + definition.id);
            catalog.Rules = rules; catalog.Parts = parts.Values.ToArray();
            foreach (var entry in catalog.BodyDefaults) rules.Validate(entry.Appearance);
            const string runtime = "Assets/GameFramework/Resources/CharacterAppearanceCatalog.json";
            File.WriteAllText(runtime, JsonUtility.ToJson(rules)); AssetDatabase.ImportAsset(runtime, ImportAssetOptions.ForceSynchronousImport);
            EditorUtility.SetDirty(catalog); AssetDatabase.SaveAssetIfDirty(catalog); AssetDatabase.SaveAssets();
            Debug.Log("Additive sculpt head sync complete: " + rules.modules.Count(m => !string.IsNullOrEmpty(m.source)) + " heads; old modules retained.");
        }
    }
}
