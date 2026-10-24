// Unity MCP execute_code body. Exercise the saved card's hover lifecycle without Play or real mouse input.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalDirty = originalScene.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
try
{
    var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab");
    var root = UnityEngine.Object.Instantiate(prefab);
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root, scene);
    var reference = root.GetComponent<ProjectY.UI.LuaReference>();
    var tip = (ProjectY.UI.SkillTooltipView)reference.Get("SkillTip");
    var anchor = (RectTransform)new GameObject("Hover test anchor", typeof(RectTransform)).transform;
    anchor.SetParent(tip.EditorLayout.Bounds, false);
    anchor.sizeDelta = new Vector2(120, 72);
    // Advance the grace deadline deterministically instead of waiting on an Editor input frame.
    var lastInside = typeof(ProjectY.UI.SkillTooltipView).GetField("lastPointerInside",
        System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
    System.Action expire = () => lastInside.SetValue(tip, Time.unscaledTime - 1f);
    System.Action<bool, string> check = (passed, message) => { if (!passed) throw new System.Exception(message); };
    var events = new GameObject("Hover test events", typeof(UnityEngine.EventSystems.EventSystem));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(events, scene);
    var pointer = new UnityEngine.EventSystems.PointerEventData(events.GetComponent<UnityEngine.EventSystems.EventSystem>());
    System.Action enter = () => {
        pointer.pointerCurrentRaycast = new UnityEngine.EventSystems.RaycastResult { gameObject = tip.gameObject };
        UnityEngine.EventSystems.ExecuteEvents.Execute(tip.gameObject, pointer, UnityEngine.EventSystems.ExecuteEvents.pointerEnterHandler);
    };
    System.Action exit = () => {
        pointer.pointerCurrentRaycast = new UnityEngine.EventSystems.RaycastResult();
        UnityEngine.EventSystems.ExecuteEvents.Execute(tip.gameObject, pointer, UnityEngine.EventSystems.ExecuteEvents.pointerExitHandler);
    };

    tip.Begin("Hover regression", "Skill description");
    tip.Show(anchor);
    expire();
    check(tip.KeepOpen(true), "A hovered skill must keep its card open");
    check(tip.KeepOpen(false), "Leaving the skill must allow crossing the card gap");
    expire();
    check(!tip.KeepOpen(false), "Leaving skill and card must expire the grace period");

    enter();
    check(tip.ContainsPointer(), "Pointer enter must reach the card");
    expire();
    check(tip.KeepOpen(false), "Hovering the card must keep terminology clickable");
    tip.Begin("Term", "Nested term description");
    tip.Show(anchor);
    check(tip.ContainsPointer(), "Term navigation must preserve the current card hover");
    exit();
    check(!tip.ContainsPointer(), "Pointer exit must clear the card hover immediately");
    check(tip.KeepOpen(false), "Card exit must retain the short crossing grace");
    expire();
    check(!tip.KeepOpen(false), "Card exit must stop retaining the tooltip after grace");

    enter();
    tip.Hide();
    check(!tip.ContainsPointer() && !tip.KeepOpen(true), "Hide must clear native hover state");
    tip.Show(anchor);
    expire();
    check(!tip.KeepOpen(false), "Cached reopen must not retain the old card hover");
    enter();
    anchor.gameObject.SetActive(false);
    check(!tip.KeepOpen(true), "A hidden anchor must invalidate the card");
    tip.Hide();
}
finally
{
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != originalDirty)
    throw new System.Exception("Hover validation changed the user's scene");
return "PASS native pointer enter/exit, anchor and card grace, term navigation, cached reopen and hidden anchor; no Play";
