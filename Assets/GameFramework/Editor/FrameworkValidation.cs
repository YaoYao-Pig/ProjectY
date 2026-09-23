using System;
using System.IO;
using System.Text;
using ProjectY.Data;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using XLua;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Integration checks run with real Unity objects and the project's xLua native plugin.</summary>
    public static class FrameworkValidation
    {
        [MenuItem("Project Y/Tests/Run Integration Checks")]
        public static void Run()
        {
            if (EditorApplication.isPlaying) throw new InvalidOperationException("Stop Play Mode before running editor checks.");
            FrameworkTools.CreateDemo();
            CheckData(); CheckReferences(); CheckLuaFiles(); CheckLocalization(); CheckLuaUI();
            Debug.Log("PROJECT_Y_INTEGRATION_PASS: direct .lua loading, data, text lookup, UITxt subscriptions, references, Lua config, UI callbacks, modal lifecycle and LuaEnv disposal.");
        }

        // Batch-mode entry point: -executeMethod ProjectY.Editor.FrameworkValidation.Batch
        public static void Batch()
        {
            Run();
            CSObjectWrapEditor.Generator.GenAll();
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }
        private static void CheckData()
        {
            var data = new PlayerData(); var notifications = 0; Action listener = () => notifications++;
            data.AddChangedListener(listener); data.AddCoins(20);
            Require(!data.TrySpendCoins(21) && data.Coins == 20, "Unaffordable spending mutated state.");
            Require(data.TrySpendCoins(5) && data.Coins == 15, "Spending failed.");
            data.AdvanceLevel(); Require(data.Level == 2 && notifications == 3, "Data notifications incorrect.");
            data.RemoveChangedListener(listener); data.AddCoins(1); Require(notifications == 3, "Data unsubscribe failed.");
            try { data.AddCoins(-1); throw new Exception("Expected negative amount rejection"); } catch (ArgumentOutOfRangeException) { }
            data.AddCoins(int.MaxValue - data.Coins);
            try { data.AddCoins(1); throw new Exception("Expected overflow rejection"); } catch (OverflowException) { }
            Require(data.Coins == int.MaxValue, "Overflow mutated data.");
        }
        private static void CheckReferences()
        {
            var root = new GameObject("ReferenceTest");
            try
            {
                var view = root.AddComponent<LuaReference>();
                view.SetEditorBindings(new LuaReference.Entry("Self", root.transform)); view.ValidateBindings();
                Require(view.GetTransform("Self") == root.transform, "Typed reference lookup failed.");
                try { view.GetButton("Self"); throw new Exception("Expected reference type error"); } catch (InvalidOperationException) { }
                view.SetEditorBindings(new LuaReference.Entry("A", root.transform), new LuaReference.Entry("A", root.transform));
                try { view.ValidateBindings(); throw new Exception("Expected duplicate reference error"); } catch (InvalidOperationException) { }
            }
            finally { Object.DestroyImmediate(root); }
        }
        private static void CheckLuaFiles()
        {
            var root = LuaScriptPaths.RuntimeRoot;
            var loader = new LuaFileLoader(root);
            var module = "Core.Class";
            var bytes = loader.Load(ref module);
            Require(bytes != null && module.Replace('\\', '/').EndsWith("/Lua/Core/Class.lua"), "Module path mapping failed.");
            foreach (var invalid in new[] { "../Main", "Game/Systems", "..", "C:\\Main", "Main\n", "Main\\Other", "" })
            {
                var request = invalid;
                Require(loader.Load(ref request) == null && request == invalid, "Invalid require path accepted: " + invalid);
            }
            var missing = "DoesNotExist"; Require(loader.Load(ref missing) == null, "Missing module must return null.");

            // Reproduce the final StreamingAssets/Lua layout using the same file selection as the build callback.
            var temporary = Path.Combine(Path.GetTempPath(), "ProjectY-LuaLoader-" + Guid.NewGuid().ToString("N"));
            var playerRoot = Path.Combine(temporary, "StreamingAssets", "Lua");
            try
            {
                foreach (var file in LuaBuildFiles.Collect(root))
                {
                    var destination = Path.Combine(playerRoot, file.Substring(root.Length + 1));
                    Directory.CreateDirectory(Path.GetDirectoryName(destination));
                    File.Copy(file, destination);
                }
                File.WriteAllText(Path.Combine(playerRoot, "Bom.lua"), "return 42", new UTF8Encoding(true));
                var playerLoader = new LuaFileLoader(playerRoot);
                using (var env = new LuaEnv())
                {
                    env.AddLoader(playerLoader.Load);
                    env.DoString("assert(require('Bom') == 42); assert(type(require('Game.Systems')) == 'function'); assert(require('_Gen.Rewards').name == 'Rewards')", "LuaFileLoaderTest");
                }
                File.WriteAllText(Path.Combine(playerRoot, "Bad.Name.lua"), "return true");
                try { LuaBuildFiles.Collect(playerRoot); throw new Exception("Expected invalid build path rejection"); }
                catch (UnityEditor.Build.BuildFailedException) { }
            }
            finally { if (Directory.Exists(temporary)) Directory.Delete(temporary, true); }
        }

        private static void CheckLocalization()
        {
            var service = LocalizationService.Shared;
            service.Clear();
            Require(service.Resolve("PrefabTxt", "missing", "fallback") == "fallback", "Missing text fallback failed.");
            service.SetText("PrefabTxt", "Confirm", "");
            Require(service.Resolve("PrefabTxt", "Confirm", "fallback") == "", "Empty translations must override defaults.");
            var obj = new GameObject("UITxtValidation", typeof(RectTransform));
            try
            {
                var text = obj.AddComponent<UITxt>();
                text.DefaultText = "Edit-mode fallback";
                text.LocalizationId = "Confirm";
                Require(text.text == "Edit-mode fallback", "UITxt editor fallback failed.");
                var view = obj.AddComponent<LuaReference>();
                view.SetEditorBindings(new LuaReference.Entry("Label", text));
                Require(view.GetUITxt("Label") == text, "UITxt binding failed.");
                var changed = typeof(LocalizationService).GetField("Changed", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
                Require(((Action)changed.GetValue(service))?.GetInvocationList().Length == 1, "UITxt subscription missing.");
                text.enabled = false;
                Require(changed.GetValue(service) == null, "UITxt subscription leaked after disable.");
                text.enabled = true;
                Require(((Action)changed.GetValue(service))?.GetInvocationList().Length == 1, "UITxt duplicate subscription.");
            }
            finally { Object.DestroyImmediate(obj); service.Clear(); }
        }

        private static void CheckLuaUI()
        {
            var root = new GameObject("FrameworkIntegration"); var host = root.AddComponent<UIHost>(); host.Initialize();
            var services = new FrameworkServices(host); var lua = new LuaEnv();
            lua.AddLoader(new LuaFileLoader(LuaScriptPaths.RuntimeRoot).Load);
            try
            {
                lua.Global.Set("Services", services);
                lua.DoString(@"
                    local registry = require('Core.SystemRegistry')(Services)
                    require('Game.Systems')(registry)
                    registry:Start()
                    assert(require('Language').Confirm == Services.Localization:Find('LuaTxt', 'Confirm'))
                    assert(Services.Localization:Find('PrefabTxt', 'Common.Confirm') ~= nil)
                    _TestRegistry = registry
                    local ui = registry:Get('UI')
                    local panel = ui:Open('Demo')
                    assert(Services.Player.Coins == 0)
                    panel.view.Reward.onClick:Invoke()
                    assert(Services.Player.Coins == 15, 'Real UnityAction did not update C# data')
                    panel.view.LevelUp.onClick:Invoke()
                    panel.view.Reward.onClick:Invoke()
                    assert(Services.Player.Coins == 35 and Services.Player.Level == 2)
                    assert(panel.widgets[1].view.Stats.text:find('35'))
                    panel.view.Info.onClick:Invoke()
                    assert(ui.panels.Info.ctrl.visible)
                    ui.panels.Info.ctrl.view.Close.onClick:Invoke()
                    assert(ui.panels.Info == nil)
                    ui:Close('Demo')
                    assert(ui:Open('Demo') == panel, 'Cached panel must be reused')
                    panel.view.Reward.onClick:Invoke()
                    assert(Services.Player.Coins == 55, 'Duplicate listeners after cached reopen')
                    for i=1,25 do ui:Open('Info'); assert(ui:Back()) end
                    registry:Dispatch('Tick', 0.016, 0.016)
                    registry:Dispatch('FixedTick', 0.02)
                    registry:Dispatch('LateTick', 0.016, 0.016)
                    registry:Dispatch('OnPause', true)
                    registry:Shutdown(); _TestRegistry = nil
                    collectgarbage('collect')
                ", "FrameworkIntegration");
            }
            finally
            {
                try { lua.DoString("if _TestRegistry then _TestRegistry:Shutdown(); _TestRegistry=nil end"); }
                finally
                {
                    services.Player.ClearListeners(); host.Shutdown(); Object.DestroyImmediate(root);
                    lua.FullGc(); lua.Dispose();
                }
            }
        }
    }
}
