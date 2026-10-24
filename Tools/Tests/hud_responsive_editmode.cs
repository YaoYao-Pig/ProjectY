// Unity MCP execute_code body: real HUD prefabs in a disposable PreviewScene.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
int cases=0;
try
{
    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab");
    var root=UnityEngine.Object.Instantiate(prefab);
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var canvas=root.GetComponent<UnityEngine.Canvas>();canvas.renderMode=UnityEngine.RenderMode.WorldSpace;
    root.GetComponent<UnityEngine.UI.CanvasScaler>().enabled=false;
    var rect=(UnityEngine.RectTransform)root.transform;rect.localScale=UnityEngine.Vector3.one;
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var main=(ProjectY.UI.MainHudView)reference.Get("HUD");
    var battleReference=reference.GetReference("BattleContent");
    var battle=(ProjectY.UI.BattleHUDView)battleReference.Get("HUD");
    reference.Get("Exploration").gameObject.SetActive(false);
    battle.gameObject.SetActive(true);
    main.Prepare();main.SetMode(false,false);battle.Prepare();
    var layout=battle.EditorLayout;
    var controls=(UnityEngine.RectTransform)battleReference.GetButton("Auto").transform.parent;
    var menu=(UnityEngine.RectTransform)reference.Get("Menu");
    var mainLayout=new UnityEditor.SerializedObject(main).FindProperty("layout");
    var clock=(UnityEngine.RectTransform)mainLayout.FindPropertyRelative("Clock").objectReferenceValue;
    var rail=(UnityEngine.RectTransform)mainLayout.FindPropertyRelative("Rail").objectReferenceValue;
    var common=(UnityEngine.RectTransform)mainLayout.FindPropertyRelative("Common").objectReferenceValue;
    var corners=new UnityEngine.Vector3[4];
    System.Func<UnityEngine.RectTransform,UnityEngine.Rect> bounds=target=>
    {
        target.GetWorldCorners(corners);
        var min=(UnityEngine.Vector2)rect.InverseTransformPoint(corners[0]);
        var max=(UnityEngine.Vector2)rect.InverseTransformPoint(corners[2]);
        return UnityEngine.Rect.MinMaxRect(min.x,min.y,max.x,max.y);
    };
    var sizes=new[]{new UnityEngine.Vector2(1280,720),new UnityEngine.Vector2(1280,540),
        new UnityEngine.Vector2(1024,768),new UnityEngine.Vector2(800,600),
        new UnityEngine.Vector2(600,900),new UnityEngine.Vector2(1600,540)};
    foreach(var size in sizes)
    foreach(bool menuOpen in new[]{false,true})
    foreach(bool expanded in new[]{false,true})
    {
        rect.sizeDelta=size;menu.gameObject.SetActive(menuOpen);
        main.ApplyLayout();battle.ApplyLayout();
        ProjectY.UI.BattleLogPresentation.Set(battle,expanded,"Latest record","First record\n\nLatest record",2);
        UnityEngine.Canvas.ForceUpdateCanvases();
        var occupied=new System.Collections.Generic.List<UnityEngine.RectTransform>{
            layout.Header,layout.Turns,layout.Deck,layout.Commands,controls,clock,rail};
        if(layout.Log.gameObject.activeSelf)occupied.Add(layout.Log);
        if(menuOpen)occupied.Add(menu);
        var safe=bounds(common);
        foreach(var target in occupied)
        {
            var area=bounds(target);
            if(area.width<=0 || area.height<=0 || area.xMin<safe.xMin-.1f || area.xMax>safe.xMax+.1f ||
                area.yMin<safe.yMin-.1f || area.yMax>safe.yMax+.1f)
                throw new System.Exception(size+": "+target.name+" escaped safe bounds: "+area);
        }
        for(int i=0;i<occupied.Count;i++)
        for(int j=i+1;j<occupied.Count;j++)
        {
            var a=bounds(occupied[i]);var b=bounds(occupied[j]);
            if(UnityEngine.Mathf.Min(a.xMax,b.xMax)-UnityEngine.Mathf.Max(a.xMin,b.xMin)>.1f &&
                UnityEngine.Mathf.Min(a.yMax,b.yMax)-UnityEngine.Mathf.Max(a.yMin,b.yMin)>.1f)
                throw new System.Exception(size+": "+occupied[i].name+" overlaps "+occupied[j].name+
                    "; menu="+menuOpen+", expanded="+expanded);
        }
        if(bounds(reference.GetText("Coins").rectTransform).yMin<=bounds(rail).yMax)
            throw new System.Exception("Coins overlap the entry rail");
        if(expanded && (!layout.Log.gameObject.activeSelf || !layout.LogScroll.enabled))
            throw new System.Exception("Expanded log unavailable");
        cases++;
    }
    // Closing the menu and restoring size must restore space, including after cache reuse.
    rect.sizeDelta=new UnityEngine.Vector2(1280,720);menu.gameObject.SetActive(false);main.ApplyLayout();
    float closedWidth=layout.SafeArea.rect.width;
    menu.gameObject.SetActive(true);main.ApplyLayout();
    if(layout.SafeArea.rect.width>=closedWidth)throw new System.Exception("Menu opening did not reserve space");
    root.SetActive(false);menu.gameObject.SetActive(false);root.SetActive(true);main.Prepare();battle.Prepare();
    if(UnityEngine.Mathf.Abs(layout.SafeArea.rect.width-closedWidth)>.1f)
        throw new System.Exception("Menu closing/cache reuse did not release space");
}
finally {UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Responsive HUD checks changed the user's scene");
return new{passed=true,layoutCases=cases,menuSpaceRestored=true,playMode=false};
