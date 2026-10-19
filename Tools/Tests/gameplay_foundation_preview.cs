// Unity MCP execute_code body. Real UGUI Prefabs and LuaReference bindings in isolated Edit Mode hosts.
// Outputs: Docs/Previews/GameplayFoundation/professions.png and deployment.png.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required for gameplay foundation previews.");

var projectRoot = System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
var outputDirectory = System.IO.Path.Combine(projectRoot, "Docs/Previews/GameplayFoundation");
System.IO.Directory.CreateDirectory(outputDirectory);
var reports = new System.Collections.Generic.List<string>();
var failures = new System.Collections.Generic.List<System.Exception>();
const int width = 1280, height = 720;

foreach (var page in new[] { "professions", "deployment" })
{
    var previousTarget = UnityEngine.RenderTexture.active;
    var previousTimeScale = UnityEngine.Time.timeScale;
    var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
    UnityEngine.GameObject root = null, cameraObject = null;
    ProjectY.UI.UIHost host = null;
    UnityEngine.Camera camera = null;
    UnityEngine.RenderTexture target = null;
    UnityEngine.Texture2D image = null;
    XLua.LuaEnv lua = null;
    ProjectY.FrameworkServices services = null;
    // The preview performs no save operation; any unexpected save still cannot target the player's file.
    var savePath = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "project-y-foundation-preview-" + System.Guid.NewGuid().ToString("N") + ".json");
    try
    {
        root = new UnityEngine.GameObject("GameplayFoundationPreview-" + page);
        UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root, scene);
        host = root.AddComponent<ProjectY.UI.UIHost>();
        host.Initialize();

        lua = new XLua.LuaEnv();
        services = new ProjectY.FrameworkServices(host, savePath);
        var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
        lua.AddLoader(loader.Load);
        lua.Global.Set("Services", services);
        if (page == "professions")
        {
            var testPath = System.IO.Path.Combine(projectRoot, "Tools/Tests/growth_ui_integration.lua");
            var values = lua.DoString(System.IO.File.ReadAllText(testPath), "@" + testPath);
            foreach (var value in values)
            {
                if (value is string) reports.Add((string)value);
                var disposable = value as System.IDisposable;
                if (disposable != null) disposable.Dispose();
            }
            lua.DoString("assert(PreviewGrowthPage, 'Growth preview entry was not created'); PreviewGrowthPage('skills')");
        }
        else
        {
            lua.DoString(@"
FoundationBattlePreview = assert(loadfile('Tools/Tests/battle_hud_fixture.lua'))()(Services)
local fixture = FoundationBattlePreview
assert(fixture.battle.data.Phase == 'deployment' and fixture.battle.data.Round == 0)
fixture.battle:Active():Damage(12)
fixture.hud:Refresh()
assert(fixture.hud.model.phase == 'deployment' and #fixture.hud.model.skills > 0 and #fixture.hud.model.items == 2)
assert(fixture.hud.items[1].view.Button.interactable and fixture.hud.items[2].view.Button.interactable)
");
        }

        cameraObject = new UnityEngine.GameObject("GameplayFoundationPreviewCamera");
        UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, scene);
        camera = cameraObject.AddComponent<UnityEngine.Camera>();
        camera.enabled = false;
        camera.scene = scene;
        camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
        camera.transform.position = new UnityEngine.Vector3(0, 0, -10);
        camera.orthographic = true;
        camera.orthographicSize = height / 2f;
        camera.nearClipPlane = .1f;
        camera.farClipPlane = 100;
        camera.cullingMask = 1 << 31;
        camera.clearFlags = UnityEngine.CameraClearFlags.SolidColor;
        camera.backgroundColor = new UnityEngine.Color(.035f, .055f, .045f);
        ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
        target = new UnityEngine.RenderTexture(width, height, 24, UnityEngine.RenderTextureFormat.ARGB32);
        target.Create();
        camera.targetTexture = target;

        foreach (var child in root.GetComponentsInChildren<UnityEngine.Transform>(true)) child.gameObject.layer = 31;
        foreach (var canvas in root.GetComponentsInChildren<UnityEngine.Canvas>(true))
        {
            if (canvas.transform.parent == root.transform && canvas.renderMode != UnityEngine.RenderMode.WorldSpace)
            {
                canvas.renderMode = UnityEngine.RenderMode.ScreenSpaceCamera;
                canvas.worldCamera = camera;
                canvas.planeDistance = 1;
            }
        }
        UnityEngine.Canvas.ForceUpdateCanvases();
        foreach (var style in root.GetComponentsInChildren<ProjectY.UI.StoryGrowthView>()) style.Prepare();
        foreach (var style in root.GetComponentsInChildren<ProjectY.UI.BattleHUDView>()) style.PreviewLayout(width);
        UnityEngine.Canvas.ForceUpdateCanvases();
        ProjectY.Rendering.UrpCameraRendering.Render(camera);
        UnityEngine.RenderTexture.active = target;
        image = new UnityEngine.Texture2D(width, height, UnityEngine.TextureFormat.RGB24, false);
        image.ReadPixels(new UnityEngine.Rect(0, 0, width, height), 0, 0);
        image.Apply();
        var output = System.IO.Path.Combine(outputDirectory, page + ".png");
        System.IO.File.WriteAllBytes(output, image.EncodeToPNG());
        reports.Add("CAPTURE " + output + " (" + width + " x " + height + ")");
    }
    catch (System.Exception error)
    {
        failures.Add(new System.Exception("Preview failed: " + page, error));
    }
    finally
    {
        // Every cleanup action is attempted, even if registry shutdown itself raises an error.
        System.Action<System.Action> cleanup = action =>
        {
            try { action(); }
            catch (System.Exception error) { failures.Add(new System.Exception("Preview cleanup failed: " + page, error)); }
        };
        if (lua != null)
        {
            cleanup(() => lua.DoString(@"
if CloseGrowthPreview then CloseGrowthPreview() end
if FoundationBattlePreview then
    local fixture = FoundationBattlePreview
    FoundationBattlePreview = nil
    fixture.registry:Shutdown()
end
"));
            cleanup(() => lua.Global.Set<string, object>("Services", null));
        }
        if (services != null) cleanup(() => services.Player.ClearListeners());
        if (host != null) cleanup(() => host.Shutdown());
        if (lua != null) cleanup(() => lua.Dispose());
        cleanup(() => UnityEngine.Time.timeScale = previousTimeScale);
        cleanup(() => UnityEngine.RenderTexture.active = previousTarget);
        if (camera != null) cleanup(() => camera.targetTexture = null);
        if (image != null) cleanup(() => UnityEngine.Object.DestroyImmediate(image));
        if (target != null)
        {
            cleanup(() => target.Release());
            cleanup(() => UnityEngine.Object.DestroyImmediate(target));
        }
        if (cameraObject != null) cleanup(() => UnityEngine.Object.DestroyImmediate(cameraObject));
        if (root != null) cleanup(() => UnityEngine.Object.DestroyImmediate(root));
        cleanup(() => UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene));
    }
}
if (failures.Count > 0) throw new System.AggregateException(string.Join("\n", reports.ToArray()), failures);
return string.Join("\n", reports.ToArray());
