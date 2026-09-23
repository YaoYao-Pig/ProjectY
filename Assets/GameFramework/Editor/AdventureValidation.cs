using System;
using System.IO;
using System.Runtime.CompilerServices;
using UnityEditor;
using UnityEngine;
using XLua;

namespace ProjectY.Editor
{
    public static class AdventureValidation
    {
        [MenuItem("Project Y/远征/验证战斗与事件")]
        public static void Run() => RunFile("Tools/Tests/adventure_integration.lua");
        [MenuItem("Project Y/地图/验证 MapArea 地牢")]
        public static void RunArea() => RunFile("Tools/Tests/maparea_integration.lua");
        [MenuItem("Project Y/地图/验证城镇漫游")]
        public static void RunTown() => RunFile("Tools/Tests/town_integration.lua");
        private static void RunFile(string relativePath)
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("此检查使用独立数据，请先退出 Play。");
            using (var lua = new LuaEnv())
            {
                var services = new FrameworkServices(null);
                var loader = new LuaFileLoader(LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
                lua.Global.Set("Services", services);
                try { Debug.Log(RunChecks(lua, relativePath)); }
                finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
            }
        }
        [MethodImpl(MethodImplOptions.NoInlining)]
        private static string RunChecks(LuaEnv lua, string relativePath)
        {
            var path = Path.Combine(Directory.GetParent(Application.dataPath).FullName, relativePath);
            return (string)lua.DoString(File.ReadAllText(path), "@" + path)[0];
        }
    }
}
