using System;
using System.IO;
using System.Runtime.CompilerServices;
using ProjectY.UI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using XLua;

namespace ProjectY.Editor
{
    public static class BattleHUDValidation
    {
        [MenuItem("Project Y/UI/验证战斗 HUD")]
        public static void Run()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("此检查在独立 PreviewScene 中运行，请先退出 Play。");
            var scene = EditorSceneManager.NewPreviewScene();
            var root = new GameObject("BattleHUDValidation"); SceneManager.MoveGameObjectToScene(root, scene);
            var host = root.AddComponent<UIHost>(); host.Initialize();
            try
            {
                using (var lua = new LuaEnv())
                {
                    var services = new FrameworkServices(host);
                    var loader = new LuaFileLoader(LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
                    lua.Global.Set("Services", services);
                    try { Debug.Log(RunChecks(lua)); }
                    finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
                }
            }
            finally { host.Shutdown(); EditorSceneManager.ClosePreviewScene(scene); }
        }
        [MethodImpl(MethodImplOptions.NoInlining)]
        private static string RunChecks(LuaEnv lua)
        {
            var path = Path.Combine(Directory.GetParent(Application.dataPath).FullName, "Tools/Tests/battle_hud_integration.lua");
            return (string)lua.DoString(File.ReadAllText(path), "@" + path)[0];
        }
    }
}
