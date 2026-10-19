using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using XLua;

namespace ProjectY.Editor
{
    public static class CharacterIntegrationValidation
    {
        [MenuItem("Project Y/角色/验证外观生成与角色存档")]
        public static void Run()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            var file = Path.Combine(Path.GetTempPath(), "project-y-character-" + Guid.NewGuid().ToString("N") + ".json");
            var services = new FrameworkServices(null, file);
            try
            {
                var lua = new LuaEnv();
                Exception failure = null;
                try
                {
                    var loader = new LuaFileLoader(LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
                    lua.Global.Set("AppearanceFixtureJson", File.ReadAllText("Art/PawnCustomization/Integration/web-example.json"));
                    using (var report = (LuaTable)lua.DoString(File.ReadAllText("Tools/Tests/character_integration.lua"))[0])
                    {
                        string saved = File.ReadAllText(file); File.WriteAllText(file, "{broken");
                        lua.DoString("AssertCorruptCharacterSaveRejected()");
                        var unknown = new System.Text.RegularExpressions.Regex("\"version\"\\s*:\\s*\\d+").Replace(saved, "\"version\": 99", 1);
                        if (unknown == saved) throw new InvalidOperationException("Missing save version fixture.");
                        File.WriteAllText(file, unknown); lua.DoString("AssertCorruptCharacterSaveRejected()");
                        var legacy = new System.Text.RegularExpressions.Regex("\"version\"\\s*:\\s*\\d+").Replace(saved, "\"version\": 4", 1);
                        File.WriteAllText(file, legacy); lua.DoString("AssertLegacyCharacterSaveMigrated()");
                        File.WriteAllText("Art/PawnCustomization/Integration/gameplay-validation.json", "{\"saveRoundTrip\":true,\"backpackRoundTrip\":true,\"healthPreserved\":true,\"stableEnemy\":true,\"corruptRejected\":true,\"unknownVersionRejected\":true,\"partyCount\":" + report.Get<int>("partyCount") + ",\"enemyGroups\":" + report.Get<int>("enemyGroups") + "}");
                        Debug.Log("Character generation and profile save/load passed, including corrupt/unknown-version rejection.");
                    }
                }
                catch (Exception error) { failure = error; }
                finally
                {
                    Cleanup(() => lua.DoString("if CloseCharacterIntegrationFixture then CloseCharacterIntegrationFixture() end"), ref failure);
                    // Remove C#-held delegates before disposing Lua, even if the fixture or its shutdown failed.
                    Cleanup(services.Player.ClearListeners, ref failure);
                    Cleanup(() => lua.Global.Set<string, object>("Services", null), ref failure);
                    Cleanup(lua.Dispose, ref failure);
                }
                if (failure != null) System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(failure).Throw();
            }
            finally
            {
                services.Player.ClearListeners();
                // The fixture created only these three exact files under the OS temp directory.
                foreach (var path in new[] { file, file + ".bak", file + ".tmp" }) if (File.Exists(path)) File.Delete(path);
            }
        }
        private static void Cleanup(Action action, ref Exception failure)
        {
            try { action(); }
            catch (Exception error)
            {
                failure = failure == null ? error : new AggregateException("Character validation and cleanup failed.", failure, error);
            }
        }
    }
}
