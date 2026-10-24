// Unity MCP execute_code body. Run after SyncLogExpansion; isolated real prefab, no Play or save access.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();object result;
try
{
    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab");
    if(prefab==null)throw new System.Exception("BattleHUD prefab missing");
    var root=UnityEngine.Object.Instantiate(prefab);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var canvas=root.GetComponent<UnityEngine.Canvas>();canvas.renderMode=UnityEngine.RenderMode.WorldSpace;
    var scaler=root.GetComponent<UnityEngine.UI.CanvasScaler>();if(scaler!=null)scaler.enabled=false;
    var rect=(UnityEngine.RectTransform)root.transform;rect.sizeDelta=new UnityEngine.Vector2(1280,720);
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
    var view=root.GetComponent<ProjectY.UI.BattleHUDView>();view.Prepare();UnityEngine.Canvas.ForceUpdateCanvases();
    var layout=view.EditorLayout;var scroll=(UnityEngine.UI.ScrollRect)reference.Get("LogScroll");
    var text=reference.GetText("Logs");
    if(layout.LogScroll!=scroll || layout.LogText!=text || layout.LogOpen!=reference.GetButton("LogOpen") || layout.LogClose!=reference.GetButton("LogClose"))
        throw new System.Exception("Persistent log layout and LuaReference bindings differ");
    if(!text.supportRichText || text.fontSize!=14 || text.horizontalOverflow!=UnityEngine.HorizontalWrapMode.Wrap || scroll.content!=text.rectTransform || scroll.verticalScrollbar==null)
        throw new System.Exception("Rich-text wrapping/content/scrollbar authoring is missing");
    var lines=new System.Collections.Generic.List<string>();
    for(int i=1;i<=80;i++)lines.Add("<color=#70B8E8><size=16>Actor "+i+"</size></color> casts <color=#EF8D85>Firebolt</color> → Target: <b>12 damage</b> · 75%");
    string full=string.Join("\n\n",lines),compact=string.Join("\n\n",lines.GetRange(77,3));
    ProjectY.UI.BattleLogPresentation.Set(view,false,compact,full,80);UnityEngine.Canvas.ForceUpdateCanvases();
    if(text.text!=compact || scroll.enabled || layout.LogClose.gameObject.activeSelf || !layout.LogOpen.interactable)
        throw new System.Exception("Compact mode does not retain the latest summary/open affordance");
    ProjectY.UI.BattleLogPresentation.Set(view,true,compact,full,80);UnityEngine.Canvas.ForceUpdateCanvases();
    if(text.text!=full || !scroll.enabled || !layout.LogClose.gameObject.activeSelf || !layout.Log.gameObject.activeSelf || scroll.content.rect.height<=scroll.viewport.rect.height)
        throw new System.Exception("Expanded log cannot scroll the complete retained history");
    if(scroll.verticalNormalizedPosition>.02f)throw new System.Exception("Expanded log did not initially show the latest record");
    scroll.verticalNormalizedPosition=.7f;float offset=scroll.content.anchoredPosition.y;
    lines.RemoveAt(0);lines.Add("<color=#79D9A7>Healing result</color> · <b>8</b> · 35%");full=string.Join("\n\n",lines);
    ProjectY.UI.BattleLogPresentation.Set(view,true,compact,full,80);UnityEngine.Canvas.ForceUpdateCanvases();
    if(UnityEngine.Mathf.Abs(scroll.content.anchoredPosition.y-offset)>1)throw new System.Exception("New record pulled a reader away from the inspected history");
    scroll.verticalNormalizedPosition=0;lines[79]="<color=#79D9A7>Another result</color> · <b>9</b>";full=string.Join("\n\n",lines);
    ProjectY.UI.BattleLogPresentation.Set(view,true,compact,full,80);UnityEngine.Canvas.ForceUpdateCanvases();
    if(scroll.verticalNormalizedPosition>.02f)throw new System.Exception("A reader already at the bottom no longer follows new records");
    rect.sizeDelta=new UnityEngine.Vector2(800,720);ProjectY.UI.BattleLogPresentation.Set(view,false,compact,full,80);view.PreviewLayout(800);
    if(layout.Log.gameObject.activeSelf)throw new System.Exception("Small-screen compact log should leave room for controls");
    ProjectY.UI.BattleLogPresentation.Set(view,true,compact,full,80);UnityEngine.Canvas.ForceUpdateCanvases();
    if(!view.Compact || !layout.Log.gameObject.activeSelf || !scroll.enabled)throw new System.Exception("Small-screen explicit log expansion is unavailable");
    // Exercise Unity's actual rich-text generator, not a string-only assertion.
    var settings=text.GetGenerationSettings(new UnityEngine.Vector2(640,20000));settings.generateOutOfBounds=true;
    text.cachedTextGenerator.Populate(full,settings);
    bool actorColor=false,resultColor=false;
    foreach(var vertex in text.cachedTextGenerator.verts)
    {
        if(vertex.color.r==0x70 && vertex.color.g==0xB8 && vertex.color.b==0xE8)actorColor=true;
        if(vertex.color.r==0x79 && vertex.color.g==0xD9 && vertex.color.b==0xA7)resultColor=true;
    }
    if(!actorColor || !resultColor)throw new System.Exception("Unity text generation did not retain distinct role/result rich-text colors");
    result=new{passed=true,retainedRecords=80,scrollable=true,readerOffsetPreserved=true,bottomFollow=true,smallScreenExpansion=true,richTextColors=true,playMode=false};
}
finally {UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Battle log validation changed the user's scene");
return result;
