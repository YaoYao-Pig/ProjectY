// Unity MCP execute_code body: actual saved UI, candidate world, renderer and save, without Play.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var config = UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var entry = config.Get("Loading"); entry.Validate(true);
if (entry.Layer != "Overlay" || !entry.Modal || !entry.PauseWorldOnOpen || entry.CloseOnBack || entry.CloseOnSceneChange)
    throw new System.Exception("Loading panel policies are invalid");
var original = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var dirty = original.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var temporary = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "project-y-loading-" + System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(temporary);
UnityEngine.Debug.Log("Loading validation temporary directory: " + temporary);
ProjectY.UI.UIHost host = null; UnityEngine.Font font = null;
int checkpoints = 0, renderSteps = 0, restoreCheckpoints = 0;
try
{
    var root = new UnityEngine.GameObject("Loading isolated validation");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root, scene);
    host = root.AddComponent<ProjectY.UI.UIHost>(); host.Initialize();
    font = UnityEngine.Font.CreateDynamicFontFromOSFont(new[] { "Microsoft YaHei", "Noto Sans CJK SC", "Arial" }, 16);
    var services = new ProjectY.FrameworkServices(host, System.IO.Path.Combine(temporary, "party.json"));
    using (var lua = new XLua.LuaEnv())
    {
        var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
        lua.Global.Set("Services", services); lua.Global.Set("LoadingFixtureFont", font);
        try
        {
            ProjectY.Samples.MapPreviewData map;
            using (var data = (XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/loading_integration.lua"), "@loading_integration")[0])
                map = ProjectY.Samples.MapPreviewData.Read(data);
            using (var fixture = lua.Global.Get<XLua.LuaTable>("LoadingFixture")) checkpoints = fixture.Get<int>("steps");
            var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
            if (shader == null) throw new System.Exception("Map preview shader is missing");
            using (var renderer = new ProjectY.Samples.MapPreviewRenderer(shader, root.transform))
            {
                renderer.SetVisible(false);
                float previous = 0;
                foreach (var value in renderer.BuildIncremental(map, asset => UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path)))
                {
                    if (value < previous || value > 1) throw new System.Exception("Invalid rendering progress");
                    previous = value; renderSteps++;
                }
                if (previous != 1 || renderSteps < 10 || renderer.Bounds.size.sqrMagnitude <= 0) throw new System.Exception("Renderer did not complete");
                using (var state = (XLua.LuaTable)lua.DoString("return CommitLoadingFixture()")[0]) ProjectY.Samples.AdventureViewData.Read(state);
            }
            using (var data = (XLua.LuaTable)lua.DoString("return PrepareRestorationFixture()")[0])
                map = ProjectY.Samples.MapPreviewData.Read(data);
            using (var fixture = lua.Global.Get<XLua.LuaTable>("LoadingFixture")) restoreCheckpoints = fixture.Get<int>("restoreSteps");
            using (var renderer = new ProjectY.Samples.MapPreviewRenderer(shader, root.transform))
            {
                renderer.SetVisible(false);
                foreach (var value in renderer.BuildIncremental(map, asset => UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path)))
                    if (value < 0 || value > 1) throw new System.Exception("Invalid restore rendering progress");
                using (var state = (XLua.LuaTable)lua.DoString("return CommitRestorationFixture()")[0])
                {
                    var view=ProjectY.Samples.AdventureViewData.Read(state);
                    if(view.Area==null)throw new System.Exception("Saved local area was not restored");
                }
            }
        }
        finally
        {
            lua.DoString("if CloseLoadingFixture then CloseLoadingFixture() elseif GameShutdown then GameShutdown() end");
            services.Player.ClearListeners();
            lua.Global.Set<string, object>("Services", null); lua.Global.Set<string, object>("LoadingFixtureFont", null);
        }
    }
}
finally
{
    if (host != null) host.Shutdown();
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (font != null) UnityEngine.Object.DestroyImmediate(font);
    // The runner removes this reported, dedicated temp directory after checking its absolute path.
}
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != original || original.isDirty != dirty)
    throw new System.Exception("Loading validation changed the user's scene");
return new { passed = true, realPrefab = true, cells = 2500, checkpoints, renderSteps, restoreCheckpoints, namedSave = true, restoredArea = true, playMode = false, temporary };
