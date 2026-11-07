// Saved Prefabs only, isolated PreviewScene; no Play and no active-scene edits.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=original.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();int cases=0;
try
{
    var health=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/HudHealthWidget.prefab"));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(health,scene);
    var reference=health.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
    var ring=reference.GetImage("Morale");
    if(ring.color!=Color.white || ring.raycastTarget || ring.type!=UnityEngine.UI.Image.Type.Filled)throw new System.Exception("White radial morale image binding invalid");
    foreach(float ratio in new[]{0f,.25f,.5f,.75f,1f})
    {
        ring.fillAmount=ratio;
        using(var vertices=new UnityEngine.UI.VertexHelper())
        {
            ring.GetComponent<ProjectY.UI.HealthRingMesh>().ModifyMesh(vertices);
            if((vertices.currentVertCount==0)!=(ratio==0))throw new System.Exception("Morale fill mesh failed");
            var vertex=new UnityEngine.UIVertex();
            for(int i=0;i<vertices.currentVertCount;i++){vertices.PopulateUIVertex(ref vertex,i);if(float.IsNaN(vertex.position.x))throw new System.Exception("Invalid ring vertex");}
        }
        cases++;
    }
    var journal=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab"));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(journal,scene);
    var view=journal.GetComponent<ProjectY.UI.LuaReference>();view.ValidateBindings();
    foreach(var key in new[]{"TitlesTab","TitlesTabText","Titles","TitleSummary","TitleRows","TitleRowsScroll","TitleDetail","TitleDetailScroll","TitleEquip","TitleEquipText"})
        if(view.Get(key)==null)throw new System.Exception("Missing title UI binding: "+key);
    var left=(UnityEngine.UI.ScrollRect)view.Get("TitleRowsScroll");var right=(UnityEngine.UI.ScrollRect)view.Get("TitleDetailScroll");
    if(left.viewport.anchorMin!=Vector2.zero || left.viewport.anchorMax!=Vector2.one || right.content.childCount!=1)
        throw new System.Exception("Title scrolling bounds invalid");
    var localizations=view.GetEditorLocalizations();int bound=0;
    foreach(var entry in localizations)if((entry.Id=="TitleTab" && entry.Target==view.Get("TitlesTabText")) || (entry.Id=="TitleEquip" && entry.Target==view.Get("TitleEquipText")))bound++;
    if(bound!=2)throw new System.Exception("Title labels need saved localization keys");
    var style=new UnityEditor.SerializedObject(view.Get("Style"));var glyphs=style.FindProperty("glyphs");int courage=0;
    for(int i=0;i<glyphs.arraySize;i++)if(glyphs.GetArrayElementAtIndex(i).FindPropertyRelative("Code").stringValue=="courage"
        && glyphs.GetArrayElementAtIndex(i).FindPropertyRelative("Sprite").objectReferenceValue!=null)courage++;
    if(courage!=1)throw new System.Exception("Courage glyph must have exactly one saved binding");
    view.Get("Titles").gameObject.SetActive(true);
    view.GetText("TitleDetail").text=new string('x',2000);
    UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(right.content);
    if(right.content.rect.height<=right.viewport.rect.height)throw new System.Exception("Long title requirements did not produce scrollable content");
    cases++;
}
finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=original || original.isDirty!=dirty)throw new System.Exception("UI validation changed active scene");
return "Passed "+cases+" saved UI cases: white ring ratios, explicit bindings, localized title controls, courage glyph and scrollable detail.";
