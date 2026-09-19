using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using UnityEngine;
using XLua;

namespace ProjectY.UI
{
    public enum UIKind { Panel, Widget }

    [Serializable, LuaCallCSharp]
    public sealed class PanelDefinition
    {
        public string Name = "NewUI";
        public string Module = "Common";
        public UIKind Kind;
        public string Layer = "Main";
        public bool Modal;
        public bool Cache = true;
        public bool CloseOnBack = true;
        public bool IsWorldUI;
        [Tooltip("Reserved flag. Runtime hot switching is not implemented yet.")]
        public bool SupportsHotSwitch;
        public bool PauseWorldOnOpen;
        public bool CloseOnSceneChange = true;
        public GameObject Prefab;

        public bool IsWidget => Kind == UIKind.Widget;
        public string PrefabName => Name + (IsWidget ? "Widget" : "Panel");
        public string PrefabPath => PanelConfig.PrefabRoot + "/" + Module + "/" + PrefabName + ".prefab";
        public string ControllerModule => "UI." + (IsWidget ? "Widget." + Name : "Panel." + Name + "Ctr");
        public string ViewType => Name + (IsWidget ? "WidgetView" : "PanelView");

        public void Validate(bool requirePrefab)
        {
            if (!PanelConfig.IsIdentifier(Name) || !PanelConfig.IsIdentifier(Module))
                throw new InvalidOperationException("UI name and module must be identifiers: " + Name + " / " + Module);
            if (Kind != UIKind.Panel && Kind != UIKind.Widget) throw new InvalidOperationException("Invalid UI kind.");
            if (Layer != "Background" && Layer != "Main" && Layer != "Popup" && Layer != "Overlay")
                throw new InvalidOperationException(Name + ": unknown UI layer " + Layer);
            if (!requirePrefab) return;
            if (Prefab == null) throw new InvalidOperationException(Name + ": generate its prefab first.");
            var view = Prefab.GetComponent<LuaReference>();
            if (view == null) throw new InvalidOperationException(Name + ": root LuaReference is required.");
            view.ValidateBindings();
            if (!IsWidget && (Prefab.GetComponent<LuaPanel>() == null || Prefab.GetComponent<Canvas>() == null))
                throw new InvalidOperationException(Name + ": root LuaPanel and Canvas are required.");
        }
    }

    /// <summary>Single UI registry. Direct references include DynamicAsset prefabs in player builds.</summary>
    public sealed class PanelConfig : ScriptableObject
    {
        public const string AssetPath = "Assets/DynamicAsset/UI/Resources/PanelConfig.asset";
        public const string ResourceName = "PanelConfig";
        public const string PrefabRoot = "Assets/DynamicAsset/UI/Prefabs";
        public List<PanelDefinition> Entries = new List<PanelDefinition>();

        public static bool IsIdentifier(string value) => LuaReference.IsValidKey(value) && Regex.IsMatch(value, @"\A[A-Za-z][A-Za-z0-9_]*\z") &&
            !Regex.IsMatch(value, @"\A(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\z");

        public PanelDefinition Get(string name)
        {
            foreach (var entry in Entries) if (entry.Name == name) return entry;
            throw new ArgumentException("Unknown UI config: " + name);
        }

        public void Validate(bool requirePrefabs)
        {
            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var modules = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var entry in Entries)
            {
                if (entry == null) throw new InvalidOperationException("Empty UI config entry.");
                entry.Validate(requirePrefabs);
                if (!names.Add(entry.Name)) throw new InvalidOperationException("Duplicate UI name (including case): " + entry.Name);
                if (modules.TryGetValue(entry.Module, out var module) && module != entry.Module)
                    throw new InvalidOperationException("Case-colliding UI module: " + entry.Module);
                modules[entry.Module] = entry.Module;
            }
        }
    }
}
