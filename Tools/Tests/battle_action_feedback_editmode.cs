// Unity MCP execute_code method body; existing real BattleHUD fixture in a separate PreviewScene, no Play.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleActionWidget.prefab");
if (prefab == null) throw new System.Exception("BattleAction prefab is missing");
var authored = prefab.GetComponent<ProjectY.UI.LuaReference>();
var authoredButton = authored.GetButton("Button"); var selectedFrame = (RectTransform)authored.Get("Selected");
if (authoredButton.transition != UnityEngine.UI.Selectable.Transition.ColorTint || authoredButton.targetGraphic.color != Color.white || selectedFrame.Find("SelectionMark") == null)
    throw new System.Exception("Run Project Y/UI/同步战斗技能悬停与选中反馈 before this check");
foreach (var edge in selectedFrame.GetComponentsInChildren<UnityEngine.UI.Image>(true))
{
    var rect = edge.rectTransform;
    if (edge.name == "Top" && Mathf.Abs(rect.offsetMin.y + 3) > .001f || edge.name == "Bottom" && Mathf.Abs(rect.offsetMax.y - 3) > .001f ||
        edge.name == "Left" && Mathf.Abs(rect.offsetMax.x - 3) > .001f || edge.name == "Right" && Mathf.Abs(rect.offsetMin.x + 3) > .001f)
        throw new System.Exception("Selection frame did not retain its authored 3-pixel thickness");
}
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var originalDirty = originalScene.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.UI.UIHost host = null;
object result;
try
{
    var root = new GameObject("BattleAction Feedback Validation"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root, scene);
    host = root.AddComponent<ProjectY.UI.UIHost>(); host.Initialize();
    using (var lua = new XLua.LuaEnv())
    {
        var services = new ProjectY.FrameworkServices(host, System.IO.Path.Combine(System.IO.Path.GetTempPath(), "battle-action-unused-" + System.Guid.NewGuid() + ".json"));
        var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
        try
        {
            using (var report = (XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/battle_action_feedback_integration.lua"), "@battle_action_feedback_integration")[0])
            {
                System.Func<string, float[]> color = name => { using (var row = report.Get<XLua.LuaTable>(name)) return new[] { row.Get<int, float>(1), row.Get<int, float>(2), row.Get<int, float>(3) }; };
                result = new { passed = true, idle = color("idle"), hover = color("hover"), selected = color("selected"), disabled = color("disabled"),
                    hoverPreserved = report.Get<bool>("hoverPreserved"), keyboardSelection = report.Get<bool>("keyboardSelection"), pointerExit = report.Get<bool>("pointerExit"),
                    disabledTooltip = report.Get<bool>("disabledTooltip"), cacheReuse = report.Get<bool>("cacheReuse"), clickListeners = report.Get<bool>("clickListeners"), playMode = false };
            }
        }
        finally { lua.Global.Set<string, object>("Services", null); services.Player.ClearListeners(); }
    }
}
finally
{
    if (host != null) host.Shutdown();
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != originalDirty)
    throw new System.Exception("Battle action validation changed the user's scene");
return result;
