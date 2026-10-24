using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Register the existing harpoon art as a usable two-handed spear without reimporting its materials.</summary>
    public static class SpearAssets
    {
        [Serializable] private sealed class AssetRow { public int id; public string prefabPath; }
        [Serializable] private sealed class AssetRows { public AssetRow[] rows; }
        [MenuItem("Project Y/装备/同步长枪资源")]
        public static void Sync()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("长枪资源同步需要 Edit Mode。");
            const string target = "Assets/DynamicAsset/EquipmentDemo/Weapons/TidecatchSpear.prefab";
            var source = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/AssetExpansion202610/ShipwreckWeapons/Prefabs/SWW_TidecatchHarpoon.prefab");
            if (source == null) throw new InvalidOperationException("Missing authored harpoon model.");
            if (AssetDatabase.LoadAssetAtPath<GameObject>(target) == null)
            {
                var root = new GameObject("TidecatchSpear");
                try
                {
                    var model = (GameObject)PrefabUtility.InstantiatePrefab(source); model.transform.SetParent(root.transform, false);
                    root.AddComponent<WeaponModelView>().SetMounts(Array.Empty<WeaponModelView.Mount>());
                    PrefabUtility.SaveAsPrefabAsset(root, target);
                }
                finally { Object.DestroyImmediate(root); }
            }
            var catalog = AssetDatabase.LoadAssetAtPath<EquipmentAssetCatalog>(EquipmentAssets.CatalogPath);
            if (catalog == null) throw new InvalidOperationException("Missing equipment catalog.");
            var rows = JsonUtility.FromJson<AssetRows>(File.ReadAllText("Config/Tables/Equipment/EquipmentAssetTable.json")).rows;
            var entries = new List<EquipmentAssetCatalog.Entry>();
            foreach (var row in rows)
            {
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(row.prefabPath);
                if (prefab == null) throw new InvalidOperationException("Missing equipment prefab: " + row.prefabPath);
                entries.Add(new EquipmentAssetCatalog.Entry { Id = row.id, Path = row.prefabPath, Prefab = prefab });
            }
            catalog.SetEntries(entries.ToArray()); EditorUtility.SetDirty(catalog);
            var settings = AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(PawnAnimationAssets.SetPath);
            if (Array.Find(settings.Holds, value => value.PoseId == 9) == null)
            {
                var hold = JsonUtility.FromJson<PawnAnimationSet.Hold>(JsonUtility.ToJson(settings.GetHold(2)));
                hold.PoseId = 9; var holds = new List<PawnAnimationSet.Hold>(settings.Holds) { hold }; settings.Holds = holds.ToArray();
            }
            if (Array.Find(settings.Actions, value => value.TemplateId == 9) == null)
            {
                var sourceAction = settings.GetAction(5);
                var action = new PawnAnimationSet.Action { TemplateId = 9, State = sourceAction.State, Clip = sourceAction.Clip,
                    Duration = .65f, Impact = .48f, UseAuthoredGrip = true, GripKeys = new[] {
                        Key(0, 76, 0), Key(.28f, 82, -.10f), Key(.48f, 90, .22f), Key(.62f, 90, .18f), Key(1, 76, 0) } };
                var actions = new List<PawnAnimationSet.Action>(settings.Actions) { action }; settings.Actions = actions.ToArray();
            }
            EditorUtility.SetDirty(settings); AssetDatabase.SaveAssetIfDirty(settings); AssetDatabase.SaveAssetIfDirty(catalog);
            EquipmentIconExporter.ExportItems(new[] { 742 });
            EquipmentAssets.SyncItemIcons(); AssetDatabase.SaveAssetIfDirty(catalog);
        }
        private static PawnAnimationSet.GripKey Key(float time, float pitch, float forward)
            => new PawnAnimationSet.GripKey { Time = time, WeaponRotation = new Vector3(pitch, 0, 0), WeaponPosition = new Vector3(0, 0, forward) };
    }
}
