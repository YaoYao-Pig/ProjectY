using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Persist the repair action on the existing inventory panel without rebuilding its layout.</summary>
    public static class EquipmentRepairAssets
    {
        [MenuItem("Project Y/装备/同步耐久维修按钮")]
        public static void Sync()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("维修按钮同步需要 Edit Mode。");
            var entry = PanelAssets.LoadOrCreate().Entries.Find(e => e.Name == "Inventory");
            if (entry == null) throw new InvalidOperationException("先同步现有背包界面。");
            var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference = root.GetComponent<LuaReference>();
                var bindings = new List<LuaReference.Entry>(reference.GetEditorBindings());
                if (!bindings.Exists(binding => binding.Key == "Repair"))
                {
                    var source = reference.GetButton("Workbench");
                    var repair = UnityEngine.Object.Instantiate(source, source.transform.parent);
                    repair.name = "Repair";
                    var rect = (RectTransform)repair.transform;
                    rect.anchoredPosition = ((RectTransform)source.transform).anchoredPosition + new Vector2(0, -48);
                    var label = repair.GetComponentInChildren<Text>(true);
                    if (label == null) throw new InvalidOperationException("现有工坊按钮缺少文字模板。");
                    label.text = "维修装备";
                    bindings.Add(new LuaReference.Entry("Repair", repair));
                    bindings.Add(new LuaReference.Entry("RepairText", label));
                    reference.SetEditorBindings(bindings.ToArray());
                }
                reference.ValidateBindings();
                var view = root.GetComponent<InventoryPanelView>();
                view.EditorLayout.Labels = root.GetComponentsInChildren<Text>(true);
                EditorUtility.SetDirty(view);
                PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
                LuaViewHints.Export(reference, entry.ViewType);
            }
            finally { PrefabUtility.UnloadPrefabContents(root); }
            AssetDatabase.SaveAssets();
            Debug.Log("Inventory repair action and LuaReference bindings saved.");
        }
    }
}
