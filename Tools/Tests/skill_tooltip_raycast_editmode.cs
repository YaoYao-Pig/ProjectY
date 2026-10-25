// Unity MCP execute_code body. Saved button/card, real UGUI raycasts and InputModule hover dispatch; no Play.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalDirty = originalScene.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var target = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
target.Create();
try
{
    var cameraObject = new GameObject("Tooltip hover camera", typeof(Camera));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, scene);
    var camera = cameraObject.GetComponent<Camera>();
    camera.enabled = false; camera.scene = scene; camera.orthographic = true; camera.orthographicSize = 360;
    camera.aspect = 1280f / 720; camera.nearClipPlane = .1f; camera.farClipPlane = 2000;
    camera.transform.position = new Vector3(0, 0, -1000); camera.targetTexture = target;
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab");
    var root = UnityEngine.Object.Instantiate(prefab);
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root, scene);
    var canvas = root.GetComponent<Canvas>(); canvas.renderMode = RenderMode.WorldSpace; canvas.worldCamera = camera;
    root.GetComponent<UnityEngine.UI.CanvasScaler>().enabled = false;
    var rect = (RectTransform)root.transform;
    rect.sizeDelta = new Vector2(1280, 720); rect.localPosition = Vector3.zero; rect.localScale = Vector3.one;
    var hud = root.GetComponent<ProjectY.UI.BattleHUDView>(); hud.Prepare(); hud.PreviewLayout(1280);
    var reference = root.GetComponent<ProjectY.UI.LuaReference>();
    var tip = (ProjectY.UI.SkillTooltipView)reference.Get("SkillTip");
    foreach (Transform child in hud.EditorLayout.SafeArea) if (child != tip.transform) child.gameObject.SetActive(false);
    var buttonPrefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleActionWidget.prefab");
    var button = UnityEngine.Object.Instantiate(buttonPrefab, hud.EditorLayout.SafeArea);
    var buttonReference = button.GetComponent<ProjectY.UI.LuaReference>();
    var hover = (ProjectY.UI.UIPointerState)buttonReference.Get("Pointer");
    var anchor = (RectTransform)buttonReference.Get("Root");
    anchor.anchorMin = anchor.anchorMax = anchor.pivot = new Vector2(.5f, .5f);
    anchor.anchoredPosition = new Vector2(-300, -230); anchor.sizeDelta = new Vector2(120, 72);
    var events = new GameObject("Tooltip hover events", typeof(UnityEngine.EventSystems.EventSystem), typeof(UnityEngine.EventSystems.StandaloneInputModule));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(events, scene);
    var module = events.GetComponent<UnityEngine.EventSystems.StandaloneInputModule>();
    var pointer = new UnityEngine.EventSystems.PointerEventData(events.GetComponent<UnityEngine.EventSystems.EventSystem>());
    var dispatch = typeof(UnityEngine.EventSystems.BaseInputModule).GetMethod("HandlePointerExitAndEnter",
        System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
    var raycaster = root.GetComponent<UnityEngine.UI.GraphicRaycaster>();
    var hits = new System.Collections.Generic.List<UnityEngine.EventSystems.RaycastResult>();
    System.Action render = () => { Canvas.ForceUpdateCanvases(); ProjectY.Rendering.UrpCameraRendering.Render(camera); };
    System.Func<RectTransform, Vector2> center = node => camera.WorldToScreenPoint(node.TransformPoint(node.rect.center));
    System.Action<Vector2, bool> move = (position, sendEvents) => {
        pointer.position = position; hits.Clear(); raycaster.Raycast(pointer, hits);
        pointer.pointerCurrentRaycast = hits.Count == 0 ? new UnityEngine.EventSystems.RaycastResult() : hits[0];
        if (sendEvents) dispatch.Invoke(module, new object[] { pointer, pointer.pointerCurrentRaycast.gameObject });
    };
    System.Action<bool, string> check = (passed, message) => { if (!passed) throw new System.Exception(message); };
    var outside = new Vector2(-10, -10);

    render(); move(center(anchor), true);
    check(hover.Hovered, "Actual skill button raycast must enter its bound UIPointerState");
    tip.Begin("Hover regression", "<link=\"term:hit\">Hit</link> description"); tip.Show(anchor); render();
    check(tip.KeepOpen(hover.Hovered), "A hovered button must retain the tooltip after a long hover");
    move(outside, true);
    check(!hover.Hovered, "Real pointer exit must clear the skill button");
    check(!tip.KeepOpen(hover.Hovered), "Leaving the button must dismiss immediately");
    move(center(tip.EditorLayout.Body.rectTransform), true);
    check(pointer.pointerCurrentRaycast.gameObject == tip.EditorLayout.Body.gameObject, "Card text must participate in the actual raycast");
    check(tip.ContainsPointer(), "Entering a TMP child must hover the parent card");
    check(tip.KeepOpen(hover.Hovered), "Card contents must retain the tooltip for term navigation");
    tip.Begin("Term", "Nested description"); tip.Show(anchor); render();
    move(center(tip.EditorLayout.Body.rectTransform), true);
    check(tip.ContainsPointer(), "Term navigation must keep hover inside the card");
    move(outside, true);
    check(!tip.ContainsPointer(), "Leaving actual card graphics must clear parent hover");
    check(!tip.KeepOpen(hover.Hovered), "Leaving both actual button and card must expire");

    // Input can update its hit before an exit callback reaches a cached controller (e.g. a changed UI hierarchy).
    move(center(anchor), true); check(hover.Hovered, "Button must re-enter");
    move(outside, false);
    check(!hover.Hovered, "A stale button enter must not retain hover after the current raycast moves outside");
    check(!tip.KeepOpen(hover.Hovered), "A missed button exit must not keep renewing the card deadline");
    move(outside, true); move(center(tip.EditorLayout.Body.rectTransform), true);
    check(tip.ContainsPointer(), "Card must re-enter");
    move(outside, false);
    check(!tip.ContainsPointer(), "A stale card enter must not retain hover after the current raycast moves outside");
    check(!tip.KeepOpen(false), "A missed card exit must not keep renewing its own deadline");
    move(outside, true); move(center(tip.EditorLayout.Body.rectTransform), true);
    tip.Hide(); tip.Show(anchor); render();
    check(!tip.ContainsPointer() && !tip.KeepOpen(false), "Cached reopen must require a new enter event");
    tip.Hide();
}
finally
{
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    target.Release(); UnityEngine.Object.DestroyImmediate(target);
}
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != originalDirty)
    throw new System.Exception("Tooltip raycast regression changed the user's scene");
return "PASS actual button/card raycasts, InputModule enter/exit, TMP child hover, term navigation, stale exit expiry and cached reopen; no Play";
