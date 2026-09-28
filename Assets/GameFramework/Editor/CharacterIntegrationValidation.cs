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
                using (var lua = new LuaEnv())
                {
                    var loader = new LuaFileLoader(LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
                    lua.Global.Set("AppearanceFixtureJson", File.ReadAllText("Art/PawnCustomization/Integration/web-example.json"));
                    try
                    {
                        using (var report = (LuaTable)lua.DoString(File.ReadAllText("Tools/Tests/character_integration.lua"))[0])
                        {
                            string saved = File.ReadAllText(file); File.WriteAllText(file, "{broken");
                            lua.DoString("AssertCorruptCharacterSaveRejected()");
                            File.WriteAllText(file, saved.Replace("\"version\": 1", "\"version\": 99")); lua.DoString("AssertCorruptCharacterSaveRejected()");
                            File.WriteAllText("Art/PawnCustomization/Integration/gameplay-validation.json", "{\"saveRoundTrip\":true,\"backpackRoundTrip\":true,\"healthPreserved\":true,\"stableEnemy\":true,\"corruptRejected\":true,\"unknownVersionRejected\":true,\"partyCount\":" + report.Get<int>("partyCount") + ",\"enemyGroups\":" + report.Get<int>("enemyGroups") + "}");
                            Debug.Log("Character generation and profile save/load passed, including corrupt/unknown-version rejection.");
                        }
                    }
                    finally { lua.DoString("if CloseCharacterIntegrationFixture then CloseCharacterIntegrationFixture() end"); lua.Global.Set<string, object>("Services", null); }
                }
            }
            finally
            {
                services.Player.ClearListeners();
                // The fixture created only these three exact files under the OS temp directory.
                foreach (var path in new[] { file, file + ".bak", file + ".tmp" }) if (File.Exists(path)) File.Delete(path);
            }
        }
    }
}
