// Unity MCP execute_code body. The saved pawn rig legitimately contains disabled, unassigned customization modules.
if (EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling) throw new System.Exception("Idle Edit Mode required");
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.BattleCinematic cinematic = null;
ProjectY.UI.SceneFocusMask mask = null;
try
{
    var prefab = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab");
    var pawn = UnityEngine.Object.Instantiate(prefab).GetComponent<ProjectY.Samples.PawnView>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn.gameObject, scene);
    // PawnView activates this skeleton for animated appearances; optional modules can remain disabled/unassigned.
    pawn.GetComponentInChildren<ProjectY.Samples.PawnAnimationView>(true).gameObject.SetActive(true);
    var dormant = new System.Collections.Generic.List<Renderer>();
    foreach (var renderer in pawn.GetComponentsInChildren<Renderer>())
        if (!renderer.enabled && System.Array.Exists(renderer.sharedMaterials, material => material == null)) dormant.Add(renderer);
    if (dormant.Count == 0) throw new System.Exception("Fixture no longer has the real disabled/unassigned customization modules");
    var canvas = new GameObject("Optional renderers test canvas", typeof(RectTransform), typeof(Canvas));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(canvas, scene);
    mask = ProjectY.UI.SceneFocusMask.Create((RectTransform)canvas.transform);
    cinematic = new ProjectY.Samples.BattleCinematic(new ProjectY.Samples.BattleCinematicSettings(), mask);
    cinematic.Begin(new[] { pawn }, .5f);
    if (!cinematic.Active) throw new System.Exception("Visible body did not enter the cinematic");
    var field = typeof(ProjectY.Samples.BattleCinematic).GetField("renderers", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
    var selected = (System.Collections.Generic.List<Renderer>)field.GetValue(cinematic);
    foreach (var renderer in selected)
        if (!renderer.enabled || !renderer.gameObject.activeInHierarchy) throw new System.Exception("Hidden renderer entered the mask/bounds collection");
    cinematic.Advance(.2f);
    var cameraObject = new GameObject("Optional renderers test camera");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, scene);
    var camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.orthographic = true; camera.aspect = 16f/9; camera.orthographicSize = 4;
    camera.transform.position = new Vector3(0, 5, -7); camera.transform.LookAt(Vector3.up);
    cinematic.ApplyCamera(camera, Vector3.up, 0, 45);
    foreach (var renderer in dormant)
    {
        var block = new MaterialPropertyBlock(); renderer.GetPropertyBlock(block, 0);
        if (!block.isEmpty || renderer.enabled) throw new System.Exception("Disabled module was modified by the cinematic");
    }
    cinematic.Clear();
    if (pawn.transform.position != Vector3.zero || cinematic.Active) throw new System.Exception("Cinematic failed to restore the actor");
    return new { passed = true, disabledUnassignedModules = dormant.Count, checks = "real prefab, disabled empty slots excluded, visible body focused, dormant properties unchanged, cleanup" };
}
finally
{
    if (cinematic != null) cinematic.Dispose(); else if (mask != null) mask.Dispose();
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
