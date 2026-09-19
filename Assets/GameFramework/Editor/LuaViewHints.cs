using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using ProjectY.UI;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    public static class LuaViewHints
    {
        // Add a component adapter here (or Register from another editor assembly), then add its xLua binding.
        private static readonly Dictionary<Type, string> Types = new Dictionary<Type, string>
        {
            {typeof(Transform), "CS.UnityEngine.Transform"}, {typeof(RectTransform), "CS.UnityEngine.RectTransform"},
            {typeof(Canvas), "CS.UnityEngine.Canvas"}, {typeof(CanvasGroup), "CS.UnityEngine.CanvasGroup"},
            {typeof(Button), "CS.UnityEngine.UI.Button"}, {typeof(Text), "CS.UnityEngine.UI.Text"},
            {typeof(Image), "CS.UnityEngine.UI.Image"}, {typeof(RawImage), "CS.UnityEngine.UI.RawImage"},
            {typeof(Toggle), "CS.UnityEngine.UI.Toggle"}, {typeof(Slider), "CS.UnityEngine.UI.Slider"},
            {typeof(Scrollbar), "CS.UnityEngine.UI.Scrollbar"}, {typeof(ScrollRect), "CS.UnityEngine.UI.ScrollRect"},
            {typeof(Dropdown), "CS.UnityEngine.UI.Dropdown"}, {typeof(InputField), "CS.UnityEngine.UI.InputField"},
            {typeof(CanvasScaler), "CS.UnityEngine.UI.CanvasScaler"}, {typeof(GraphicRaycaster), "CS.UnityEngine.UI.GraphicRaycaster"},
            {typeof(LuaReference), "CS.ProjectY.UI.LuaReference"}, {typeof(LuaPanel), "CS.ProjectY.UI.LuaPanel"},
            {typeof(UITxt), "CS.ProjectY.UI.UITxt"}, {typeof(TMPro.TextMeshProUGUI), "CS.TMPro.TextMeshProUGUI"}
        };
        public static void Register(Type component, string luaType) => Types[component] = luaType;

        public static string Export(LuaReference view, string viewType)
        {
            if (!PanelConfig.IsIdentifier(viewType)) throw new ArgumentException("View type must be an identifier.");
            view.ValidateBindings();
            var output = new StringBuilder("---@meta\n-- Generated from LuaReference. Do not edit; never require this file.\n---@class " + viewType + "\n");
            foreach (var entry in view.GetEditorBindings())
            {
                if (!Types.TryGetValue(entry.Target.GetType(), out var type))
                {
                    type = "CS.UnityEngine.Component";
                    Debug.LogWarning("No EmmyLua adapter for " + entry.Target.GetType().FullName + "; using Component.", view);
                }
                output.Append("---@field ").Append(entry.Key).Append(' ').Append(type).Append('\n');
            }
            output.Append("local View = {}\nreturn View\n");
            var path = Path.Combine(LuaScriptPaths.RuntimeRoot, "UI", "Types", viewType + ".lua");
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllText(path, output.ToString(), new UTF8Encoding(false));
            return path;
        }
    }
}
